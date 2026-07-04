extends Node
## Athlete names per country (placeholder, era-flavoured, ASCII-only so any pixel font renders them).
## Data-driven: extend a country's list or add a country and names flow through automatically.

const NAMES := {
	&"USSR": ["Павел Полоний"],
	&"GDR": ["PETER PROLL"],
	&"GBR": ["CLIVE CRUMPET"],
	&"AUS": ["BRUCE BONZA"],
}

const FALLBACK := ["ATHLETE", "RUNNER", "JUMPER", "THROWER"]

func names_for(id: StringName) -> Array:
	return NAMES.get(id, FALLBACK)

## Pick a name for a country using the given RNG (so a championship can seed its own reproducible set).
func pick_name(id: StringName, rng: RandomNumberGenerator = null) -> String:
	var list: Array = names_for(id)
	if list.is_empty():
		return str(id)
	var idx: int
	if rng != null:
		idx = rng.randi_range(0, list.size() - 1)
	else:
		idx = randi() % list.size()
	return list[idx]
