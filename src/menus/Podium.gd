extends BaseScreen
## Final podium ceremony: top three nations on the blocks with flags, names and points; the champion
## celebrates under falling confetti and a fanfare. A returns to the title.

const TITLE_SCENE := "res://src/menus/TitleScreen.tscn"

# Screen slots per finishing place: 1st centre+tallest, 2nd left, 3rd right.
const SLOTS := [
	{"x": 192.0, "top": 120.0, "w": 44.0},   # 1st
	{"x": 142.0, "top": 138.0, "w": 44.0},   # 2nd
	{"x": 242.0, "top": 150.0, "w": 44.0},   # 3rd
]
const MEDAL := [Color("ffd23f"), Color("cfcfe0"), Color("cd7f32")]

var _t := 0.0
var _busy := false
var _confetti: Array = []
var _rows: Array = []

func _screen_ready() -> void:
	_rows = Game.standings_sorted()

	var champ_id: StringName = _rows[0]["country"] if not _rows.is_empty() else CountryData.all_ids()[0]
	var head := UI.center_label("CHAMPIONS OF THE 1980 GAMES", 11, Palette.HIGHLIGHT)
	head.position = Vector2(0, 12)
	head.size = Vector2(Palette.BASE_WIDTH, 12)
	add_child(head)

	var winner := UI.center_label("%s  —  %s" % [CountryData.name_of(champ_id), Game.name_of(champ_id)], 9, CountryData.accent_of(champ_id))
	winner.position = Vector2(0, 26)
	winner.size = Vector2(Palette.BASE_WIDTH, 10)
	add_child(winner)

	for place in mini(3, _rows.size()):
		var slot: Dictionary = SLOTS[place]
		var id: StringName = _rows[place]["country"]

		var flag := FlagRenderer.new()
		flag.set_country(id)
		flag.position = Vector2(slot["x"] - 15.0, slot["top"] - 40.0)
		flag.size = Vector2(30, 20)
		add_child(flag)

		var ath := Athlete.new()
		ath.set_country(id)
		ath.set_state(Athlete.State.CELEBRATE if place == 0 else Athlete.State.IDLE)
		ath.position = Vector2(slot["x"], slot["top"])
		add_child(ath)

		var nm := UI.center_label(CountryData.abbrev_of(id), 8, Palette.INK)
		nm.position = Vector2(slot["x"] - slot["w"] / 2.0, slot["top"] + 8.0)
		nm.size = Vector2(slot["w"], 8)
		add_child(nm)

		var pts := UI.center_label("%d PTS" % int(_rows[place]["points"]), 7, Palette.INK)
		pts.position = Vector2(slot["x"] - slot["w"] / 2.0, slot["top"] + 18.0)
		pts.size = Vector2(slot["w"], 8)
		add_child(pts)

	var prompt := UI.center_label("PRESS  A  TO RETURN TO TITLE", 8, Palette.PAPER)
	prompt.position = Vector2(0, 194)
	prompt.size = Vector2(Palette.BASE_WIDTH, 8)
	add_child(prompt)

	# Confetti.
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var cols := [Palette.HIGHLIGHT, Palette.ACCENT, Palette.GOOD, Color("3b7be2"), Palette.PAPER]
	for i in 80:
		_confetti.append({
			"pos": Vector2(rng.randf_range(0, Palette.BASE_WIDTH), rng.randf_range(-Palette.BASE_HEIGHT, 0)),
			"vel": Vector2(rng.randf_range(-6, 6), rng.randf_range(20, 55)),
			"col": cols[rng.randi_range(0, cols.size() - 1)],
			"sw": rng.randf_range(0, TAU),
		})

	AudioBus.play(&"fanfare")
	AudioBus.swell_crowd(-4.0)
	AudioBus.loop_crowd(true, -16.0)

func _process(delta: float) -> void:
	_t += delta
	for c in _confetti:
		c["pos"] += c["vel"] * delta
		c["pos"].x += sin(_t * 3.0 + c["sw"]) * 8.0 * delta
		if c["pos"].y > Palette.BASE_HEIGHT + 4.0:
			c["pos"].y = -4.0
			c["pos"].x = randf() * Palette.BASE_WIDTH
	queue_redraw()

	if not _busy and Input.is_action_just_pressed(Platform.act(0, &"a")):
		_busy = true
		AudioBus.play(&"select")
		Game.reset()
		SceneRouter.goto_scene(TITLE_SCENE)

func _paint_bg() -> void:
	var w := float(Palette.BASE_WIDTH)
	var h := float(Palette.BASE_HEIGHT)
	# Night ceremony gradient.
	var steps := 16
	for i in steps:
		var f := float(i) / steps
		var col := Color("1a1740").lerp(Color("3a2a5a"), f)
		draw_rect(Rect2(0, h * f, w, h / steps + 1.0), col)

	# Spotlights.
	for sx in [0.25, 0.5, 0.75]:
		var origin := Vector2(w * sx, h)
		var aim := Vector2(w * sx + sin(_t + sx * 6.0) * 30.0, 40.0)
		var dir := (aim - origin).normalized()
		var perp := Vector2(-dir.y, dir.x)
		var far := origin + dir * (h * 1.1)
		draw_colored_polygon(PackedVector2Array([origin, far + perp * 20.0, far - perp * 20.0]), Color(1, 0.95, 0.7, 0.05))

	# Podium blocks.
	for place in mini(3, _rows.size()):
		var slot: Dictionary = SLOTS[place]
		var top: float = slot["top"]
		var bw: float = slot["w"]
		var rect := Rect2(slot["x"] - bw / 2.0, top, bw, h - top)
		draw_rect(rect, MEDAL[place].darkened(0.1))
		draw_rect(rect, Palette.INK, false, 1.0)
		draw_rect(Rect2(rect.position, Vector2(bw, 3)), MEDAL[place])

	# Confetti.
	for c in _confetti:
		draw_rect(Rect2(c["pos"], Vector2(2, 3)), c["col"])
