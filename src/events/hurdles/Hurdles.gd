extends EventBase
## Event 3 — 110m Hurdles.
## Same alternate-A/B running as the sprint, plus press LB to jump each hurdle. Clean timing keeps your
## speed; a mistimed jump CLIPS the hurdle (speed loss); running into it grounded is a heavy COLLISION
## (big speed loss + a brief stumble). Two humans can race simultaneously; the rest are AI.

enum St { INTRO, MARKS, SET, RUN, DONE }

const PX_PER_M := 17.5
const DIST_M := 110.0
const START_X := 115.0
const FINISH_X := START_X + DIST_M * PX_PER_M
const WORLD_W := FINISH_X + 135.0
const LANE_Y := [490.0, 470.0, 450.0, 430.0]
const LANE_SCALE := [1.0, 0.94, 0.88, 0.82]
const RACE_TIMEOUT := 26.0

const JUMP_DUR := 0.44
const JUMP_H := 37.5
const HURDLE_M := [13.7, 22.8, 31.9, 41.0, 50.1, 59.2, 68.3, 77.4, 86.5, 95.6]

var stadium: Stadium
var cam: CameraManager
var runners: Array = []
var ai_values: Dictionary = {}
var state: St = St.INTRO
var state_t := 0.0
var set_wait := 1.2
var elapsed := 0.0
var _clock: Label
var _post_started := false        # all runners crossed; now running off-screen before results
var _post_t := 0.0
var hurdle_fall := {}             # (hurdle_index*100 + lane) -> tip progress 0..1
var tape_broken := false
var tape_t := 0.0
var tape_break_y := 0.0

const COAST_TOP_PX := 185.0       # px/s at full coast for the run-off

func _music_key() -> StringName:
	return &"track"

func _event_ready() -> void:
	ai_values = Game.roll_ai_values()

	stadium = Stadium.new()
	stadium.world_width = WORLD_W
	stadium.ground_y = LANE_Y[0]
	stadium.set_backdrop("res://assets/stadium/track.png")
	add_child(stadium)

	var ordered: Array = []
	for pi in range(Game.human_count()):
		var id := Game.country_for_player(pi)
		if id != &"":
			ordered.append(id)
	for id in Game.participants:
		if not ordered.has(id):
			ordered.append(id)

	for i in ordered.size():
		var id: StringName = ordered[i]
		var lane := i % LANE_Y.size()
		var ath := Athlete.new()
		ath.set_country(id)
		ath.set_state(Athlete.State.READY)
		ath.position = Vector2(START_X, LANE_Y[lane])
		ath.set_depth(LANE_SCALE[lane])
		ath.z_index = LANE_Y.size() - lane      # front lanes draw on top of back lanes
		add_child(ath)
		runners.append({
			"id": id, "human": Game.is_human(id), "pidx": Game.player_index_of(id),
			"lane": lane, "node": ath, "base_y": LANE_Y[lane],
			"engine": (RunEngine.new() if Game.is_human(id) else null),
			"target": float(ai_values.get(id, 15.0)),
			"dist": 0.0, "done": false, "time": 0.0,
			"air": false, "air_t": 0.0, "next_h": 0, "stumble": 0.0,
		})

	cam = CameraManager.new()
	add_child(cam)
	cam.setup(WORLD_W, 350.0)
	cam.set_targets(runners.map(func(r): return r["node"]))
	cam.make_current()

	_clock = UI.label("0.00", 25, Palette.PAPER)
	_clock.position = Vector2(Palette.BASE_WIDTH - 110, 10)
	hud.add_child(_clock)

	AudioBus.loop_crowd(true, -22.0)
	queue_redraw()
	_enter(St.MARKS)

func _enter(s: St) -> void:
	state = s
	state_t = 0.0
	match s:
		St.MARKS:
			banner_persist("ON YOUR MARKS", Palette.PAPER)
		St.SET:
			banner_persist("SET", Palette.HIGHLIGHT)
			set_wait = randf_range(0.7, 1.7)
			AudioBus.play(&"beep")
		St.RUN:
			banner("GO!", Palette.GOOD, 0.9)
			for r in runners:
				if r["engine"] != null:
					r["engine"].start()
			set_prompt("A / B  RUN      LB  JUMP THE HURDLES")
			AudioBus.play(&"go")

