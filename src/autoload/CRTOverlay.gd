extends CanvasLayer
## Topmost full-screen CRT post-process (layer 100). Wraps everything below — gameplay, menus and the
## scene-transition fade — in the grainy tube look. Toggleable (CRTOverlay.set_enabled(false)) so it
## can be disabled for debugging or as a future accessibility setting.

const SHADER_PATH := "res://src/shaders/crt.gdshader"

var _rect: ColorRect
var _enabled := true

func _ready() -> void:
	layer = 100
	_rect = ColorRect.new()
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var mat := ShaderMaterial.new()
	var shader: Shader = load(SHADER_PATH)
	if shader:
		mat.shader = shader
	_rect.material = mat
	add_child(_rect)
	get_viewport().size_changed.connect(_resize)
	_resize()

func _resize() -> void:
	if _rect:
		_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func set_enabled(on: bool) -> void:
	_enabled = on
	if _rect:
		_rect.visible = on

func is_enabled() -> bool:
	return _enabled

func toggle() -> void:
	set_enabled(not _enabled)
