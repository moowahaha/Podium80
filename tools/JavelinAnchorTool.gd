extends Node2D
## Dev tool: click the hold-point (where the CENTRE of the javelin meets the hand) on each sprite frame.
## Saves to res://assets/sprites/javelin_anchors.json, which Athlete reads to place the javelin exactly.
## Launch:  godot --scene res://tools/JavelinAnchorTool.tscn
## Controls: CLICK set point   WHEEL / Q,E rotate   ←/→ frame   ↑/↓ sprite   S save   R reset   ESC quit

const DIR := "res://assets/sprites/"
const OUT := "res://assets/sprites/javelin_anchors.json"
const ZOOM := 6.0
const ORIGIN := Vector2(430.0, 96.0)

# The sprites the javelin is drawn against (country, file, grid). GBR runs on its normal run sheet.
var targets := [
	{"country": "aus",  "file": "javelin-run", "cols": 3, "rows": 3, "frames": 9, "angle": -6.0},
	{"country": "aus",  "file": "standing",    "cols": 1, "rows": 1, "frames": 1, "angle": 0.0},
	{"country": "gdr",  "file": "javelin-run", "cols": 3, "rows": 3, "frames": 9, "angle": -6.0},
	{"country": "gdr",  "file": "stand",       "cols": 1, "rows": 1, "frames": 1, "angle": 0.0},
	{"country": "ussr", "file": "javelin-run", "cols": 3, "rows": 3, "frames": 9, "angle": -6.0},
	{"country": "ussr", "file": "standing",    "cols": 1, "rows": 1, "frames": 1, "angle": 0.0},
	{"country": "gbr",  "file": "running",     "cols": 4, "rows": 4, "frames": 12, "angle": 2.0},
	{"country": "gbr",  "file": "standing",    "cols": 1, "rows": 1, "frames": 1, "angle": 0.0},
]

var ti := 0
var frame := 0
var tex: Texture2D
var fw := 0.0
var fh := 0.0
var data: Dictionary = {}          # country -> file -> [[x,y,angle,hx,hy,hw,hh] per frame]
var touched: Dictionary = {}       # "country/file/frame" -> true (explicitly edited)
var drag_start := Vector2(-2, -2)  # right-drag in progress = defining the hand region box

func _ready() -> void:
	texture_filter = TEXTURE_FILTER_NEAREST
	if FileAccess.file_exists(OUT):
		var d = JSON.parse_string(FileAccess.get_file_as_string(OUT))
		if d is Dictionary:
			data = d
	_load_target()

func _load_target() -> void:
	var t: Dictionary = targets[ti]
	var path: String = DIR + t["country"] + "/" + t["file"] + ".png"
	tex = load(path) if ResourceLoader.exists(path) else null
	if tex != null:
		fw = float(tex.get_width()) / int(t["cols"])
		fh = float(tex.get_height()) / int(t["rows"])
	frame = clampi(frame, 0, int(t["frames"]) - 1)
	_ensure(t)
	queue_redraw()

func _ensure(t: Dictionary) -> void:
	if not data.has(t["country"]):
		data[t["country"]] = {}
	var files: Dictionary = data[t["country"]]
	if not files.has(t["file"]) or (files[t["file"]] as Array).size() != int(t["frames"]):
		var arr: Array = []
		for i in int(t["frames"]):
			arr.append([fw * 0.5, fh * 0.55, float(t["angle"])])   # default: centre-ish, pose angle
		files[t["file"]] = arr
	else:
		for entry in (files[t["file"]] as Array):    # pad angle onto older [x,y]-only data
			if (entry as Array).size() < 3:
				(entry as Array).append(float(t["angle"]))

func _cur() -> Vector2:
	var t: Dictionary = targets[ti]
	var a = data[t["country"]][t["file"]][frame]
	return Vector2(float(a[0]), float(a[1]))

func _cur_angle() -> float:
	var t: Dictionary = targets[ti]
	var a = data[t["country"]][t["file"]][frame]
	return float(a[2]) if (a as Array).size() >= 3 else float(t["angle"])

