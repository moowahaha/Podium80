extends BaseScreen
## Country selection. Choose 1 or 2 players (set on the mode screen), then each player picks a nation
## (D-pad left/right, A to lock). Two players must pick different nations. B unlocks / goes back.
## Each card: a flag sweeping diagonally across the top, the athlete in the middle, the name at the
## bottom, over a semi-transparent panel.

const MODE_SELECT := "res://src/menus/ModeSelect.tscn"
const HUB_SCENE := "res://src/menus/ChampionshipHub.tscn"

const CARD_W := 200.0
const GAP := 30.0
const CARD_Y := 130.0
const CARD_H := 300.0
const FLAG_LEFT_Y := CARD_Y + CARD_H * 0.5   # flag's diagonal meets the left edge 50% of the way down

var ids: Array[StringName] = []
var num_players := 1
var cursor := [0, 1]                 # per-player highlighted nation index
var locked := [false, false]
var _athletes: Array = []
var _flag_tex: Array = []
var _t := 0.0
var _bg: Texture2D

func _screen_ready() -> void:
	num_players = maxi(1, Game.pending_players)
	texture_filter = TEXTURE_FILTER_LINEAR
	if ResourceLoader.exists("res://assets/backgrounds/character_select.png"):
		_bg = load("res://assets/backgrounds/character_select.png")
	ids = CountryData.all_ids()
	var start_x := _start_x()

	for i in ids.size():
		var cx := start_x + i * (CARD_W + GAP)
		var fp := "res://assets/flags/%s.png" % String(ids[i]).to_lower()
		_flag_tex.append(load(fp) if ResourceLoader.exists(fp) else null)

		var name_lbl := UI.center_label(CountryData.name_of(ids[i]), 17, Palette.PAPER)
		name_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		name_lbl.custom_minimum_size = Vector2(CARD_W - 12, 0)
		name_lbl.position = Vector2(cx + 6, 360)
		name_lbl.size = Vector2(CARD_W - 12, 46)
		add_child(name_lbl)

		var ath := Athlete.new()
		ath.set_country(ids[i])
		ath.run_in_place = true               # jog on the spot when this nation is highlighted
		ath.set_state(Athlete.State.IDLE)
		ath.position = Vector2(cx + CARD_W / 2.0, 322)   # upper-middle of the card, below the flag
		add_child(ath)
		_athletes.append(ath)

	_title_labels()

func _start_x() -> float:
	var total := ids.size() * CARD_W + (ids.size() - 1) * GAP
	return (Palette.BASE_WIDTH - total) / 2.0

func _title_labels() -> void:
	var t := UI.center_label("SELECT YOUR NATION", 30, Palette.HIGHLIGHT)
	t.position = Vector2(0, 50)
	t.size = Vector2(Palette.BASE_WIDTH, 35)
	add_child(t)

func _process(delta: float) -> void:
	_t += delta
	_handle_input()
	_update_athlete_states()
	queue_redraw()

## The athlete on each highlighted card jogs on the spot; the rest stand idle.
func _update_athlete_states() -> void:
	for i in _athletes.size():
		var selected := false
		for p in num_players:
			if cursor[p] == i:
				selected = true
		_athletes[i].set_state(Athlete.State.RUN if selected else Athlete.State.IDLE)

