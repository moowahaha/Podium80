extends BaseScreen
## Event select — a horizontally scrolling carousel. First card is the CHAMPIONSHIP (all events, played
## in a RANDOM order with the 400m always last), then a spacer, then the individual events in
## ALPHABETICAL order. Each card: an icon above, the event name in white, and its bootleg Russian name
## below (red, in the Cyrillic display face). The championship name shimmers gold.
## ◄ ► browse, A confirm, B back.

const PLAYER_SELECT := "res://src/menus/PlayerSelect.tscn"
const COUNTRY_SELECT := "res://src/menus/CountrySelect.tscn"
const ICON_DIR := "res://assets/icons/"
const RUSLAN := "res://assets/fonts/RuslanDisplay.ttf"

const CARD_W := 300.0
const STEP := CARD_W + 45.0                         # uniform spacing between cards (cyclic carousel)
const ICON_W := 196.0                               # max icon box
const ICON_H := 204.0
const ICON_BASE_Y := 320.0                          # icon bottoms rest here
const CENTER_X := 480.0

# Bootleg Russian event names.
const RU := {
	&"sprint": "Быстрый Бег",
	&"hurdles": "Прыг-Бег",
	&"long_jump": "Большой Прыжок",
	&"triple_jump": "Прыг Прыг Прыжок",
	&"javelin": "Острое Копьё",
	&"sprint_400": "Долгий Бег",
	&"hammer": "Крутящийся Шар",
}

var options: Array = []
var sel_cont := 0.0                                 # continuous selected index (unbounded; wraps cyclically)
var _scroll := 0.0                                  # continuous scroll position (index units), lerps to sel_cont
var num_players := 1
var _t := 0.0
var _rufont: Font

func _sel() -> int:
	return int(posmod(roundi(sel_cont), options.size()))

func _screen_ready() -> void:
	bg_scrim = 0.5
	num_players = maxi(1, Game.pending_players)
	texture_filter = TEXTURE_FILTER_NEAREST
	if ResourceLoader.exists(RUSLAN):
		_rufont = load(RUSLAN)

	options.append({"champ": true, "index": -1, "id": &"", "label": "CHAMPIONSHIP", "tex": _icon("championship")})
	var idxs: Array = []
	for i in Game.EVENTS.size():
		idxs.append(i)
	idxs.sort_custom(func(a, b): return String(Game.EVENTS[a]["title"]) < String(Game.EVENTS[b]["title"]))
	for i in idxs:
		var ev: Dictionary = Game.EVENTS[i]
		options.append({"champ": false, "index": i, "id": ev["id"], "label": String(ev["title"]), "tex": _icon(String(ev["id"]))})

	UI.add_podium_logo(self, 12, 30)

func _icon(name: String) -> Texture2D:
	var p := ICON_DIR + name + ".png"
	return load(p) if ResourceLoader.exists(p) else null

func _process(delta: float) -> void:
	_t += delta
	_scroll = lerpf(_scroll, sel_cont, clampf(delta * 10.0, 0.0, 1.0))
	_handle_input()
	queue_redraw()

func _handle_input() -> void:
	if Input.is_action_just_pressed(Platform.act(0, &"left")):
		sel_cont -= 1.0                              # cyclic — wraps past either end
		AudioBus.play(&"move")
	if Input.is_action_just_pressed(Platform.act(0, &"right")):
		sel_cont += 1.0
		AudioBus.play(&"move")
	if Input.is_action_just_pressed(Platform.act(0, &"a")):
		_confirm()
	if Input.is_action_just_pressed(Platform.act(0, &"b")):
		AudioBus.play(&"back")
		SceneRouter.goto_scene(PLAYER_SELECT)

func _confirm() -> void:
	AudioBus.play(&"select")
	Game.pending_players = num_players
	var opt: Dictionary = options[_sel()]
	if opt["champ"]:
		Game.pending_mode = "championship"
	else:
		Game.pending_mode = "single"
		Game.pending_event_index = int(opt["index"])
	SceneRouter.goto_scene(COUNTRY_SELECT)

