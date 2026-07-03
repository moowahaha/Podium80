extends Node2D
class_name Athlete
## Reusable competitor. Placeholder blocky pixel-athlete drawn procedurally in the country's kit
## colours, with a small animation state machine (idle / ready / run / jump / land / throw / fall /
## stumble / celebrate). Origin is at the FEET (0,0); the body is drawn upward. Facing via `facing`.
##
## Replaceable later: swap _draw for an AnimatedSprite2D without touching callers — the public API
## (set_country, state, run cycle, facing) is what gameplay uses.

enum State { IDLE, READY, RUN, JUMP, LAND, THROW, FALL, STUMBLE, CELEBRATE, SWIM, HURDLE }

# Per-country sprite sheets by state (expand as art arrives). Files live at
# `assets/sprites/<country>/<file>.png`; frames are laid out left-to-right, top-to-bottom in a
# cols×rows grid. `foot` = empty px below the figure's feet in the frame (keeps it on its shadow).
# States without a sheet fall back to the procedural drawing.
const SPRITE_DIR := "res://assets/sprites/"
const SPRITE_STATES := {
	&"USSR": {
		State.IDLE:   {"file": "standing", "cols": 1, "rows": 1, "frames": 1, "foot": 3},
		State.RUN:    {"file": "running",  "cols": 3, "rows": 3, "frames": 9, "foot": 3},
		State.READY:  {"file": "crouch",   "cols": 1, "rows": 1, "frames": 1, "foot": 7},
		State.HURDLE: {"file": "hurdle",   "cols": 1, "rows": 1, "frames": 1, "foot": 4},
	},
}

@export var country_id: StringName = &"USSR"
@export var facing := 1                       # +1 right, -1 left

var state: State = State.IDLE
var run_speed := 0.0                          # 0..1, drives leg-cycle rate
var depth := 1.0                              # lane-depth scale (events set this)
var _phase := 0.0                             # leg cycle phase
var _anim_t := 0.0                            # generic state timer (jump arc, celebrate bob)
var _spin := 0.0                              # hammer wind-up body spin (throw)
var _sheets: Dictionary = {}                  # State -> {tex, cols, rows, frames, fw, fh}

const H := 26.0                               # nominal procedural height in px

func set_country(id: StringName) -> void:
	country_id = id
	_load_sheets()
	_apply_scale()
	queue_redraw()

func set_state(s: State) -> void:
	if state != s:
		state = s
		_anim_t = 0.0
		_apply_scale()
	queue_redraw()

func set_depth(d: float) -> void:
	depth = d
	_apply_scale()

## A sprite frame is native ~64px (the target on-screen size); the procedural drawing is ~26px, so it
## gets ATHLETE_SCALE. Either way the athlete lands at ~64px * depth on screen, keeping states + lanes
## consistent when we mix sprites and placeholders.
func _apply_scale() -> void:
	var factor := 1.0 if _sheets.has(state) else Palette.ATHLETE_SCALE
	scale = Vector2(depth * factor, depth * factor)

func _load_sheets() -> void:
	_sheets = {}
	var m: Dictionary = SPRITE_STATES.get(country_id, {})
	var cdir := SPRITE_DIR + String(country_id).to_lower() + "/"
	for st in m:
		var info: Dictionary = m[st]
		var path := cdir + String(info["file"]) + ".png"
		if ResourceLoader.exists(path):
			var tex: Texture2D = load(path)
			_sheets[st] = {
				"tex": tex, "cols": info["cols"], "rows": info["rows"], "frames": info["frames"],
				"foot": info.get("foot", 0),
				"fw": float(tex.get_width()) / info["cols"], "fh": float(tex.get_height()) / info["rows"],
			}

func _process(delta: float) -> void:
	_anim_t += delta
	if state == State.RUN or state == State.READY or state == State.SWIM:
		_phase += delta * (6.0 + run_speed * 22.0)
	if state == State.THROW:
		_spin += delta * 10.0
	queue_redraw()

