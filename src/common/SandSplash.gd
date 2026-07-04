extends Node2D
class_name SandSplash
## An over-the-top burst of sand kicked up when an athlete lands in the pit. Drawn in world space over
## the athlete. Call burst(world_pos, power); larger power = more, faster grains.

var _p: Array = []          # particles: {pos, vel, life, life0, size, col}
var _bursts := 0            # varies the RNG seed per burst (no time source available)

const SAND_COLS := [Color("efdca4"), Color("e2cd93"), Color("d2b877"), Color("bf9f5f")]

func _ready() -> void:
	z_index = 60            # over the sand + athlete

func burst(at: Vector2, power: float = 1.0) -> void:
	var rng := RandomNumberGenerator.new()
	_bursts += 1
	rng.seed = 7000 + _bursts
	var n := int(52 * power)
	for _i in n:
		var ang := rng.randf_range(-PI * 0.94, -PI * 0.06)     # fan upward and out
		var spd := rng.randf_range(55.0, 245.0) * power
		var life := rng.randf_range(0.35, 0.9)
		_p.append({
			"pos": at + Vector2(rng.randf_range(-8.0, 8.0), rng.randf_range(-3.0, 1.0)),
			"vel": Vector2(cos(ang), sin(ang)) * spd,
			"life": life, "life0": life,
			"size": rng.randf_range(1.5, 4.5),
			"col": SAND_COLS[rng.randi_range(0, SAND_COLS.size() - 1)],
		})
	queue_redraw()

func _process(delta: float) -> void:
	if _p.is_empty():
		return
	var grav := 540.0
	var alive: Array = []
	for pt in _p:
		pt["life"] -= delta
		if pt["life"] <= 0.0:
			continue
		pt["vel"].y += grav * delta
		pt["pos"] += pt["vel"] * delta
		alive.append(pt)
	_p = alive
	queue_redraw()

func _draw() -> void:
	for pt in _p:
		var a: float = clampf(pt["life"] / pt["life0"], 0.0, 1.0)
		var c: Color = pt["col"]
		c.a = a
		var s: float = pt["size"]
		draw_rect(Rect2(pt["pos"] - Vector2(s, s) * 0.5, Vector2(s, s)), c)
