extends EventBase
## Event 1 — 100m Sprint.
## Countdown start with false-start detection, alternate-A/B running (shared RunEngine with light
## fatigue), all four nations racing in lanes, dynamic camera that keeps the field framed, a race
## clock and a finish. Humans run their own A/B; AI runners are animated to their pre-rolled times so
## the on-track finish order matches the scored result. Supports two simultaneous human sprinters.

enum St { INTRO, MARKS, SET, RUN, DONE }

const PX_PER_M := 7.0
const DIST_M := 100.0
const START_X := 46.0
const FINISH_X := START_X + DIST_M * PX_PER_M
const WORLD_W := FINISH_X + 54.0
const LANE_Y := [196.0, 188.0, 180.0, 172.0]
const LANE_SCALE := [1.0, 0.94, 0.88, 0.82]
const RACE_TIMEOUT := 22.0

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

func _event_ready() -> void:
	ai_values = Game.roll_ai_values()

	stadium = Stadium.new()
	stadium.world_width = WORLD_W
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
		ath.scale = Vector2(LANE_SCALE[lane], LANE_SCALE[lane])
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
	cam.setup(WORLD_W, 140.0)
	cam.set_targets(runners.map(func(r): return r["node"]))
	cam.make_current()

	_clock = UI.label("0.00", 10, Palette.PAPER)
	_clock.position = Vector2(Palette.BASE_WIDTH - 44, 4)
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
	var all_done := true
	for r in runners:
		if r["done"]:
			continue
		all_done = false
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
			r["dist"] = DIST_M * pow(x, 1.06)
			r["node"].run_speed = clampf(1.2 - x * 0.2, 0.4, 1.0)
		r["node"].set_state(Athlete.State.RUN)
		r["node"].position.x = START_X + r["dist"] * PX_PER_M
		if r["dist"] >= DIST_M:
			r["done"] = true
			r["time"] = elapsed if r["human"] else r["target"]
			r["node"].position.x = FINISH_X
			r["node"].set_state(Athlete.State.CELEBRATE)
			AudioBus.play(&"step", -2.0, 1.5)

	if elapsed > RACE_TIMEOUT:
		for r in runners:
			if not r["done"]:
				r["done"] = true
				r["time"] = RACE_TIMEOUT
	if all_done or elapsed > RACE_TIMEOUT:
		_finish_race()

func _finish_race() -> void:
	if state == St.DONE:
		return
	_enter(St.DONE)
	AudioBus.swell_crowd(-6.0)
	var human_values: Dictionary = {}
	for r in runners:
		if r["human"]:
			human_values[r["id"]] = r["time"]
	# Show the human's headline time.
	var mine := ""
	for r in runners:
		if r["human"]:
			mine = "%s  %.2f s" % [CountryData.abbrev_of(r["id"]), r["time"]]
			break
	banner_persist("FINISH!  %s" % mine, Palette.HIGHLIGHT)
	set_prompt("")
	finish(human_values, ai_values)

func _draw() -> void:
	# Start + finish lines (world space).
	draw_line(Vector2(START_X, 150), Vector2(START_X, 208), Palette.TRACK_LINE, 1.0)
	# Checkered finish.
	var y := 150.0
	var on := true
	while y < 208.0:
		draw_rect(Rect2(FINISH_X - 2.0, y, 4.0, 4.0), Palette.PAPER if on else Palette.INK)
		on = not on
		y += 4.0
