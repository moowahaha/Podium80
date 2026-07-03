extends EventBase
## Event 5 — Vault (the signature event). No run-up: pick a difficulty, then nail a rhythm/reflex
## sequence of D-pad + A/B/LB/RB prompts, each within its timing window. One wrong or missed input and
## the gymnast falls (zero). Complete the routine and you score on difficulty × length × timing
## accuracy — higher difficulty means longer, faster routines but far bigger potential scores.

enum St { SELECT, READY, RUN, LAND, FALL, DONE }

const TOKENS: Array[StringName] = [&"up", &"down", &"left", &"right", &"a", &"b", &"lb", &"rb"]
const TABLE := Vector2(192.0, 150.0)

# difficulty: [name, length, window seconds, score multiplier]
const LEVELS := [
	{"name": "I · STEADY", "len": 8, "window": 1.05, "mult": 1.0},
	{"name": "II · DARING", "len": 12, "window": 0.82, "mult": 1.7},
	{"name": "III · FEARLESS", "len": 16, "window": 0.60, "mult": 2.6},
]
const SCORE_K := 2.4

var stadium: Stadium
var ath: Athlete
var human_id: StringName
var ai_values: Dictionary = {}

var state: St = St.SELECT
var sel := 1
var seq: Array = []
var idx := 0
var window := 1.0
var timer := 0.0
var acc_sum := 0.0
var combo := 0
var flash := 0.0
var progress := 0.0
var _info: Label
var _level_labels: Array[Label] = []
var _select_title: Label
var _rng := RandomNumberGenerator.new()

func _event_ready() -> void:
	ai_values = Game.roll_ai_values()
	human_id = humans()[0] if not humans().is_empty() else Game.participants[0]
	_rng.randomize()

	stadium = Stadium.new()
	stadium.world_width = Palette.BASE_WIDTH
	stadium.track_markings = false
	stadium.set_backdrop("res://assets/stadium/vault.png")
	add_child(stadium)

	ath = Athlete.new()
	ath.set_country(human_id)
	ath.position = Vector2(120, TABLE.y)
	ath.set_state(Athlete.State.READY)
	add_child(ath)

	_info = UI.center_label("", 8, Palette.PAPER)
	_info.position = Vector2(0, 30)
	_info.size = Vector2(Palette.BASE_WIDTH, 10)
	hud.add_child(_info)

	_select_title = UI.center_label("CHOOSE YOUR VAULT", 12, Palette.HIGHLIGHT)
	_select_title.position = Vector2(0, 44)
	_select_title.size = Vector2(Palette.BASE_WIDTH, 14)
	hud.add_child(_select_title)
	for i in LEVELS.size():
		var lv: Dictionary = LEVELS[i]
		var maxp := int(round(int(lv["len"]) * float(lv["mult"]) * SCORE_K))
		var txt := "%s        %d MOVES        MAX %d PTS" % [lv["name"], int(lv["len"]), maxp]
		var l := UI.center_label(txt, 8, Palette.PAPER)
		l.position = Vector2(0, 74 + i * 22)
		l.size = Vector2(Palette.BASE_WIDTH, 12)
		hud.add_child(l)
		_level_labels.append(l)

	AudioBus.loop_crowd(true, -20.0)
	_show_select()
	if "--vault-demo" in OS.get_cmdline_args():   # dev: jump straight into a routine for verification
		_start_routine()

func _show_select() -> void:
	state = St.SELECT
	_select_title.visible = true
	for l in _level_labels:
		l.visible = true
	set_prompt("UP / DOWN  CHOOSE DIFFICULTY      A  BEGIN")

func _process(delta: float) -> void:
	super._process(delta)
	flash = maxf(0.0, flash - delta * 3.0)
	match state:
		St.SELECT:
			_select_input()
			for i in _level_labels.size():
				_level_labels[i].add_theme_color_override("font_color", Palette.HIGHLIGHT if i == sel else Palette.PANEL_LIGHT)
		St.RUN:
			_run(delta)
	queue_redraw()

func _select_input() -> void:
	var pi := Game.player_index_of(human_id)
	if Input.is_action_just_pressed(Platform.act(pi, &"up")):
		sel = (sel - 1 + LEVELS.size()) % LEVELS.size()
		AudioBus.play(&"move")
	if Input.is_action_just_pressed(Platform.act(pi, &"down")):
		sel = (sel + 1) % LEVELS.size()
		AudioBus.play(&"move")
	if Input.is_action_just_pressed(Platform.act(pi, &"a")):
		AudioBus.play(&"select")
		_start_routine()

func _start_routine() -> void:
	var lv: Dictionary = LEVELS[sel]
	window = float(lv["window"])
	seq.clear()
	var last := -1
	for i in int(lv["len"]):
		var t := _rng.randi_range(0, TOKENS.size() - 1)
		if t == last:
			t = (t + 1) % TOKENS.size()
		last = t
		seq.append(TOKENS[t])
	idx = 0
	acc_sum = 0.0
	combo = 0
	progress = 0.0
	timer = window
	state = St.RUN
	ath.set_state(Athlete.State.JUMP)
	set_prompt("HIT EACH PROMPT IN TIME!")
	_info.text = ""
	_select_title.visible = false
	for l in _level_labels:
		l.visible = false

