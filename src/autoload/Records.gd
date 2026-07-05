extends Node
## Persistent per-event best marks ("records"). Stored in the game's own user data so they survive
## across plays on the same install. Higher-is-better events (jumps/throws) keep the biggest mark;
## time events (sprints/hurdles) keep the fastest. Only real player marks set records — never the AI.

const PATH := "user://records.cfg"
const SECTION := "records"

var _cfg := ConfigFile.new()

func _ready() -> void:
	_cfg.load(PATH)   # a missing file just means "no records yet"

## The stored record for an event, or NAN if none has been set.
func best(event_id: StringName) -> float:
	return float(_cfg.get_value(SECTION, String(event_id), NAN))

func has_record(event_id: StringName) -> bool:
	return not is_nan(best(event_id))

## Store `value` as the new record if it beats the stored one (or there is none yet); returns true on a
## new record. Fouls / non-positive marks are ignored.
func try_set(event_id: StringName, value: float, higher_better: bool) -> bool:
	if is_nan(value) or value <= 0.0:
		return false
	var cur := best(event_id)
	var beat: bool = is_nan(cur) or (value > cur if higher_better else value < cur)
	if beat:
		_cfg.set_value(SECTION, String(event_id), value)
		_cfg.save(PATH)
	return beat
