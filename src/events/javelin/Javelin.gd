extends EventBase
## Event 5 — Javelin (side-on, like the long jump).
## Sprint the run-up (A/B) to build speed, then press L to PLANT before the scratch line — crossing it,
## or failing to plant in time, is a FOUL and you fall on your face (as in the long/triple jump). A
## quarter-circle meter then sweeps a needle UP from flat (0°) to vertical (90°); press L to LAUNCH.
## Distance is a factor of run-up speed and how close the launch angle is to 45° (real projectile range
## peaks at 45°), plus the slight advantage of planting close to the line (distance is measured from
## it). The camera follows the javelin down the grass field; the AUS thrower's javelin tumbles
## end-over-end, the USSR one flies as a flaming missile. Three attempts, best counts.

enum St { APPROACH, AIM, FLIGHT, LANDED, DONE }

const PX_PER_M := 20.0
const RUNUP_X := 70.0
const FOUL_X := 540.0                 # scratch line at the end of the run strip
const WORLD_W := FOUL_X + 96.0 * PX_PER_M + 240.0
const ATTEMPTS := 3
const GRAV := 9.8
const V_MIN := 22.0                   # launch speed (m/s) at zero run-up (~49 m at 45°)
const V_MAX := 30.0                   # launch speed (m/s) at full run-up (~92 m at 45° — a world-class throw)
const ARC_SCALE := 0.42               # compress the (very tall) real 45° loft to something screen-readable
const NEEDLE_SLOW := 1.5              # needle sweep time (0..90°) at zero run-up — easy to time
const NEEDLE_FAST := 0.72             # needle sweep time at full run-up — snappy (faster run = harder aim, risk/reward)
const SWEET_DEG := 45.0
const SWEET_HALF := 7.0               # green sweet-spot half-width around 45° (visual guide)
const METER_C := Vector2(120.0, 432.0)
const METER_R := 78.0
const TUMBLE_RATE := 13.0             # rad/s end-over-end spin (AUS)
# Right-hand anchor (feet-relative WORLD px, facing +1) per phase, and drawn javelin length. The
# implement is gripped at its MIDDLE and wobbles with the run cycle (see hand_world / held_angle).
const HAND_STAND := Vector2(10.0, -34.0)         # standing: upright in the right hand, by the side
const HAND_RAISED := Vector2(11.0, -68.0)        # default raised right hand (overhead)
const HAND_AUS_RAISED := Vector2(10.0, -74.0)    # AUS: raised hand sits high (was at the forehead)
const HAND_GDR_RAISED := Vector2(5.0, -66.0)     # GDR: pulled back (was hovering by the head)
const HAND_USSR_RAISED := Vector2(11.0, -68.0)   # USSR
const HAND_GB_UNDERARM := Vector2(-2.0, -31.0)   # GBR (normal run sprite): underarm, back and down
const JAV_LEN := 52.0

var stadium: Stadium
var cam: CameraManager
var ath: Athlete
var jav_marker: Node2D                # camera follow target during flight
var splash: SandSplash                # dirt/grass debris kicked up on landing
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
var _info: Label

# aim
var aim_t := 0.0
var aim_deg := 0.0
var aim_dur := 1.2                    # needle sweep time this attempt (set from run-up speed at plant)
var plant_x := 0.0
var plant_speed := 0.0

# flight
var flight_t := 0.0
var flight_dur := 1.2
var launch_pos := Vector2.ZERO
var land_x := 0.0
var throw_angle := 0.0                # radians up from horizontal
var arc_h := 0.0
var measured := 0.0
var jav_pos := Vector2.ZERO
var jav_rot := 0.0
var flame_t := 0.0
var land_stick_pos := Vector2.ZERO    # where the implement stands, stuck in the turf
var land_stick_ang := 0.0

