extends Camera2D
class_name CameraManager
## Smart gameplay camera. Follows one or two competitors along x; with two, it dynamically zooms OUT
## just enough to keep both comfortably on-screen (per the brief), then eases back in as they converge.
## Vertical framing is fixed. Motion + zoom are smoothed for a polished feel, and the view is clamped
## to the world bounds.

var targets: Array[Node2D] = []
var priority: Array[Node2D] = []   # must stay framed (the human runners) even if the field spreads wider
var world_width := 720.0
var fixed_y := 120.0
var margin := 300.0            # world px of breathing room around the outermost targets
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

## Targets that must never leave the frame (the human runners). The camera nudges off the field's
## geometric centre as needed to keep these on-screen, so a player can't run off camera.
func set_priority(t: Array) -> void:
	priority.clear()
	for n in t:
		if n != null:
			priority.append(n)

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
	# Keep the priority (human) targets inside the frame even when the field has spread wider than
	# the zoom-out can cover — otherwise a trailing/leading player runs clean off camera in the 400m.
	if not priority.is_empty():
		var pmin := INF
		var pmax := -INF
		for a in priority:
			pmin = minf(pmin, a.position.x)
			pmax = maxf(pmax, a.position.x)
		var pad := minf(half * 0.4, 110.0)          # keep them off the very edge
		var lo := pmax - half + pad                 # centre must be >= this so the rearmost stays in view
		var hi := pmin + half - pad                 # centre must be <= this so the foremost stays in view
		center_x = clampf(center_x, lo, hi) if lo <= hi else (pmin + pmax) * 0.5

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