func _rotate(delta_deg: float) -> void:
	var t: Dictionary = targets[ti]
	var a: Array = data[t["country"]][t["file"]][frame]
	while a.size() < 3:
		a.append(float(t["angle"]))
	a[2] = snappedf(float(a[2]) + delta_deg, 0.5)
	touched["%s/%s/%d" % [t["country"], t["file"], frame]] = true
	queue_redraw()

func _srcpos() -> Vector2:
	var s: Vector2 = (get_global_mouse_position() - ORIGIN) / ZOOM
	return Vector2(clampf(s.x, 0.0, fw), clampf(s.y, 0.0, fh))

func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventMouseButton:
		var mb := e as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			var src := _srcpos()
			var t: Dictionary = targets[ti]
			var old: Array = data[t["country"]][t["file"]][frame]
			var ne: Array = [floorf(src.x) + 0.5, floorf(src.y) + 0.5, _cur_angle()]
			if old.size() >= 7:                          # keep any marked hand box
				ne.append_array([old[3], old[4], old[5], old[6]])
			data[t["country"]][t["file"]][frame] = ne
			touched["%s/%s/%d" % [t["country"], t["file"], frame]] = true
			queue_redraw()
		elif mb.button_index == MOUSE_BUTTON_RIGHT:
			if mb.pressed:
				drag_start = _srcpos()                   # begin the hand box
			elif drag_start.x > -1.5:
				_set_hand(drag_start, _srcpos())
				drag_start = Vector2(-2, -2)
		elif mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
			_rotate(-1.0)
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
			_rotate(1.0)
	elif e is InputEventMouseMotion and drag_start.x > -1.5:
		queue_redraw()
	elif e is InputEventKey and e.pressed and not e.echo:
		match (e as InputEventKey).keycode:
			KEY_RIGHT: frame = (frame + 1) % int(targets[ti]["frames"]); queue_redraw()
			KEY_LEFT:  frame = (frame - 1 + int(targets[ti]["frames"])) % int(targets[ti]["frames"]); queue_redraw()
			KEY_DOWN:  ti = (ti + 1) % targets.size(); frame = 0; _load_target()
			KEY_UP:    ti = (ti - 1 + targets.size()) % targets.size(); frame = 0; _load_target()
			KEY_Q:     _rotate(-2.0)
			KEY_E:     _rotate(2.0)
			KEY_C:     _clear_hand()
			KEY_S:     _save()
			KEY_R:     _reset_frame()
			KEY_ESCAPE: get_tree().quit()

## Store the hand-region box (source px) on the current frame's entry (extends it to 7 elements).
func _set_hand(p0: Vector2, p1: Vector2) -> void:
	var w := absf(p1.x - p0.x)
	var h := absf(p1.y - p0.y)
	if w < 2.0 or h < 2.0:
		return
	var t: Dictionary = targets[ti]
	var a: Array = data[t["country"]][t["file"]][frame]
	while a.size() < 3:
		a.append(float(t["angle"]))
	while a.size() < 7:
		a.append(0.0)
	a[3] = floorf(minf(p0.x, p1.x)); a[4] = floorf(minf(p0.y, p1.y)); a[5] = ceilf(w); a[6] = ceilf(h)
	touched["%s/%s/%d" % [t["country"], t["file"], frame]] = true
	queue_redraw()

func _clear_hand() -> void:
	var a: Array = data[targets[ti]["country"]][targets[ti]["file"]][frame]
	if a.size() > 3:
		a.resize(3)
	queue_redraw()

func _hand_box() -> Rect2:
	var a: Array = data[targets[ti]["country"]][targets[ti]["file"]][frame]
	if a.size() >= 7:
		return Rect2(float(a[3]), float(a[4]), float(a[5]), float(a[6]))
	return Rect2(-1, -1, 0, 0)

func _reset_frame() -> void:
	var t: Dictionary = targets[ti]
	data[t["country"]][t["file"]][frame] = [fw * 0.5, fh * 0.55, float(t["angle"])]
	touched.erase("%s/%s/%d" % [t["country"], t["file"], frame])
	queue_redraw()

func _save() -> void:
	var f := FileAccess.open(OUT, FileAccess.WRITE)
	f.store_string(JSON.stringify(data, "  "))
	f.close()
	print("[JavelinAnchorTool] saved -> ", OUT)

