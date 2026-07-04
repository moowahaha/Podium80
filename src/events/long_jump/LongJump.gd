extends EventBase
## Event 2 — Long Jump.
## Alternate A/B to build run-up speed, then press LB to take off. Distance depends only on run-up
## speed and take-off timing: leaving the ground right at the board maximises the measured jump;
## taking off early wastes distance (it's measured from the board); crossing the board is a FOUL.
## Three attempts, best counts.

enum St { APPROACH, FLIGHT, LANDED, BETWEEN, DONE }

const PX_PER_M := 30.0
const RUNUP_X := 60.0
const BOARD_X := 700.0          # longer run-up: board sits further down the runway, sand starts here
const WORLD_W := 1175.0
const ATTEMPTS := 3

var stadium: Stadium
var cam: CameraManager
var ath: Athlete
var engine := RunEngine.new()
var state: St = St.APPROACH
var target := 0.0                # best AI mark to beat (shown to the player)
var ai_values: Dictionary = {}
var players: Array = []          # human country ids in player order (turn-taking)
var best: Dictionary = {}        # country_id -> best mark
var player_attempt: Dictionary = {}  # player index -> attempts taken
var turn_order: Array = []       # round-robin sequence of player indices
var turn_idx := 0
var cur_id: StringName           # current jumper's country

# flight
var flight_t := 0.0
var flight_dur := 0.9
var takeoff_x := 0.0
var land_x := 0.0
var jump_h := 0.0
var measured := 0.0
var _info: Label
var _sand_flecks: Array = []     # static grain specks over the sand pit (seeded)
var _splash: SandSplash

func _music_key() -> StringName:
	return &"long_jump"

func _event_ready() -> void:
	ai_values = Game.roll_ai_values()
	for v in ai_values.values():
		target = maxf(target, float(v))
	players = humans()
	if players.is_empty():
		players = [Game.participants[0]]
	for i in players.size():
		best[players[i]] = 0.0
		player_attempt[i] = 0
	for _r in ATTEMPTS:
		for i in players.size():
			turn_order.append(i)

	stadium = Stadium.new()
	stadium.world_width = WORLD_W
	stadium.track_markings = false
	stadium.runway = true                                    # single run strip flanked by grass
	stadium.set_backdrop("res://assets/stadium/track.png")   # shares the running-stadium backdrop
	add_child(stadium)

	ath = Athlete.new()
	ath.set_country(players[0])
	add_child(ath)

	cam = CameraManager.new()
	add_child(cam)
	cam.setup(WORLD_W, 350.0)
	cam.max_zoom = 1.2
	cam.set_targets([ath])
	cam.make_current()

	_splash = SandSplash.new()
	add_child(_splash)
	_build_sand_texture()

	_info = UI.label("", 20, Palette.PAPER)
	_info.position = Vector2(15, 70)
	hud.add_child(_info)

	AudioBus.loop_crowd(true, -13.0)
	_begin_attempt()

func _begin_attempt() -> void:
	var cur: int = turn_order[turn_idx]
	cur_id = players[cur]
	player_attempt[cur] = int(player_attempt[cur]) + 1
	engine.reset()
	engine.start()
	ath.set_country(cur_id)
	ath.position = Vector2(RUNUP_X, stadium.ground_y)
	ath.set_state(Athlete.State.IDLE)         # standing at the runway, waiting to start the run-up
	measured = 0.0
	state = St.APPROACH
	_update_info()
	set_prompt("ALTERNATE  A / B  TO RUN     LB  TO JUMP AT THE BOARD")

func _update_info() -> void:
	var cur: int = turn_order[turn_idx]
	var who := "" if players.size() == 1 else "P%d   " % (cur + 1)
	_info.text = "%sATTEMPT %d/%d    BEST %.2f m    TARGET %.2f m" % [who, int(player_attempt[cur]), ATTEMPTS, float(best[cur_id]), target]

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
	var pi := Game.player_index_of(cur_id)
	if Input.is_action_just_pressed(Platform.act(pi, &"a")):
		engine.tap_a()
	if Input.is_action_just_pressed(Platform.act(pi, &"b")):
		engine.tap_b()
	engine.update(delta)
	ath.run_speed = engine.speed_ratio()
	ath.set_state(Athlete.State.RUN if ath.run_speed > 0.012 else Athlete.State.IDLE)
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
	jump_h = 30.0 + jump_len_m * 5.5
	flight_t = 0.0
	state = St.FLIGHT
	ath.set_state(Athlete.State.JUMP)
	AudioBus.play(&"jump")

