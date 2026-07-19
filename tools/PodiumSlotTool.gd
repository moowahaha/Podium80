extends Node2D
## Dev tool: click the CENTRE-FRONT of each podium block (where an athlete's feet stand) for every
## podium backdrop. Saves to res://assets/backgrounds/podium_slots.json, which Podium reads.
## Launch:  godot --scene res://tools/PodiumSlotTool.tscn
## Controls: CLICK set the current slot   1/2/3 pick gold/silver/bronze   ←/→ backdrop   S save   ESC quit
## The backdrop is drawn at the game's exact 960x540 base, so clicks map 1:1 to in-game coordinates.

const OUT := "res://assets/backgrounds/podium_slots.json"
const BGS := ["podium.png", "podium2.png", "podium3.png", "podium4.png", "podium5.png"]
# Seed defaults from the game's current hardcoded slots (gold, silver, bronze) so the ORIGINAL podium
# stays correct and you only need to re-click the ones that are off.
const SEED := {
	"podium.png":  [[453, 370], [305, 398], [602, 406]],
	"podium2.png": [[435, 377], [350, 400], [560, 400]],
	"podium3.png": [[465, 390], [350, 410], [580, 410]],
	"podium4.png": [[435, 390], [358, 405], [560, 405]],
	"podium5.png": [[480, 390], [390, 405], [575, 405]],
}
const PLACES := ["GOLD (1st)", "SILVER (2nd)", "BRONZE (3rd)"]
const PLACE_COL := [Color("f4d84a"), Color("d8d8e0"), Color("cd7f32")]

var bi := 0
var slot := 0
var tex: Texture2D
var data: Dictionary = {}          # bg filename -> [[x,y] gold, silver, bronze]
var _t := 0.0

func _ready() -> void:
	texture_filter = TEXTURE_FILTER_LINEAR
	if FileAccess.file_exists(OUT):
		var d = JSON.parse_string(FileAccess.get_file_as_string(OUT))
		if d is Dictionary:
			data = d
	_load_bg()
	set_process(true)

func _load_bg() -> void:
	var name: String = BGS[bi]
	var path := "res://assets/backgrounds/" + name
	tex = load(path) if ResourceLoader.exists(path) else null
	if not data.has(name):
		data[name] = SEED[name].duplicate(true) if SEED.has(name) else [[480.0, 400.0], [400.0, 420.0], [560.0, 420.0]]
	queue_redraw()

func _cur() -> Array:
	return data[BGS[bi]]

func _process(_d: float) -> void:
	_t += _d
	queue_redraw()

func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.pressed and (e as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		var p := get_global_mouse_position()
		if p.x >= 0 and p.y >= 0 and p.x < Palette.BASE_WIDTH and p.y < Palette.BASE_HEIGHT:
			_cur()[slot] = [snappedf(p.x, 1.0), snappedf(p.y, 1.0)]
			slot = (slot + 1) % 3                       # auto-advance to the next place
			queue_redraw()
	elif e is InputEventKey and e.pressed and not e.echo:
		match (e as InputEventKey).keycode:
			KEY_1: slot = 0; queue_redraw()
			KEY_2: slot = 1; queue_redraw()
			KEY_3: slot = 2; queue_redraw()
			KEY_RIGHT: bi = (bi + 1) % BGS.size(); _load_bg()
			KEY_LEFT:  bi = (bi - 1 + BGS.size()) % BGS.size(); _load_bg()
			KEY_S: _save()
			KEY_ESCAPE: get_tree().quit()

func _save() -> void:
	var f := FileAccess.open(OUT, FileAccess.WRITE)
	f.store_string(JSON.stringify(data, "  "))
	f.close()
	print("[PodiumSlotTool] saved -> ", OUT)

func _draw() -> void:
	var font := ThemeDB.fallback_font
	if tex != null:
		draw_texture_rect(tex, Rect2(0, 0, Palette.BASE_WIDTH, Palette.BASE_HEIGHT), false)
	else:
		draw_rect(Rect2(0, 0, Palette.BASE_WIDTH, Palette.BASE_HEIGHT), Color(0.1, 0.1, 0.14))
		draw_string(font, Vector2(40, 60), "missing: %s" % BGS[bi], HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(1, 0.5, 0.5))

	# Each placed slot: a marker + a ghost of a standing athlete's footprint.
	var s := _cur()
	for i in 3:
		var p := Vector2(float(s[i][0]), float(s[i][1]))
		var col: Color = PLACE_COL[i]
		var a := 1.0 if i == slot else 0.65
		col.a = a
		# footprint ellipse + vertical guide (where the pole/body would rise)
		draw_line(p - Vector2(0, 150), p, Color(col.r, col.g, col.b, 0.35 * a), 1.5)
		_ellipse(p, 12.0, 4.0, Color(col.r, col.g, col.b, 0.5 * a))
		draw_line(p - Vector2(11, 0), p + Vector2(11, 0), col, 2.0)
		draw_line(p - Vector2(0, 8), p + Vector2(0, 4), col, 2.0)
		draw_string(font, p + Vector2(-14, -12), str(i + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, col)

	# HUD.
	_label(font, Vector2(20, 24), "PODIUM SLOT TOOL   —   %s   (%d/%d)" % [BGS[bi], bi + 1, BGS.size()], 22, Color("f4d84a"))
	_label(font, Vector2(20, 52), "setting: %s   (%.0f, %.0f)" % [PLACES[slot], float(s[slot][0]), float(s[slot][1])], 18, PLACE_COL[slot])
	_label(font, Vector2(20, Palette.BASE_HEIGHT - 44), "CLICK centre-front of the block   1/2/3 pick place   ←/→ backdrop   S save   ESC quit", 15, Color(0.85, 0.92, 1.0))
	_label(font, Vector2(20, Palette.BASE_HEIGHT - 24), "click order auto-advances gold→silver→bronze; the marker is where the feet stand", 13, Color(0.7, 0.8, 0.9))

func _label(font: Font, pos: Vector2, text: String, size: int, col: Color) -> void:
	for o in [Vector2(-1, 0), Vector2(1, 0), Vector2(0, -1), Vector2(0, 1)]:
		draw_string(font, pos + o, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color.BLACK)
	draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)

func _ellipse(c: Vector2, rx: float, ry: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 16:
		var ang := TAU * i / 16.0
		pts.append(c + Vector2(cos(ang) * rx, sin(ang) * ry))
	draw_colored_polygon(pts, col)
