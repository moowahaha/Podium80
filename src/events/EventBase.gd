extends Node2D
class_name EventBase
## Base for every event scene. Owns the common systems so each event module stays focused on its own
## gameplay: a screen-space HUD (event title, EVENT n/5, a centre message banner, a bottom prompt),
## the list of human competitors, and the standard "finish -> submit result -> results screen" route.
##
## Subclasses override `_event_ready()` and use: humans(), set_prompt(), show_message(), banner(),
## finish(). World content (Stadium, Athletes, CameraManager) is added by the subclass.

const RESULTS_SCENE := "res://src/menus/EventResults.tscn"

var hud: CanvasLayer
var _title: Label
var _counter: Label
var _prompt: Label
var _banner: Label
var _banner_t := 0.0
var _finished := false

func _ready() -> void:
	_build_hud()
	if _music_key() != &"":
		AudioBus.play_music(_music_key())
	_event_ready()

## Override in subclasses.
func _event_ready() -> void:
	pass

## Music track key for this event (loads assets/music/<key>.ogg), paired with its stadium backdrop.
func _music_key() -> StringName:
	return &""

func _build_hud() -> void:
	hud = CanvasLayer.new()
	hud.layer = 5
	add_child(hud)

	var ev := Game.current_event()
	_title = UI.label(String(ev["title"]), 25, Palette.HIGHLIGHT)
	_title.position = Vector2(15, 10)
	hud.add_child(_title)

	if not Game.single_event_mode:
		_counter = UI.label("EVENT %d/%d" % [Game.current_event_index + 1, Game.event_count()], 18, Palette.PAPER)
		_counter.position = Vector2(15, 40)
		hud.add_child(_counter)

	_banner = UI.center_label("", 40, Palette.PAPER)
	_banner.position = Vector2(0, 195)
	_banner.size = Vector2(Palette.BASE_WIDTH, 60)
	_banner.modulate.a = 0.0
	hud.add_child(_banner)

	_prompt = UI.center_label("", 20, Palette.PAPER)
	_prompt.position = Vector2(0, 500)
	_prompt.size = Vector2(Palette.BASE_WIDTH, 25)
	hud.add_child(_prompt)

func _process(delta: float) -> void:
	if _banner_t > 0.0:
		_banner_t -= delta
		if _banner_t <= 0.0:
			_banner.modulate.a = 0.0

# --- Helpers for subclasses ---------------------------------------------------

## Human competitor country ids in player order ([] if a demo/AI-only run).
func humans() -> Array:
	var out: Array = []
	for pi in range(Game.human_count()):
		var id := Game.country_for_player(pi)
		if id != &"":
			out.append(id)
	return out

func set_prompt(text: String) -> void:
	_prompt.text = text

## A transient centre banner (e.g. "FALSE START", "FOUL", "NEW RECORD").
func banner(text: String, color := Palette.PAPER, hold := 1.4) -> void:
	_banner.text = text
	_banner.add_theme_color_override("font_color", color)
	_banner.modulate.a = 1.0
	_banner_t = hold

func banner_persist(text: String, color := Palette.PAPER) -> void:
	_banner.text = text
	_banner.add_theme_color_override("font_color", color)
	_banner.modulate.a = 1.0
	_banner_t = 0.0

## Finish the event: submit results (human + optional pre-rolled AI) and go to the results screen.
func finish(human_values: Dictionary, ai_values: Dictionary = {}) -> void:
	if _finished:
		return
	_finished = true
	Game.submit_event(human_values, ai_values)
	set_prompt("")
	await get_tree().create_timer(0.6).timeout
	SceneRouter.goto_scene(RESULTS_SCENE)

## A short countdown helper (returns when done). Cancel by setting `cancel` via the callable check.
func wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout
