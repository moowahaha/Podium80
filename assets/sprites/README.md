# assets/sprites — athlete sprites

Sprites are grouped **by country**, one folder each, with **state-named files**:

```
assets/sprites/
  ussr/
    standing.png      # IDLE  — stationary (menus, waiting, no input)
    crouch.png        # READY — sprint/hurdles start position (in the blocks)
    running.png       # RUN   — run cycle (multi-frame grid)
    hurdle.png        # HURDLE— clearing a hurdle
  gdr/  gbr/  aus/     ← add the same files per country
```

Add a country by creating its folder and dropping the files in; register it in the
`SPRITE_STATES` map in `src/common/Athlete.gd`. Missing states fall back to the procedural
placeholder, so you can add sprites incrementally.

## Frame format

- **64×64 px per frame.** Single-pose files are 64×64; animations are a grid of 64×64 cells read
  **left→right, top→bottom** (e.g. `running.png` is 192×192 = a 3×3 grid of 9 frames).
- Figure faces **right**; the engine flips it when needed.
- In `Athlete.SPRITE_STATES` each state declares `cols`, `rows`, `frames`, and `foot` (empty px below
  the figure's feet in the frame, so it sits on its shadow — e.g. the crouch has ~7).

## States the game uses (make these per country)

| State | Used by | Notes |
|-------|---------|-------|
| `standing` (IDLE) | everywhere stationary | menus, podium, waiting at the runway |
| `crouch` (READY) | Sprint, Hurdles | start blocks |
| `running` (RUN) | Sprint, Hurdles, Long Jump | run cycle (loop) |
| `hurdle` (HURDLE) | Hurdles | clearing a hurdle |
| `jump` (JUMP) | Long Jump | flight (not yet wired — procedural for now) |
| `throw` (THROW) | Hammer | wind-up + release |
| `swim` (SWIM) | 100m Swim | side-on stroke (loop) |
| `celebrate` (CELEBRATE) | finishes, podium winner | |
| `fall` / `stumble` | Vault-style falls / hurdle clatter | |

Kit colours per country still come from `CountryData`, so sprites should be drawn in each nation's kit.
