extends EventBase
## Event 5 — 100m Swim, rendered SIDE-ON like the running events (stadium, stacked lanes, scrolling
## camera). Two lengths of a 50m pool: LB to DIVE on the start, alternate A/B to stroke, LB to flip-
## TURN at the far wall (the swimmer heads back), finish at the start wall. Two humans can race; the
## rest are AI. Lower time wins championship points.

enum St { INTRO, MARKS, SET, RACE, DONE }

const PX_PER_M := 20.0
const START_X := 120.0
const LENGTH_M := 50.0
const DIST_M := 100.0
const TURN_X := START_X + LENGTH_M * PX_PER_M
const WORLD_W := TURN_X + 130.0
const LANE_Y := [490.0, 470.0, 450.0, 430.0]
const LANE_SCALE := [1.0, 0.94, 0.88, 0.82]
const DIVE_WINDOW := 0.55
const TURN_ZONE := 47.5           # metres — LB turn window opens here
const RACE_TIMEOUT := 42.0

var stadium: Stadium
var cam: CameraManager
var swimmers: Array = []
var ai_values: Dictionary = {}
var state: St = St.INTRO
var state_t := 0.0
var set_wait := 1.2
var elapsed := 0.0
var _clock: Label

func _music_key() -> StringName:
	return &"swim"

func _event_ready() -> void:
	ai_values = Game.roll_ai_values()

	stadium = Stadium.new()
	stadium.world_width = WORLD_W
	stadium.surface = "pool"
	stadium.ground_y = LANE_Y[0]
	stadium.set_backdrop("res://assets/stadium/swim.png")
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
		var human := Game.is_human(id)
		var ath := Athlete.new()
		ath.set_country(id)
		ath.set_state(Athlete.State.READY)
		ath.position = Vector2(START_X, LANE_Y[lane])
		ath.set_depth(LANE_SCALE[lane])
		ath.z_index = LANE_Y.size() - lane      # front lanes draw on top of back lanes
		add_child(ath)
		var eng: RunEngine = null
		if human:
			eng = RunEngine.new()
			eng.max_speed = 7.6
			eng.impulse = 0.5
			eng.drag = 1.7
			eng.fatigue_gain = 0.03
			eng.fatigue_recover = 0.5
			eng.fatigue_cap = 0.5
		swimmers.append({
			"id": id, "human": human, "pidx": Game.player_index_of(id),
			"lane": lane, "node": ath, "base_y": LANE_Y[lane],
			"engine": eng, "target": float(ai_values.get(id, 18.0)),
			"dist": 0.0, "done": false, "time": 0.0,
			"dived": false, "dive_t": 0.0, "turned": false,
		})

	cam = CameraManager.new()
	add_child(cam)
	cam.setup(WORLD_W, 362.5)
	cam.set_targets(swimmers.map(func(s): return s["node"]))
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
			banner_persist("TAKE YOUR MARKS", Palette.PAPER)
			set_prompt("")
		St.SET:
			banner_persist("SET", Palette.HIGHLIGHT)
			set_wait = randf_range(0.7, 1.6)
			AudioBus.play(&"beep")
		St.RACE:
			banner("GO!  —  DIVE!", Palette.GOOD, 1.0)
			for sw in swimmers:
				if sw["engine"] != null:
					sw["engine"].start()
			set_prompt("LB  DIVE     A / B  STROKE     LB  TURN AT THE WALL")
			AudioBus.play(&"go")

func _process(delta: float) -> void:
	super._process(delta)
	match state:
		St.MARKS:
			state_t += delta
			if _any_human_input():
				_false_start()
			elif state_t > 1.1:
				_enter(St.SET)
		St.SET:
			state_t += delta
			if _any_human_input():
				_false_start()
			elif state_t > set_wait:
				_enter(St.RACE)
		St.RACE:
			_race_step(delta)

func _any_human_input() -> bool:
	for sw in swimmers:
		if sw["human"]:
			var pi: int = sw["pidx"]
			for b in [&"a", &"b", &"lb"]:
				if Input.is_action_just_pressed(Platform.act(pi, b)):
					return true
	return false

func _false_start() -> void:
	AudioBus.play(&"foul")
	banner("FALSE START!", Palette.BAD, 1.3)
	for sw in swimmers:
		sw["dist"] = 0.0
		sw["done"] = false
		sw["dived"] = false
		sw["dive_t"] = 0.0
		sw["turned"] = false
		if sw["engine"] != null:
			sw["engine"].reset()
		sw["node"].position = Vector2(START_X, sw["base_y"])
		sw["node"].facing = 1
		sw["node"].set_state(Athlete.State.READY)
	elapsed = 0.0
	state = St.INTRO
	await get_tree().create_timer(1.3).timeout
	_enter(St.MARKS)

