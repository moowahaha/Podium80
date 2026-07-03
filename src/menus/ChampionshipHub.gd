extends BaseScreen
## Championship hub shown before each event: current standings + the next event, with A to compete.
## Also the progression spine — after the fifth event it routes to the podium.

const TITLE_SCENE := "res://src/menus/TitleScreen.tscn"
const RESULTS_SCENE := "res://src/menus/EventResults.tscn"

var _t := 0.0
var _flags: Array = []
var _busy := false

func _screen_ready() -> void:
	if Game.participants.is_empty():
		# Safety: reached without a championship (e.g. direct run) — start a default one.
		Game.start_championship([CountryData.all_ids()[0]])

	var t := UI.center_label("CHAMPIONSHIP STANDINGS", 30, Palette.HIGHLIGHT)
	t.position = Vector2(0, 30)
	t.size = Vector2(Palette.BASE_WIDTH, 35)
	add_child(t)

	# Standings rows built fresh each entry.
	var rows := Game.standings_sorted()
	var y := 100.0
	for r in rows:
		var id: StringName = r["country"]
		var flag := FlagRenderer.new()
		flag.waving = false
		flag.set_country(id)
		flag.position = Vector2(175, y)
		flag.size = Vector2(50, 32)
		add_child(flag)
		_flags.append(flag)

		var nm := UI.label(CountryData.name_of(id), 20, _row_color(id))
		nm.position = Vector2(240, y + 5)
		add_child(nm)

		var pts := UI.label("%d PTS" % int(r["points"]), 20, Palette.PAPER)
		pts.position = Vector2(625, y + 5)
		add_child(pts)
		y += 55.0

	var ev := Game.current_event()
	var nxt := UI.center_label("NEXT — EVENT %d/%d:  %s" % [Game.current_event_index + 1, Game.event_count(), ev["title"]], 22, Palette.PAPER)
	nxt.position = Vector2(0, 375)
	nxt.size = Vector2(Palette.BASE_WIDTH, 30)
	add_child(nxt)

	var prompt := UI.center_label("PRESS  A  TO COMPETE      B  QUIT", 20, Palette.GOOD)
	prompt.position = Vector2(0, 465)
	prompt.size = Vector2(Palette.BASE_WIDTH, 25)
	add_child(prompt)

func _row_color(id: StringName) -> Color:
	return Palette.HIGHLIGHT if Game.is_human(id) else Palette.PAPER

func _process(delta: float) -> void:
	_t += delta
	if _busy:
		return
	if Input.is_action_just_pressed(Platform.act(0, &"a")):
		_compete()
	elif Input.is_action_just_pressed(Platform.act(0, &"b")):
		_busy = true
		AudioBus.play(&"back")
		Game.reset()
		SceneRouter.goto_scene(TITLE_SCENE)

func _compete() -> void:
	_busy = true
	AudioBus.play(&"select")
	var scene: String = Game.current_event()["scene"]
	if ResourceLoader.exists(scene):
		SceneRouter.goto_scene(scene)
	else:
		# Event not built yet: simulate it so the championship loop stays fully playable.
		Game.submit_event({})
		SceneRouter.goto_scene(RESULTS_SCENE)
