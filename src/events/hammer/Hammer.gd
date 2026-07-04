extends EventBase
## Event 4 — Hammer Throw (top-down).
## Alternate A/B to build spin speed; press LB to release. The thrower (top-down hold sprite) spins in
## the circle with the hammer sweeping on its chain; release while the hammer is in the forward SECTOR
## for a legal throw (centre = best distance). The camera holds close on the thrower during the
## wind-up, then pulls back and FOLLOWS the hammer down the sector. Three attempts, best counts. The
## static field (circle, cage, sector, distance arcs) is the top-down art; the game overlays the
## thrower, chain, hammer, target arc, landing mark, distance labels and the release gauge.

enum St { WINDUP, FLIGHT, LANDED, DONE }

const FIELD := "res://assets/stadium/hammer_field.png"
const CIRCLE := Vector2(113.0, 286.0)      # throwing-circle centre (matches the art)
const ARC0 := 56.0                          # px from the circle to the 0 m reference (aligns the art's arcs)
const PX_PER_M := 9.75
const FIELD_SECTOR := 0.20                   # legal landing sector half-angle (inside the art's lines)
const SECTOR_HALF := 0.62                    # legal release arc around forward
const ATTEMPTS := 3
const ARC_MARKS := [20, 30, 40, 50, 60]      # distances of the art's arcs, for labelling
const GAUGE_C := Vector2(118.0, 430.0)       # release gauge (screen space)
const GAUGE_R := 46.0
const CAM_WINDUP_POS := Vector2(300.0, 286.0)
const CAM_WINDUP_ZOOM := 1.7
const HOLD_FIT := 0.62                        # hold-sprite draw scale (small, so the hammer swings on a visible chain)
const FEET_FRAC := 0.39                       # pivot point in the sprite (nudged further toward the sprite centre)
const GRIP := 26.0                            # chain anchor (hands) distance from the circle centre
const CHAIN := 48.0                           # hammer-head distance while spinning (past the thrower → visible chain)

var _field: Texture2D
var _hold_tex: Texture2D
var cam: Camera2D
var engine := RunEngine.new()
var ai_values: Dictionary = {}
var players: Array = []
var best: Dictionary = {}
var player_attempt: Dictionary = {}
var turn_order: Array = []
var turn_idx := 0
var cur_id: StringName

var state: St = St.WINDUP
var target := 0.0
var angle := 0.0
var release_angle := 0.0
var _info: Label

# flight
var flight_t := 0.0
var flight_dur := 1.0
var throw_dist := 0.0
var throw_dir := Vector2.RIGHT
var land_pos := Vector2.ZERO

func radius_of(d: float) -> float:
	return ARC0 + d * PX_PER_M

func _music_key() -> StringName:
	return &"hammer"

func _event_ready() -> void:
	ai_values = Game.roll_ai_values()
	# Scale the AI (and the whole event) down to fit the top-down field's distance arcs.
	for aid in ai_values:
		ai_values[aid] = float(ai_values[aid]) * 0.72
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

	if ResourceLoader.exists(FIELD):
		_field = load(FIELD)

	cam = Camera2D.new()
	cam.position = CAM_WINDUP_POS
	cam.zoom = Vector2(CAM_WINDUP_ZOOM, CAM_WINDUP_ZOOM)
	add_child(cam)
	cam.make_current()

	var gauge := GaugeNode.new()
	gauge.ev = self
	hud.add_child(gauge)

	_info = UI.label("", 20, Palette.PAPER)
	_info.position = Vector2(15, 70)
	hud.add_child(_info)

	_begin_attempt()

func _begin_attempt() -> void:
	var cur: int = turn_order[turn_idx]
	cur_id = players[cur]
	player_attempt[cur] = int(player_attempt[cur]) + 1
	engine.reset()
	engine.start()
	AudioBus.loop_crowd(false)             # silent during the wind-up
	angle = 0.0
	state = St.WINDUP
	cam.position = CAM_WINDUP_POS
	cam.zoom = Vector2(CAM_WINDUP_ZOOM, CAM_WINDUP_ZOOM)
	var hp := "res://assets/sprites/%s/hammer-hold.png" % String(cur_id).to_lower()
	_hold_tex = load(hp) if ResourceLoader.exists(hp) else null
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
			_cam_to(CAM_WINDUP_POS, CAM_WINDUP_ZOOM, delta)
		St.FLIGHT:
			_flight(delta)
			var p := clampf(flight_t / flight_dur, 0.0, 1.0)
			_cam_to(_clamp_cam(CIRCLE.lerp(land_pos, p), 1.7), 1.7, delta)   # tight follow — loses the thrower
		St.LANDED, St.DONE:
			_cam_to(_clamp_cam(land_pos, 1.7), 1.7, delta)
	queue_redraw()

func _cam_to(pos: Vector2, zoom: float, delta: float) -> void:
	var k := 1.0 - exp(-6.0 * delta)
	cam.position = cam.position.lerp(pos, k)
	cam.zoom = cam.zoom.lerp(Vector2(zoom, zoom), k)

## Keep a camera centred on `pos` from showing outside the field image at the given zoom.
func _clamp_cam(pos: Vector2, zoom: float) -> Vector2:
	var hx := (Palette.BASE_WIDTH / zoom) * 0.5
	var hy := (Palette.BASE_HEIGHT / zoom) * 0.5
	return Vector2(clampf(pos.x, hx, Palette.BASE_WIDTH - hx), clampf(pos.y, hy, Palette.BASE_HEIGHT - hy))