func _music_key() -> StringName:
	return &"javelin"

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
	stadium.runway = true
	stadium.runway_end_x = FOUL_X            # red run strip ends AT the scratch line; grass field beyond for the throw
	stadium.set_backdrop("res://assets/stadium/track.png")
	add_child(stadium)

	ath = Athlete.new()
	ath.set_country(players[0])
	add_child(ath)

	jav_marker = Node2D.new()
	add_child(jav_marker)

	splash = SandSplash.new()
	splash.cols = [Color("6b4a2a"), Color("55411f"), Color("3f5322"), Color("87613a")]   # dirt + torn grass
	add_child(splash)

	var jd := JavelinDraw.new()
	jd.ev = self
	jd.z_index = -1                          # draw the javelin BEHIND the thrower (hand/arm grips over it)
	add_child(jd)

	cam = CameraManager.new()
	add_child(cam)
	cam.setup(WORLD_W, 350.0)
	cam.max_zoom = 1.15
	cam.set_targets([ath])
	cam.make_current()

	var meter := AngleMeter.new()
	meter.ev = self
	hud.add_child(meter)

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
	ath.run_speed = 0.0
	ath.set_state(Athlete.State.IDLE)          # normal standing pose, javelin in the right hand
	aim_deg = 0.0
	aim_t = 0.0
	jav_pos = Vector2.ZERO
	state = St.APPROACH
	cam.max_zoom = 1.15
	cam.set_targets([ath])
	_update_info()
	set_prompt("A / B  RUN-UP      L  BEGIN THE THROW (BEFORE THE LINE)")

func _update_info() -> void:
	var cur: int = turn_order[turn_idx]
	var who := "" if players.size() == 1 else "P%d   " % (cur + 1)
	_info.text = "%sATTEMPT %d/%d    BEST %.2f m    TARGET %.2f m" % [who, int(player_attempt[cur]), ATTEMPTS, float(best[cur_id]), target]

func _process(delta: float) -> void:
	super._process(delta)
	match state:
		St.APPROACH:
			_approach(delta)
		St.AIM:
			_aim(delta)
		St.FLIGHT:
			_flight(delta)
		St.LANDED, St.DONE:
			pass
	queue_redraw()

func _approach(delta: float) -> void:
	var pi := maxi(0, Game.player_index_of(cur_id))     # P1 keys even on the no-human fallback path
	if Input.is_action_just_pressed(Platform.act(pi, &"a")):
		engine.tap_a()
	if Input.is_action_just_pressed(Platform.act(pi, &"b")):
		engine.tap_b()
	engine.update(delta)
	ath.run_speed = engine.speed_ratio()
	# GBR runs with its normal run sprite (javelin underarm); the rest use the javelin-run sheet.
	var run_state: int = Athlete.State.RUN if cur_id == &"GBR" else Athlete.State.JAV_RUN
	ath.set_state(run_state if ath.run_speed > 0.012 else Athlete.State.IDLE)
	var x := RUNUP_X + engine.distance * PX_PER_M
	ath.position.x = x
	if Input.is_action_just_pressed(Platform.act(pi, &"l")):
		if x <= FOUL_X:
			_plant(x)
		else:
			_foul("OVERSTEP")
	elif x > FOUL_X + 2.0:
		_foul("RAN THROUGH")

func _plant(x: float) -> void:
	plant_x = x
	plant_speed = engine.speed_ratio()
	ath.run_speed = 0.0                        # freeze the run sprite in place (position stops → frame holds)
	aim_dur = lerpf(NEEDLE_SLOW, NEEDLE_FAST, clampf(plant_speed, 0.0, 1.0))   # faster run-up → faster needle
	state = St.AIM
	# NOTE: keep the (now frozen) run sprite through the aim; switch to the thrown pose only at release.
	aim_t = 0.0
	aim_deg = 0.0
	set_prompt("L  PICK THE TRAJECTORY — RELEASE NEAR 45°")
	AudioBus.play(&"step", -2.0, 1.0)

