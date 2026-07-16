extends EventBase
## Event 5 — Triple Jump.
## Alternate A/B to build run-up speed, L to take off at the board, then time an L press at the
## landing of the HOP and the STEP to spring into the next phase — good timing keeps your momentum,
## poor timing (or a miss) bleeds it. Distance is the sum of the three phases, measured from the board.
## Three attempts, best counts. Reuses the run / leap (hurdle) / flight & landing (long jump) sprites.

enum St { APPROACH, PHASE, LANDED, DONE }

const PX_PER_M := 22.0
const RUNUP_X := 60.0
const BOARD_X := 470.0
const WORLD_W := 1080.0
const ATTEMPTS := 3
const PHASE_DUR := 0.70
const PHASE_NAME := ["HOP", "STEP", "JUMP"]
const PIT_OFFSET_M := 12.0       # sand starts this far past the board — hop + step land on the runway
const LEAP_PLANT := 13.0         # foot bias that drops the leap pose so its feet reach the ground

var stadium: Stadium
var cam: CameraManager
var ath: Athlete
var engine := RunEngine.new()
var state: St = St.APPROACH
var target := 0.0
var ai_values: Dictionary = {}
var players: Array = []
var best: Dictionary = {}
var player_attempt: Dictionary = {}
var turn_order: Array = []
var turn_idx := 0
var cur_id: StringName

# jump phases
var cur_phase := 0                 # 0 hop, 1 step, 2 jump
var momentum := 0.0                # m/s carried through the phases
var phase_t := 0.0
var takeoff_x := 0.0
var pressed := false
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
	stadium.set_backdrop("res://assets/stadium/track.png")
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
	ath.set_state(Athlete.State.IDLE)
	ath.foot_bias = 0.0
	state = St.APPROACH
	_update_info()
	set_prompt("ALTERNATE  A / B  TO RUN     L  TO TAKE OFF AT THE BOARD")

func _update_info() -> void:
	var cur: int = turn_order[turn_idx]
	var who := "" if players.size() == 1 else "P%d   " % (cur + 1)
	_info.text = "%sATTEMPT %d/%d    BEST %.2f m    TARGET %.2f m" % [who, int(player_attempt[cur]), ATTEMPTS, float(best[cur_id]), target]

func _process(delta: float) -> void:
	super._process(delta)
	match state:
		St.APPROACH:
			_approach(delta)
		St.PHASE:
			_phase_step(delta)

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
	if Input.is_action_just_pressed(Platform.act(pi, &"l")):
		if x <= BOARD_X:
			takeoff_x = x
			momentum = engine.speed
			_start_phase(0)
		else:
			_foul("OVERSTEP")
	elif x > BOARD_X + 2.0:
		_foul("RAN THROUGH")

func _start_phase(idx: int) -> void:
	cur_phase = idx
	phase_t = 0.0
	pressed = false
	state = St.PHASE
	ath.set_state(Athlete.State.HURDLE)      # leap into the phase
	ath.foot_bias = LEAP_PLANT
	AudioBus.play(&"jump", -2.0, 1.0 + idx * 0.1)
	if idx < 2:
		set_prompt("L  —  %s !" % PHASE_NAME[idx + 1])
	else:
		set_prompt("")

