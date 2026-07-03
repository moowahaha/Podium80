extends EventBase
## Event 4 — Hammer Throw.
## Alternate A/B rhythmically to build rotational speed; press LB to release. A rotating gauge shows
## the hammer head sweeping the circle — release while it is in the forward SECTOR for a legal throw
## (centre = best distance). Releasing outside the sector is a FOUL. Three attempts, best counts. The
## target line shows the mark to beat.

enum St { WINDUP, FLIGHT, LANDED, DONE }

const PX_PER_M := 8.75
const CIRCLE := Vector2(135.0, 375.0)
const GAUGE_C := Vector2(135.0, 240.0)
const GAUGE_R := 50.0
const SECTOR_HALF := 0.62               # legal release arc (radians) around forward (angle 0)
const FIELD_SECTOR := 0.52              # legal landing sector half-angle (radians)
const ATTEMPTS := 3

var stadium: Stadium
var ath: Athlete
var engine := RunEngine.new()
var ai_values: Dictionary = {}
var players: Array = []                  # human country ids in player order (turn-taking)
var best: Dictionary = {}                # country_id -> best mark
var player_attempt: Dictionary = {}      # player index -> attempts taken
var turn_order: Array = []               # round-robin sequence of player indices
var turn_idx := 0
var cur_id: StringName                   # current thrower's country

var state: St = St.WINDUP
var target := 0.0                       # best AI mark to beat (shown to the player)
var angle := 0.0                        # hammer head sweep angle
var _info: Label

# flight
var flight_t := 0.0
var flight_dur := 1.0
var throw_dist := 0.0
var throw_dir := Vector2.RIGHT
var land_pos := Vector2.ZERO
var released := false

func _music_key() -> StringName:
	return &"hammer"

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
	stadium.world_width = Palette.BASE_WIDTH
	stadium.track_markings = false
	stadium.set_backdrop("res://assets/stadium/hammer.png")
	add_child(stadium)

	ath = Athlete.new()
	ath.set_country(players[0])
	ath.position = CIRCLE
	add_child(ath)

	_info = UI.label("", 20, Palette.PAPER)
	_info.position = Vector2(15, 70)
	hud.add_child(_info)

	AudioBus.loop_crowd(true, -22.0)
	_begin_attempt()

func _begin_attempt() -> void:
	var cur: int = turn_order[turn_idx]
	cur_id = players[cur]
	player_attempt[cur] = int(player_attempt[cur]) + 1
	engine.reset()
	engine.start()
	angle = 0.0
	released = false
	state = St.WINDUP
	ath.set_country(cur_id)
	ath.position = CIRCLE
	ath.set_state(Athlete.State.THROW)
	_update_info()
	set_prompt("A / B  SPIN     LB  RELEASE IN THE SECTOR")

func _update_info() -> void:
	var cur: int = turn_order[turn_idx]
	var who := "" if players.size() == 1 else "P%d   " % (cur + 1)
	_info.text = "%sATTEMPT %d/%d    BEST %.2f m    TARGET %.2f m" % [who, int(player_attempt[cur]), ATTEMPTS, float(best[cur_id]), target]

func _process(delta: float) -> void:
	super._process(delta)
	match state:
		St.WINDUP:
			_windup(delta)
		St.FLIGHT:
			_flight(delta)
	queue_redraw()

func _windup(delta: float) -> void:
	var pi := Game.player_index_of(cur_id)
	if Input.is_action_just_pressed(Platform.act(pi, &"a")):
		engine.tap_a()
	if Input.is_action_just_pressed(Platform.act(pi, &"b")):
		engine.tap_b()
	engine.update(delta)
	var spin := engine.speed_ratio()

	# Hammer head sweeps faster the faster you spin.
	angle = fposmod(angle + (2.2 + spin * 9.0) * delta, TAU)

	if Input.is_action_just_pressed(Platform.act(pi, &"lb")):
		_release(spin)

