extends Node
## Shared palette + layout constants for Podium '80.
##
## Central place for the retro colour scheme and the fixed 16:9 pixel-art base resolution, so the
## look can be retuned in one file. All gameplay/menus render into this base and are scaled up
## pixel-perfect by the canvas_items stretch (see project.godot / MeboboxOS override.cfg).

# --- Base resolution (16:9, x2 = 1920x1080 exactly => pixel-perfect on the console) ---
const BASE_WIDTH: int = 960
const BASE_HEIGHT: int = 540
const BASE_SIZE := Vector2i(BASE_WIDTH, BASE_HEIGHT)

# Placeholder athlete draw ≈ 26px tall; scale it so figures read ~64px, matching the final sprites.
const ATHLETE_SCALE := 2.45

# --- Core retro palette (NES/SNES-ish, warm 1980s stadium) ---
const INK := Color("14131f")          # near-black UI ink
const PANEL := Color("241f38")         # UI panel fill
const PANEL_LIGHT := Color("3b3357")
const PAPER := Color("efe9d8")         # off-white text
const HIGHLIGHT := Color("ffd23f")     # gold highlight / selection
const HIGHLIGHT_DIM := Color("b8901f")
const ACCENT := Color("ff5d5d")        # warm red accent
const GOOD := Color("5dd39e")          # success green
const BAD := Color("ff5d5d")           # foul / fail
const SHADOW := Color(0, 0, 0, 0.35)

# --- Stadium environment ---
const SKY_TOP := Color("2b5fa8")
const SKY_BOTTOM := Color("6fa8dc")
const TRACK := Color("c8552e")         # classic red-orange running track
const TRACK_LINE := Color("efe9d8")
const INFIELD := Color("3f8a4b")       # grass green
const STAND_BASE := Color("6b5aa0")    # stadium stand concrete/seat base

func base_rect() -> Rect2:
	return Rect2(Vector2.ZERO, Vector2(BASE_WIDTH, BASE_HEIGHT))