func _process(delta: float) -> void:
	super._process(delta)
	match state:
		St.MARKS:
			state_t += delta
			if _any_human_run():
				_false_start()
			elif state_t > 1.1:
				_enter(St.SET)
		St.SET:
			state_t += delta
			if _any_human_run():
				_false_start()
			elif state_t > set_wait:
				_enter(St.RUN)
		St.RUN:
			_run_step(delta)

func _any_human_run() -> bool:
	for r in runners:
		if r["human"]:
			var pi: int = r["pidx"]
			if Input.is_action_just_pressed(Platform.act(pi, &"a")) or Input.is_action_just_pressed(Platform.act(pi, &"b")):
				return true
	return false

func _false_start() -> void:
	AudioBus.play(&"foul")
	banner("FALSE START!", Palette.BAD, 1.3)
	for r in runners:
		r["dist"] = 0.0
		r["done"] = false
		r["next_h"] = 0
		r["air"] = false
		r["stumble"] = 0.0
		if r["engine"] != null:
			r["engine"].reset()
		r["node"].position = Vector2(START_X, r["base_y"])
		r["node"].set_state(Athlete.State.READY)
	elapsed = 0.0
	state = St.INTRO
	await get_tree().create_timer(1.3).timeout
	_enter(St.MARKS)

func _run_step(delta: float) -> void:
	elapsed += delta
	_clock.text = "%.2f" % elapsed
	for r in runners:
		if r["done"]:
			_coast(r, delta)                     # keep running through the line and off-screen
			continue
		if r["human"]:
			_human_step(r, delta)
		else:
			_ai_step(r)
		# hurdle crossing check
		while r["next_h"] < HURDLE_M.size() and r["dist"] >= HURDLE_M[r["next_h"]]:
			_cross_hurdle(r)
			r["next_h"] += 1
		# place
		r["node"].position.x = START_X + r["dist"] * PX_PER_M
		# vertical for jump arc
		if r["air"]:
			var p: float = clampf(r["air_t"] / JUMP_DUR, 0.0, 1.0)
			r["node"].position.y = r["base_y"] - sin(p * PI) * JUMP_H
			r["air_t"] += delta
			if r["air_t"] >= JUMP_DUR:
				r["air"] = false
				r["node"].position.y = r["base_y"]
		else:
			r["node"].position.y = r["base_y"]
		if r["dist"] >= DIST_M:
			r["done"] = true
			r["time"] = elapsed if r["human"] else r["target"]
			r["coast"] = maxf(r["node"].run_speed, 0.7)
			if not tape_broken:                  # first across breaks the tape
				tape_broken = true
				tape_break_y = r["base_y"] - 32.0

	# Advance falling hurdles + tape break.
	for k in hurdle_fall:
		hurdle_fall[k] = minf(1.0, float(hurdle_fall[k]) + delta / 0.35)
	if tape_broken:
		tape_t += delta

	if elapsed > RACE_TIMEOUT:
		for r in runners:
			if not r["done"]:
				r["done"] = true
				r["time"] = RACE_TIMEOUT
				r["coast"] = 0.7

	var all_done := true
	for r in runners:
		if not r["done"]:
			all_done = false
			break
	if all_done and not _post_started:
		_post_started = true
		_post_t = 0.0
		AudioBus.swell_crowd(-6.0)
		var mine := ""
		for r in runners:
			if r["human"]:
				mine = "%s  %.2f s" % [CountryData.abbrev_of(r["id"]), r["time"]]
				break
		banner_persist("FINISH!  %s" % mine, Palette.HIGHLIGHT)
		set_prompt("")
	if _post_started:
		_post_t += delta
		if _post_t > 2.2:
			_finish_race()

## A finished runner keeps running right (never celebrates) until it's off-screen.
func _coast(r: Dictionary, delta: float) -> void:
	r["coast"] = maxf(0.5, float(r["coast"]) - 0.15 * delta)
	r["node"].run_speed = r["coast"]
	r["node"].set_state(Athlete.State.RUN)
	r["node"].position.x += float(r["coast"]) * COAST_TOP_PX * delta
	r["node"].position.y = r["base_y"]

