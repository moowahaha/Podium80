extends Control
class_name FlagRenderer
## Draws each nation's real flag procedurally (no image assets), sized to the control's rect. Correct
## designs: USSR (red, gold star + hammer & sickle), GDR (black-red-gold + state emblem), Great Britain
## (Union Jack), Australia (Blue Ensign — Union Jack canton, Commonwealth star, Southern Cross).
## Instantiate: var f := FlagRenderer.new(); f.set_country(&"USSR").

@export var country_id: StringName = &"USSR"
@export var waving := true

var _t := 0.0

func _ready() -> void:
	set_process(waving)

func set_country(id: StringName) -> void:
	country_id = id
	queue_redraw()

func _process(delta: float) -> void:
	if waving:
		_t += delta
		queue_redraw()

func _draw() -> void:
	var w := size.x
	var h := size.y
	# A gentle whole-flag sway when waving (keeps the design undistorted).
	var off := Vector2(0, sin(_t * 3.0) * h * 0.02) if waving else Vector2.ZERO
	var r := Rect2(off, Vector2(w, h))
	match country_id:
		&"USSR":
			_ussr(r)
		&"GDR":
			_gdr(r)
		&"GBR":
			_gbr(r)
		&"AUS":
			_aus(r)
		_:
			draw_rect(r, Palette.PANEL)

# --- USSR: red field, gold star over hammer & sickle in the upper hoist -------
func _ussr(r: Rect2) -> void:
	var w := r.size.x
	var h := r.size.y
	draw_rect(r, Color("c60c1e"))
	var gold := Color("ffd633")
	var cx := r.position.x + w * 0.24
	# star
	var star_c := Vector2(cx, r.position.y + h * 0.22)
	draw_colored_polygon(_star(star_c, h * 0.10, h * 0.045, 5), gold)
	# hammer & sickle below
	var c := Vector2(cx, r.position.y + h * 0.52)
	var s := h * 0.22
	# sickle (arc + blade)
	draw_arc(c + Vector2(-s * 0.05, 0), s * 0.42, deg_to_rad(60), deg_to_rad(300), 12, gold, maxf(1.0, s * 0.12))
	# hammer (handle + head)
	draw_line(c + Vector2(-s * 0.30, s * 0.30), c + Vector2(s * 0.30, -s * 0.30), gold, maxf(1.0, s * 0.12))
	draw_line(c + Vector2(s * 0.12, -s * 0.42), c + Vector2(s * 0.42, -s * 0.12), gold, maxf(1.0, s * 0.16))

# --- GDR: black/red/gold horizontal thirds + centred emblem -------------------
func _gdr(r: Rect2) -> void:
	var w := r.size.x
	var h := r.size.y
	var third := h / 3.0
	draw_rect(Rect2(r.position, Vector2(w, third)), Color("111111"))
	draw_rect(Rect2(r.position + Vector2(0, third), Vector2(w, third)), Color("d21e2b"))
	draw_rect(Rect2(r.position + Vector2(0, third * 2.0), Vector2(w, third)), Color("ffce00"))
	# state emblem: hammer + compass inside a rye wreath (simplified)
	var c := r.position + r.size * 0.5
	var rad := h * 0.22
	var gold := Color("caa02a")
	draw_arc(c, rad, deg_to_rad(120), deg_to_rad(420), 20, gold, maxf(1.0, h * 0.03))   # wreath
	draw_rect(Rect2(c.x - rad * 0.5, c.y - rad * 0.28, rad, rad * 0.56), gold, false, maxf(1.0, h * 0.03))  # hammer/compass block
	draw_line(c + Vector2(-rad * 0.35, rad * 0.3), c + Vector2(rad * 0.35, -rad * 0.3), gold, maxf(1.0, h * 0.03))

# --- Great Britain: the Union Jack --------------------------------------------
func _gbr(r: Rect2) -> void:
	_union_jack(r)

func _union_jack(r: Rect2) -> void:
	var blue := Color("012169")
	var white := Color("ffffff")
	var red := Color("c8102e")
	var w := r.size.x
	var h := r.size.y
	var o := r.position
	draw_rect(r, blue)
	var tl := o
	var tr := o + Vector2(w, 0)
	var bl := o + Vector2(0, h)
	var br := o + Vector2(w, h)
	# white saltire (St Andrew) then red saltire (St Patrick, thinner)
	draw_line(tl, br, white, h * 0.22)
	draw_line(tr, bl, white, h * 0.22)
	draw_line(tl, br, red, h * 0.10)
	draw_line(tr, bl, red, h * 0.10)
	# white cross (broad) then red cross (St George)
	var c := o + r.size * 0.5
	draw_rect(Rect2(c.x - w * 0.17, o.y, w * 0.34, h), white)
	draw_rect(Rect2(o.x, c.y - h * 0.17, w, h * 0.34), white)
	draw_rect(Rect2(c.x - w * 0.10, o.y, w * 0.20, h), red)
	draw_rect(Rect2(o.x, c.y - h * 0.10, w, h * 0.20), red)

# --- Australia: Blue Ensign ---------------------------------------------------
func _aus(r: Rect2) -> void:
	var w := r.size.x
	var h := r.size.y
	var o := r.position
	draw_rect(r, Color("012169"))
	# Union Jack canton (upper hoist quarter)
	_union_jack(Rect2(o, Vector2(w * 0.5, h * 0.5)))
	var white := Color("ffffff")
	# Commonwealth star under the canton
	draw_colored_polygon(_star(o + Vector2(w * 0.25, h * 0.75), h * 0.14, h * 0.06, 7), white)
	# Southern Cross on the fly
	var cross := [
		Vector2(0.74, 0.30), Vector2(0.74, 0.82), Vector2(0.60, 0.55),
		Vector2(0.88, 0.60), Vector2(0.72, 0.62),
	]
	for i in cross.size():
		var p: Vector2 = cross[i]
		var rad: float = h * (0.055 if i < 4 else 0.032)
		draw_colored_polygon(_star(o + Vector2(p.x * w, p.y * h), rad, rad * 0.45, 5), white)

# --- helpers ------------------------------------------------------------------
func _star(center: Vector2, outer: float, inner: float, points: int) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in points * 2:
		var rad := outer if i % 2 == 0 else inner
		var ang := -PI / 2.0 + PI * i / points
		pts.append(center + Vector2(cos(ang), sin(ang)) * rad)
	return pts