func _aim(delta: float) -> void:
	var pi := maxi(0, Game.player_index_of(cur_id))
	aim_t += delta
	aim_deg = clampf(aim_t / aim_dur, 0.0, 1.0) * 90.0
	if Input.is_action_just_pressed(Platform.act(pi, &"l")):
		_launch(aim_deg)
	elif aim_deg >= 90.0:
		_launch(90.0)                           # dithered too long → near-vertical, very short

func _launch(deg: float) -> void:
	throw_angle = deg_to_rad(deg)
	var v := lerpf(V_MIN, V_MAX, clampf(plant_speed, 0.0, 1.0))
	var range_m := maxf(1.0, v * v * sin(2.0 * throw_angle) / GRAV)
	launch_pos = hand_world()                  # leaves from the hand it was held in (state is still AIM here)
	ath.set_state(Athlete.State.JAV_LAUNCH)    # now switch to the thrown / follow-through sprite
	land_x = launch_pos.x + range_m * PX_PER_M
	measured = maxf(0.0, (land_x - FOUL_X) / PX_PER_M)      # measured from the scratch line
	arc_h = (land_x - launch_pos.x) * tan(throw_angle) * 0.25 * ARC_SCALE
	flight_dur = clampf(0.9 + measured * 0.02, 0.9, 2.6)
	flight_t = 0.0
	flame_t = 0.0
	jav_pos = launch_pos
	jav_rot = -throw_angle
	ath.set_state(Athlete.State.JAV_LAUNCH)
	state = St.FLIGHT
	cam.max_zoom = 0.85
	jav_marker.position = jav_pos
	cam.set_targets([jav_marker])
	AudioBus.play(&"whoosh")
	AudioBus.swell_crowd(-6.0)
	set_prompt("")

func _flight(delta: float) -> void:
	flight_t += delta
	flame_t += delta
	var p := clampf(flight_t / flight_dur, 0.0, 1.0)
	var x := lerpf(launch_pos.x, land_x, p)
	var ybase := lerpf(launch_pos.y, stadium.ground_y, p)
	var y := ybase - 4.0 * arc_h * p * (1.0 - p)
	jav_pos = Vector2(x, y)
	jav_marker.position = jav_pos
	var spin := 0.0
	if _jav_style() == &"boomerang":
		spin = TUMBLE_RATE                     # boomerang whirls flat
	elif _jav_style() == &"branch":
		spin = TUMBLE_RATE * 0.32              # stick tumbles slowly end over end
	if spin > 0.0:
		jav_rot += spin * delta
	else:
		var dxdp := land_x - launch_pos.x
		var dydp := (stadium.ground_y - launch_pos.y) - 4.0 * arc_h * (1.0 - 2.0 * p)
		jav_rot = atan2(dydp, dxdp)
	if p >= 1.0:
		var entry := Vector2(land_x, stadium.ground_y)
		land_stick_ang = deg_to_rad(64.0)                    # plant nose-down, standing up out of the turf
		var d := Vector2(cos(land_stick_ang), sin(land_stick_ang))
		land_stick_pos = entry - d * (JAV_LEN * 0.5 - 6.0)   # bottom buried ~6 px
		jav_pos = entry
		splash.burst(entry, clampf(0.7 + measured * 0.02, 0.7, 1.8))
		AudioBus.play(&"land")
		_record(measured, false)

func _foul(reason: String) -> void:
	AudioBus.play(&"foul")
	ath.set_state(Athlete.State.STUMBLE)
	jav_pos = Vector2.ZERO
	banner("FOUL — %s" % reason, Palette.BAD, 1.4)
	_record(0.0, true)

