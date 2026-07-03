extends Camera2D
class_name CameraManager
## Smart gameplay camera. Follows one or two competitors along x; with two, it dynamically zooms OUT
## just enough to keep both comfortably on-screen (per the brief), then eases back in as they converge.
## Vertical framing is fixed. Motion + zoom are smoothed for a polished feel, and the view is clamped
## to the world bounds.

var targets: Array[Node2D] = []
var world_width := 720.0
var fixed_y := 120.0
var margin := 120.0            # world px of breathing room around the outermost targets
var min_zoom := 0.62           # most zoomed OUT
var max_zoom := 1.15           # most zoomed IN (single runner / converged)
var follow_lerp := 8.0
var zoom_lerp := 6.0

func setup(world_w: float, y: float) -> void:
	world_width = world_w
	fixed_y = y
	position = Vector2(clampf(_center_x(), _half_view(), world_width - _half_view()), fixed_y)

func set_targets(t: Array) -> void:
	targets.clear()
	for n in t:
		if n != null:
			targets.append(n)

func _process(delta: float) -> void:
	if targets.is_empty():
		return
	var min_x := INF
	var max_x := -INF
	for a in targets:
		min_x = minf(min_x, a.position.x)
		max_x = maxf(max_x, a.position.x)
	var center_x := (min_x + max_x) * 0.5
	var span := (max_x - min_x) + margin

	# Choose zoom so `span` fits the base viewport width.
	var target_zoom := 1.0
	if targets.size() >= 2:
		target_zoom = clampf(float(Palette.BASE_WIDTH) / maxf(span, 1.0), min_zoom, max_zoom)
	else:
		target_zoom = max_zoom

	var z := lerpf(zoom.x, target_zoom, clampf(delta * zoom_lerp, 0.0, 1.0))
	zoom = Vector2(z, z)

	var half := _half_view()
	var tx := clampf(center_x, half, maxf(half, world_width - half))
	var nx := lerpf(position.x, tx, clampf(delta * follow_lerp, 0.0, 1.0))
	position = Vector2(nx, fixed_y)

func _half_view() -> float:
	return (float(Palette.BASE_WIDTH) * 0.5) / maxf(zoom.x, 0.01)

func _center_x() -> float:
	if targets.is_empty():
		return world_width * 0.5
	var s := 0.0
	for a in targets:
		s += a.position.x
	return s / targets.size()
