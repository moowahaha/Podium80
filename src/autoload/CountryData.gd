extends Node
## Data-driven country definitions for Podium '80.
##
## Four fictional-event competitor nations. Each entry drives flag, kit colours, scoreboard accent
## and abbreviation only (per the brief). Adding a country later = one more entry here; nothing else
## in the game hard-codes the set of four. Colours are chosen to read as four DISTINCT hues on a CRT
## (red / gold / white / blue) so competitors are easy to tell apart at a glance.
##
## No protected marks: flags are simple procedural band+emblem placeholders drawn by FlagRenderer.

const ORDER: Array[StringName] = [&"USSR", &"GDR", &"GBR", &"FRA"]

const COUNTRIES := {
	&"USSR": {
		"name": "USSR",
		"long_name": "SOVIET UNION",
		"abbrev": "URS",
		"accent": Color("e23b3b"),          # scoreboard / UI accent
		"kit_primary": Color("cc2a2a"),     # jersey
		"kit_secondary": Color("f4d84a"),   # trim / shorts
		"kit_skin": Color("e8b48c"),
		"flag": {
			"orient": "horizontal",
			"bands": [Color("c11a1a")],
			"emblem": {"shape": "star", "color": Color("f4d84a"), "pos": Vector2(0.24, 0.30), "size": 0.16},
		},
	},
	&"GDR": {
		"name": "GDR",
		"long_name": "EAST GERMANY",
		"abbrev": "GDR",
		"accent": Color("f2c841"),
		"kit_primary": Color("e0a92a"),
		"kit_secondary": Color("1a1a1a"),
		"kit_skin": Color("e8b48c"),
		"flag": {
			"orient": "horizontal",
			"bands": [Color("161616"), Color("c11a1a"), Color("f4c430")],
			"emblem": {"shape": "ring", "color": Color("d9a520"), "pos": Vector2(0.5, 0.5), "size": 0.22},
		},
	},
	&"GBR": {
		"name": "GREAT BRITAIN",
		"long_name": "GREAT BRITAIN",
		"abbrev": "GBR",
		"accent": Color("e6e6ea"),
		"kit_primary": Color("dcdce4"),
		"kit_secondary": Color("c81f2e"),
		"kit_skin": Color("e8b48c"),
		"flag": {
			"orient": "horizontal",
			"bands": [Color("1f3a93"), Color("e8e8ec"), Color("c81f2e")],
			"emblem": null,
		},
	},
	&"FRA": {
		"name": "FRANCE",
		"long_name": "FRANCE",
		"abbrev": "FRA",
		"accent": Color("3b7be2"),
		"kit_primary": Color("2f5fd0"),
		"kit_secondary": Color("e6e6ea"),
		"kit_skin": Color("e8b48c"),
		"flag": {
			"orient": "vertical",
			"bands": [Color("2b3aa0"), Color("f0f0f4"), Color("d21f33")],
			"emblem": null,
		},
	},
}

func all_ids() -> Array[StringName]:
	return ORDER.duplicate()

func has(id: StringName) -> bool:
	return COUNTRIES.has(id)

func get_country(id: StringName) -> Dictionary:
	return COUNTRIES.get(id, COUNTRIES[ORDER[0]])

func name_of(id: StringName) -> String:
	return get_country(id).get("name", str(id))

func abbrev_of(id: StringName) -> String:
	return get_country(id).get("abbrev", str(id))

func accent_of(id: StringName) -> Color:
	return get_country(id).get("accent", Palette.PAPER)

func kit_primary_of(id: StringName) -> Color:
	return get_country(id).get("kit_primary", Palette.ACCENT)

func kit_secondary_of(id: StringName) -> Color:
	return get_country(id).get("kit_secondary", Palette.PAPER)

func kit_skin_of(id: StringName) -> Color:
	return get_country(id).get("kit_skin", Color("e8b48c"))

func flag_of(id: StringName) -> Dictionary:
	return get_country(id).get("flag", {})