func _record(mark: float, foul: bool) -> void:
	state = St.LANDED
	if not foul:
		target = maxf(target, mark)
		if mark > float(best[cur_id]):
			best[cur_id] = mark
			banner("%.2f m  —  BEST!" % mark, Palette.HIGHLIGHT, 1.4)
			AudioBus.swell_crowd(-8.0)
		else:
			banner("%.2f m" % mark, Palette.PAPER, 1.4)
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
	cam.set_targets([ath])
	if players.size() == 1:
		banner_persist("FINAL: %.2f m" % float(best[players[0]]), Palette.HIGHLIGHT)
	else:
		banner_persist("P1  %.2f m      P2  %.2f m" % [float(best[players[0]]), float(best[players[1]])], Palette.HIGHLIGHT)
	finish(best.duplicate(), ai_values)

func _jav_style() -> StringName:
	if cur_id == &"AUS":
		return &"boomerang"
	if cur_id == &"USSR":
		return &"missile"
	if cur_id == &"GDR":
		return &"branch"
	if cur_id == &"GBR":
		return &"tricolor"
	return &"normal"

## World position of the right hand (where the javelin is anchored) for the current phase.
func hand_world() -> Vector2:
	if ath.has_anchor():
		return ath.anchor_world()               # exact per-frame hold-point from the sprite's magenta marker
	if state == St.AIM or ath.run_speed > 0.012:
		var bob := sin(ath._phase)              # fallback wobble in time with the run cycle (frozen during aim)
		return ath.position + _carry_hand() + Vector2(0.8 * bob, -2.2 * bob)
	return ath.position + HAND_STAND

## The carrying hand (per country): overhead raised hand for most, tucked underarm for GBR.
func _carry_hand() -> Vector2:
	match cur_id:
		&"GBR": return HAND_GB_UNDERARM
		&"AUS": return HAND_AUS_RAISED
		&"GDR": return HAND_GDR_RAISED
		&"USSR": return HAND_USSR_RAISED
	return HAND_RAISED

## Orientation (radians, screen space) of the held javelin for the current phase.
func held_angle() -> float:
	if state == St.AIM:
		return -deg_to_rad(aim_deg)             # aiming: tilt to the needle
	if ath.has_anchor():
		var aa := ath.anchor_angle()            # per-frame angle authored in the tool
		if not is_nan(aa):
			return aa
	if ath.run_speed > 0.012:
		var base := 2.0 if cur_id == &"GBR" else -6.0
		return deg_to_rad(base + 5.0 * sin(ath._phase))   # wobble with the arm
	return 0.0                                  # standing: held horizontal in the right hand

func _draw() -> void:
	# Scratch line at the end of the run strip.
	draw_line(Vector2(FOUL_X, stadium.ground_y - Stadium.RUNWAY_UP), Vector2(FOUL_X, stadium.ground_y + Stadium.RUNWAY_DOWN), Palette.PAPER, 3.0)
	# Distance markers on the grass, every 10 m from the line.
	var font := ThemeDB.fallback_font
	var m := 10
	while m <= 100:
		var mx := FOUL_X + m * PX_PER_M
		if mx > WORLD_W:
			break
		draw_line(Vector2(mx, stadium.ground_y - 6.0), Vector2(mx, stadium.ground_y + 11.0), Color(1, 1, 1, 0.55), 2.0)
		draw_string(font, Vector2(mx - 8.0, stadium.ground_y + 27.0), "%dm" % m, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1, 1, 1, 0.7))
		m += 10
	# Target-to-beat line.
	if target > 0.0:
		var tx := FOUL_X + target * PX_PER_M
		if tx < WORLD_W:
			draw_line(Vector2(tx, stadium.ground_y - 42.0), Vector2(tx, stadium.ground_y + 22.0), Palette.HIGHLIGHT, 2.5)

