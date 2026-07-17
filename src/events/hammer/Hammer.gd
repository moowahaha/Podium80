extends EventBase
## Event 4 — Hammer Throw (top-down).
## Alternate A/B to rev up — keep the meter's marker in the green sweet-spot, which sinks ever faster so
## it demands steadily quicker tapping; press L to release. Throw distance = spin built × release
## closeness to the sector centre. The thrower (top-down hold sprite) spins in
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
const SECTOR_HALF := 0.76                    # legal release arc around forward (wide sweet spot — forgiving)
const ROT_SLOW := 1.5                         # thrower sweep (rad/s) at zero spin — slow, easy to time a release
const ROT_FAST := 9.2                         # thrower sweep (rad/s) at full spin — fast, so a good launch is HARD (but not impossible)
# Rev-up meter. Alternate A/B to lift the marker; it sinks on its own, and sinks FASTER the higher it
# sits — so the green sweet-spot demands quicker tapping the further up it goes. The sweet-spot's BOTTOM
# edge rises as spin builds (difficulty tracks PROGRESS, not the clock — idling never ramps it), so it
# gets progressively harder to hold up high. Its TOP edge rises too but meets the bar's ceiling (1.0)
# well before full spin — so once the sweet-spot has reached the top there's nothing above it to
# overshoot into, and hammering the buttons up there no longer stalls you. Mid-bar, overshooting ABOVE
# the band is still possible (hold it in the band, don't just mash) but is NOT punished — ease off to
# sink back in. Only falling out the BOTTOM (too slow) bleeds speed, and gently.
const REV_KICK := 0.13                        # marker rise per valid alternation
const REV_SINK_BASE := 0.28                   # marker sink/sec at the bottom of the bar (sets the easy starting pace)
const REV_SINK_SLOPE := 0.62                  # extra sink/sec at the top of the bar (why higher = faster tapping)
const BAND_BOTTOM_LO := 0.08                  # sweet-spot bottom edge at zero spin (low → easy to reach)
const BAND_BOTTOM_HI := 0.80                  # sweet-spot bottom edge at full spin (high → needs fast tapping)
const BAND_TOP_LO := 0.48                     # sweet-spot top edge at zero spin
const BAND_TOP_HI := 1.15                     # sweet-spot top edge slope (clamped to 1.0 — reaches the ceiling by ~78% spin)
const SPIN_GAIN := 0.42                       # spin built per sec while the marker is in the band
const SPIN_DROP := 0.16                       # spin lost per sec when the marker falls below the band (gentle)
const SPIN_TOP_TAPER := 0.65                  # how much the spin gain slows as it nears the top (progressively harder)
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
var rev := 0.0              # rev-meter marker, 0..1 (slightly over 1 = overshoot)
var spin := 0.0            # actual spin 0..1 → drives rotation speed AND throw distance (and the band height)
var _last_tap := 0         # last button used (1=A, 2=B) — only alternations lift the marker
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
	# Scale the AI (and the whole event) down to fit the top-down field's distance arcs. 0.80 puts the
	# field's best throws in the low-60s m, so a near-perfect human throw is needed to win.
	for aid in ai_values:
		ai_values[aid] = float(ai_values[aid]) * 0.80
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
	AudioBus.loop_crowd(false)             # silent during the wind-up
	angle = 0.0
	rev = 0.0
	spin = 0.0
	_last_tap = 0
	state = St.WINDUP
	cam.position = CAM_WINDUP_POS
	cam.zoom = Vector2(CAM_WINDUP_ZOOM, CAM_WINDUP_ZOOM)
	var hp := "res://assets/sprites/%s/hammer-hold.png" % String(cur_id).to_lower()
	_hold_tex = load(hp) if ResourceLoader.exists(hp) else null
	_update_info()
	set_prompt("A / B  REV UP — KEEP THE MARKER GREEN      L  RELEASE IN THE SECTOR")

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

## The green sweet-spot [lo, hi] on the 0..1 bar. Both edges rise as spin builds, but the TOP edge
## clamps at the bar max (1.0) and reaches it well before full spin — so near the top there's no
## overshoot region left. Difficulty tracks the player's own progress rather than elapsed time.
func band_range() -> Vector2:
	var s := clampf(spin, 0.0, 1.0)
	var bottom := lerpf(BAND_BOTTOM_LO, BAND_BOTTOM_HI, s)
	var top := minf(1.0, lerpf(BAND_TOP_LO, BAND_TOP_HI, s))
	return Vector2(bottom, top)

