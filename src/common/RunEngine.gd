extends RefCounted
class_name RunEngine
## Shared "alternate two buttons to run" mechanic with a light fatigue system, used by the sprint and
## the hurdles. Input-agnostic: the caller feeds taps (tap_a / tap_b), so the exact same engine drives
## P1, P2 or an AI. Physics-y speed model integrated per frame.
##
## Rules from the brief:
##  * Alternate the two buttons; pressing the SAME button twice in a row does nothing.
##  * A light fatigue mechanic discourages impossible mashing but stays fun: each valid alternation
##    adds speed scaled by (1 - fatigue); fatigue rises per tap and recovers over time, so there's an
##    optimal sustainable rhythm rather than "mash infinitely fast = infinitely fast".

# Tunables (m/s unless noted). Tuned so a good sustained rhythm gives a realistic ~10.8-11.5s 100m
# (competitive with the AI field, mean 11.2s), poor rhythm loses, and impossible mashing plateaus
# rather than scaling forever (see DevTools --runtest).
var impulse := 0.62            # speed added per valid alternation at zero fatigue
var drag := 1.9               # natural deceleration (per second, proportional-ish)
var max_speed := 10.6
var fatigue_gain := 0.03       # fatigue added per tap
var fatigue_recover := 0.5     # fatigue recovered per second
var fatigue_cap := 0.5         # floors impulse at (1-cap): faster is never WORSE, just plateaus

# State.
var speed := 0.0
var distance := 0.0
var fatigue := 0.0
var running := false
var _last := 0                 # 0 none, 1 = A, 2 = B
var taps := 0

func reset() -> void:
	speed = 0.0
	distance = 0.0
	fatigue = 0.0
	_last = 0
	taps = 0
	running = false

func start() -> void:
	running = true

func tap_a() -> bool:
	return _tap(1)

func tap_b() -> bool:
	return _tap(2)

func _tap(which: int) -> bool:
	if not running:
		return false
	if which == _last:
		return false                       # same button twice: no effect
	_last = which
	taps += 1
	fatigue = minf(fatigue_cap, fatigue + fatigue_gain)
	speed = minf(max_speed, speed + impulse * (1.0 - fatigue))
	return true

## Advance the model. Returns distance travelled this frame.
func update(delta: float) -> float:
	if running:
		fatigue = maxf(0.0, fatigue - fatigue_recover * delta)
		speed = maxf(0.0, speed - drag * delta * (0.3 + speed / max_speed))
	var moved := speed * delta
	distance += moved
	return moved

## 0..1 normalized speed, for driving run-cycle animation.
func speed_ratio() -> float:
	return clampf(speed / max_speed, 0.0, 1.0)
