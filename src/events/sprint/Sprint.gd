extends EventBase
## Event 1 — 100m Sprint.
## Countdown start with false-start detection, alternate-A/B running (shared RunEngine with light
## fatigue), all four nations racing in lanes, dynamic camera that keeps the field framed, a race
## clock and a finish. Humans run their own A/B; AI runners are animated to their pre-rolled times so
## the on-track finish order matches the scored result. Supports two simultaneous human sprinters.

enum St { INTRO, MARKS, SET, RUN, DONE }

const PX_PER_M := 17.5
const START_X := 115.0
const LANE_Y := [490.0, 470.0, 450.0, 430.0]
const LANE_SCALE := [1.0, 0.94, 0.88, 0.82]

# Race distance is data-driven (100m sprint vs 400m) — set from the event config.
var dist_m := 100.0
var finish_x := 1865.0
var world_w := 2000.0
var race_timeout := 22.0

var stadium: Stadium
var cam: CameraManager
var runners: Array = []           # [{id, human, pidx, lane, node, engine, target, dist, done, time}]
var ai_values: Dictionary = {}
var state: St = St.INTRO
var state_t := 0.0
var set_wait := 1.2
var elapsed := 0.0
var _clock: Label
var _false_count := 0
var _post_started := false        # all runners crossed; now running off-screen before results
var _post_t := 0.0
var tape_broken := false
var tape_t := 0.0
var tape_break_y := 0.0

const COAST_TOP_PX := 185.0       # px/s at full coast (≈ max speed) for the run-off

func _music_key() -> StringName:
	return &"track"

func _event_ready() -> void:
	ai_values = Game.roll_ai_values()
	dist_m = float(Game.current_event().get("dist", 100.0))
	finish_x = START_X + dist_m * PX_PER_M
	world_w = finish_x + 135.0
	race_timeout = dist_m * 0.15 + 12.0

	stadium = Stadium.new()
	stadium.world_width = world_w
	stadium.ground_y = LANE_Y[0]
	stadium.set_backdrop("res://assets/stadium/track.png")   # drop-in art; procedural fallback
	add_child(stadium)

	# Order nations: humans first (front lanes for visibility), then the rest.
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
		var human := Game.is_human(id)
		runners.append({
			"id": id, "human": human, "pidx": Game.player_index_of(id),
			"lane": lane, "node": ath,
			"engine": (RunEngine.new() if human else null),
			"target": float(ai_values.get(id, 12.0)),
			"dist": 0.0, "done": false, "time": 0.0,
		})

	cam = CameraManager.new()
	add_child(cam)
	cam.setup(world_w, 350.0)
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
			set_prompt("")
		St.SET:
			banner_persist("SET", Palette.HIGHLIGHT)
			set_wait = randf_range(0.7, 1.8)
			AudioBus.play(&"beep")
		St.RUN:
			_banner_go()
			for r in runners:
				if r["engine"] != null:
					r["engine"].start()
			set_prompt("ALTERNATE  A / B  TO RUN")
			AudioBus.play(&"go")
		St.DONE:
			pass

func _banner_go() -> void:
	banner("GO!", Palette.GOOD, 0.9)

func _process(delta: float) -> void:
	super._process(delta)
	match state:
		St.MARKS:
			state_t += delta
			if _any_human_run_pressed():
				_false_start()
			elif state_t > 1.1:
				_enter(St.SET)
		St.SET:
			state_t += delta
			if _any_human_run_pressed():
				_false_start()
			elif state_t > set_wait:
				_enter(St.RUN)
		St.RUN:
			_run_step(delta)
		St.DONE:
			pass

func _any_human_run_pressed() -> bool:
	for r in runners:
		if r["human"]:
			var pi: int = r["pidx"]
			if Input.is_action_just_pressed(Platform.act(pi, &"a")) or Input.is_action_just_pressed(Platform.act(pi, &"b")):
				return true
	return false

