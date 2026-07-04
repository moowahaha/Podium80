extends BaseScreen
## Mode select: choose the number of players (◄ ► 1/2), then pick CHAMPIONSHIP (all events) or any
## single event to play on its own. A confirms, B returns to the title.

const TITLE_SCENE := "res://src/menus/TitleScreen.tscn"
const COUNTRY_SELECT := "res://src/menus/CountrySelect.tscn"

var options: Array = []                # [{label, champ, index}]
var sel := 0
var num_players := 1
var _t := 0.0
var _rows: Array[Label] = []
var _players_lbl: Label

func _screen_ready() -> void:
	num_players = maxi(1, Game.pending_players)

	options.append({"label": "CHAMPIONSHIP  —  ALL EVENTS", "champ": true, "index": -1})
	for i in Game.EVENTS.size():
		options.append({"label": String(Game.EVENTS[i]["title"]), "champ": false, "index": i})

	UI.add_podium_logo(self, 12, 58)

	_players_lbl = UI.center_label("", 26, Palette.PAPER)
	_players_lbl.position = Vector2(0, 108)
	_players_lbl.size = Vector2(Palette.BASE_WIDTH, 30)
	add_child(_players_lbl)

	var y := 175.0
	for i in options.size():
		var lbl := UI.center_label(options[i]["label"], 26, Palette.PAPER)
		lbl.position = Vector2(0, y)
		lbl.size = Vector2(Palette.BASE_WIDTH, 30)
		add_child(lbl)
		_rows.append(lbl)
		y += 48.0

	var prompt := UI.center_label("↑ ↓  SELECT      ◄ ►  PLAYERS      A  CONFIRM      B  BACK", 18, Palette.GOOD)
	prompt.position = Vector2(0, 505)
	prompt.size = Vector2(Palette.BASE_WIDTH, 22)
	add_child(prompt)

func _process(delta: float) -> void:
	_t += delta
	_players_lbl.text = "◄  %s  ►" % ("1 PLAYER" if num_players == 1 else "2 PLAYERS")
	for i in _rows.size():
		if i == sel:
			_rows[i].add_theme_color_override("font_color", Palette.HIGHLIGHT)
			_rows[i].modulate.a = 0.85 + 0.15 * sin(_t * 6.0)
		else:
			_rows[i].add_theme_color_override("font_color", Palette.PAPER)
			_rows[i].modulate.a = 1.0
	_handle_input()

func _handle_input() -> void:
	if Input.is_action_just_pressed(Platform.act(0, &"up")):
		sel = (sel - 1 + options.size()) % options.size()
		AudioBus.play(&"move")
	if Input.is_action_just_pressed(Platform.act(0, &"down")):
		sel = (sel + 1) % options.size()
		AudioBus.play(&"move")
	if Input.is_action_just_pressed(Platform.act(0, &"left")) or Input.is_action_just_pressed(Platform.act(0, &"right")):
		num_players = 3 - num_players
		AudioBus.play(&"move")
	if Input.is_action_just_pressed(Platform.act(0, &"a")):
		_confirm()
	if Input.is_action_just_pressed(Platform.act(0, &"b")):
		AudioBus.play(&"back")
		SceneRouter.goto_scene(TITLE_SCENE)

func _confirm() -> void:
	AudioBus.play(&"select")
	Game.pending_players = num_players
	var opt: Dictionary = options[sel]
	if opt["champ"]:
		Game.pending_mode = "championship"
	else:
		Game.pending_mode = "single"
		Game.pending_event_index = int(opt["index"])
	SceneRouter.goto_scene(COUNTRY_SELECT)
