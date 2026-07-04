extends Control
class_name FlagRenderer
## Draws each nation's flag from a bitmap in assets/flags/. The source art is a transparent
## waving-flag PNG, cropped to the flag and stretched to fill the control's rect (with an optional
## gentle vertical sway when waving). Instantiate: var f := FlagRenderer.new(); f.set_country(&"USSR").

@export var country_id: StringName = &"USSR"
@export var waving := true

const TEXTURES := {
	&"USSR": "res://assets/flags/ussr.png",
	&"GDR": "res://assets/flags/gdr.png",
	&"GBR": "res://assets/flags/gbr.png",
	&"AUS": "res://assets/flags/aus.png",
}

var _t := 0.0
var _texture: Texture2D

func _ready() -> void:
	if _texture == null:
		_load_texture()
	set_process(waving)

func set_country(id: StringName) -> void:
	country_id = id
	_load_texture()
	queue_redraw()

func _load_texture() -> void:
	_texture = load(TEXTURES[country_id]) if TEXTURES.has(country_id) else null

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
	if _texture != null:
		draw_texture_rect(_texture, r, false)
	else:
		draw_rect(r, Palette.PANEL)
