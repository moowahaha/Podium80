extends Control
class_name BaseScreen
## Base for all menu/flow screens: applies the shared theme, fills the fixed 16:9 base resolution, and
## paints the shared menu backdrop (a supplied background image if present, else a warm gradient).
## Subclasses override `_screen_ready()` (not `_ready()`), and may override `_paint_bg()`.
##
## The backdrop image is loaded once and shared by every menu screen. `bg_scrim` darkens it for text
## contrast on content-heavy screens (standings/results); lighter screens lower it.

const MENU_BG := "res://assets/menu/background.png"
static var _menu_bg: Texture2D
static var _menu_bg_loaded := false

var bg_scrim := 0.42          # 0 = show image as-is, 1 = fully dark

func _ready() -> void:
	theme = UI.theme
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	custom_minimum_size = Palette.BASE_SIZE
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if not _menu_bg_loaded:
		_menu_bg_loaded = true
		if ResourceLoader.exists(MENU_BG):
			_menu_bg = load(MENU_BG)
	AudioBus.play_music(_music_key())
	_screen_ready()

## Override in subclasses.
func _screen_ready() -> void:
	pass

## Music track key for this screen (loads assets/music/<key>.ogg). Menu screens share "menu".
func _music_key() -> StringName:
	return &"menu"

func _draw() -> void:
	_paint_bg()

func _paint_bg() -> void:
	var r := Palette.base_rect()
	if _menu_bg:
		draw_texture_rect(_menu_bg, r, false)
		if bg_scrim > 0.0:
			draw_rect(r, Color(Palette.INK.r, Palette.INK.g, Palette.INK.b, bg_scrim))
		return
	# Fallback: vertical gradient sky->deep for a night-stadium feel.
	var steps := 12
	for i in steps:
		var t := float(i) / steps
		var col := Palette.SKY_TOP.lerp(Palette.INK, t)
		draw_rect(Rect2(0, r.size.y * t, r.size.x, r.size.y / steps + 1), col)

## Shared menu backdrop texture, or null if none supplied.
func menu_bg() -> Texture2D:
	return _menu_bg
