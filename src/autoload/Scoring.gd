extends Node
## Championship scoring: turn a set of per-country event results into a ranking + championship points.
## Data-driven points table so it can be retuned or extended for more competitors later.

## Points awarded by finishing place (index 0 = 1st). Places beyond the table award 0.
const POINTS_BY_PLACE: Array[int] = [8, 5, 3, 1]

func points_for_place(place: int) -> int:
	if place >= 0 and place < POINTS_BY_PLACE.size():
		return POINTS_BY_PLACE[place]
	return 0

## Rank countries by their raw result value.
##   values           : { country_id : float }  (event metric, e.g. time or distance or score)
##   higher_is_better  : true for distance/score, false for race times
## Returns an ordered Array of { country, value, place, points } best-first. Ties are broken
## deterministically by CountryData.ORDER so results are stable and reproducible.
func rank(values: Dictionary, higher_is_better: bool) -> Array:
	var entries: Array = []
	for id in values.keys():
		entries.append({"country": id, "value": float(values[id])})

	entries.sort_custom(func(a, b):
		if a["value"] == b["value"]:
			return CountryData.ORDER.find(a["country"]) < CountryData.ORDER.find(b["country"])
		if higher_is_better:
			return a["value"] > b["value"]
		return a["value"] < b["value"]
	)

	var ranked: Array = []
	for i in entries.size():
		var e: Dictionary = entries[i]
		ranked.append({
			"country": e["country"],
			"value": e["value"],
			"place": i,                       # 0-based
			"points": points_for_place(i),
		})
	return ranked
