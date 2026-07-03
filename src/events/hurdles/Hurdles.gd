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
	var all_done := true
	for r in runners:
		if r["done"]:
			continue
		all_done = false
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
			r["node"].position.x = FINISH_X
			r["node"].set_state(Athlete.State.CELEBRATE)

	if elapsed > RACE_TIMEOUT:
		for r in runners:
			if not r["done"]:
				r["done"] = true
				r["time"] = RACE_TIMEOUT
	if all_done or elapsed > RACE_TIMEOUT:
		_finish_race()

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
		r["node"].set_state(Athlete.State.RUN if r["node"].run_speed > 0.05 else Athlete.State.IDLE)

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
			eng.speed *= 0.72                        # mistimed clip
			AudioBus.play(&"clang", -4.0)
	else:
		# grounded collision: heavy
		eng.speed *= 0.4
		r["stumble"] = 0.5
		AudioBus.play(&"clang")
		AudioBus.play(&"foul", -6.0)
		banner("CLATTER!", Palette.BAD, 0.7)

func _finish_race() -> void:
	if state == St.DONE:
		return
	_enter(St.DONE)
	AudioBus.swell_crowd(-6.0)
	var human_values: Dictionary = {}
	var mine := ""
	for r in runners:
		if r["human"]:
			human_values[r["id"]] = r["time"]
			if mine == "":
				mine = "%s  %.2f s" % [CountryData.abbrev_of(r["id"]), r["time"]]
	banner_persist("FINISH!  %s" % mine, Palette.HIGHLIGHT)
	set_prompt("")
	finish(human_values, ai_values)

func _draw() -> void:
	draw_line(Vector2(START_X, 375), Vector2(START_X, 520), Palette.TRACK_LINE, 2.5)
	# hurdles
	for m in HURDLE_M:
		var hx: float = START_X + m * PX_PER_M
		for lane in LANE_Y.size():
			var gy: float = LANE_Y[lane]
			draw_rect(Rect2(hx - 2.5, gy - 22.0, 5.0, 22.0), Palette.PAPER)
			draw_rect(Rect2(hx - 7.5, gy - 22.0, 15.0, 5.0), Palette.ACCENT)
	# finish
	var y := 375.0
	var on := true
	while y < 520.0:
		draw_rect(Rect2(FINISH_X - 5.0, y, 10.0, 10.0), Palette.PAPER if on else Palette.INK)
		on = not on
		y += 10.0
