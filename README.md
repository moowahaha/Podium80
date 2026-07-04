# Podium '80

A polished retro pixel-art sports game for the **MeboboxOS** console, built in **Godot 4.6**.
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

The console exposes only **D-pad + A + B + LB + RB** (START/SELECT are reserved by the OS for
pause / hold-to-quit). The whole game is playable with those. Two players use two controllers
(true per-pad input — see *MeboboxOS integration*).

### Button → key mapping (must match the Creator Hub)

The game binds these exact keys (`src/autoload/Platform.gd`) and ships them in `manifest.json`. When
publishing to the Mebobox Creator Hub, set **both** maps — omitting `controlsP2` collapses both
controllers onto Player 1, so the second pad does nothing.

| Logical button | Player 1 (`controls`) | Player 2 (`controlsP2`) |
|---|---|---|
| Up | Arrow Up | `i` |
| Down | Arrow Down | `k` |
| Left | Arrow Left | `j` |
| Right | Arrow Right | `l` |
| A | Space | `f` |
| B | `b` | `g` |
| LB | `q` | `h` |
| RB | `w` | `n` |

## Running & building

Requires Godot 4.x (`godot` on PATH).

```sh
godot .                       # open/run in the editor
godot --headless --import     # import resources (first run / CI)
./build.sh                    # export build/game.pck + build/podium-80.zip
```

Handy dev flags (see `src/autoload/DevTools.gd`):

```sh
godot --scene res://src/events/vault/Vault.tscn --event 4     # jump to a scene/event
godot --sim 5 --scene res://src/menus/Podium.tscn             # simulate a full championship
godot --shot out.png --shot-delay 1.2                         # render a frame to PNG (visual QA)
godot --headless --runtest                                    # print the run-mechanic balance table
```

## MeboboxOS integration

MeboboxOS runs this as a **native** game: it launches `game.pck` on its bundled Godot 4 ARM64
runtime, firejail-sandboxed and fullscreen (`agent/src/native.js`). The game is **keyboard-driven** —
on the console a pad→keyboard injector (`agent/mebobox-input.py`) translates each controller into
synthetic key presses, so the game never reads the pad directly. `manifest.json` maps the console's
logical buttons to the keys this game listens for:

- **Player 1:** arrows, A=Space, B=b, LB=q, RB=w
- **Player 2:** i/k/j/l, A=f, B=g, LB=h, RB=n (`controlsP2` — drives true local 2-player)

Godot's InputMap (`src/autoload/Platform.gd`) binds those exact keys **and** the physical gamepad, so
the game is fully playable off-console with a keyboard or pad for development.

The display uses a fixed **960×540** base (16:9) with `canvas_items`/`keep` stretch → pixel-perfect
×2 to 1080p, matching the letterbox override the console applies.

**Publishing:** upload `build/podium-80.zip` (or this repo) via the Mebobox Creator Hub. Enter the
same `controls` / `controlsP2` maps from `manifest.json` so LB/RB and player 2 are mapped.

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
