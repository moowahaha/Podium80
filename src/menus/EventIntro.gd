extends BaseScreen
## Pre-event title card: the event's backdrop, its name in big type, a state slogan, a trumpet
## fanfare, and "press any button" to drop into the event. Shown before every event (championship or
## single). Reads the target from Game.current_event().

const SIM_RESULTS := "res://src/menus/EventResults.tscn"

var _bg: Texture2D
var _ev: Dictionary
var _t := 0.0
var _armed := false
var _busy := false
var _prompt: Label

func _music_key() -> StringName:
	return &""            # silence under the fanfare

func _screen_ready() -> void:
	_ev = Game.current_event()
	var path := "res://assets/backgrounds/%s.png" % String(_ev["id"])
	if ResourceLoader.exists(path):
		_bg = load(path)

	if not Game.single_event_mode:
		var counter := UI.center_label("EVENT %d/%d" % [Game.event_number(), Game.event_count()], 24, Palette.PAPER)
		counter.position = Vector2(0, 120)
		counter.size = Vector2(Palette.BASE_WIDTH, 30)
		add_child(counter)

	var title := UI.center_label(String(_ev["title"]), 60, Palette.HIGHLIGHT)
	title.position = Vector2(0, 160)
	title.size = Vector2(Palette.BASE_WIDTH, 80)
	add_child(title)

	# State slogan in the Cyrillic display face.
	var ruslan: Font = load("res://assets/fonts/RuslanDisplay.ttf")
	var sub := Label.new()
	sub.text = Slogans.pick()
	sub.add_theme_font_override("font", ruslan)
	sub.add_theme_font_size_override("font_size", 26)
	sub.add_theme_color_override("font_color", Color("e2342f"))
	sub.add_theme_color_override("font_outline_color", Palette.INK)
	sub.add_theme_constant_override("outline_size", 3)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sub.position = Vector2(90, 260)
	sub.size = Vector2(Palette.BASE_WIDTH - 180, 90)
	add_child(sub)

	_prompt = UI.center_label("PRESS ANY BUTTON", 28, Palette.GOOD)
	_prompt.position = Vector2(0, 460)
	_prompt.size = Vector2(Palette.BASE_WIDTH, 36)
	add_child(_prompt)

	AudioBus.play(&"fanfare")

func _process(delta: float) -> void:
	_t += delta
	if _t > 0.35:
		_armed = true                                  # ignore the press that entered this screen
	_prompt.modulate.a = 0.55 + 0.45 * (0.5 + 0.5 * sin(_t * 4.0))
	queue_redraw()

func _input(event: InputEvent) -> void:
	if _busy or not _armed:
		return
	var go: bool = (event is InputEventKey and event.pressed and not event.echo) \
		or (event is InputEventJoypadButton and event.pressed) \
		or (event is InputEventMouseButton and event.pressed)
	if go:
		_advance()

func _advance() -> void:
	_busy = true
	AudioBus.play(&"select")
	var scene := String(_ev["scene"])
	if ResourceLoader.exists(scene):
		SceneRouter.goto_scene(scene)
	else:
		Game.submit_event({})                          # unbuilt event: simulate + results
		SceneRouter.goto_scene(SIM_RESULTS)

func _paint_bg() -> void:
	var r := Palette.base_rect()
	if _bg:
		draw_texture_rect(_bg, r, false)
		draw_rect(Rect2(0, 110, r.size.x, 250), Color(0, 0, 0, 0.38))     # scrim behind title
		draw_rect(Rect2(0, 445, r.size.x, 70), Color(0, 0, 0, 0.45))      # scrim behind prompt
	else:
		super._paint_bg()