func _human_step(r: Dictionary, delta: float) -> void:
	var pi: int = r["pidx"]
	var eng: RunEngine = r["engine"]
	if r["stumble"] > 0.0:
		r["stumble"] -= delta
		r["node"].set_state(Athlete.State.STUMBLE)
		eng.update(delta)
		r["dist"] = eng.distance
		r["node"].run_speed = eng.speed_ratio()
		return
	if Input.is_action_just_pressed(Platform.act(pi, &"a")):
		eng.tap_a()
	if Input.is_action_just_pressed(Platform.act(pi, &"b")):
		eng.tap_b()
	if Input.is_action_just_pressed(Platform.act(pi, &"lb")) and not r["air"]:
		r["air"] = true
		r["air_t"] = 0.0
		AudioBus.play(&"jump", -4.0)
	eng.update(delta)
	r["dist"] = eng.distance
	r["node"].run_speed = eng.speed_ratio()
	if r["air"]:
		r["node"].set_state(Athlete.State.HURDLE)
	else:
		r["node"].set_state(Athlete.State.RUN if r["node"].run_speed > 0.012 else Athlete.State.IDLE)

func _ai_step(r: Dictionary) -> void:
	var x := clampf(elapsed / maxf(r["target"], 0.1), 0.0, 1.0)
	r["dist"] = DIST_M * pow(x, 1.05)
	r["node"].run_speed = clampf(1.1 - x * 0.15, 0.4, 1.0)
	r["node"].set_state(Athlete.State.RUN)
	# little auto-hop near hurdles for flavour
	if r["next_h"] < HURDLE_M.size():
		var d: float = HURDLE_M[r["next_h"]] - r["dist"]
		if not r["air"] and d < 1.4 and d > 0.0:
			r["air"] = true
			r["air_t"] = 0.0

func _cross_hurdle(r: Dictionary) -> void:
	if not r["human"]:
		return    # AI clears cleanly
	var eng: RunEngine = r["engine"]
	if r["air"]:
		var p: float = r["air_t"] / JUMP_DUR
		if p >= 0.12 and p <= 0.70:
			AudioBus.play(&"whoosh", -8.0)          # clean clear
		else:
			eng.speed *= 0.72                        # mistimed clip — clips and topples the hurdle
			hurdle_fall[r["next_h"] * 100 + r["lane"]] = 0.001
			AudioBus.play(&"clang", -4.0)
	else:
		# grounded collision: heavy — knock this lane's hurdle over
		eng.speed *= 0.4
		r["stumble"] = 0.5
		hurdle_fall[r["next_h"] * 100 + r["lane"]] = 0.001
		AudioBus.play(&"clang")
		AudioBus.play(&"foul", -6.0)
		banner("CLATTER!", Palette.BAD, 0.7)

func _finish_race() -> void:
	if state == St.DONE:
		return
	_enter(St.DONE)
	var human_values: Dictionary = {}
	for r in runners:
		if r["human"]:
			human_values[r["id"]] = r["time"]
	set_prompt("")
	finish(human_values, ai_values)

func _draw() -> void:
	# Start line just ahead of the runners' feet (centred on START_X) so they line up behind it.
	var start_line_x := START_X + 18.0
	draw_line(Vector2(start_line_x, 375), Vector2(start_line_x, 520), Palette.TRACK_LINE, 2.5)
	# Hurdles (back lanes first so nearer lanes overlap them), 3D-ish, with falls.
	for lane in range(LANE_Y.size() - 1, -1, -1):
		for hi in HURDLE_M.size():
			var hx: float = START_X + HURDLE_M[hi] * PX_PER_M
			_draw_hurdle(hx, LANE_Y[lane], LANE_SCALE[lane], float(hurdle_fall.get(hi * 100 + lane, 0.0)))
	# Finish line checker.
	var y := 375.0
	var on := true
	while y < 520.0:
		draw_rect(Rect2(FINISH_X - 5.0, y, 10.0, 10.0), Palette.PAPER if on else Palette.INK)
		on = not on
		y += 10.0
	_draw_tape()

