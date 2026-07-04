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
	# Menus/UI use Racing Sans One.
	if ResourceLoader.exists("res://assets/fonts/RacingSansOne-Regular.ttf"):
		set_pixel_font(load("res://assets/fonts/RacingSansOne-Regular.ttf"))

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

# --- Shared "PODIUM '80" wordmark (Russo One, red + blue) ---------------------
const RUSSO := "res://assets/fonts/RussoOne-Regular.ttf"
const LOGO_RED := Color("e2342f")
const LOGO_BLUE := Color("2f6fe0")

## Add the two-colour PODIUM '80 wordmark to `parent`, centred at font size `fsize`, top at `y`.
## Returns the wordmark's pixel width. Use everywhere the logo appears so it stays identical.
func add_podium_logo(parent: Node, y: float, fsize: int) -> float:
	var russo: Font = load(RUSSO)
	var w1: float = russo.get_string_size("PODIUM ", HORIZONTAL_ALIGNMENT_LEFT, -1, fsize).x
	var w2: float = russo.get_string_size("'80", HORIZONTAL_ALIGNMENT_LEFT, -1, fsize).x
	var sx := (Palette.BASE_WIDTH - (w1 + w2)) / 2.0
	parent.add_child(_logo_part("PODIUM ", LOGO_RED, russo, fsize, sx, y))
	parent.add_child(_logo_part("'80", LOGO_BLUE, russo, fsize, sx + w1, y))
	return w1 + w2

func _logo_part(text: String, color: Color, font: Font, fsize: int, x: float, y: float) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", fsize)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Palette.INK)
	l.add_theme_constant_override("outline_size", maxi(2, fsize / 10))
	l.position = Vector2(x, y)
	return l