func _windup(delta: float) -> void:
	var pi := Game.player_index_of(cur_id)
	if Input.is_action_just_pressed(Platform.act(pi, &"a")):
		engine.tap_a()
	if Input.is_action_just_pressed(Platform.act(pi, &"b")):
		engine.tap_b()
	engine.update(delta)
	var spin := engine.speed_ratio()
	angle = fposmod(angle + (2.2 + spin * 9.0) * delta, TAU)
	if Input.is_action_just_pressed(Platform.act(pi, &"lb")):
		_release(spin)

func _release(spin: float) -> void:
	release_angle = angle
	var off := angle
	if off > PI:
		off -= TAU
	if absf(off) > SECTOR_HALF:
		_foul("OUT OF SECTOR")
		return
	var accuracy := 1.0 - absf(off) / SECTOR_HALF * 0.35
	throw_dist = (14.0 + spin * 50.0) * accuracy      # ~14..64 m — sits inside the field's arcs
	var land_ang := clampf(off * 0.6, -FIELD_SECTOR * 0.9, FIELD_SECTOR * 0.9)   # always inside the lines
	throw_dir = Vector2(cos(land_ang), sin(land_ang))
	land_pos = CIRCLE + throw_dir * radius_of(throw_dist)
	flight_t = 0.0
	flight_dur = clampf(0.7 + throw_dist * 0.02, 0.7, 1.7)
	state = St.FLIGHT
	AudioBus.play(&"whoosh")
	AudioBus.loop_crowd(true, -11.0)       # crowd roars only once the hammer is airborne
	AudioBus.swell_crowd(-6.0)

func _flight(delta: float) -> void:
	flight_t += delta
	if flight_t >= flight_dur:
		AudioBus.play(&"land")
		_record(throw_dist, false)

func _foul(reason: String) -> void:
	AudioBus.play(&"foul")
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
	AudioBus.loop_crowd(false)             # silent when the event ends
	if players.size() == 1:
		banner_persist("FINAL: %.2f m" % float(best[players[0]]), Palette.HIGHLIGHT)
	else:
		banner_persist("P1  %.2f m      P2  %.2f m" % [float(best[players[0]]), float(best[players[1]])], Palette.HIGHLIGHT)
	finish(best.duplicate(), ai_values)

func _draw() -> void:
	if _field:
		draw_texture_rect(_field, Rect2(0, 0, Palette.BASE_WIDTH, Palette.BASE_HEIGHT), false)
	# Distance labels along the lower sector edge (kept off the flight path).
	var font := ThemeDB.fallback_font
	for m in ARC_MARKS:
		var a := FIELD_SECTOR * 0.82
		var lp := CIRCLE + Vector2(cos(a), sin(a)) * radius_of(m)
		draw_string(font, lp - Vector2(12.0, -4.0), "%dm" % m, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1, 1, 1, 0.85))
	# Target-to-beat arc.
	if target > 0.0:
		draw_arc(CIRCLE, radius_of(target), -FIELD_SECTOR, FIELD_SECTOR, 40, Palette.HIGHLIGHT, 3.0)

	# Chain + spinning hammer head (before release), then the flying hammer.
	if state == St.WINDUP:
		var dir := Vector2(cos(angle), sin(angle))
		_draw_hammer(CIRCLE + dir * GRIP, CIRCLE + dir * CHAIN)
	elif state == St.FLIGHT:
		var p := clampf(flight_t / flight_dur, 0.0, 1.0)
		_draw_hammer(CIRCLE + throw_dir * GRIP, CIRCLE.lerp(land_pos, p))
	elif state == St.LANDED:
		draw_circle(land_pos, 6.0, Palette.BAD)
		draw_arc(land_pos, 9.0, 0, TAU, 16, Palette.INK, 1.5)

	# Thrower: top-down hold sprite, rotated to face the (release) spin direction. Anchored on the
	# FEET (bottom-centre of the art) so the spin pivots about the feet, planted at the circle centre —
	# not about the sprite's centre (which made the whole figure orbit).
	if _hold_tex:
		var face := angle if state == St.WINDUP else release_angle
		var sz := 64.0 * HOLD_FIT
		draw_set_transform(CIRCLE, face - PI / 2.0, Vector2.ONE)
		draw_texture_rect(_hold_tex, Rect2(-sz * 0.5, -sz * FEET_FRAC, sz, sz), false)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _draw_hammer(from: Vector2, head: Vector2) -> void:
	draw_line(from, head, Color(0.55, 0.55, 0.6), 2.0)     # chain
	draw_circle(head, 4.5, Color(0.2, 0.2, 0.22))          # head
	draw_circle(head, 4.5, Palette.PANEL_LIGHT, false, 1.0)

## The release gauge, drawn in screen space in the HUD so the world camera doesn't move it.
class GaugeNode extends Node2D:
	var ev = null
	func _process(_delta: float) -> void:
		queue_redraw()
	func _draw() -> void:
		if ev == null or ev.state != 0:                 # 0 == St.WINDUP
			return
		var c: Vector2 = ev.GAUGE_C
		var r: float = ev.GAUGE_R
		draw_arc(c, r, 0, TAU, 36, Palette.PANEL_LIGHT, 5.0)
		draw_arc(c, r, -ev.SECTOR_HALF, ev.SECTOR_HALF, 16, Palette.GOOD, 7.5)
		var head: Vector2 = c + Vector2(cos(ev.angle), sin(ev.angle)) * r
		draw_line(c, head, Palette.HIGHLIGHT, 2.5)
		draw_circle(head, 6.0, Palette.HIGHLIGHT)