func _font() -> Font:
	var f := get_theme_default_font()
	return f if f != null else ThemeDB.fallback_font

const _OUTLINE := [Vector2(-1, 0), Vector2(1, 0), Vector2(0, -1), Vector2(0, 1), Vector2(-1, -1), Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1)]

## draw_string with a thin dark outline, matching the label style used on the other screens.
func _ostr(font: Font, pos: Vector2, text: String, align: int, width: float, size: int, color: Color) -> void:
	for o in _OUTLINE:
		draw_string(font, pos + o, text, align, width, size, Palette.INK)
	draw_string(font, pos, text, align, width, size, color)

func _draw() -> void:
	_paint_bg()
	var font := _font()
	var n := options.size()
	var cur := _sel()
	for pass_sel in [false, true]:               # draw the selected card last (on top)
		for i in n:
			var seld := i == cur
			if seld != pass_sel:
				continue
			# Cyclic offset from the scroll position → each card wraps around either end.
			var d := wrapf(float(i) - _scroll, -float(n) / 2.0, float(n) / 2.0)
			var cx := CENTER_X + d * STEP
			if cx < -260.0 or cx > Palette.BASE_WIDTH + 260.0:
				continue
			# Cards away from focus fade darker (full at centre, ~0.4 by one step out).
			var bright := lerpf(0.4, 1.0, clampf(1.0 - absf(d) * 0.72, 0.0, 1.0))
			_draw_card(options[i], cx, seld, bright, font)
	_ostr(font, Vector2(0, 512), "◀ ▶  SELECT      A  CONFIRM      B  BACK", HORIZONTAL_ALIGNMENT_CENTER, Palette.BASE_WIDTH, 18, Palette.GOOD)

func _draw_card(opt: Dictionary, cx: float, seld: bool, bright: float, font: Font) -> void:
	var s := 1.0 if seld else 0.72
	var tint := Color(bright, bright, bright)
	var tex: Texture2D = opt["tex"]
	if tex != null:
		var tw := float(tex.get_width())
		var th := float(tex.get_height())
		var dh := ICON_H * s
		var dw := dh * tw / th
		if dw > ICON_W * s:
			dw = ICON_W * s
			dh = dw * th / tw
		draw_texture_rect(tex, Rect2(cx - dw / 2.0, ICON_BASE_Y - dh, dw, dh), false, tint)
	var ly := ICON_BASE_Y + (28.0 if seld else 22.0)
	var size := 27 if seld else 22
	var rf := _rufont if _rufont != null else font
	var rsize := 20 if seld else 16
	var ry := ly + (28.0 if seld else 22.0)
	if opt["champ"]:
		_draw_shimmer(String(opt["label"]), cx, ly, size, font, bright)
		_ostr(rf, Vector2(cx - 170.0, ry), "Много спорта!", HORIZONTAL_ALIGNMENT_CENTER, 340.0, rsize, Color("e2342f") * tint)
	else:
		_ostr(font, Vector2(cx - 160.0, ly), String(opt["label"]), HORIZONTAL_ALIGNMENT_CENTER, 320.0, size, tint)
		var ru: String = RU.get(opt.get("id", &""), "")
		if ru != "":
			_ostr(rf, Vector2(cx - 170.0, ry), ru, HORIZONTAL_ALIGNMENT_CENTER, 340.0, rsize, Color("e2342f") * tint)

## Gold shimmer: a bright band sweeps across the letters.
func _draw_shimmer(text: String, cx: float, y: float, size: int, font: Font, bright: float = 1.0) -> void:
	var total := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var x := cx - total / 2.0
	var dim := Color(bright, bright, bright)
	for j in text.length():
		var ch := text.substr(j, 1)
		var wave := 0.5 + 0.5 * sin(_t * 5.5 - float(j) * 0.55)
		var col := Color("caa030").lerp(Color("fff4bf"), wave) * dim
		for o in _OUTLINE:
			draw_string(font, Vector2(x, y) + o, ch, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Palette.INK)
		draw_string(font, Vector2(x, y), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)
		x += font.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
