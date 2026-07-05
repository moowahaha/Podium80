# Podium '80

A polished retro pixel-art sports game built in **Godot 4.6**, made for controller play on a TV.
Inspired by the atmosphere of the 1980 summer games — a **fictional** international sporting event
(no Olympic trademarks, rings, mascots, music, or the words "Olympic/Olympiad"). Six track & field
events form a championship; pick one of four nations and chase the most points.

Full-widescreen 16:9, NES/SNES-inspired pixel art, a grainy CRT presentation, and arcade-responsive
controls running at 60 FPS.

## The championship

Pick a nation (**USSR · East Germany · Great Britain · Australia**) and compete across six events for
championship points; the nation with the most points after all six wins the podium. Each event opens
with a title card (artwork + name + a state slogan + a trumpet fanfare); the ceremony ends on the
Red Square podium with the top three dancing under fireworks as their flags raise up the poles.

| # | Event | Core mechanic |
|---|-------|---------------|
| 1 | 100m Sprint | Start sequence (На старт!/Внимание!/Марш! + pistol), alternate **A/B** to run (light fatigue), dynamic-zoom 2-player races |
| 2 | Long Jump | Alternate **A/B** for run-up, **LB** to take off on the board — distance = speed × timing; 3 attempts |
| 3 | 110m Hurdles | Run with **A/B**, **LB** to clear each hurdle — clips slow you and topple the hurdle; 2-player |
| 4 | Hammer Throw | **Top-down**: rhythmic **A/B** to spin, **LB** to release in the legal sector; camera follows the throw; 3 attempts |
| 5 | Triple Jump | Alternate **A/B** for run-up, **LB** to take off, then time the hop and step; 3 attempts |
| 6 | 400m | Longer alternate-**A/B** race with pacing/fatigue; 2-player |

## Controls

Everything plays on **D-pad + A + B + LB + RB** (START/SELECT are reserved for pause / hold-to-quit).
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
- Event title cards & menu backgrounds → `assets/backgrounds/*.png`
- A real pixel font → `UI.set_pixel_font()` (one call)

Prompts for generating the SNES-style art (side-on backdrops, title cards, the top-down hammer
field) are in [`docs/ART_PROMPTS.md`](docs/ART_PROMPTS.md).

## License / trademarks

Original fictional sporting event. Contains no Olympic trademarks, logos, rings, mascots, or the
words "Olympic/Olympics/Olympiad".
