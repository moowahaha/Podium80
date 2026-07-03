extends Node2D
class_name Stadium
## Reusable lively stadium backdrop drawn in world space across [0, world_width]: dusk sky, tiered
## stands with an animated crowd (rolling Mexican wave + twinkle), hanging banners, a red running
## track with lane markings and an infield. Events place athletes on top and pan a camera along x.
##
## Layout (in the 216px-tall base): sky 0..46, stands 46..148, track 148..208. Feet sit on `ground_y`.

@export var world_width := 720.0
@export var track_markings := true

const SKY_H := 46.0
const STANDS_BOTTOM := 148.0
const TRACK_BOTTOM := 208.0

var ground_y := 196.0          # where athlete feet rest
var backdrop: Texture2D        # optional generated stadium art (drop-in); tiled across the world
var _t := 0.0
var _crowd: Array = []         # [{x, y, base_col, phase, w, h}]

func _ready() -> void:
	z_index = -10          # always the backmost layer, so event decorations + athletes draw on top
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
	var step := 3.0
	var x := 4.0
	while x < world_width - 4.0:
		var rows := 6
		for r in rows:
			# skip some seats for texture
			if rng.randf() < 0.12:
				continue
			_crowd.append({
				"x": x + rng.randf_range(-0.6, 0.6),
				"y": 52.0 + r * 15.0,
				"col": shirt_cols[rng.randi_range(0, shirt_cols.size() - 1)],
				"phase": x * 0.04,
				"w": 2.0,
				"h": 2.0,
			})
		x += step

func _process(delta: float) -> void:
	_t += delta
	queue_redraw()

func _draw() -> void:
	var w := world_width
	if backdrop:
		# Tile the generated art across the whole world, then overlay the track for gameplay.
		draw_texture_rect(backdrop, Rect2(0, 0, w, float(Palette.BASE_HEIGHT)), true)
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
	for tier in range(1, 6):
		var ty := 52.0 + tier * 15.0
		draw_rect(Rect2(0, ty, w, 1.0), Palette.STAND_BASE.darkened(0.35))

	# Crowd with a rolling wave.
	var wave_x := _t * 120.0
	for s in _crowd:
		var d: float = (s["x"] - wave_x)
		var wave: float = maxf(0.0, sin(d * 0.03))
		var lift: float = wave * 2.0
		var tw: float = 0.9 + 0.1 * sin(_t * 8.0 + s["phase"])
		var col: Color = (s["col"] as Color) * tw
		col = col.lerp(Palette.PAPER, wave * 0.18)
		col.a = 1.0
		draw_rect(Rect2(s["x"], s["y"] - lift, s["w"], s["h"]), col)

	# Banner rail + hanging banners (placeholder national colours).
	draw_rect(Rect2(0, STANDS_BOTTOM - 12.0, w, 2.0), Palette.PANEL_LIGHT)
	var ids := CountryData.ORDER
	var bx := 24.0
	var i := 0
	while bx < w - 20.0:
		var accent: Color = CountryData.accent_of(ids[i % ids.size()])
		draw_rect(Rect2(bx, STANDS_BOTTOM - 10.0, 14.0, 9.0), accent)
		draw_rect(Rect2(bx + 4.0, STANDS_BOTTOM - 7.0, 6.0, 3.0), Palette.INK)   # placeholder emblem
		bx += 90.0
		i += 1

	_draw_track(w)

func _draw_track(w: float) -> void:
	# Track apron + track.
	draw_rect(Rect2(0, STANDS_BOTTOM, w, 6.0), Palette.INFIELD.darkened(0.2))
	draw_rect(Rect2(0, STANDS_BOTTOM + 6.0, w, TRACK_BOTTOM - STANDS_BOTTOM - 6.0), Palette.TRACK)
	# Lane lines.
	draw_rect(Rect2(0, STANDS_BOTTOM + 6.0, w, 1.0), Palette.TRACK_LINE)
	draw_rect(Rect2(0, ground_y + 6.0, w, 1.0), Palette.TRACK_LINE)
	draw_rect(Rect2(0, TRACK_BOTTOM - 1.0, w, 1.0), Palette.TRACK_LINE)

	# Distance tick marks for a sense of speed.
	if track_markings:
		var m := 0.0
		while m < w:
			draw_rect(Rect2(m, TRACK_BOTTOM - 4.0, 1.0, 3.0), Palette.TRACK_LINE * Color(1, 1, 1, 0.5))
			m += 20.0
