extends CanvasLayer
## Scene transitions with a CRT-friendly fade-to-black. Autoloaded above gameplay (layer 90) but below
## the CRT overlay (layer 100). Call SceneRouter.goto_scene("res://...") from anywhere.

const FADE_TIME := 0.28

var _fade: ColorRect
var _busy := false

func _ready() -> void:
	layer = 90
	_fade = ColorRect.new()
	_fade.color = Color(0, 0, 0, 0)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_fade)
	# Cover the whole viewport regardless of stretch.
	get_viewport().size_changed.connect(_resize)
	_resize()

func _resize() -> void:
	if _fade:
		_fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func goto_scene(path: String) -> void:
	if _busy:
		return
	_busy = true
	await _fade_to(1.0)
	var err := get_tree().change_scene_to_file(path)
	if err != OK:
		push_error("SceneRouter: failed to load %s (err %d)" % [path, err])
	# Let the new scene enter the tree before fading back in.
	await get_tree().process_frame
	await _fade_to(0.0)
	_busy = false

func _fade_to(target_alpha: float) -> void:
	var t := create_tween()
	t.tween_property(_fade, "color:a", target_alpha, FADE_TIME)
	await t.finished
