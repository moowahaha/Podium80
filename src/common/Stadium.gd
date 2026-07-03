extends Node2D
class_name Stadium
## Reusable lively stadium backdrop drawn in world space across [0, world_width]: dusk sky, tiered
## stands with an animated crowd (rolling Mexican wave + twinkle), hanging banners, a red running
## track (or a blue pool) with lane markings. Events place athletes on top and pan a camera along x.
##
## Layout is resolution-relative (fractions of the 960x540 base): sky ~21%, stands to ~69%, track to
## ~96%. Feet sit on `ground_y`.

@export var world_width := 1800.0
@export var track_markings := true
@export var surface := "track"          # "track" (red running track) or "pool" (blue water lanes)

var SKY_H := 115.0
var STANDS_BOTTOM := 370.0
var TRACK_BOTTOM := 520.0
var ground_y := 490.0          # where athlete feet rest
var backdrop: Texture2D        # optional generated stadium art (drop-in); tiled across the world
var _t := 0.0
var _crowd: Array = []         # [{x, y, base_col, phase, w, h}]

func _ready() -> void:
	z_index = -10          # always the backmost layer, so event decorations + athletes draw on top
	SKY_H = Palette.BASE_HEIGHT * 0.213
	STANDS_BOTTOM = Palette.BASE_HEIGHT * 0.685
	TRACK_BOTTOM = Palette.BASE_HEIGHT * 0.963
	_build_crowd()

## Use a generated backdrop image if one exists at `path` (SNES stadium art). See docs/ART_PROMPTS.md.
## When set, the art replaces the procedural sky/stands/crowd; the track + lane lines stay overlaid
## for gameplay clarity. Falls back to procedural art if the file is missing.
func set_backdrop(path: String) -> void:
	if ResourceLoader.exists(path):
		backdrop = load(path)
		queue_redraw()

func _build_crowd() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 80
	var shirt_cols := [
		Color("e2d5c0"), Color("c85c4c"), Color("4c78c8"), Color("d8b23a"),
		Color("6cae7a"), Color("b06cc0"), Color("d0d0d8"), Color("c88a4a"),
	]
	var row_h := (STANDS_BOTTOM - SKY_H * 1.15) / 6.0
	var step := 7.5
	var x := 10.0
	while x < world_width - 10.0:
		for r in 6:
			if rng.randf() < 0.12:
				continue
			_crowd.append({
				"x": x + rng.randf_range(-1.5, 1.5),
				"y": SKY_H * 1.15 + r * row_h,
				"col": shirt_cols[rng.randi_range(0, shirt_cols.size() - 1)],
				"phase": x * 0.016,
				"w": 5.0,
				"h": 5.0,
			})
		x += step

func _process(delta: float) -> void:
	_t += delta
	queue_redraw()

