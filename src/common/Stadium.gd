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
@export var backdrop_tile := true       # true: repeat/mirror the art; false: one fixed wide image (pool)

const INFIELD_H := 20.0        # depth of the grassy infield strip between the stand wall and track

var SKY_H := 115.0
var STANDS_BOTTOM := 370.0
var TRACK_BOTTOM := 520.0
var ground_y := 490.0          # where athlete feet rest
var backdrop: Texture2D        # optional generated stadium art (drop-in); tiled across the world
var _t := 0.0
var _crowd: Array = []         # [{x, y, base_col, phase, w, h}]
var _grass: Array = []         # static grass blades over the infield strip (seeded)
var _track_grain: Array = []   # static grain specks over the running track (seeded)

func _ready() -> void:
	z_index = -10          # always the backmost layer, so event decorations + athletes draw on top
	SKY_H = Palette.BASE_HEIGHT * 0.213
	STANDS_BOTTOM = Palette.BASE_HEIGHT * 0.685
	TRACK_BOTTOM = Palette.BASE_HEIGHT * 0.963
	_build_crowd()
	_build_ground_texture()

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

## Pre-bake static specks so the ground reads as grass + gritty track rather than flat fills. Seeded,
## so the grain is stable frame-to-frame (no shimmer) and consistent across runs.
func _build_ground_texture() -> void:
	_grass.clear()
	_track_grain.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = 1980
	# Grass blades rooted at the bottom of the infield strip, growing up.
	var strip_bottom := STANDS_BOTTOM + INFIELD_H
	var gx := 0.0
	while gx < world_width:
		var lighter := rng.randf() < 0.6
		var col := Palette.INFIELD.lightened(rng.randf_range(0.05, 0.30)) if lighter else Palette.INFIELD.darkened(rng.randf_range(0.08, 0.30))
		col.a = rng.randf_range(0.35, 0.8)
		var h := rng.randf_range(2.5, 6.0)
		_grass.append({
			"x": gx + rng.randf_range(-1.0, 1.0),
			"y": strip_bottom - h - rng.randf_range(0.0, 3.0),
			"w": rng.randf_range(1.0, 1.8),
			"h": h,
			"col": col,
		})
		gx += rng.randf_range(2.0, 4.5)
	# Fine grain flecks scattered across the track.
	var top := STANDS_BOTTOM + INFIELD_H
	var count := int(world_width / 5.0)
	for _i in count:
		var lighten := rng.randf() < 0.5
		var col2 := Palette.TRACK.lightened(rng.randf_range(0.05, 0.18)) if lighten else Palette.TRACK.darkened(rng.randf_range(0.06, 0.20))
		col2.a = rng.randf_range(0.12, 0.30)
		_track_grain.append({
			"x": rng.randf_range(0.0, world_width),
			"y": rng.randf_range(top + 2.0, TRACK_BOTTOM - 2.0),
			"w": rng.randf_range(1.5, 3.5),
			"h": rng.randf_range(1.0, 2.2),
			"col": col2,
		})

func _process(delta: float) -> void:
	_t += delta
	queue_redraw()

func _draw() -> void:
	var w := world_width
	if backdrop:
		var th := float(Palette.BASE_HEIGHT)
		if backdrop_tile:
			# Repeat the art across the world, MIRRORING every other tile so the seams line up (a
			# tile's edge meets its own mirror image = identical pixels = seamless).
			var tw: float = backdrop.get_width() * (th / backdrop.get_height())
			var x := 0.0
			var i := 0
			while x < w:
				if i % 2 == 1:
					draw_set_transform(Vector2(x + tw, 0.0), 0.0, Vector2(-1, 1))
					draw_texture_rect(backdrop, Rect2(0, 0, tw, th), false)
					draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
				else:
					draw_texture_rect(backdrop, Rect2(x, 0, tw, th), false)
				x += tw
				i += 1
		else:
			# One fixed wide image spanning the whole world (e.g. the swim pool: fixed start + turn ends).
			draw_texture_rect(backdrop, Rect2(0, 0, w, th), false)
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
	# Grassy infield strip below the stand wall, with blade texture + a shaded seam onto the track.
	var top := STANDS_BOTTOM + INFIELD_H
	draw_rect(Rect2(0, STANDS_BOTTOM, w, INFIELD_H), Palette.INFIELD.darkened(0.12))
	for b in _grass:
		draw_rect(Rect2(b["x"], b["y"], b["w"], b["h"]), b["col"])
	draw_rect(Rect2(0, top - 1.5, w, 1.5), Palette.INFIELD.darkened(0.45))
	# Track, dusted with grain so it doesn't read as a flat fill.
	draw_rect(Rect2(0, top, w, TRACK_BOTTOM - top), Palette.TRACK)
	for g in _track_grain:
		draw_rect(Rect2(g["x"], g["y"], g["w"], g["h"]), g["col"])
	# Lane lines (evenly spaced across the running lanes).
	var lanes := 6
	for i in lanes + 1:
		var y := lerpf(top, TRACK_BOTTOM, float(i) / lanes)
		draw_rect(Rect2(0, y - 1.25, w, 2.5), Palette.TRACK_LINE)
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
