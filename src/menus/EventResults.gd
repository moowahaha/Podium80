extends BaseScreen
## Per-event results: the four nations ranked with their marks and the championship points awarded.
## A continues — to the hub for the next event, or to the podium after the fifth.

const HUB := "res://src/menus/ChampionshipHub.tscn"
const PODIUM := "res://src/menus/Podium.tscn"

var _busy := false
var _reveal := 0.0

func _screen_ready() -> void:
	var ev := Game.current_event()
	var ranked := Game.last_result()

	var t := UI.center_label("%s — RESULTS" % ev["title"], 12, Palette.HIGHLIGHT)
	t.position = Vector2(0, 14)
	t.size = Vector2(Palette.BASE_WIDTH, 14)
	add_child(t)

	var y := 44.0
	var medal := [Palette.HIGHLIGHT, Color("c0c0cc"), Color("cd7f32"), Palette.PANEL_LIGHT]
	for i in ranked.size():
		var r: Dictionary = ranked[i]
		var id: StringName = r["country"]

		var place := UI.label("%d" % (i + 1), 12, medal[mini(i, 3)])
		place.position = Vector2(50, y)
		add_child(place)

		var flag := FlagRenderer.new()
		flag.waving = false
		flag.set_country(id)
		flag.position = Vector2(68, y + 1)
		flag.size = Vector2(20, 13)
		add_child(flag)

		var nm := UI.label("%s  %s" % [CountryData.abbrev_of(id), Game.name_of(id)], 8, _color(id))
		nm.position = Vector2(94, y + 2)
		add_child(nm)

		var mark := UI.label(_format(float(r["value"]), String(ev["unit"])), 8, Palette.PAPER)
		mark.position = Vector2(228, y + 2)
		add_child(mark)

		var pts := UI.label("+%d" % int(r["points"]), 8, Palette.GOOD)
		pts.position = Vector2(300, y + 2)
		add_child(pts)
		y += 22.0

	var prompt := UI.center_label("PRESS  A  TO CONTINUE", 8, Palette.PAPER)
	prompt.position = Vector2(0, 190)
	prompt.size = Vector2(Palette.BASE_WIDTH, 10)
	add_child(prompt)

	AudioBus.play(&"points")

func _format(v: float, unit: String) -> String:
	match unit:
		"s":
			return "%.2f s" % v
		"m":
			return "%.2f m" % v
		"pts":
			return "%d pts" % int(round(v))
		_:
			return "%.2f" % v

func _color(id: StringName) -> Color:
	return Palette.HIGHLIGHT if Game.is_human(id) else Palette.PAPER

func _process(_delta: float) -> void:
	if _busy:
		return
	if Input.is_action_just_pressed(Platform.act(0, &"a")):
		_busy = true
		AudioBus.play(&"select")
		if Game.is_championship_over():
			SceneRouter.goto_scene(PODIUM)
		else:
			Game.advance_event()
			SceneRouter.goto_scene(HUB)