func _race_step(delta: float) -> void:
	elapsed += delta
	_clock.text = "%.2f" % elapsed
	var all_done := true
	for sw in swimmers:
		if sw["done"]:
			continue
		all_done = false
		if sw["human"]:
			_human_step(sw, delta)
		else:
			_ai_step(sw)
		# turn at the far wall (once)
		if not sw["turned"] and sw["dist"] >= LENGTH_M:
			if sw["human"]:
				sw["engine"].speed *= 0.55           # missed the window
				AudioBus.play(&"clang", -4.0)
				banner("FUMBLED TURN!", Palette.BAD, 0.7)
			sw["turned"] = true
		_place(sw)
		if sw["dist"] >= DIST_M:
			sw["done"] = true
			sw["time"] = elapsed if sw["human"] else sw["target"]
			sw["node"].position.x = START_X
			sw["node"].set_state(Athlete.State.CELEBRATE)
			AudioBus.play(&"land", -4.0)

	if elapsed > RACE_TIMEOUT:
		for sw in swimmers:
			if not sw["done"]:
				sw["done"] = true
				sw["time"] = RACE_TIMEOUT
	if all_done or elapsed > RACE_TIMEOUT:
		_finish_race()

func _place(sw: Dictionary) -> void:
	var d: float = sw["dist"]
	var node: Athlete = sw["node"]
	if d <= LENGTH_M:
		node.position.x = START_X + d * PX_PER_M
		node.facing = 1
	else:
		node.position.x = TURN_X - (d - LENGTH_M) * PX_PER_M
		node.facing = -1
	if state != St.DONE and not sw["done"]:
		node.set_state(Athlete.State.SWIM)
		node.run_speed = _speed_ratio(sw)

func _human_step(sw: Dictionary, delta: float) -> void:
	var pi: int = sw["pidx"]
	var eng: RunEngine = sw["engine"]
	if not sw["dived"]:
		sw["dive_t"] += delta
		if Input.is_action_just_pressed(Platform.act(pi, &"lb")):
			var q := 1.0 - clampf(sw["dive_t"] / DIVE_WINDOW, 0.0, 1.0)
			eng.speed = lerpf(4.5, 7.6, q)
			sw["dived"] = true
			AudioBus.play(&"whoosh", -4.0)
		elif sw["dive_t"] > DIVE_WINDOW:
			eng.speed = 2.0
			sw["dived"] = true
		eng.update(delta)
		sw["dist"] = eng.distance
		return
	if Input.is_action_just_pressed(Platform.act(pi, &"a")):
		eng.tap_a()
	if Input.is_action_just_pressed(Platform.act(pi, &"b")):
		eng.tap_b()
	if not sw["turned"] and sw["dist"] >= TURN_ZONE and Input.is_action_just_pressed(Platform.act(pi, &"lb")):
		eng.speed = maxf(eng.speed, eng.speed * 1.12 + 1.2)
		sw["turned"] = true
		AudioBus.play(&"jump", -3.0)
	eng.update(delta)
	sw["dist"] = eng.distance

func _ai_step(sw: Dictionary) -> void:
	var x := clampf(elapsed / maxf(sw["target"], 0.1), 0.0, 1.0)
	sw["dist"] = DIST_M * pow(x, 1.04)

func _speed_ratio(sw: Dictionary) -> float:
	if sw["engine"] != null:
		return sw["engine"].speed_ratio()
	return clampf(1.0 - elapsed / maxf(sw["target"], 0.1) * 0.2, 0.4, 1.0)

func _finish_race() -> void:
	if state == St.DONE:
		return
	_enter(St.DONE)
	AudioBus.swell_crowd(-6.0)
	var human_values: Dictionary = {}
	var mine := ""
	for sw in swimmers:
		if sw["human"]:
			human_values[sw["id"]] = sw["time"]
			if mine == "":
				mine = "%s  %.2f s" % [CountryData.abbrev_of(sw["id"]), sw["time"]]
	banner_persist("FINISH!  %s" % mine, Palette.HIGHLIGHT)
	set_prompt("")
	finish(human_values, ai_values)

func _draw() -> void:
	# Start/finish wall and the turn wall (vertical), drawn over the water.
	draw_line(Vector2(START_X, 375), Vector2(START_X, 520), Palette.PAPER, 2.5)
	var y := 375.0
	var on := true
	while y < 520.0:
		draw_rect(Rect2(START_X - 5.0, y, 10.0, 10.0), Palette.PAPER if on else Palette.INK)
		on = not on
		y += 10.0
	draw_rect(Rect2(TURN_X - 2.5, 380, 7.5, 140.0), Palette.STAND_BASE)
	draw_rect(Rect2(TURN_X - 2.5, 380, 7.5, 140.0), Palette.TRACK_LINE, false, 2.5)