func _release(spin: float) -> void:
	released = true
	# Angle measured from forward (0). Small angle = good.
	var off := angle
	if off > PI:
		off -= TAU
	if absf(off) > SECTOR_HALF:
		_foul("OUT OF SECTOR")
		return
	# Distance: best at centre of the sector, scaled by spin.
	var accuracy := 1.0 - absf(off) / SECTOR_HALF * 0.35
	throw_dist = (18.0 + spin * 66.0) * accuracy
	# Landing direction within the field sector, biased by release offset.
	var land_ang := clampf(off * 0.8, -FIELD_SECTOR, FIELD_SECTOR)
	throw_dir = Vector2(cos(land_ang), sin(land_ang))
	land_pos = CIRCLE + throw_dir * throw_dist * PX_PER_M
	flight_t = 0.0
	flight_dur = clampf(0.7 + throw_dist * 0.012, 0.7, 1.6)
	state = St.FLIGHT
	ath.set_state(Athlete.State.CELEBRATE)
	AudioBus.play(&"whoosh")

func _flight(delta: float) -> void:
	flight_t += delta
	if flight_t >= flight_dur:
		AudioBus.play(&"land")
		_record(throw_dist, false)

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

func _draw() -> void:
	# Grass throwing field.
	draw_rect(Rect2(0, 350, Palette.BASE_WIDTH, Palette.BASE_HEIGHT - 350), Palette.INFIELD)
	# Legal landing sector fanning from the circle.
	var far := 90.0 * PX_PER_M
	var a := PackedVector2Array([
		CIRCLE,
		CIRCLE + Vector2(cos(-FIELD_SECTOR), sin(-FIELD_SECTOR)) * far,
		CIRCLE + Vector2(cos(FIELD_SECTOR), sin(FIELD_SECTOR)) * far,
	])
	draw_colored_polygon(a, Palette.INFIELD.lightened(0.12))
	draw_line(a[0], a[1], Palette.TRACK_LINE, 2.5)
	draw_line(a[0], a[2], Palette.TRACK_LINE, 2.5)
	# distance arcs
	for m in [30, 50, 70, 90]:
		draw_arc(CIRCLE, m * PX_PER_M, -FIELD_SECTOR, FIELD_SECTOR, 24, Color(1, 1, 1, 0.25), 2.5)
	# target-to-beat arc
	if target > 0.0:
		draw_arc(CIRCLE, target * PX_PER_M, -FIELD_SECTOR, FIELD_SECTOR, 32, Palette.HIGHLIGHT, 3.5)
	# throwing circle
	draw_circle(CIRCLE, 12.5, Palette.STAND_BASE)
	draw_arc(CIRCLE, 12.5, 0, TAU, 20, Palette.TRACK_LINE, 2.5)

	# Release gauge.
	if state == St.WINDUP:
		draw_arc(GAUGE_C, GAUGE_R, 0, TAU, 36, Palette.PANEL_LIGHT, 5.0)
		# legal sector highlight (around forward = angle 0, drawn at top for clarity)
		draw_arc(GAUGE_C, GAUGE_R, -SECTOR_HALF, SECTOR_HALF, 16, Palette.GOOD, 7.5)
		var head := GAUGE_C + Vector2(cos(angle), sin(angle)) * GAUGE_R
		draw_line(GAUGE_C, head, Palette.HIGHLIGHT, 2.5)
		draw_circle(head, 6.0, Palette.HIGHLIGHT)

	# Flying hammer.
	if state == St.FLIGHT:
		var p := clampf(flight_t / flight_dur, 0.0, 1.0)
		var pos := CIRCLE.lerp(land_pos, p)
		pos.y -= sin(p * PI) * 65.0
		draw_line(CIRCLE, pos, Color(0.7, 0.7, 0.75, 0.4), 2.5)
		draw_circle(pos, 6.0, Palette.INK)
