extends Control
class_name FlagRenderer
## Draws a country's placeholder flag from its CountryData spec (bands + optional emblem). Purely
## procedural (no image assets) and data-driven, so new flags are just data. Optional gentle wave for
## a lively banner. Instantiate in code: var f := FlagRenderer.new(); f.set_country(&"USSR").

@export var country_id: StringName = &"USSR"
@export var waving := true

const COLS := 16
const ROWS := 11

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
	var spec := CountryData.flag_of(country_id)
	if spec.is_empty():
		draw_rect(Rect2(Vector2.ZERO, size), Palette.PANEL)
		return
	var w := size.x
	var h := size.y
	var cw := w / COLS
	var ch := h / ROWS
	var amp := h * 0.05 if waving else 0.0

	# Draw the flag as a low-res grid so it can wave, then draw a subtle pole shadow.
	for cx in COLS:
		var u := (cx + 0.5) / COLS
		var wave: float = sin(_t * 4.5 + u * TAU) * amp * u   # more sway toward the free edge
		var shade: float = 1.0 - 0.10 * cos(_t * 4.5 + u * TAU) * u
		for cy in ROWS:
			var v := (cy + 0.5) / ROWS
			var col := _sample(spec, u, v)
			col = col * shade
			col.a = 1.0
			draw_rect(Rect2(cx * cw, cy * ch + wave, cw + 1.0, ch + 1.0), col)

	# Emblem on top (drawn crisp; follows the local wave at its column).
	var emblem = spec.get("emblem")
	if emblem != null:
		var pos: Vector2 = emblem["pos"]
		var wave2: float = sin(_t * 4.5 + pos.x * TAU) * amp * pos.x
		var center := Vector2(pos.x * w, pos.y * h + wave2)
		var radius: float = emblem["size"] * min(w, h)
		match String(emblem["shape"]):
			"star":
				draw_colored_polygon(_star_points(center, radius, radius * 0.45, 5), emblem["color"])
			"ring":
				draw_arc(center, radius, 0.0, TAU, 24, emblem["color"], max(1.0, radius * 0.28))
			_:
				draw_circle(center, radius, emblem["color"])

func _sample(spec: Dictionary, u: float, v: float) -> Color:
	var bands: Array = spec["bands"]
	if bands.is_empty():
		return Palette.PANEL
	var t := v if String(spec.get("orient", "horizontal")) == "horizontal" else u
	var idx := clampi(int(t * bands.size()), 0, bands.size() - 1)
	return bands[idx]

func _star_points(center: Vector2, outer: float, inner: float, points: int) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in points * 2:
		var r := outer if i % 2 == 0 else inner
		var ang := -PI / 2.0 + PI * i / points
		pts.append(center + Vector2(cos(ang), sin(ang)) * r)
	return pts