func _run(delta: float) -> void:
	var pi := Game.player_index_of(human_id)
	timer -= delta
	# Wrong button -> fall.
	for t in TOKENS:
		if t != seq[idx] and Input.is_action_just_pressed(Platform.act(pi, t)):
			_fall("WRONG!")
			return
	# Correct button -> hit.
	if Input.is_action_just_pressed(Platform.act(pi, seq[idx])):
		var accuracy := clampf(timer / window, 0.0, 1.0)
		acc_sum += 0.4 + 0.6 * accuracy          # floor so a valid-but-late press still counts
		combo += 1
		flash = 1.0
		AudioBus.play(&"points", -2.0, 1.0 + combo * 0.03)
		idx += 1
		progress = float(idx) / seq.size()
		if idx >= seq.size():
			_land()
		else:
			timer = window
		return
	# Timed out -> miss -> fall.
	if timer <= 0.0:
		_fall("TOO SLOW!")

func _land() -> void:
	state = St.LAND
	var lv: Dictionary = LEVELS[sel]
	var avg := acc_sum / seq.size()
	var score := seq.size() * float(lv["mult"]) * avg * SCORE_K
	score = clampf(score, 0.0, 100.0)
	ath.position = Vector2(250, TABLE.y)
	ath.rotation = 0.0
	ath.set_state(Athlete.State.CELEBRATE)
	banner_persist("STUCK THE LANDING!  %d PTS" % int(round(score)), Palette.HIGHLIGHT)
	AudioBus.play(&"fanfare")
	AudioBus.swell_crowd(-4.0)
	set_prompt("")
	_finish(score)

func _fall(reason: String) -> void:
	if state == St.FALL:
		return
	state = St.FALL
	ath.rotation = 0.0
	ath.set_state(Athlete.State.FALL)
	banner_persist("%s  —  FALL!  0 PTS" % reason, Palette.BAD)
	AudioBus.play(&"foul")
	set_prompt("")
	_finish(0.0)

func _finish(score: float) -> void:
	await get_tree().create_timer(1.9).timeout
	finish({human_id: score}, ai_values)

func _run_gymnast() -> void:
	# Arc the gymnast over the table as the routine progresses; spin for flair.
	var p := progress
	ath.position = Vector2(lerpf(140.0, 244.0, p), TABLE.y - sin(p * PI) * 40.0)
	ath.rotation = p * TAU * 2.0

func _draw() -> void:
	# Vault apparatus.
	draw_rect(Rect2(0, TABLE.y + 8.0, Palette.BASE_WIDTH, Palette.BASE_HEIGHT - TABLE.y - 8.0), Palette.PANEL.darkened(0.2))
	draw_rect(Rect2(TABLE.x - 14.0, TABLE.y - 2.0, 28.0, 10.0), Color("b6893f"))   # vault table
	draw_rect(Rect2(TABLE.x - 14.0, TABLE.y + 8.0, 4.0, 12.0), Palette.INK)
	draw_rect(Rect2(TABLE.x + 10.0, TABLE.y + 8.0, 4.0, 12.0), Palette.INK)

	if state == St.RUN:
		_run_gymnast()
		_draw_routine()

func _draw_routine() -> void:
	# Upcoming queue (small) to the right of the active prompt.
	var base := Vector2(Palette.BASE_WIDTH / 2.0, 78.0)
	for j in range(1, mini(6, seq.size() - idx)):
		var c := base + Vector2(28 + j * 22.0, 0)
		_draw_token(seq[idx + j], c, 7.0, 0.5)

	# Active prompt with a shrinking timing ring.
	if idx < seq.size():
		var frac := clampf(timer / window, 0.0, 1.0)
		var ring_col := Palette.GOOD if frac > 0.35 else Palette.BAD
		draw_arc(base, 16.0, -PI / 2.0, -PI / 2.0 + TAU * frac, 24, ring_col, 2.5)
		if flash > 0.0:
			draw_circle(base, 18.0, Color(1, 1, 1, flash * 0.5))
		_draw_token(seq[idx], base, 12.0, 1.0)

func _draw_token(tok: StringName, c: Vector2, r: float, alpha: float) -> void:
	match tok:
		&"up":
			_arrow(c, r, Vector2(0, -1), Palette.HIGHLIGHT, alpha)
		&"down":
			_arrow(c, r, Vector2(0, 1), Palette.HIGHLIGHT, alpha)
		&"left":
			_arrow(c, r, Vector2(-1, 0), Palette.HIGHLIGHT, alpha)
		&"right":
			_arrow(c, r, Vector2(1, 0), Palette.HIGHLIGHT, alpha)
		&"a":
			_badge(c, r, "A", Palette.GOOD, alpha)
		&"b":
			_badge(c, r, "B", Palette.ACCENT, alpha)
		&"lb":
			_badge(c, r, "L", Color("3bd6e2"), alpha)
		&"rb":
			_badge(c, r, "R", Color("d69ce2"), alpha)

func _arrow(c: Vector2, r: float, dir: Vector2, col: Color, alpha: float) -> void:
	var perp := Vector2(-dir.y, dir.x)
	var pts := PackedVector2Array([
		c + dir * r, c - dir * r * 0.6 + perp * r * 0.8, c - dir * r * 0.6 - perp * r * 0.8,
	])
	var cc := col
	cc.a = alpha
	draw_colored_polygon(pts, cc)

func _badge(c: Vector2, r: float, letter: String, col: Color, alpha: float) -> void:
	var cc := col
	cc.a = alpha
	draw_circle(c, r, cc)
	draw_arc(c, r, 0, TAU, 16, Color(0, 0, 0, alpha * 0.6), 1.0)
	var f := ThemeDB.fallback_font
	var fs := int(r * 1.4)
	var sz := f.get_string_size(letter, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
	draw_string(f, c - sz * 0.5 + Vector2(0, sz.y * 0.35), letter, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0, 0, 0, alpha))