# --- javelin drawing (own node so it sits above the thrower) ------------------
class JavelinDraw extends Node2D:
	var ev = null
	func _process(_delta: float) -> void:
		z_index = 5                              # the implement always draws IN FRONT of the athlete...
		texture_filter = TEXTURE_FILTER_NEAREST
		queue_redraw()
	func _draw() -> void:
		if ev == null:
			return
		match ev.state:
			0, 1:                                # APPROACH / AIM — held in hand
				_javelin(ev.hand_world(), ev.held_angle(), ev._jav_style(), false)
				var hb: Dictionary = ev.ath.hand_blit(8.0)   # ...then redraw the HAND over the grip
				if not hb.is_empty():
					draw_texture_rect_region(hb["tex"], hb["dest"], hb["src"])
			2:                                   # FLIGHT — free
				_javelin(ev.jav_pos, ev.jav_rot, ev._jav_style(), ev._jav_style() == &"missile")
			3:                                   # LANDED — stuck in the turf (unless it was a foul)
				if absf(ev.jav_pos.x) > 0.5:
					_javelin(ev.land_stick_pos, ev.land_stick_ang, ev._jav_style(), false)
					var e: Vector2 = ev.jav_pos      # little dirt mound where it entered the turf
					draw_circle(e + Vector2(0, 1), 4.5, Color("5a4326"))
					draw_circle(e + Vector2(-3, 2), 2.6, Color("6b4a2a"))
					draw_circle(e + Vector2(3, 2), 2.3, Color("463618"))

	func _javelin(pos: Vector2, ang: float, style: StringName, flame: bool) -> void:
		var length: float = ev.JAV_LEN
		var dir := Vector2(cos(ang), sin(ang))
		var nrm := Vector2(-dir.y, dir.x)
		var tip := pos + dir * (length * 0.5)   # gripped at the middle
		var tail := pos - dir * (length * 0.5)
		if style == &"tricolor":
			# GBR javelin in flag colours — back third red, middle third skin (hides the grip), front blue.
			var seg := (tip - tail) / 3.0
			var skin: Color = CountryData.kit_skin_of(ev.cur_id)
			draw_line(tail, tail + seg, Color("c8102e"), 3.0)             # back third: red
			draw_line(tail + seg, tail + seg * 2.0, skin, 3.0)            # middle third: skin
			draw_line(tail + seg * 2.0, tip, Color("1e50a0"), 3.0)        # front third: blue
			draw_line(tip - dir * 4.0, tip, Color("d8dde2"), 3.0)         # metal point
			return
		if style == &"boomerang":
			# Two fairly straight wooden arms meeting at a DISTINCT (but rounded) bend, fat in the middle
			# and tapering to the tips — whirls as it flies.
			var wood := Color("9a5a2a")
			var woodhi := Color("b57a3a")
			var arm: float = length * 0.52
			var half := deg_to_rad(60.0)                # 120° between the arms — a clear bend, not a bow
			var d1 := Vector2(cos(ang - half), sin(ang - half))
			var d2 := Vector2(cos(ang + half), sin(ang + half))
			var steps := 6
			for arm_dir in [d1, d2]:
				for j in range(steps + 1):
					var u := float(j) / float(steps)
					draw_circle(pos + arm_dir * (arm * u), lerpf(3.2, 1.3, u), wood)   # thick bend → thin tip
			draw_circle(pos, 3.8, wood)                 # fat elbow = the distinct bend
			draw_circle(pos, 1.7, woodhi)               # highlight knot at the bend
			return
		if style == &"branch":
			# A gnarled tree branch: crooked tapering shaft (fixed kinks = organic but stable) with a
			# couple of twigs and a forked tip. Rotates rigidly with `ang`.
			var base := pos - dir * (length * 0.5)
			var knots := [0.0, 0.22, 0.46, 0.7, 1.0]
			var offs := [0.0, 2.6, -2.2, 1.8, -1.0]        # perpendicular crook (px)
			var wid := [5.0, 4.2, 3.4, 2.6, 1.6]           # taper thick base -> thin tip
			var bark := Color("6b4a2a")
			var barkhi := Color("8a6238")
			var pts: Array[Vector2] = []
			for i in knots.size():
				pts.append(base + dir * (length * float(knots[i])) + nrm * float(offs[i]))
			for i in range(pts.size() - 1):
				draw_line(pts[i], pts[i + 1], bark, float(wid[i]))
			# twigs branching off, forward and out to each side
			draw_line(pts[1], pts[1] + (dir * 0.5 + nrm).normalized() * 10.0, bark, 2.0)
			draw_line(pts[3], pts[3] + (dir * 0.5 - nrm).normalized() * 8.0, bark, 2.0)
			# forked tip
			draw_line(pts[4], pts[4] + (dir + nrm * 0.6).normalized() * 6.0, bark, 1.6)
			draw_line(pts[4], pts[4] + (dir - nrm * 0.5).normalized() * 5.0, bark, 1.6)
			draw_circle(pts[2], 1.8, barkhi)               # a knot
			return
		if style == &"missile":
			# Long thin body, bright nose cone, tail fins; a flame when it's flying.
			draw_line(tail, tip, Color("b9c0c8"), 3.5)
			draw_line(tip - dir * 6.0, tip, Color("e8edf2"), 3.5)
			draw_line(tail, tail + (nrm - dir) * 5.0, Color("8a929c"), 2.0)
			draw_line(tail, tail - (nrm + dir) * 5.0, Color("8a929c"), 2.0)
			if flame:
				var f := 1.0 + 0.4 * sin(ev.flame_t * 40.0)
				draw_line(tail, tail - dir * (16.0 * f), Color("ff7a1a", 0.85), 3.0)
				draw_line(tail, tail - dir * (10.0 * f), Color("ffd24a"), 5.0)
				draw_circle(tail - dir * (5.0 * f), 3.0, Color("fff0a0"))
			return
		# Normal / tumbling javelin: thin shaft, metal head, cord grip.
		draw_line(tail, tip, Color("cdbf9a"), 2.0)
		draw_line(tip - dir * 7.0, tip, Color("9a9aa2"), 2.5)
		draw_line(pos - dir * 3.0, pos + dir * 3.0, Color("6a5a3a"), 3.0)

