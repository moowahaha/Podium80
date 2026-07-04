extends BaseScreen
## Animated title screen. Dusk stadium with twinkling stands, bunting, a sweeping spotlight and a
## bobbing wordmark. Press A to begin (country select). Fully driven by the console's controls.

const COUNTRY_SELECT := "res://src/menus/ModeSelect.tscn"
## Drop a title image here later and it replaces the procedural backdrop automatically (text/prompt
## stay on top). No code change needed — just add the file. Recommended 384x216 (or any 16:9).
const TITLE_IMAGE := "res://assets/menu/title.png"

var _bg_tex: Texture2D
var _t := 0.0
var _title: Label
var _sub: Label
var _prompt: Label
var _lights: Array = []      # [{pos, phase}]
var _started := false

func _screen_ready() -> void:
	if ResourceLoader.exists(TITLE_IMAGE):
		_bg_tex = load(TITLE_IMAGE)
	# Twinkling stand lights.
	var seed_rng := RandomNumberGenerator.new()
	seed_rng.seed = 1980
	for i in 90:
		_lights.append({
			"pos": Vector2(seed_rng.randf_range(15, Palette.BASE_WIDTH - 15), seed_rng.randf_range(375, 490)),
			"phase": seed_rng.randf_range(0, TAU),
			"size": seed_rng.randi_range(3, 5),
		})

	# Shared two-colour PODIUM '80 wordmark.
	var tsize := 118
	var ty := 40.0
	var total := UI.add_podium_logo(self, ty, tsize)

	# Russian tagline ("history simply repeats") in Ruslan Display, red, ~1/3 the title width.
	var ruslan: Font = load("res://assets/fonts/RuslanDisplay.ttf")
	var tag := "История просто повторяется"
	var target_w := total / 3.0 * 1.3
	var mw: float = ruslan.get_string_size(tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 100).x
	var tag_size := int(100.0 * target_w / maxf(mw, 1.0))
	var sub := Label.new()
	sub.text = tag
	sub.add_theme_font_override("font", ruslan)
	sub.add_theme_font_size_override("font_size", tag_size)
	sub.add_theme_color_override("font_color", Color("e2342f"))
	sub.add_theme_color_override("font_outline_color", Palette.INK)
	sub.add_theme_constant_override("outline_size", 3)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.position = Vector2(0, ty + tsize * 1.05)
	sub.size = Vector2(Palette.BASE_WIDTH, tag_size + 12)
	add_child(sub)
	_prompt = _band("PRESS  A  TO BEGIN", 25, Palette.HIGHLIGHT, 460, 35)

	AudioBus.loop_crowd(true, -24.0)

## A full-width, centre-aligned text band at a fixed y — reliable pixel-space layout.
func _band(text: String, size: int, color: Color, y: float, h: float) -> Label:
	var l := UI.center_label(text, size, color)
	l.position = Vector2(0, y)
	l.size = Vector2(Palette.BASE_WIDTH, h)
	add_child(l)
	return l

func _process(delta: float) -> void:
	_t += delta
	_prompt.modulate.a = 0.6 + 0.4 * (0.5 + 0.5 * sin(_t * 4.0))
	queue_redraw()

	if not _started and Input.is_action_just_pressed(Platform.act(0, &"a")):
		_started = true
		AudioBus.play(&"select")
		SceneRouter.goto_scene(COUNTRY_SELECT)

func _paint_bg() -> void:
	var w := float(Palette.BASE_WIDTH)
	var h := float(Palette.BASE_HEIGHT)
	# Priority: a dedicated title image, else the shared menu background, else the procedural dusk.
	if _bg_tex:
		draw_texture_rect(_bg_tex, Rect2(0, 0, w, h), false)
		return
	if menu_bg():
		draw_texture_rect(menu_bg(), Rect2(0, 0, w, h), false)
		# Bottom scrim so the prompt/footer read clearly over the artwork.
		var scrim_top := 410.0
		var bands := 10
		for i in bands:
			var f := float(i) / bands
			var a := 0.62 * f
			draw_rect(Rect2(0, scrim_top + (h - scrim_top) * f, w, (h - scrim_top) / bands + 1.0), Color(0, 0, 0, a))
		return
	# Dusk gradient sky.
	var top := Color("1a1740")
	var horizon := Color("c05a2e")
	var steps := 24
	for i in steps:
		var f := float(i) / steps
		var col := top.lerp(horizon, pow(f, 1.6))
		draw_rect(Rect2(0, h * f, w, h / steps + 1.0), col)

	# Sweeping spotlight cone from a tower.
	var sweep := 0.5 + 0.5 * sin(_t * 0.6)
	var origin := Vector2(w * 0.5, h * 0.95)
	var aim := Vector2(lerpf(w * 0.2, w * 0.8, sweep), h * 0.15)
	var dir := (aim - origin).normalized()
	var perp := Vector2(-dir.y, dir.x)
	var far := origin + dir * (h * 1.1)
	var cone := PackedVector2Array([origin, far + perp * 26.0, far - perp * 26.0])
	draw_colored_polygon(cone, Color(1, 0.95, 0.7, 0.06))

	# Stadium bowl silhouette.
	draw_rect(Rect2(0, 148, w, h - 148), Color("241f38"))
	draw_rect(Rect2(0, 196, w, h - 196), Color("16121f"))

	# Twinkling stand lights.
	for lt in _lights:
		var tw: float = 0.5 + 0.5 * sin(_t * 3.0 + lt["phase"])
		var c := Color("ffe9a8")
		c.a = 0.25 + 0.75 * tw
		draw_rect(Rect2(lt["pos"], Vector2(lt["size"], lt["size"])), c)

	# Bunting across the top.
	var flag_colors := [Palette.ACCENT, Palette.HIGHLIGHT, Palette.GOOD, Color("3b7be2")]
	var count := 16
	for i in count + 1:
		var x := w * float(i) / count
		var droop := 6.0 + sin(_t * 1.5 + i) * 1.5
		var col: Color = flag_colors[i % flag_colors.size()]
		var tri := PackedVector2Array([
			Vector2(x - 6, 4), Vector2(x + 6, 4), Vector2(x, 4 + droop),
		])
		draw_colored_polygon(tri, col)