func _handle_input() -> void:
	# Player 1
	if not locked[0]:
		if Input.is_action_just_pressed(Platform.act(0, &"left")):
			_move_cursor(0, -1)
		if Input.is_action_just_pressed(Platform.act(0, &"right")):
			_move_cursor(0, 1)
		if Input.is_action_just_pressed(Platform.act(0, &"a")):
			locked[0] = true
			AudioBus.play(&"select")
			if num_players == 2 and cursor[1] == cursor[0]:
				_move_cursor(1, 1)               # ensure P2 not on P1's nation
		if Input.is_action_just_pressed(Platform.act(0, &"b")):
			SceneRouter.goto_scene(MODE_SELECT)
		return

	# Player 2 (only when enabled and P1 done)
	if num_players == 2 and not locked[1]:
		if Input.is_action_just_pressed(Platform.act(1, &"left")):
			_move_cursor(1, -1)
		if Input.is_action_just_pressed(Platform.act(1, &"right")):
			_move_cursor(1, 1)
		if Input.is_action_just_pressed(Platform.act(1, &"a")):
			locked[1] = true
			AudioBus.play(&"select")
		if Input.is_action_just_pressed(Platform.act(1, &"b")):
			locked[0] = false                    # step back: P1 re-picks
			AudioBus.play(&"back")
		return

	# Everyone locked -> start on P1 A, unlock on B.
	if Input.is_action_just_pressed(Platform.act(0, &"a")):
		_start()
	if Input.is_action_just_pressed(Platform.act(0, &"b")):
		locked[0] = false
		locked[1] = false
		AudioBus.play(&"back")

func _move_cursor(player: int, dir: int) -> void:
	var other := 1 - player
	var n := ids.size()
	var c: int = cursor[player]
	for _i in n:
		c = (c + dir + n) % n
		if num_players == 2 and locked[other] and c == cursor[other]:
			continue
		break
	cursor[player] = c
	AudioBus.play(&"move")

func _start() -> void:
	var picks: Array = [ids[cursor[0]]]
	if num_players == 2:
		picks.append(ids[cursor[1]])
	AudioBus.play(&"select")
	if Game.pending_mode == "single":
		Game.start_single_event(Game.pending_event_index, picks)
		SceneRouter.goto_scene("res://src/menus/EventIntro.tscn")
	else:
		Game.start_championship(picks)
		SceneRouter.goto_scene(HUB_SCENE)

func _paint_bg() -> void:
	if _bg:
		draw_texture_rect(_bg, Palette.base_rect(), false)
		draw_rect(Palette.base_rect(), Color(Palette.INK.r, Palette.INK.g, Palette.INK.b, 0.30))
	else:
		super._paint_bg()

	var start_x := _start_x()
	for i in ids.size():
		var cx := start_x + i * (CARD_W + GAP)
		var panel_col := Color(0.07, 0.08, 0.13)
		# Semi-transparent panel fill.
		draw_rect(Rect2(cx, CARD_Y, CARD_W, CARD_H), Color(panel_col.r, panel_col.g, panel_col.b, 0.5))

		# Whole flag drawn upright across the top of the card, inside the box.
		var tex: Texture2D = _flag_tex[i]
		if tex != null:
			var fw := CARD_W - 24.0
			var fh := fw * float(tex.get_height()) / float(tex.get_width())
			draw_texture_rect(tex, Rect2(cx + 12.0, CARD_Y + 18.0, fw, fh), false)

		# Subtle opaque frame in the same hue, over the flag's edges.
		draw_rect(Rect2(cx, CARD_Y, CARD_W, CARD_H), panel_col, false, 3.0)

		# Selection highlight (per active player) — a glowing frame, no tag.
		for p in num_players:
			if cursor[p] == i:
				var col: Color = Palette.HIGHLIGHT if p == 0 else Color("3bd6e2")
				var pad := 4.0 + p * 4.0
				draw_rect(Rect2(cx - pad, CARD_Y - pad, CARD_W + pad * 2.0, CARD_H + pad * 2.0), col, false, 4.0)

	_ensure_prompt(_prompt_text())

func _prompt_text() -> String:
	if not locked[0]:
		return "P1:  ◀ ▶  CHOOSE    A  LOCK    B  BACK"
	if num_players == 2 and not locked[1]:
		return "P2:  ◀ ▶  CHOOSE    A  LOCK    B  BACK"
	return "PRESS  A  TO START    B  BACK"

var _prompt_lbl: Label
func _ensure_prompt(text: String) -> void:
	if _prompt_lbl == null:
		_prompt_lbl = UI.center_label("", 18, Palette.PAPER)
		_prompt_lbl.position = Vector2(0, 470)
		_prompt_lbl.size = Vector2(Palette.BASE_WIDTH, 25)
		call_deferred("add_child", _prompt_lbl)
	_prompt_lbl.text = text
