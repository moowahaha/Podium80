extends Node2D
class_name Fireworks
## Continuous celebratory fireworks bursting within a screen region. Drop into a CanvasLayer/HUD; it
## keeps launching bursts until freed.

const COLS := [Color("ffe14d"), Color("ff5b5b"), Color("5bd0ff"), Color("b98bff"), Color("6cff8f"), Color("ffffff"), Color("ff9d3b")]

var region := Rect2(60, 40, 840, 210)   # where bursts appear (screen space)
var rate := Vector2(0.18, 0.45)         # seconds between bursts (min,max)
var _p: Array = []
var _timer := 0.0

func _process(delta: float) -> void:
	_timer -= delta
	if _timer <= 0.0:
		_burst()
		_timer = randf_range(rate.x, rate.y)
	var alive: Array = []
	for p in _p:
		p["life"] -= delta
		if p["life"] <= 0.0:
			continue
		p["vel"].y += 60.0 * delta
		p["vel"] *= 0.985
		p["pos"] += p["vel"] * delta
		alive.append(p)
	_p = alive
	queue_redraw()

func _burst() -> void:
	var c := Vector2(randf_range(region.position.x, region.end.x), randf_range(region.position.y, region.end.y))
	var col: Color = COLS[randi() % COLS.size()]
	var count := randi_range(24, 40)
	var power := randf_range(50.0, 135.0)
	for i in count:
		var ang := TAU * float(i) / count + randf_range(-0.1, 0.1)
		var spd := power * randf_range(0.55, 1.0)
		var life := randf_range(0.6, 1.3)
		_p.append({
			"pos": c, "vel": Vector2(cos(ang), sin(ang)) * spd,
			"life": life, "life0": life,
			"col": col if randf() < 0.8 else Palette.PAPER,
			"size": randf_range(1.5, 3.5),
		})

func _draw() -> void:
	for p in _p:
		var a: float = clampf(p["life"] / p["life0"], 0.0, 1.0)
		var col: Color = p["col"]
		col.a = a
		var s: float = p["size"] * (0.6 + 0.4 * a)
		draw_rect(Rect2(p["pos"] - Vector2(s, s) * 0.5, Vector2(s, s)), col)
