extends Node
## Shared UI theme + widget helpers. One place to retune fonts/colours; a real pixel-font TTF can be
## assigned to `_font` here later and every screen picks it up (see set_pixel_font).

var theme: Theme
var _font: Font

func _ready() -> void:
	theme = Theme.new()
	theme.default_font_size = 20
	# Panel default look
	var sb := StyleBoxFlat.new()
	sb.bg_color = Palette.PANEL
	sb.set_border_width_all(1)
	sb.border_color = Palette.PANEL_LIGHT
	sb.set_corner_radius_all(0)
	theme.set_stylebox("panel", "PanelContainer", sb)
	theme.set_color("font_color", "Label", Palette.PAPER)

## Drop in a real pixel font later without touching any screen.
func set_pixel_font(font: Font) -> void:
	_font = font
	if theme:
		theme.default_font = font

## Make a Label with common defaults (size, colour, optional outline for readability over stadiums).
func label(text: String, size := 20, color := Palette.PAPER, outline := true) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if outline:
		l.add_theme_color_override("font_outline_color", Palette.INK)
		l.add_theme_constant_override("outline_size", 5)
	if _font:
		l.add_theme_font_override("font", _font)
	return l

func center_label(text: String, size := 20, color := Palette.PAPER) -> Label:
	var l := label(text, size, color)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return l
