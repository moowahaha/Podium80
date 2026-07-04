extends BaseScreen
## Country selection. Choose 1 or 2 players (P1 Up/Down), then each player picks a nation (D-pad
## left/right, A to lock). Two players must pick different nations. B unlocks / goes back to the title.
## Fully controller-driven with only D-pad + A + B.

const MODE_SELECT := "res://src/menus/ModeSelect.tscn"
const HUB_SCENE := "res://src/menus/ChampionshipHub.tscn"

const CARD_W := 200.0
const GAP := 30.0

var ids: Array[StringName] = []
var num_players := 1
var cursor := [0, 1]                 # per-player highlighted nation index
var locked := [false, false]
var _flags: Array = []
var _athletes: Array = []
var _t := 0.0

func _screen_ready() -> void:
	num_players = maxi(1, Game.pending_players)   # chosen on the mode screen
	ids = CountryData.all_ids()
	var total := ids.size() * CARD_W + (ids.size() - 1) * GAP
	var start_x := (Palette.BASE_WIDTH - total) / 2.0

	for i in ids.size():
		var cx := start_x + i * (CARD_W + GAP)
		var flag := FlagRenderer.new()
		flag.set_country(ids[i])
		flag.position = Vector2(cx + (CARD_W - 115.0) / 2.0, 155)
		flag.size = Vector2(115, 75)
		add_child(flag)
		_flags.append(flag)

		var name_lbl := UI.center_label(CountryData.name_of(ids[i]), 17, Palette.PAPER)
		name_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART   # set before size so width isn't clamped to the text
		name_lbl.vertical_alignment = VERTICAL_ALIGNMENT_TOP
		name_lbl.custom_minimum_size = Vector2(CARD_W - 12, 0)
		name_lbl.position = Vector2(cx + 6, 236)
		name_lbl.size = Vector2(CARD_W - 12, 100)
		add_child(name_lbl)

		var ath := Athlete.new()
		ath.set_country(ids[i])
		ath.set_state(Athlete.State.IDLE)
		ath.position = Vector2(cx + CARD_W / 2.0, 400)
		add_child(ath)
		_athletes.append(ath)

	_title_labels()

func _title_labels() -> void:
	var t := UI.center_label("SELECT YOUR NATION", 30, Palette.HIGHLIGHT)
	t.position = Vector2(0, 50)
	t.size = Vector2(Palette.BASE_WIDTH, 35)
	add_child(t)

func _process(delta: float) -> void:
	_t += delta
	_handle_input()
	queue_redraw()

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
		# skip the other player's locked nation
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
		SceneRouter.goto_scene(String(Game.EVENTS[Game.pending_event_index]["scene"]))
	else:
		Game.start_championship(picks)
		SceneRouter.goto_scene(HUB_SCENE)

func _paint_bg() -> void:
	super._paint_bg()
	var total := ids.size() * CARD_W + (ids.size() - 1) * GAP
	var start_x := (Palette.BASE_WIDTH - total) / 2.0
	for i in ids.size():
		var cx := start_x + i * (CARD_W + GAP)
		var accent: Color = CountryData.accent_of(ids[i])
		# Card panel.
		draw_rect(Rect2(cx, 130, CARD_W, 300), Palette.PANEL)
		draw_rect(Rect2(cx, 130, CARD_W, 300), Palette.PANEL_LIGHT, false, 2.5)
		# Accent strip.
		draw_rect(Rect2(cx, 130, CARD_W, 7.5), accent)

		# Selection highlights per active player.
		for p in num_players:
			if cursor[p] == i:
				var col: Color = Palette.HIGHLIGHT if p == 0 else Color("3bd6e2")
				var pad := 5.0 + p * 5.0
				draw_rect(Rect2(cx - pad, 125 - pad, CARD_W + pad * 2.0, 310 + pad * 2.0), col, false, 5.0)
				# player tag
				draw_rect(Rect2(cx + CARD_W / 2.0 - 22, 108 - p * 20, 45, 15), col)

	# Bottom prompt.
	var msg := ""
	if not locked[0]:
		msg = "P1: ◄ ► CHOOSE   A LOCK   B BACK"
	elif num_players == 2 and not locked[1]:
		msg = "P2: ◄ ► CHOOSE   A LOCK    B BACK"
	else:
		msg = "PRESS A TO START THE CHAMPIONSHIP    B BACK"
	# drawn as text via a cached label would be cleaner, but keep prompt in _draw-free label:
	_ensure_prompt(msg)

var _prompt_lbl: Label
func _ensure_prompt(text: String) -> void:
	if _prompt_lbl == null:
		_prompt_lbl = UI.center_label("", 18, Palette.PAPER)
		_prompt_lbl.position = Vector2(0, 475)
		_prompt_lbl.size = Vector2(Palette.BASE_WIDTH, 25)
		call_deferred("add_child", _prompt_lbl)
	_prompt_lbl.text = text
