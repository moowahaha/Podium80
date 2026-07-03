extends EventBase
## Event 2 — Long Jump.
## Alternate A/B to build run-up speed, then press LB to take off. Distance depends only on run-up
## speed and take-off timing: leaving the ground right at the board maximises the measured jump;
## taking off early wastes distance (it's measured from the board); crossing the board is a FOUL.
## Three attempts, best counts.

enum St { APPROACH, FLIGHT, LANDED, BETWEEN, DONE }

const PX_PER_M := 12.0
const RUNUP_X := 24.0
const BOARD_X := 236.0
const WORLD_W := 470.0
const ATTEMPTS := 3

var stadium: Stadium
var cam: CameraManager
var ath: Athlete
var engine := RunEngine.new()
var state: St = St.APPROACH
var attempt := 1
var best_m := 0.0
var ai_values: Dictionary = {}
var human_id: StringName

# flight
var flight_t := 0.0
var flight_dur := 0.9
var takeoff_x := 0.0
var land_x := 0.0
var jump_h := 0.0
var measured := 0.0
var _info: Label

func _event_ready() -> void:
	ai_values = Game.roll_ai_values()
	human_id = humans()[0] if not humans().is_empty() else Game.participants[0]

	stadium = Stadium.new()
	stadium.world_width = WORLD_W
	stadium.track_markings = false
	stadium.set_backdrop("res://assets/stadium/long_jump.png")   # drop-in art; procedural fallback
	add_child(stadium)

	ath = Athlete.new()
	ath.set_country(human_id)
	add_child(ath)

	cam = CameraManager.new()
	add_child(cam)
	cam.setup(WORLD_W, 140.0)
	cam.max_zoom = 1.2
	cam.set_targets([ath])
	cam.make_current()

	_info = UI.label("", 8, Palette.PAPER)
	_info.position = Vector2(6, 28)
	hud.add_child(_info)

	AudioBus.loop_crowd(true, -22.0)
	_begin_attempt()

func _begin_attempt() -> void:
	engine.reset()
	engine.start()
	ath.position = Vector2(RUNUP_X, stadium.ground_y)
	ath.set_state(Athlete.State.READY)
	measured = 0.0
	state = St.APPROACH
	_update_info()
	set_prompt("ALTERNATE  A / B  TO RUN     LB  TO JUMP AT THE BOARD")

func _update_info() -> void:
	_info.text = "ATTEMPT %d/%d    BEST %.2f m" % [attempt, ATTEMPTS, best_m]

func _process(delta: float) -> void:
	super._process(delta)
	match state:
		St.APPROACH:
			_approach(delta)
		St.FLIGHT:
			_flight(delta)
		St.LANDED, St.BETWEEN, St.DONE:
			pass

func _approach(delta: float) -> void:
	var pi := Game.player_index_of(human_id)
	if Input.is_action_just_pressed(Platform.act(pi, &"a")):
		engine.tap_a()
	if Input.is_action_just_pressed(Platform.act(pi, &"b")):
		engine.tap_b()
	engine.update(delta)
	ath.run_speed = engine.speed_ratio()
	ath.set_state(Athlete.State.RUN)
	var x := RUNUP_X + engine.distance * PX_PER_M
	ath.position.x = x

	if Input.is_action_just_pressed(Platform.act(pi, &"lb")):
		if x <= BOARD_X:
			_take_off(x)
		else:
			_foul("OVERSTEP")
	elif x > BOARD_X + 2.0:
		_foul("RAN THROUGH")

func _take_off(x: float) -> void:
	takeoff_x = x
	var jump_len_m := 1.0 + engine.speed * 0.72         # air distance
	measured = maxf(0.0, jump_len_m - (BOARD_X - x) / PX_PER_M)   # measured from the board
	land_x = x + jump_len_m * PX_PER_M
	flight_dur = clampf(0.5 + jump_len_m * 0.06, 0.5, 1.1)
	jump_h = 12.0 + jump_len_m * 2.2
	flight_t = 0.0
	state = St.FLIGHT
	ath.set_state(Athlete.State.JUMP)
	AudioBus.play(&"jump")

func _flight(delta: float) -> void:
	flight_t += delta
	var p := clampf(flight_t / flight_dur, 0.0, 1.0)
	ath.position.x = lerpf(takeoff_x, land_x, p)
	ath.position.y = stadium.ground_y - sin(p * PI) * jump_h
	if p >= 1.0:
		ath.position.y = stadium.ground_y
		ath.set_state(Athlete.State.LAND)
		AudioBus.play(&"land")
		_record(measured, false)

func _foul(reason: String) -> void:
	AudioBus.play(&"foul")
	ath.set_state(Athlete.State.STUMBLE)
	banner("FOUL — %s" % reason, Palette.BAD, 1.4)
	_record(0.0, true)

func _record(mark: float, foul: bool) -> void:
	state = St.LANDED
	if not foul:
		if mark > best_m:
			best_m = mark
			banner("%.2f m  —  BEST!" % mark, Palette.HIGHLIGHT, 1.4)
			AudioBus.swell_crowd(-8.0)
		else:
			banner("%.2f m" % mark, Palette.PAPER, 1.4)
	_update_info()
	set_prompt("")
	await get_tree().create_timer(1.6).timeout
	if attempt >= ATTEMPTS:
		_finish()
	else:
		attempt += 1
		_begin_attempt()

func _finish() -> void:
	state = St.DONE
	banner_persist("FINAL: %.2f m" % best_m, Palette.HIGHLIGHT)
	finish({human_id: best_m}, ai_values)

func _draw() -> void:
	# Sand pit + take-off board over the track.
	draw_rect(Rect2(BOARD_X, stadium.ground_y - 2.0, WORLD_W - BOARD_X, 14.0), Color("d9c48a"))
	draw_rect(Rect2(BOARD_X - 3.0, stadium.ground_y - 3.0, 4.0, 6.0), Palette.PAPER)   # board
	# distance guide marks every metre from the board
	for m in range(1, 12):
		var mx := BOARD_X + m * PX_PER_M
		if mx > WORLD_W:
			break
		draw_rect(Rect2(mx, stadium.ground_y + 8.0, 1.0, 3.0), Palette.INK)