func _flight(delta: float) -> void:
	flight_t += delta
	var p := clampf(flight_t / flight_dur, 0.0, 1.0)
	ath.anim01 = p                                # play the flight sprite through the arc
	ath.position.x = lerpf(takeoff_x, land_x, p)
	ath.position.y = stadium.ground_y - sin(p * PI) * jump_h
	if p >= 1.0:
		ath.position.y = stadium.ground_y
		ath.set_state(Athlete.State.LAND)
		AudioBus.play(&"land")
		_splash.burst(Vector2(land_x, stadium.ground_y + 6.0), clampf(1.0 + measured * 0.12, 1.0, 2.2))
		_record(measured, false)

func _foul(reason: String) -> void:
	AudioBus.play(&"foul")
	ath.set_state(Athlete.State.STUMBLE)
	banner("FOUL — %s" % reason, Palette.BAD, 1.4)
	_record(0.0, true)

func _record(mark: float, foul: bool) -> void:
	state = St.LANDED
	if not foul:
		if mark > float(best[cur_id]):
			best[cur_id] = mark
			banner("%.2f m  —  BEST!" % mark, Palette.HIGHLIGHT, 1.4)
			AudioBus.swell_crowd(-8.0)
		else:
			banner("%.2f m" % mark, Palette.PAPER, 1.4)
	_update_info()
	set_prompt("")
	await get_tree().create_timer(1.6).timeout
	turn_idx += 1
	if turn_idx >= turn_order.size():
		_finish()
	else:
		_begin_attempt()

func _finish() -> void:
	state = St.DONE
	if players.size() == 1:
		banner_persist("FINAL: %.2f m" % float(best[players[0]]), Palette.HIGHLIGHT)
	else:
		banner_persist("P1  %.2f m      P2  %.2f m" % [float(best[players[0]]), float(best[players[1]])], Palette.HIGHLIGHT)
	finish(best.duplicate(), ai_values)

## Pre-bake static grain for the sand so the pit reads as grippy sand, not a flat tan block. Seeded
## for a stable, non-shimmering texture.
func _build_sand_texture() -> void:
	_sand_flecks.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var y0 := stadium.ground_y - Stadium.RUNWAY_UP + 2.0
	var y1 := stadium.ground_y + Stadium.RUNWAY_DOWN - 2.0
	var base := Color("d9c48a")
	var count := int((WORLD_W - BOARD_X) * 1.1)
	for _i in count:
		var lighten := rng.randf() < 0.5
		var col := base.lightened(rng.randf_range(0.08, 0.28)) if lighten else base.darkened(rng.randf_range(0.10, 0.34))
		col.a = rng.randf_range(0.35, 0.7)
		_sand_flecks.append({
			"x": rng.randf_range(BOARD_X, WORLD_W),
			"y": rng.randf_range(y0, y1),
			"w": rng.randf_range(1.5, 3.0),
			"h": rng.randf_range(1.0, 2.5),
			"col": col,
		})

func _draw() -> void:
	# Sand pit + take-off board over the runway (fills the full strip thickness).
	draw_rect(Rect2(BOARD_X, stadium.ground_y - Stadium.RUNWAY_UP, WORLD_W - BOARD_X, Stadium.RUNWAY_UP + Stadium.RUNWAY_DOWN), Color("d9c48a"))
	for s in _sand_flecks:
		draw_rect(Rect2(s["x"], s["y"], s["w"], s["h"]), s["col"])
	draw_rect(Rect2(BOARD_X - 7.5, stadium.ground_y - 7.5, 10.0, 15.0), Palette.PAPER)   # board
	# distance guide marks every metre from the board
	for m in range(1, 12):
		var mx := BOARD_X + m * PX_PER_M
		if mx > WORLD_W:
			break
		draw_rect(Rect2(mx, stadium.ground_y + 20.0, 2.5, 7.5), Palette.INK)
	# target-to-beat line
	if target > 0.0:
		var tx := BOARD_X + target * PX_PER_M
		draw_line(Vector2(tx, stadium.ground_y - 40.0), Vector2(tx, stadium.ground_y + 30.0), Palette.HIGHLIGHT, 2.5)
