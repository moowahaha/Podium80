extends Node
## Central championship state for Podium '80.
##
## Owns: the four participating nations, which are human-controlled (1 or 2 players), the athlete
## names, the ordered list of five events, and the accumulated results. Event scenes report only the
## HUMAN result(s); AI opponents for the remaining nations are simulated here (one place to balance),
## then Scoring ranks all four and awards championship points. The overall winner is the nation with
## the most points after all five events.

signal championship_started
signal event_completed(event_id: StringName, ranked: Array)

## The five championship events, in order. Each is a self-contained scene sharing common systems.
## `ai` gives the opponent-simulation distribution for the nations no human is playing.
const EVENTS: Array[Dictionary] = [
	{
		"id": &"sprint", "title": "100M SPRINT", "unit": "s", "higher_better": false, "dist": 100.0,
		"two_player": true, "scene": "res://src/events/sprint/Sprint.tscn",
		"ai": {"mean": 11.2, "sd": 0.55, "min": 10.2, "max": 13.6},
	},
	{
		"id": &"long_jump", "title": "LONG JUMP", "unit": "m", "higher_better": true,
		"two_player": false, "scene": "res://src/events/long_jump/LongJump.tscn",
		"ai": {"mean": 7.6, "sd": 0.6, "min": 5.0, "max": 8.6},
	},
	{
		"id": &"hurdles", "title": "110M HURDLES", "unit": "s", "higher_better": false,
		"two_player": true, "scene": "res://src/events/hurdles/Hurdles.tscn",
		"ai": {"mean": 14.3, "sd": 0.8, "min": 13.2, "max": 17.5},
	},
	{
		"id": &"hammer", "title": "HAMMER THROW", "unit": "m", "higher_better": true,
		"two_player": false, "scene": "res://src/events/hammer/Hammer.tscn",
		"ai": {"mean": 65.0, "sd": 6.5, "min": 38.0, "max": 80.0},
	},
	{
		"id": &"triple_jump", "title": "TRIPLE JUMP", "unit": "m", "higher_better": true,
		"two_player": false, "scene": "res://src/events/triple_jump/TripleJump.tscn",
		"ai": {"mean": 15.2, "sd": 1.3, "min": 10.5, "max": 18.2},
	},
	{
		"id": &"javelin", "title": "JAVELIN", "unit": "m", "higher_better": true,
		"two_player": false, "scene": "res://src/events/javelin/Javelin.tscn",
		"ai": {"mean": 80.7, "sd": 3.66, "min": 71.1, "max": 89.3},   # tight, high field (~4% easier than a real final)
	},
	{
		"id": &"sprint_400", "title": "400M", "unit": "s", "higher_better": false, "dist": 400.0,
		"two_player": true, "scene": "res://src/events/sprint/Sprint.tscn",
		"ai": {"mean": 46.0, "sd": 2.8, "min": 42.0, "max": 55.0},
	},
]

var rng := RandomNumberGenerator.new()
var participants: Array[StringName] = []          # all four nations, fixed order
var human_map: Dictionary = {}                    # country_id -> player_index (0/1); AI nations absent
var two_player: bool = false
var athlete_names: Dictionary = {}                # country_id -> String
var current_event_index: int = 0     # the actual EVENTS index in play (= event_order[event_pos])
var event_order: Array = []           # EVENTS indices in play order (randomised for a championship)
var event_pos: int = 0                # position within event_order
var event_results: Array[Dictionary] = []         # [{ event:StringName, ranked:Array }]

# Menu selection carried from ModeSelect -> CountrySelect.
var single_event_mode: bool = false               # true = play one event, then back to the menu
var pending_players: int = 1                       # 1 or 2 (chosen on the mode screen)
var pending_mode: String = "championship"          # "championship" or "single"
var pending_event_index: int = 0                   # which event, when single

func _ready() -> void:
	rng.randomize()

## Begin a championship. `human_country_ids` has one entry (solo) or two (local 2P: index 0 = P1).
func start_championship(human_country_ids: Array) -> void:
	rng.randomize()
	participants = CountryData.all_ids()
	human_map.clear()
	two_player = human_country_ids.size() >= 2
	for i in human_country_ids.size():
		human_map[human_country_ids[i]] = i
	athlete_names.clear()
	for id in participants:
		athlete_names[id] = AthleteData.pick_name(id, rng)
	# Championship runs least-complex → most-complex, and always finishes with the 400m.
	event_order = _championship_order()
	event_pos = 0
	current_event_index = event_order[0]
	event_results.clear()
	single_event_mode = false
	championship_started.emit()

## Play order by rising mechanical complexity, 400m always last. Unlisted events fall in before the 400m.
const COMPLEXITY_ORDER: Array[StringName] = [
	&"sprint",       # mash A/B
	&"long_jump",    # run + one take-off
	&"hurdles",      # run + time each hurdle
	&"triple_jump",  # run + take-off, then hop & step
	&"javelin",      # run, plant, then a trajectory meter
	&"hammer",       # rhythmic rev-up meter + release sector
	&"sprint_400",   # always last
]