## A side-on hurdle: a weighted base, two metal uprights and a striped top board. `fall` tips it
## forward (rotates about the base) when clattered.
func _draw_hurdle(hx: float, gy: float, s: float, fall: float) -> void:
	var h := 34.0 * s          # board height
	var w := 8.0 * s           # half base width (slimmer)
	var bw := w * 1.3
	var by := -h - 6.5 * s
	var bh := 6.0 * s
	var dep := Vector2(2.5 * s, -1.5 * s)   # small depth offset — mostly side-on, easy to read
	var metal := Color("cfd2da")
	var metal_d := Color("9195a0")
	var base := Palette.STAND_BASE.darkened(0.25)
	# Cast shadow on the track, projecting toward the approaching runner (a "jump now" cue). Flat on
	# the ground (drawn before the tip transform); fades as the hurdle falls.
	if fall < 1.0:
		var slen := h * 0.9
		var sy := gy + 2.0 * s
		draw_colored_polygon(PackedVector2Array([
			Vector2(hx - w * 0.5, sy), Vector2(hx + w * 0.6, sy),
			Vector2(hx + w * 0.6 - slen, sy + 4.0 * s), Vector2(hx - w * 0.5 - slen, sy + 4.0 * s),
		]), Color(0, 0, 0, 0.24 * (1.0 - fall)))
	draw_set_transform(Vector2(hx, gy), fall * PI / 2.0, Vector2.ONE)
	# --- Back frame (offset into the screen, darker) ---
	draw_rect(Rect2(-w * 1.1 + dep.x, -3.0 * s + dep.y, w * 2.2, 3.0 * s), base.darkened(0.25))
	draw_rect(Rect2(-w * 0.55 + dep.x, -h + dep.y, 2.5 * s, h), metal_d.darkened(0.2))
	draw_rect(Rect2(w * 0.35 + dep.x, -h + dep.y, 2.5 * s, h), metal_d.darkened(0.2))
	# --- Top face of the rail (parallelogram receding to the back) ---
	draw_colored_polygon(PackedVector2Array([
		Vector2(-bw, by), Vector2(bw, by), Vector2(bw + dep.x, by + dep.y), Vector2(-bw + dep.x, by + dep.y),
	]), Palette.PAPER.lightened(0.12))
	# --- Front frame ---
	draw_rect(Rect2(-w * 1.25, -3.5 * s, w * 2.5, 3.5 * s), base)
	draw_rect(Rect2(-w * 1.25, -3.5 * s, w * 2.5, 1.0 * s), base.lightened(0.2))
	draw_rect(Rect2(-w * 0.55, -h, 2.5 * s, h), metal)
	draw_rect(Rect2(w * 0.35, -h, 2.5 * s, h), metal)
	draw_rect(Rect2(-w * 0.55, -h * 0.45, w * 0.9, 1.5 * s), metal_d)   # cross-brace
	# --- Top board front face: white with black stripes + coloured leading edge ---
	draw_rect(Rect2(-bw, by, bw * 2.0, bh), Palette.PAPER)
	var sx := -bw
	var k := 0
	while sx < bw:
		if k % 2 == 1:
			draw_rect(Rect2(sx, by, 5.0 * s, bh), Palette.INK)
		sx += 5.0 * s
		k += 1
	draw_rect(Rect2(-bw, by, bw * 2.0, 2.0 * s), Palette.ACCENT)
	draw_rect(Rect2(-bw, by, bw * 2.0, bh), Palette.INK, false, 1.0 * s)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

## Finishing tape across the lanes at the line; snaps apart when the first runner crosses.
func _draw_tape() -> void:
	var top: float = LANE_Y[LANE_Y.size() - 1] - 40.0
	var bot: float = LANE_Y[0] - 26.0
	if not tape_broken:
		draw_line(Vector2(FINISH_X, top), Vector2(FINISH_X, bot), Palette.PAPER, 2.5)
		return
	var p := clampf(tape_t / 0.5, 0.0, 1.0)
	if p >= 1.0:
		return
	var by := clampf(tape_break_y, top, bot)
	var recoil := sin(p * PI) * 26.0          # ends whip out then settle
	var a := 1.0 - p
	var col := Color(Palette.PAPER.r, Palette.PAPER.g, Palette.PAPER.b, a)
	# upper half retracts toward the top anchor, lower toward the bottom
	draw_line(Vector2(FINISH_X, top), Vector2(FINISH_X - recoil, lerpf(by, top, p)), col, 2.5)
	draw_line(Vector2(FINISH_X, bot), Vector2(FINISH_X - recoil, lerpf(by, bot, p)), col, 2.5)