func _false_start() -> void:
	_false_count += 1
	AudioBus.play(&"foul")
	banner("FALSE START!", Palette.BAD, 1.3)
	# Reset runners and restart the countdown.
	for r in runners:
		r["dist"] = 0.0
		r["done"] = false
		r["time"] = 0.0
		if r["engine"] != null:
			r["engine"].reset()
		r["node"].position.x = START_X
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
			var pi: int = r["pidx"]
			var eng: RunEngine = r["engine"]
			if Input.is_action_just_pressed(Platform.act(pi, &"a")):
				eng.tap_a()
			if Input.is_action_just_pressed(Platform.act(pi, &"b")):
				eng.tap_b()
			eng.update(delta)
			r["dist"] = eng.distance
			r["node"].run_speed = eng.speed_ratio()
		else:
			var x := clampf(elapsed / maxf(r["target"], 0.1), 0.0, 1.0)
			r["dist"] = dist_m * pow(x, 1.06)
			r["node"].run_speed = clampf(1.2 - x * 0.2, 0.4, 1.0)
		# Standing pose only when genuinely stopped; while any speed remains the (distance-locked)
		# run cycle carries the deceleration so the feet don't slide.
		if r["human"] and r["node"].run_speed <= 0.012:
			r["node"].set_state(Athlete.State.IDLE)
		else:
			r["node"].set_state(Athlete.State.RUN)
		r["node"].position.x = START_X + r["dist"] * PX_PER_M
		if r["dist"] >= dist_m:
			r["done"] = true
			r["time"] = elapsed if r["human"] else r["target"]
			r["coast"] = maxf(r["node"].run_speed, 0.7)   # power through the line, don't celebrate
			AudioBus.play(&"step", -2.0, 1.5)
			if not tape_broken:
				tape_broken = true
				tape_break_y = LANE_Y[r["lane"]] - 32.0

	if tape_broken:
		tape_t += delta

	if elapsed > race_timeout:
		for r in runners:
			if not r["done"]:
				r["done"] = true
				r["time"] = race_timeout
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
		if _post_t > 2.2:                        # let them clear the screen, then results
			_finish_race()

## A finished runner keeps sprinting right (never celebrates on the line) until it's off-screen.
func _coast(r: Dictionary, delta: float) -> void:
	r["coast"] = maxf(0.5, float(r["coast"]) - 0.15 * delta)
	r["node"].run_speed = r["coast"]
	r["node"].set_state(Athlete.State.RUN)
	r["node"].position.x += float(r["coast"]) * COAST_TOP_PX * delta

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
	# Start + finish lines (world space).
	draw_line(Vector2(START_X, 375), Vector2(START_X, 520), Palette.TRACK_LINE, 2.5)
	# Checkered finish.
	var y := 375.0
	var on := true
	while y < 520.0:
		draw_rect(Rect2(finish_x - 5.0, y, 10.0, 10.0), Palette.PAPER if on else Palette.INK)
		on = not on
		y += 10.0
	_draw_tape()

## Finishing tape across the lanes; snaps apart when the first runner crosses.
func _draw_tape() -> void:
	var top: float = LANE_Y[LANE_Y.size() - 1] - 40.0
	var bot: float = LANE_Y[0] - 26.0
	if not tape_broken:
		draw_line(Vector2(finish_x, top), Vector2(finish_x, bot), Palette.PAPER, 2.5)
		return
	var p := clampf(tape_t / 0.5, 0.0, 1.0)
	if p >= 1.0:
		return
	var by := clampf(tape_break_y, top, bot)
	var recoil := sin(p * PI) * 26.0
	var a := 1.0 - p
	var col := Color(Palette.PAPER.r, Palette.PAPER.g, Palette.PAPER.b, a)
	draw_line(Vector2(finish_x, top), Vector2(finish_x - recoil, lerpf(by, top, p)), col, 2.5)
	draw_line(Vector2(finish_x, bot), Vector2(finish_x - recoil, lerpf(by, bot, p)), col, 2.5)