func _windup(delta: float) -> void:
	var pi := Game.player_index_of(cur_id)
	# The marker sinks faster the higher it sits, so holding it up the bar needs quicker tapping.
	var sink := REV_SINK_BASE + REV_SINK_SLOPE * rev
	rev = maxf(0.0, rev - sink * delta)
	# Alternate A/B to lift the marker; the same button twice does nothing (must alternate).
	var which := 0
	if Input.is_action_just_pressed(Platform.act(pi, &"a")):
		which = 1
	elif Input.is_action_just_pressed(Platform.act(pi, &"b")):
		which = 2
	if which != 0:
		if which != _last_tap:
			rev = minf(1.0, rev + REV_KICK)      # ceiling is the bar maximum
		_last_tap = which
	# Spin builds only while the marker is IN the (rising, narrowing) sweet-spot. Overshooting above
	# it neither gains nor costs — ease off to let it sink back in. Only falling out the BOTTOM (too
	# slow) bleeds speed, and gently. Topping-off slows near the max, so the last of it is the hardest.
	var band := band_range()
	if rev >= band.x and rev <= band.y:
		var gain := SPIN_GAIN * (1.0 - SPIN_TOP_TAPER * clampf(spin, 0.0, 1.0))
		spin = minf(1.0, spin + gain * delta)
	elif rev < band.x:
		spin = maxf(0.0, spin - SPIN_DROP * delta)
	# The thrower sweeps faster the more spin you've built — so a legal, well-centred launch gets
	# harder the faster you go (speed vs. accuracy risk/reward), but the window stays catchable.
	var rot := lerpf(ROT_SLOW, ROT_FAST, clampf(spin, 0.0, 1.0))
	angle = fposmod(angle + rot * delta, TAU)
	if Input.is_action_just_pressed(Platform.act(pi, &"l")):
		_release(spin)

func _release(spin_speed: float) -> void:
	release_angle = angle
	var off := angle
	if off > PI:
		off -= TAU
	if absf(off) > SECTOR_HALF:
		_foul("OUT OF SECTOR")
		return
	# Distance is a product of two things: spin speed built up, and how close to the sweet-spot centre
	# the release was (dead-centre = full credit, sector edge = ~55%).
	var accuracy := 1.0 - absf(off) / SECTOR_HALF * 0.45
	throw_dist = (14.0 + spin_speed * 50.0) * accuracy      # ~14..64 m — sits inside the field's arcs
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
		# --- Release dial: the spin marker sweeps the ring; press L while it is in the green front
		# sector. Closer to the sector centre = more distance. ---
		draw_arc(c, r, 0, TAU, 36, Palette.PANEL_LIGHT, 5.0)
		draw_arc(c, r, -ev.SECTOR_HALF, ev.SECTOR_HALF, 20, Palette.GOOD, 7.5)
		var head: Vector2 = c + Vector2(cos(ev.angle), sin(ev.angle)) * r
		draw_line(c, head, Palette.HIGHLIGHT, 2.5)
		draw_circle(head, 6.0, Palette.HIGHLIGHT)

		# --- Rev bar: alternate A/B to lift the marker into the green sweet-spot and hold it there.
		# The band drifts UP and narrows as spin builds and the marker sinks faster up high, so you tap
		# steadily faster to chase it. Spin only climbs while the marker is green. ---
		var bx: float = c.x + r + 40.0
		var btop: float = c.y - r
		var bh: float = r * 2.0
		var bw: float = 20.0
		var left: float = bx - bw * 0.5
		draw_rect(Rect2(left, btop, bw, bh), Palette.INK)
		var band: Vector2 = ev.band_range()
		var y_hi: float = btop + (1.0 - clampf(band.y, 0.0, 1.0)) * bh
		var y_lo: float = btop + (1.0 - clampf(band.x, 0.0, 1.0)) * bh
		draw_rect(Rect2(left, y_hi, bw, y_lo - y_hi), Color(Palette.GOOD, 0.45))
		draw_rect(Rect2(left, btop, bw, bh), Palette.PANEL_LIGHT, false, 2.0)
		var in_band: bool = ev.rev >= band.x and ev.rev <= band.y
		var my: float = btop + (1.0 - clampf(ev.rev, 0.0, 1.0)) * bh
		var mcol: Color = Palette.GOOD if in_band else Palette.BAD
		draw_rect(Rect2(left - 4.0, my - 2.5, bw + 8.0, 5.0), mcol)