func _championship_order() -> Array:
	var order: Array = []
	for want in COMPLEXITY_ORDER:
		for i in EVENTS.size():
			if EVENTS[i]["id"] == want:
				order.append(i)
	# Safety: append any event not covered by the list (before the 400m if present).
	for i in EVENTS.size():
		if not order.has(i):
			var insert_at := order.size()
			if order.size() > 0 and EVENTS[order[-1]]["id"] == &"sprint_400":
				insert_at -= 1
			order.insert(insert_at, i)
	return order

## Play a single event (chosen from the menu), then return to the menu instead of the podium.
func start_single_event(event_index: int, human_country_ids: Array) -> void:
	start_championship(human_country_ids)
	single_event_mode = true
	event_order = [clampi(event_index, 0, EVENTS.size() - 1)]
	event_pos = 0
	current_event_index = event_order[0]

func reset() -> void:
	participants.clear()
	human_map.clear()
	athlete_names.clear()
	event_results.clear()
	current_event_index = 0
	event_order = []
	event_pos = 0
	two_player = false

# --- Event access -------------------------------------------------------------

func current_event() -> Dictionary:
	return EVENTS[clampi(current_event_index, 0, EVENTS.size() - 1)]

func event_count() -> int:
	return event_order.size() if not event_order.is_empty() else EVENTS.size()

## 1-based position of the current event within the championship (for the "EVENT n/N" counter).
func event_number() -> int:
	return event_pos + 1

func is_last_event() -> bool:
	return event_pos >= event_count() - 1

func is_championship_over() -> bool:
	return event_results.size() >= EVENTS.size()

func advance_event() -> void:
	event_pos = mini(event_pos + 1, event_count() - 1)
	if not event_order.is_empty():
		current_event_index = event_order[event_pos]

# --- Human / player helpers ---------------------------------------------------

func is_human(country_id: StringName) -> bool:
	return human_map.has(country_id)

func player_index_of(country_id: StringName) -> int:
	return human_map.get(country_id, -1)

func country_for_player(player_index: int) -> StringName:
	for id in human_map.keys():
		if human_map[id] == player_index:
			return id
	return &""

func human_count() -> int:
	return human_map.size()

func name_of(country_id: StringName) -> String:
	return athlete_names.get(country_id, str(country_id))

# --- Result submission --------------------------------------------------------

## Pre-roll AI results for the non-human nations of the current event. Call before an event when a
## visible on-track rival should be animated to a real, already-decided time, then pass the same dict
## back into submit_event so the shown rival and the scored result agree.
func roll_ai_values() -> Dictionary:
	var ev := current_event()
	var out: Dictionary = {}
	for id in participants:
		if not is_human(id):
			out[id] = _simulate_ai(ev)
	return out

## Report the human result(s) for the current event and resolve the full four-nation ranking.
## `human_values` maps a human country_id -> its raw metric. `ai_values` optionally supplies
## already-rolled AI results (see roll_ai_values); any nation missing from both is simulated now.
## Returns the ranked Array (best-first, with place + points), and stores it for standings.
func submit_event(human_values: Dictionary, ai_values: Dictionary = {}) -> Array:
	var ev := current_event()
	var values: Dictionary = {}
	for id in participants:
		if human_values.has(id):
			values[id] = human_values[id]
		elif ai_values.has(id):
			values[id] = ai_values[id]
		else:
			values[id] = _simulate_ai(ev)
	var ranked := Scoring.rank(values, bool(ev["higher_better"]))
	event_results.append({"event": ev["id"], "ranked": ranked})
	event_completed.emit(ev["id"], ranked)
	return ranked

func _simulate_ai(ev: Dictionary) -> float:
	var a: Dictionary = ev["ai"]
	var v := rng.randfn(float(a["mean"]), float(a["sd"]))
	return clampf(v, float(a["min"]), float(a["max"]))

## Ranked result of the most recently completed event (for the results screen), or [] if none.
func last_result() -> Array:
	if event_results.is_empty():
		return []
	return event_results.back()["ranked"]

# --- Standings ----------------------------------------------------------------

func standings_points() -> Dictionary:
	var totals: Dictionary = {}
	for id in participants:
		totals[id] = 0
	for er in event_results:
		for r in er["ranked"]:
			totals[r["country"]] = int(totals.get(r["country"], 0)) + int(r["points"])
	return totals

## Standings best-first: [{ country, points, place }]. Ties broken by CountryData.ORDER.
func standings_sorted() -> Array:
	var totals := standings_points()
	var rows: Array = []
	for id in participants:
		rows.append({"country": id, "points": int(totals[id])})
	rows.sort_custom(func(a, b):
		if a["points"] == b["points"]:
			return CountryData.ORDER.find(a["country"]) < CountryData.ORDER.find(b["country"])
		return a["points"] > b["points"]
	)
	for i in rows.size():
		rows[i]["place"] = i
	return rows