func _phase_step(delta: float) -> void:
	var pi := Game.player_index_of(cur_id)
	phase_t += delta
	var p := clampf(phase_t / PHASE_DUR, 0.0, 1.2)
	# Move forward at the current momentum; arc up and down.
	ath.position.x += momentum * PX_PER_M * delta
	var height := 30.0 + momentum * 6.0
	ath.position.y = stadium.ground_y - sin(minf(p, 1.0) * PI) * height
	# Hop and step just leap (hurdle pose); only the final jump into the sand leaps then spins.
	if cur_phase < 2:
		ath.set_state(Athlete.State.HURDLE)
		ath.foot_bias = LEAP_PLANT
	elif p < 0.28:
		ath.set_state(Athlete.State.HURDLE)
		ath.foot_bias = LEAP_PLANT
	else:
		ath.set_state(Athlete.State.JUMP)
		ath.foot_bias = 0.0
		ath.anim01 = clampf((p - 0.28) / 0.72, 0.0, 1.0)

	if cur_phase < 2:
		# Time the bounce into the next phase near the landing (p ~ 0.9).
		if not pressed and Input.is_action_just_pressed(Platform.act(pi, &"l")) and p >= 0.5:
			var acc := clampf(1.0 - absf(p - 0.9) / 0.32, 0.0, 1.0)
			momentum *= lerpf(0.55, 0.98, acc)
			pressed = true
			if acc > 0.8:
				banner("PERFECT!", Palette.GOOD, 0.5)
				AudioBus.play(&"points", -2.0, 1.4)
			elif acc > 0.4:
				banner("GOOD", Palette.HIGHLIGHT, 0.5)
				AudioBus.play(&"points", -4.0, 1.1)
			else:
				banner("TOO EARLY" if p < 0.9 else "TOO LATE", Palette.BAD, 0.5)
			_start_phase(cur_phase + 1)
		elif p >= 1.1:
			momentum *= 0.45                 # missed the bounce
			banner("TOO LATE!", Palette.BAD, 0.6)
			AudioBus.play(&"clang", -4.0)
			_start_phase(cur_phase + 1)
	else:
		if p >= 1.0:
			ath.position.y = stadium.ground_y
			ath.set_state(Athlete.State.LAND)
			AudioBus.play(&"land")
			_splash.burst(Vector2(ath.position.x, stadium.ground_y + 6.0), 1.7)
			_record(maxf(0.0, (ath.position.x - BOARD_X) / PX_PER_M), false)

func _foul(reason: String) -> void:
	AudioBus.play(&"foul")
	ath.foot_bias = 0.0
	ath.set_state(Athlete.State.STUMBLE)
	banner("FOUL — %s" % reason, Palette.BAD, 1.4)
	_record(0.0, true)

func _record(mark: float, foul: bool) -> void:
	state = St.LANDED
	if not foul:
		target = maxf(target, mark)   # a mark that beats the target-to-beat moves the line up
		if mark > float(best[cur_id]):
			best[cur_id] = mark
			banner("%.2f m  —  BEST!" % mark, Palette.HIGHLIGHT, 1.5)
			AudioBus.swell_crowd(-8.0)
		else:
			banner("%.2f m" % mark, Palette.PAPER, 1.5)
	_update_info()
	set_prompt("")
	await get_tree().create_timer(1.7).timeout
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

## Pre-bake static grain so the pit reads as grippy sand, not a flat tan block (seeded, stable).
func _build_sand_texture() -> void:
	_sand_flecks.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var pit_x := BOARD_X + PIT_OFFSET_M * PX_PER_M
	var base := Color("d9c48a")
	var count := int((WORLD_W - pit_x) * 1.1)
	for _i in count:
		var lighten := rng.randf() < 0.5
		var col := base.lightened(rng.randf_range(0.08, 0.28)) if lighten else base.darkened(rng.randf_range(0.10, 0.34))
		col.a = rng.randf_range(0.35, 0.7)
		_sand_flecks.append({"x": rng.randf_range(pit_x, WORLD_W), "y": rng.randf_range(stadium.ground_y - Stadium.RUNWAY_UP + 2.0, stadium.ground_y + Stadium.RUNWAY_DOWN - 2.0), "w": rng.randf_range(1.5, 3.0), "h": rng.randf_range(1.0, 2.5), "col": col})

func _draw() -> void:
	# Take-off board + sand pit (pit is out where the final jump lands).
	var pit_x := BOARD_X + PIT_OFFSET_M * PX_PER_M
	draw_rect(Rect2(pit_x, stadium.ground_y - Stadium.RUNWAY_UP, WORLD_W - pit_x, Stadium.RUNWAY_UP + Stadium.RUNWAY_DOWN), Color("d9c48a"))
	for s in _sand_flecks:
		draw_rect(Rect2(s["x"], s["y"], s["w"], s["h"]), s["col"])
	draw_rect(Rect2(BOARD_X - 7.5, stadium.ground_y - 7.5, 10.0, 15.0), Palette.PAPER)   # board
	for m in range(1, 20):
		var mx := BOARD_X + m * PX_PER_M
		if mx > WORLD_W:
			break
		draw_rect(Rect2(mx, stadium.ground_y + 20.0, 2.5, 7.5), Palette.INK)
	if target > 0.0:
		var tx := BOARD_X + target * PX_PER_M
		draw_line(Vector2(tx, stadium.ground_y - 40.0), Vector2(tx, stadium.ground_y + 30.0), Palette.HIGHLIGHT, 2.5)
