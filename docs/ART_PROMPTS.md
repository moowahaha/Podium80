# Podium '80 — Paired Background + Music Prompts (SNES art · NES chiptune · Soviet-1980)

Each screen/event has a **background image** (ChatGPT / image gen) and a **matching music track** (Suno)
that share a filename key, so they drop in together and play as a pair. Drop the files at the paths
shown — no code change. Fallbacks (procedural art / silence) apply until then.

Art vibe: **overtly stereotypical Russian / Soviet 1980** — red banners, gold-star and folk motifs,
brutalist concrete stands, onion-dome skyline silhouettes, red running track — as bright **16-bit
SNES pixel art**. Music: **8-bit / NES chiptune** (square + triangle + noise channels), leaning into
Russian cliché melodies (*Korobeiniki / Kalinka* energy, Soviet-march feel) but authentically chiptune.
**No Olympic rings/marks/word, no real mascots; keep any emblem generic/invented.**

**Resolution:** the game renders at **960×540** (×2 to 1080p). Athlete sprites are ~**96 px tall**
(154×154 frames), so a standing figure is roughly a **fifth** of the screen height.

---

## Global blocks (paste at the top of each)

**IMAGE (attach your existing `background.png` as a style reference):**
> **STYLE — MUST OBEY: flat 2D 16-bit SNES/pixel-art sprite graphics, hand-drawn early-90s console
> game.** Visible chunky square pixels, limited ~64–128 colour palette, crisp dithering, hard-edged
> flat colour. Read like a screenshot from a 1992 16-bit sports game, matching the attached image.
> **NOT a photo, NOT photorealistic, NOT a 3D render, NOT CGI, no smooth gradients, no realistic
> lighting/reflections, no depth-of-field, no anti-aliased soft edges.**
> Soviet-1980 stadium: bold blue sky, tiered colourful crowd, concrete brutalist stands, tall
> floodlight pylons, rows of small red pennants with gold-star motifs, red running track, an
> onion-dome/tower city skyline silhouette on the horizon. No text, no logos, no Olympic rings, no real
> mascots. Side-on view. **The playing surface (track / pool / field) must be EMPTY — do NOT draw any
> athletes, swimmers, runners or players on it; the game engine adds every athlete sprite itself.** A
> crowd in the stands is fine, but no people on the track or in the water. Keep the bottom ~150 px a
> simple flat empty lane/apron band. Fill the frame, no border.

**MUSIC (Suno style):**
> **8-bit NES chiptune**, authentic 2A03 sound — square-wave leads, a second square for harmony,
> triangle-wave bass, noise-channel percussion. Catchy Russian-folk melody (*Korobeiniki/Kalinka*,
> Soviet-march feel), minor key, tight looping. Instrumental, no vocals unless noted. Mono-friendly.

---

## 1 · Menu / Title — `assets/menu/background.png` (960×540) + `assets/music/menu.ogg`

**Image:** [BLOCK] A grand establishing shot inside a packed Soviet stadium at midday: floodlight
pylons left and right, tiers of colourful crowd, red pennants, red track across the lower third, an
onion-dome skyline on the horizon, open centre space for a game logo. **960×540.**

**Suno:** [BLOCK] A proud, catchy NES title-theme march — bright square-lead melody over a marching
triangle bass and noise snare, mid-tempo ~120 BPM, anthemic and inviting, loops cleanly.

## 2 · Sprint & Hurdles — `assets/stadium/track.png` (1920×540, tileable) + `assets/music/track.ogg`

**Image:** [BLOCK] Long side-on stadium stand for a scrolling race: sky, one continuous tier of
colourful crowd, concrete stands, floodlight pylons, red-pennant rail; bottom ~150 px a flat dark
apron (the game draws the red track + lanes + sprites). **Exactly 1920×540, seamlessly tileable left↔right.**

**Suno:** [BLOCK] Fast, frantic NES chase theme — rapid arpeggiated square lead, *Korobeiniki* gallop,
busy noise-channel percussion, accelerating ~165 BPM. Breathless and competitive.

## 3 · Long Jump — `assets/stadium/long_jump.png` (1920×540, tileable) + `assets/music/long_jump.ogg`

**Image:** [BLOCK] Side-on stadium backdrop for a long-jump runway, same style/framing as the track:
sky, tiered crowd, floodlights, red-pennant rail, bottom ~150 px flat apron (game draws runway, board
and sand pit). **Exactly 1920×540, seamlessly tileable.**

**Suno:** [BLOCK] Build-and-release NES theme — staccato square ostinato that ramps then lands on a
big triangle-bass downbeat, ~135 BPM. Tension of the run-up and the leap.

## 4 · Hammer Throw — **TOP-DOWN** — `assets/stadium/hammer.png` (top-down field) + `assets/music/hammer.ogg`