# --- launch-angle meter (screen space, in the HUD) ---------------------------
class AngleMeter extends Node2D:
	var ev = null
	func _process(_delta: float) -> void:
		queue_redraw()
	func _draw() -> void:
		if ev == null or ev.state != 1:          # 1 == St.AIM
			return
		var c: Vector2 = ev.METER_C
		var r: float = ev.METER_R
		# Quarter arc from flat (0°, right) up to vertical (90°, up). Screen up is -y, so up = negative.
		draw_arc(c, r, -PI / 2.0, 0.0, 26, Palette.PANEL_LIGHT, 4.0)
		draw_line(c, c + Vector2(r, 0.0), Palette.PANEL_LIGHT, 2.0)
		draw_line(c, c + Vector2(0.0, -r), Palette.PANEL_LIGHT, 2.0)
		# Red danger zone above the sweet-spot (too steep — you've let the needle climb too far).
		draw_arc(c, r, -PI / 2.0, -deg_to_rad(ev.SWEET_DEG + ev.SWEET_HALF), 16, Palette.BAD, 7.5)
		# Green sweet-spot band around 45°.
		var s0 := -deg_to_rad(ev.SWEET_DEG + ev.SWEET_HALF)
		var s1 := -deg_to_rad(ev.SWEET_DEG - ev.SWEET_HALF)
		draw_arc(c, r, s0, s1, 12, Palette.GOOD, 7.5)
		var g := Vector2(cos(-deg_to_rad(45.0)), sin(-deg_to_rad(45.0)))
		draw_line(c + g * (r - 9.0), c + g * (r + 5.0), Palette.GOOD, 2.0)
		# Needle at the current angle, sweeping up.
		var a := -deg_to_rad(ev.aim_deg)
		var nd := Vector2(cos(a), sin(a))
		draw_line(c, c + nd * r, Palette.HIGHLIGHT, 3.0)
		draw_circle(c + nd * r, 5.0, Palette.HIGHLIGHT)
		draw_circle(c, 4.0, Palette.PAPER)
