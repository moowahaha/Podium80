extends BaseScreen
## First screen on boot: the wordmark, a state slogan, and the 1/2-player choice, then straight to
## event selection.

const NEXT := "res://src/menus/ModeSelect.tscn"

var num_players := 1
var _t := 0.0
var _busy := false
var _lbl: Label

func _screen_ready() -> void:
	Platform.reset_claims()   # fresh session: the first pad to press here becomes P1, the next P2
	num_players = maxi(1, Game.pending_players)
	UI.add_podium_logo(self, 60, 82)
	_add_slogan(158.0)

	var head := UI.center_label("HOW MANY PLAYERS?", 30, Palette.PAPER)
	head.position = Vector2(0, 220)
	head.size = Vector2(Palette.BASE_WIDTH, 36)
	add_child(head)

	_lbl = UI.center_label("", 42, Palette.HIGHLIGHT)
	_lbl.position = Vector2(0, 280)
	_lbl.size = Vector2(Palette.BASE_WIDTH, 52)
	add_child(_lbl)

	var prompt := UI.center_label("◄ ►  CHOOSE      A  CONFIRM", 20, Palette.GOOD)
	prompt.position = Vector2(0, 470)
	prompt.size = Vector2(Palette.BASE_WIDTH, 26)
	add_child(prompt)

## A random state slogan under the wordmark, sized to fit ~60% of the screen width.
func _add_slogan(y: float) -> void:
	var ruslan: Font = load("res://assets/fonts/RuslanDisplay.ttf")
	var tag := Slogans.pick()
	var mw: float = ruslan.get_string_size(tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 100).x
	var size := clampi(int(0.9 * 100.0 * (Palette.BASE_WIDTH * 0.62) / maxf(mw, 1.0)), 12, 22)
	var sub := Label.new()
	sub.text = tag
	sub.add_theme_font_override("font", ruslan)
	sub.add_theme_font_size_override("font_size", size)
	sub.add_theme_color_override("font_color", Color("e2342f"))
	sub.add_theme_color_override("font_outline_color", Palette.INK)
	sub.add_theme_constant_override("outline_size", 3)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.position = Vector2(0, y)
	sub.size = Vector2(Palette.BASE_WIDTH, size + 8)
	add_child(sub)

func _process(delta: float) -> void:
	_t += delta
	_lbl.text = "◄   %s   ►" % ("1 PLAYER" if num_players == 1 else "2 PLAYERS")
	_lbl.modulate.a = 0.85 + 0.15 * sin(_t * 6.0)
	queue_redraw()
	if _busy:
		return
	if Input.is_action_just_pressed(Platform.act(0, &"left")) or Input.is_action_just_pressed(Platform.act(0, &"right")):
		num_players = 3 - num_players
		AudioBus.play(&"move")
	if Input.is_action_just_pressed(Platform.act(0, &"a")):
		_busy = true
		Game.pending_players = num_players
		AudioBus.play(&"select")
		SceneRouter.goto_scene(NEXT)