The hammer throw is played **exclusively top-down** (bird's-eye), unlike the side-on races and jumps.
The image is the whole playing field seen from above; the game overlays the spin gauge, the rotating
hammer, the target-to-beat arc and the landing marker, and spins the thrower sprite in the circle. The
**static** throwing circle, safety cage, grass sector and distance-arc lines are baked into the art —
the game code is aligned to wherever they fall in the image (measure the circle position + sector
angle from the generated file, then set the constants to match). Camera starts close on the thrower
during the wind-up, then zooms out and follows the hammer flight.

**Image:** [TOP-DOWN — this overrides the "Side-on view" line in the global STYLE block]
> Top-down bird's-eye view of a hammer-throw field at a grand 1980 Soviet athletics stadium. 16-bit
> SNES-era pixel art — richly detailed, vibrant, dithered shading, saturated palette. Landscape 16:9,
> pure overhead perspective (no sky, no horizon). On the LEFT: a round pale-concrete throwing circle
> enclosed at its back by a curved dark steel safety cage (net panels) that opens toward the right.
> From the circle a ~35°-wide grass landing sector fans out to the RIGHT across the whole field, its
> two straight edges marked by crisp white boundary lines, with a few faint white distance-arc lines
> curving across it; mown grass with subtle stripes and tonal variation. Framing the field: a deep
> red-orange running track along the top and bottom edges, and beyond it tiered stands packed with a
> dense crowd, draped with long red Soviet banners and gold-trimmed flags. Warm midday light, soft
> shadows. No text, no numbers, no UI, no athletes, no hammer; keep the circle + sector readable as the
> focal point. Generate large (e.g. 1672×941); the game resizes to 960×540.

**Suno:** [BLOCK] Heavy, spinning NES waltz in a minor key that accelerates like a whirling dance —
chunky square chords, driving triangle bass, ~3/4 building to a release hit, ~130 BPM.

## 5 · Triple Jump & 400m — reuse `assets/stadium/track.png` (no separate art)

The **Triple Jump** and the **400m** both run on the same runway/track as the sprint and long jump, so
they reuse `track.png` and its music (`track.ogg` / `long_jump.ogg`) — no dedicated stadium image or
track needed. (The 100m Swim was removed; the water/pool render wasn't working out.)

## 6 · Podium ceremony — `assets/stadium/podium.png` (960×540) + `assets/music/podium.ogg`

**Image:** [BLOCK] A medal-ceremony backdrop at dusk: tiered crowd, sweeping spotlights, hanging red
banners with gold-star motifs, a glowing sky; leave the lower-centre open (game draws podium blocks +
athletes) with room for confetti. **960×540.**

**Suno:** [BLOCK] Triumphant NES victory anthem — soaring square-lead fanfare, full triangle-bass
march, celebratory noise rolls, slow-to-mid tempo ~100 BPM. Grand and emotional (a short chiptune
"anthem" that could loop).

## 7 · Event title cards & menu backgrounds — `assets/backgrounds/*.png` (960×540)

Separate from the in-game stadium backdrops above, these are **full-screen scene art** shown before
each event on the "PRESS ANY BUTTON" title card, and behind the character-select and podium screens.
Generate large (e.g. **1672×941**) and the game resizes to 960×540. One per event, keyed by event id,
plus two menu screens:

| File | Used for |
| --- | --- |
| `sprint.png` | 100m sprint title card |
| `sprint_400.png` | 400m title card |
| `hurdles.png` | 110m hurdles title card |
| `long_jump.png` | long jump title card |
| `triple_jump.png` | triple jump title card |
| `hammer.png` | hammer throw title card |
| `character_select.png` | nation-select backdrop (Moscow skyline) |
| `podium.png` | podium ceremony backdrop (Red Square, gold/silver/bronze blocks) |

**Image:** [use the global STYLE block, but these are **full standalone scenes** — action and athletes
are welcome here, unlike the empty gameplay backdrops] A dramatic 1980 Soviet-stadium scene themed to
the event (sprinters exploding from the blocks, a hurdler mid-flight, a hammer thrower mid-spin, the
Red Square medal podium with gold/silver/bronze blocks, the Moscow/Kremlin skyline for character
select), 16-bit SNES pixel art, bold red banners + gold-star motifs, packed crowd, saturated palette.
The game overlays large event-title text + a slogan, so keep the composition from being too busy dead
centre. **Generate large; resized to 960×540.**

> **Podium note:** colour-code the three podium blocks **gold (1st, centre/tallest), silver (2nd,
> left), bronze (3rd, right)** with a clear flat top surface each — the game detects those colours to
> stand the athletes on them.

---

## Integration notes

- **Two kinds of art:** (1) in-game **stadium backdrops** in `assets/stadium/` — side-on and **tileable
  1920×540** for the scrolling races/jumps, or the **top-down** field for the hammer; and (2) full-screen
  **title-card / menu backgrounds** in `assets/backgrounds/` (§7), generated large and resized to 960×540.
- **Dimensions:** single-screen art = **960×540**; side-on **scrolling** backdrops (track / long_jump)
  = **1920×540** and must **tile horizontally**. The triple jump and 400m reuse `track.png`. The game
  renders at 960×540 (×2 to 1080p). The hammer field is **top-down** (§4), not side-on/tiled.
- The **100m Swim was removed**; the current events are 100m sprint, long jump, 110m hurdles, hammer
  throw, triple jump and the 400m.
- Backgrounds = **PNG**; music = **`.ogg`** (small, loops cleanly; `.mp3`/`.wav` also work).
- Leave the bottom **~150 px** of side-on backdrops flat — the game overlays the track/pool, lanes and
  the ~96 px sprites there for gameplay clarity.
- Music with the same key plays seamlessly across screens that share it (all menu screens = `menu`).