func _draw() -> void:
	var t: Dictionary = targets[ti]
	var font := ThemeDB.fallback_font
	if tex == null:
		draw_string(font, Vector2(40, 300), "missing sprite: %s/%s.png" % [t["country"], t["file"]], HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(1, 0.5, 0.5))
		return
	var cols := int(t["cols"])
	var src := Rect2((frame % cols) * fw, (frame / cols) * fh, fw, fh)
	var dest := Rect2(ORIGIN, Vector2(fw, fh) * ZOOM)
	# checker backdrop so transparent areas read
	var sq := 8.0
	var yy := ORIGIN.y
	var row := 0
	while yy < dest.end.y:
		var xx := ORIGIN.x
		var col := 0
		while xx < dest.end.x:
			draw_rect(Rect2(xx, yy, minf(sq, dest.end.x - xx), minf(sq, dest.end.y - yy)), Color(0.22, 0.22, 0.26) if (row + col) % 2 == 0 else Color(0.16, 0.16, 0.2))
			xx += sq; col += 1
		yy += sq; row += 1
	draw_texture_rect_region(tex, dest, src)
	draw_rect(dest, Color(1, 1, 1, 0.35), false, 1.0)

	# anchor crosshair + horizontal javelin-centre preview
	var a := _cur()
	var sp := ORIGIN + a * ZOOM
	var set_here: bool = touched.has("%s/%s/%d" % [t["country"], t["file"], frame])
	var col_a: Color = Color(1, 0, 1) if set_here else Color(0.6, 0.6, 0.6)
	var ang := deg_to_rad(_cur_angle())
	var dirv := Vector2(cos(ang), sin(ang))
	var half := 26.0 * ZOOM
	draw_line(sp - dirv * half, sp + dirv * half, Color(1, 0.9, 0.2, 0.85), 2.0)   # javelin (centre at the point)
	draw_circle(sp + dirv * half, 4.0, Color(0.7, 0.85, 1.0))                      # front-tip marker
	draw_line(sp - Vector2(14, 0), sp + Vector2(14, 0), col_a, 1.5)
	draw_line(sp - Vector2(0, 14), sp + Vector2(0, 14), col_a, 1.5)
	draw_circle(sp, 3.0, col_a)

	# Hand region (right-drag): the patch of the sprite redrawn OVER the javelin in-game.
	var hb := _hand_box()
	if hb.position.x >= 0.0:
		draw_rect(Rect2(ORIGIN + hb.position * ZOOM, hb.size * ZOOM), Color(0.3, 1.0, 1.0, 0.95), false, 1.5)
	if drag_start.x > -1.5:
		var cur := _srcpos()
		var mn := Vector2(minf(drag_start.x, cur.x), minf(drag_start.y, cur.y))
		draw_rect(Rect2(ORIGIN + mn * ZOOM, (cur - drag_start).abs() * ZOOM), Color(0.3, 1.0, 1.0, 0.5), false, 1.5)

	# labels
	draw_string(font, Vector2(40, 40), "%s / %s" % [String(t["country"]).to_upper(), t["file"]], HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Palette.HIGHLIGHT)
	draw_string(font, Vector2(40, 70), "frame %d / %d   (%.1f, %.1f)   angle %.1f°%s" % [frame + 1, int(t["frames"]), a.x, a.y, _cur_angle(), "" if set_here else "   (default)"], HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color.WHITE)
	# per-target progress
	var setc := 0
	for i in int(t["frames"]):
		if touched.has("%s/%s/%d" % [t["country"], t["file"], i]):
			setc += 1
	draw_string(font, Vector2(40, 96), "set %d / %d frames" % [setc, int(t["frames"])], HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.7, 1.0, 0.7))
	draw_string(font, Vector2(40, 500), "L-CLICK point   RIGHT-DRAG hand box   C clear box   WHEEL / Q,E rotate   ←/→ frame   ↑/↓ sprite   S save   R reset   ESC quit", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(0.8, 0.9, 1.0))
	draw_string(font, Vector2(40, 522), "yellow line = javelin centred on your point;  cyan box = the HAND drawn over it in-game", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.9, 0.85, 0.5))
