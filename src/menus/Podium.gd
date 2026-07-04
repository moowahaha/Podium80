extends BaseScreen
## Podium ceremony over the Red Square backdrop. Shown after the championship (overall standings) or
## after a single event (that event's ranking). The top three nations stand on the gold/silver/bronze
## blocks (positions detected from the colour-coded art) under a sky full of fireworks.

const PLAYER_SELECT := "res://src/menus/PlayerSelect.tscn"
const MODE_SELECT := "res://src/menus/ModeSelect.tscn"
const BG := "res://assets/backgrounds/podium.png"

# Feet positions on each block's top surface (place 0/1/2 = gold/silver/bronze), read off the art.
const SLOTS := [Vector2(453, 370), Vector2(305, 398), Vector2(602, 406)]

func _music_key() -> StringName:
	return &"menu"

var _t := 0.0
var _busy := false
var _bg: Texture2D
var _rows: Array = []
var _flagpoles: Array = []       # {flag, x, base, cap, lo, hi, delay}
var _fw: Array = []              # firework particles {pos, vel, life, life0, col, size}
var _fw_timer := 0.0

func _screen_ready() -> void:
	bg_scrim = 0.0
	if ResourceLoader.exists(BG):
		_bg = load(BG)

	# Single event -> that event's ranking; championship -> overall standings.
	_rows = Game.last_result() if Game.single_event_mode else Game.standings_sorted()

	var title_txt := (String(Game.current_event()["title"]) + "  —  PODIUM") if Game.single_event_mode else "CHAMPIONS OF THE 1980 GAMES"
	var head := UI.center_label(title_txt, 28, Palette.HIGHLIGHT)
	head.position = Vector2(0, 24)
	head.size = Vector2(Palette.BASE_WIDTH, 32)
	add_child(head)

	for place in mini(3, _rows.size()):
		var id: StringName = _rows[place]["country"]
		var foot: Vector2 = SLOTS[place]

		var ath := Athlete.new()
		ath.set_country(id)
		ath.set_state(Athlete.State.CELEBRATE)     # dance sheet (ping-pong)
		ath.set_depth(1.15)
		ath.position = foot
		ath.z_index = 5
		ath._phase = place * 5.0                    # desync each place's dance
		add_child(ath)

		# A flag that raises up a pole behind the athlete (animated in _process).
		var flag := FlagRenderer.new()
		flag.waving = true
		flag.set_country(id)
		flag.size = Vector2(52, 33)
		flag.z_index = 4
		add_child(flag)
		_flagpoles.append({
			"flag": flag, "x": foot.x, "base": foot.y - 2.0, "cap": foot.y - 174.0,
			"lo": foot.y - 36.0, "hi": foot.y - 170.0,
			"delay": 0.35 + (2 - place) * 0.28,     # 3rd raises first, champion last
		})

	var prompt := UI.center_label("PRESS  A  TO CONTINUE", 20, Palette.PAPER)
	prompt.position = Vector2(0, 500)
	prompt.size = Vector2(Palette.BASE_WIDTH, 25)
	prompt.z_index = 6
	add_child(prompt)

	AudioBus.play(&"fanfare")

func _process(delta: float) -> void:
	_t += delta
	_update_fireworks(delta)
	for fp in _flagpoles:
		var tt := clampf((_t - float(fp["delay"])) / 1.3, 0.0, 1.0)
		fp["flag"].position = Vector2(float(fp["x"]) + 2.0, lerpf(float(fp["lo"]), float(fp["hi"]), ease(tt, 0.4)))
	queue_redraw()

	if not _busy and Input.is_action_just_pressed(Platform.act(0, &"a")):
		_busy = true
		AudioBus.play(&"select")
		if Game.single_event_mode:
			SceneRouter.goto_scene(MODE_SELECT)
		else:
			Game.reset()
			SceneRouter.goto_scene(PLAYER_SELECT)

# --- Fireworks ---------------------------------------------------------------

const FW_COLS := [Color("ffe14d"), Color("ff5b5b"), Color("5bd0ff"), Color("b98bff"), Color("6cff8f"), Color("ffffff"), Color("ff9d3b")]

func _update_fireworks(delta: float) -> void:
	_fw_timer -= delta
	if _fw_timer <= 0.0:
		_burst()
		_fw_timer = randf_range(0.12, 0.32)          # lots of them
	var grav := 60.0
	var alive: Array = []
	for p in _fw:
		p["life"] -= delta
		if p["life"] <= 0.0:
			continue
		p["vel"].y += grav * delta
		p["vel"] *= 0.985                             # air drag so sparks slow + hang
		p["pos"] += p["vel"] * delta
		alive.append(p)
	_fw = alive

func _burst() -> void:
	var center := Vector2(randf_range(70, Palette.BASE_WIDTH - 70), randf_range(35, 250))
	var col: Color = FW_COLS[randi() % FW_COLS.size()]
	var count := randi_range(26, 44)
	var power := randf_range(55.0, 150.0)
	for i in count:
		var ang := TAU * float(i) / count + randf_range(-0.1, 0.1)
		var spd := power * randf_range(0.55, 1.0)
		var life := randf_range(0.6, 1.35)
		_fw.append({
			"pos": center,
			"vel": Vector2(cos(ang), sin(ang)) * spd,
			"life": life, "life0": life,
			"col": col if randf() < 0.8 else Palette.PAPER,
			"size": randf_range(1.5, 3.5),
		})

func _paint_bg() -> void:
	var r := Palette.base_rect()
	if _bg:
		draw_texture_rect(_bg, r, false)
	else:
		super._paint_bg()
	# Flagpoles behind the athletes.
	for fp in _flagpoles:
		draw_line(Vector2(float(fp["x"]), float(fp["base"])), Vector2(float(fp["x"]), float(fp["cap"])), Palette.PANEL_LIGHT, 2.0)
		draw_circle(Vector2(float(fp["x"]), float(fp["cap"])), 3.0, Color("f4d84a"))
	# Fireworks over the sky (drawn under the athlete child nodes).
	for p in _fw:
		var a: float = clampf(p["life"] / p["life0"], 0.0, 1.0)
		var c: Color = p["col"]
		c.a = a
		var s: float = p["size"] * (0.6 + 0.4 * a)
		draw_rect(Rect2(p["pos"] - Vector2(s, s) * 0.5, Vector2(s, s)), c)