func _draw() -> void:
	# Real sprite sheet for this state (e.g. USSR run / crouch), if present.
	if _sheets.has(state):
		_draw_sheet(_sheets[state])
		return

	var kp := CountryData.kit_primary_of(country_id)
	var ks := CountryData.kit_secondary_of(country_id)
	var skin := CountryData.kit_skin_of(country_id)
	var f := float(facing)

	# Shadow.
	draw_ellipse_approx(Vector2(0, 0), 7.0, 2.0, Palette.SHADOW)

	match state:
		State.FALL:
			_draw_fallen(kp, ks, skin, f)
		State.CELEBRATE:
			_draw_celebrate(kp, ks, skin, f)
		State.THROW:
			_draw_throw(kp, ks, skin, f)
		State.SWIM:
			_draw_swim(kp, ks, skin, f)
		_:
			_draw_upright(kp, ks, skin, f)

## The figure only fills ~80% of its square frame; scale up so it reads at the same ~64px as the
## procedural placeholders.
const SPRITE_FIT := 1.25

func _draw_sheet(sh: Dictionary) -> void:
	var fw: float = sh["fw"]
	var fh: float = sh["fh"]
	var dw: float = fw * SPRITE_FIT
	var dh: float = fh * SPRITE_FIT
	# Shadow sized to the sprite footprint.
	draw_ellipse_approx(Vector2(0, -1.0), dw * 0.24, dw * 0.07, Palette.SHADOW)
	var frames := int(sh["frames"])
	var idx := int(_phase) % frames if frames > 1 else 0
	var col := idx % int(sh["cols"])
	var row := idx / int(sh["cols"])
	var src := Rect2(col * fw, row * fh, fw, fh)
	var foot: float = float(sh.get("foot", 0)) * SPRITE_FIT   # drop the frame so the feet sit on the shadow
	var dest := Rect2(-dw / 2.0, -dh + foot, dw, dh)     # feet at origin, centred
	if facing < 0:
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(-1, 1))
		draw_texture_rect_region(sh["tex"], dest, src)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	else:
		draw_texture_rect_region(sh["tex"], dest, src)

func _draw_upright(kp: Color, ks: Color, skin: Color, f: float) -> void:
	var swing := 0.0
	var arm := 0.0
	var crouch := 0.0
	var lean := 0.0
	match state:
		State.RUN:
			swing = sin(_phase) * 5.0
			arm = -sin(_phase) * 4.0
			lean = 3.0 * f
		State.READY:
			crouch = 5.0
			lean = 4.0 * f
		State.JUMP, State.HURDLE:
			swing = -3.0
			arm = -6.0
		State.LAND:
			crouch = 3.0
		State.STUMBLE:
			lean = 6.0 * f
			crouch = 2.0
		_:
			swing = sin(_anim_t * 3.0) * 0.6   # idle breathing

	var hip := Vector2(lean, -12.0 + crouch)
	var shoulder := Vector2(lean * 1.2, -20.0 + crouch)
	# Legs
	_limb(hip, hip + Vector2(f * 2.0 + swing, 12.0 - abs(swing) * 0.3), skin, 2.0)
	_limb(hip, hip + Vector2(f * 2.0 - swing, 12.0 - abs(swing) * 0.3), ks, 2.0)
	# Shorts
	draw_rect(Rect2(hip.x - 4.0, hip.y - 1.0, 8.0, 5.0), ks)
	# Torso
	draw_rect(Rect2(shoulder.x - 4.0, shoulder.y, 8.0, 9.0 - crouch * 0.2), kp)
	# Arms
	_limb(shoulder + Vector2(0, 1), shoulder + Vector2(f * 3.0 + arm, 7.0), skin, 2.0)
	_limb(shoulder + Vector2(0, 1), shoulder + Vector2(f * 3.0 - arm, 7.0), kp, 2.0)
	# Head
	draw_circle(shoulder + Vector2(f * 1.0, -3.0), 3.0, skin)
	draw_rect(Rect2(shoulder.x + f * 1.0 - 3.0, shoulder.y - 6.5, 6.0, 2.0), kp)  # cap band