func _draw() -> void:
	var w := world_width
	if backdrop:
		# Scale the art to the screen height and repeat it horizontally across the world.
		var th := float(Palette.BASE_HEIGHT)
		var tw: float = backdrop.get_width() * (th / backdrop.get_height())
		var x := 0.0
		while x < w:
			draw_texture_rect(backdrop, Rect2(x, 0, tw, th), false)
			x += tw
		_draw_track(w)
		return
	# Sky gradient.
	var steps := 10
	for i in steps:
		var f := float(i) / steps
		var col := Palette.SKY_TOP.lerp(Palette.SKY_BOTTOM, f)
		draw_rect(Rect2(0, SKY_H * f, w, SKY_H / steps + 1.0), col)

	# Distant stand structure (concrete tiers).
	draw_rect(Rect2(0, SKY_H, w, STANDS_BOTTOM - SKY_H), Palette.STAND_BASE.darkened(0.15))
	var row_h := (STANDS_BOTTOM - SKY_H * 1.15) / 6.0
	for tier in range(1, 6):
		draw_rect(Rect2(0, SKY_H * 1.15 + tier * row_h, w, 2.5), Palette.STAND_BASE.darkened(0.35))

	# Crowd with a rolling wave.
	var wave_x := _t * 300.0
	for s in _crowd:
		var d: float = (s["x"] - wave_x)
		var wave: float = maxf(0.0, sin(d * 0.012))
		var lift: float = wave * 5.0
		var tw: float = 0.9 + 0.1 * sin(_t * 8.0 + s["phase"])
		var col: Color = (s["col"] as Color) * tw
		col = col.lerp(Palette.PAPER, wave * 0.18)
		col.a = 1.0
		draw_rect(Rect2(s["x"], s["y"] - lift, s["w"], s["h"]), col)

	# Banner rail + hanging banners (placeholder national colours).
	draw_rect(Rect2(0, STANDS_BOTTOM - 30.0, w, 5.0), Palette.PANEL_LIGHT)
	var ids := CountryData.ORDER
	var bx := 60.0
	var i := 0
	while bx < w - 50.0:
		var accent: Color = CountryData.accent_of(ids[i % ids.size()])
		draw_rect(Rect2(bx, STANDS_BOTTOM - 25.0, 35.0, 22.0), accent)
		draw_rect(Rect2(bx + 10.0, STANDS_BOTTOM - 17.0, 15.0, 7.0), Palette.INK)   # placeholder emblem
		bx += 225.0
		i += 1

	_draw_track(w)

func _draw_track(w: float) -> void:
	if surface == "pool":
		_draw_pool(w)
		return
	# Track apron + track.
	draw_rect(Rect2(0, STANDS_BOTTOM, w, 15.0), Palette.INFIELD.darkened(0.2))
	draw_rect(Rect2(0, STANDS_BOTTOM + 15.0, w, TRACK_BOTTOM - STANDS_BOTTOM - 15.0), Palette.TRACK)
	# Lane lines.
	draw_rect(Rect2(0, STANDS_BOTTOM + 15.0, w, 2.5), Palette.TRACK_LINE)
	draw_rect(Rect2(0, ground_y + 15.0, w, 2.5), Palette.TRACK_LINE)
	draw_rect(Rect2(0, TRACK_BOTTOM - 2.5, w, 2.5), Palette.TRACK_LINE)
	# Distance tick marks for a sense of speed.
	if track_markings:
		var m := 0.0
		while m < w:
			draw_rect(Rect2(m, TRACK_BOTTOM - 10.0, 2.5, 7.5), Palette.TRACK_LINE * Color(1, 1, 1, 0.5))
			m += 50.0

func _draw_pool(w: float) -> void:
	# Poolside deck, then the water, drawn side-on like the running track band.
	draw_rect(Rect2(0, STANDS_BOTTOM, w, 15.0), Palette.STAND_BASE.darkened(0.25))
	draw_rect(Rect2(0, STANDS_BOTTOM + 15.0, w, TRACK_BOTTOM - STANDS_BOTTOM - 15.0), Color("1f7fb8"))
	draw_rect(Rect2(0, STANDS_BOTTOM + 15.0, w, 2.5), Palette.PAPER)
	# Depth lane ropes.
	var top := STANDS_BOTTOM + 15.0
	for k in range(1, 4):
		var y := lerpf(top, TRACK_BOTTOM, k / 4.0)
		var x := 0.0
		while x < w:
			draw_rect(Rect2(x, y - 1.25, 7.5, 2.5), Palette.HIGHLIGHT if int(x / 15) % 2 == 0 else Palette.ACCENT)
			x += 15.0
	# Moving surface shimmer.
	var sh := 0.0
	while sh < w:
		var a := 0.10 + 0.06 * sin(_t * 3.0 + sh * 0.08)
		draw_rect(Rect2(sh + fmod(_t * 50.0, 30.0), top + 7.5, 10.0, 2.5), Color(1, 1, 1, a))
		sh += 30.0
