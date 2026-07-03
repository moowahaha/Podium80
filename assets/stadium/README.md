# assets/stadium — event backdrops

Drop generated SNES-style stadium art here. Each loads automatically (procedural fallback if absent).
See `docs/ART_PROMPTS.md` for the generation prompts.

| File | Used by | Size | Notes |
|------|---------|------|-------|
| `track.png` | Sprint + Hurdles | **768×216** | seamless L↔R tiling (scrolls) |
| `long_jump.png` | Long Jump | **768×216** | seamless L↔R tiling |
| `hammer.png` | Hammer Throw | **384×216** | single screen |
| `swim.png` | 100m Swim | **768×216** | seamless L↔R tiling (side-on pool) |
| `podium.png` | Podium ceremony | **384×216** | single screen |

Keep the bottom ~60 px a flat apron (the game overlays the red track, lane lines and the 48×72 sprites there).