func _draw_throw(kp: Color, ks: Color, skin: Color, f: float) -> void:
	var lean := sin(_spin) * 3.0
	var hip := Vector2(lean, -12.0)
	var shoulder := Vector2(lean * 1.4, -20.0)
	# Wide stance
	_limb(hip, hip + Vector2(-4.0, 12.0), ks, 2.0)
	_limb(hip, hip + Vector2(4.0, 12.0), skin, 2.0)
	draw_rect(Rect2(hip.x - 4.0, hip.y - 1.0, 8.0, 5.0), ks)
	draw_rect(Rect2(shoulder.x - 4.0, shoulder.y, 8.0, 9.0), kp)
	# Extended arms (both forward, spinning)
	var reach := Vector2(cos(_spin) * 7.0, 2.0 + sin(_spin) * 2.0)
	_limb(shoulder + Vector2(0, 1), shoulder + reach, skin, 2.0)
	_limb(shoulder + Vector2(0, 1), shoulder + reach * 0.8, kp, 2.0)
	draw_circle(shoulder + Vector2(0, -3.0), 3.0, skin)

func _draw_celebrate(kp: Color, ks: Color, skin: Color, f: float) -> void:
	var bob := sin(_anim_t * 6.0) * 2.0
	var hip := Vector2(0, -12.0 + bob)
	var shoulder := Vector2(0, -20.0 + bob)
	_limb(hip, hip + Vector2(-3.0, 12.0), ks, 2.0)
	_limb(hip, hip + Vector2(3.0, 12.0), skin, 2.0)
	draw_rect(Rect2(hip.x - 4.0, hip.y - 1.0, 8.0, 5.0), ks)
	draw_rect(Rect2(shoulder.x - 4.0, shoulder.y, 8.0, 9.0), kp)
	# Arms raised
	_limb(shoulder + Vector2(0, 1), shoulder + Vector2(-5.0, -6.0), skin, 2.0)
	_limb(shoulder + Vector2(0, 1), shoulder + Vector2(5.0, -6.0), skin, 2.0)
	draw_circle(shoulder + Vector2(0, -3.0), 3.0, skin)

func _draw_swim(kp: Color, ks: Color, skin: Color, f: float) -> void:
	# Side-on freestyle at the water surface. Origin sits on the surface line.
	var sw := sin(_phase)
	var yb := -2.0
	# wake / kick splash behind
	draw_ellipse_approx(Vector2(-f * 9.0, 0.0), 3.0, 1.5, Color(1, 1, 1, 0.45))
	# submerged legs (faint) trailing behind
	draw_line(Vector2(-f * 6.0, yb + 1.0), Vector2(-f * 11.0, yb + 1.0 + sw * 1.5), ks, 2.0)
	# body along the surface
	draw_rect(Rect2(-7.0, yb - 1.5, 14.0, 4.0), kp)
	# head at the front with a cap
	var head := Vector2(f * 7.0, yb - 1.0 + sw * 0.4)
	draw_circle(head, 2.5, skin)
	draw_rect(Rect2(head.x - 2.5, head.y - 2.5, 5.0, 2.0), ks)
	# recovering arm arcs over the water on the up-stroke
	var shoulder := Vector2(f * 2.0, yb - 1.0)
	var lift: float = maxf(0.0, sw)
	var hand := shoulder + Vector2(f * (2.0 + 4.0 * lift), -(1.0 + 6.0 * lift))
	draw_line(shoulder, hand, skin, 2.0)

func _draw_fallen(kp: Color, ks: Color, skin: Color, f: float) -> void:
	# Lying on the ground.
	draw_rect(Rect2(-8.0 * f, -5.0, 14.0 * f, 4.0), kp)   # torso horizontal
	_limb(Vector2(-6.0 * f, -3.0), Vector2(-11.0 * f, -1.0), ks, 2.0)
	_limb(Vector2(6.0 * f, -3.0), Vector2(11.0 * f, -4.0), skin, 2.0)
	draw_circle(Vector2(7.0 * f, -3.0), 3.0, skin)

func _limb(a: Vector2, b: Vector2, col: Color, width: float) -> void:
	draw_line(a, b, col, width)

func draw_ellipse_approx(center: Vector2, rx: float, ry: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 12:
		var ang := TAU * i / 12.0
		pts.append(center + Vector2(cos(ang) * rx, sin(ang) * ry))
	draw_colored_polygon(pts, col)
