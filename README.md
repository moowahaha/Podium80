# Podium '80

A polished retro pixel-art sports game built in **Godot 4.6**, made for controller play on a TV.
Inspired by the atmosphere of the 1980 summer games — a **fictional** international sporting event
(no Olympic trademarks, rings, mascots, music, or the words "Olympic/Olympiad"). Seven track & field
events form a championship; pick one of four nations and chase the most points.

Full-widescreen 16:9, NES/SNES-inspired pixel art, a grainy CRT presentation, and arcade-responsive
controls running at 60 FPS.

## The championship

Pick a nation (**USSR · East Germany · Great Britain · Australia**) and compete across seven events for
championship points; the nation with the most points after all seven wins the podium. Each event opens
with a title card (artwork + name + a state slogan + a trumpet fanfare); the ceremony ends on a podium
(one of four backdrops, chosen at random) with the top three dancing under fireworks as their flags
raise up the poles — to the **national anthem of the winning nation**.

| # | Event | Core mechanic |
|---|-------|---------------|
| 1 | 100m Sprint | Start sequence (На старт!/Внимание!/Марш! + pistol), alternate **A/B** to run (light fatigue), dynamic-zoom 2-player races |
| 2 | Long Jump | Alternate **A/B** for run-up, **L** to take off on the board — distance = speed × timing; 3 attempts |
| 3 | 110m Hurdles | Run with **A/B**, **L** to clear each hurdle — clips slow you and topple the hurdle; 2-player |
| 4 | Hammer Throw | **Top-down**: rev-up meter (**A/B** to hold the marker in the rising sweet-spot), **L** to release in the legal sector; camera follows the throw; 3 attempts |
| 5 | Triple Jump | Alternate **A/B** for run-up, **L** to take off, then time the hop and step; 3 attempts |
| 6 | Javelin | Side-on: **A/B** run-up, **L** to plant before the line (overstep = fall), then a quarter-circle needle — **L** at **45°** for max range; distance = speed × angle; camera follows the throw. Each nation throws a different implement (boomerang / flaming missile / tree branch / tricolour javelin) that sticks in the turf; 3 attempts |
| 7 | 400m | Longer alternate-**A/B** race with pacing/fatigue; 2-player |

## Controls

Everything plays on **D-pad + A + B + L + R** (START/SELECT are reserved for pause / hold-to-quit).
Two players use two controllers — player 1 is the first-connected pad, player 2 the second. The game
reads both gamepads and the keyboard, so it's fully playable with a pad or a keyboard for development.

## Running & building

Requires Godot 4.x (`godot` on PATH).

```sh
godot .                       # open/run in the editor
godot --headless --import     # import resources (first run / CI)
./build.sh                    # export build/game.pck + build/podium-80.zip
```

Handy dev flags (see `src/autoload/DevTools.gd`):

```sh
godot --scene res://src/events/hammer/Hammer.tscn --event 3   # jump to a scene/event
godot --sim 5 --scene res://src/menus/Podium.tscn             # simulate a full championship
godot --shot out.png --shot-delay 1.2                         # render a frame to PNG (visual QA)
godot --headless --runtest                                    # print the run-mechanic balance table
godot --scene res://tools/JavelinAnchorTool.tscn             # author javelin hold-points per frame
```

The game renders at a fixed **960×540** 16:9 base with `canvas_items` / `keep` stretch, so it scales
pixel-perfect (×2 to 1080p) with letterboxing.

## Architecture

Clean, modular, data-driven. Autoload singletons (`src/autoload/`) provide the shared systems:
`Palette`, `CountryData`, `AthleteData`, `Scoring`, `Game` (championship state + AI), `Platform`
(input), `UI` (theme), `AudioBus` (synthesized placeholder SFX), `SceneRouter`, `CRTOverlay`.

Reusable components (`src/common/`): `Athlete`, `Stadium`, `FlagRenderer`, `CameraManager`,
`RunEngine`. Each event is a self-contained scene (`src/events/*`) extending `EventBase`. Menus/flow
live in `src/menus/`.

## Art & assets

Real pixel art is in for the flags, the per-nation athlete sprites (run/jump/hurdle/land/dance/…),
the scrolling stadium backdrop, the **top-down hammer field**, and the full-screen event/menu
backgrounds; anything without art falls back to the procedural drawing, and audio is still
synthesized (see `AudioBus`). Drop-in paths:

- Athlete sprite sheets → `assets/sprites/<nation>/<state>.png` (see `Athlete.SPRITE_STATES`)
- Nation flags → `assets/flags/<nation>.png`
- In-game stadium backdrops → `assets/stadium/{track,hammer_field}.png`
- Event title cards & menu backgrounds → `assets/backgrounds/*.png` (podiums: `podium{,2,3,4}.png`, one picked at random)
- National anthems (looped on the podium) → `assets/music/anthem_<nation>.mp3`
- A real pixel font → `UI.set_pixel_font()` (one call)

The javelin implements (boomerang / missile / branch / tricolour javelin) are **drawn by the event**,
not baked into the sprites; their hold-point (position + angle) is authored per animation frame with
the **javelin anchor tool** (`tools/JavelinAnchorTool.tscn`) and saved to
`assets/sprites/javelin_anchors.json`, which `Athlete` reads back to place them exactly on the hand.

Prompts for generating the SNES-style art (side-on backdrops, title cards, the top-down hammer
field) are in [`docs/ART_PROMPTS.md`](docs/ART_PROMPTS.md).

## License / trademarks

Original fictional sporting event. Contains no Olympic trademarks, logos, rings, mascots, or the
words "Olympic/Olympics/Olympiad".
