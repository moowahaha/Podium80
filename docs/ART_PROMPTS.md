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

## 4 · Hammer Throw — `assets/stadium/hammer.png` (960×540) + `assets/music/hammer.ogg`

**Image:** [BLOCK] Single-screen view across a grass infield throwing sector: green field lower half
with faint sector lines fanning right, a suggested safety-cage frame at left, tiered crowd +
floodlights + blue sky behind, red banners. Keep centre-left clear for a large thrower. **960×540.**

**Suno:** [BLOCK] Heavy, spinning NES waltz in a minor key that accelerates like a whirling dance —
chunky square chords, driving triangle bass, ~3/4 building to a release hit, ~130 BPM.

## 5 · 100m Swim — `assets/stadium/swim.png` (1250×540, a WHOLE pool — not tileable) + `assets/music/swim.ogg`

**Image:** [BLOCK] **Flat 16-bit SNES pixel-art** (NOT photoreal, NOT 3D — see STYLE block) **side-on**
aquatics-hall backdrop showing **one complete 50 m competition pool end to end** — the swim is a fixed
there-and-back (dive off the near wall, flip-turn at the far wall, finish back at the near wall), so the
pool has TWO fixed ends and must **NOT** tile. Compose the whole pool in one frame: at the **far-left
~10 %** the **start / finish end** — raised starting blocks / diving platforms on the pool deck above
the near wall; at the **far-right ~10 %** the **turn end** — the far pool wall with a row of
**backstroke flags strung across** above it. Between them the empty lane water, and behind: bright hall,
tiered colourful crowd, floodlights, red banners. **Leave the water EMPTY — NO swimmers, NO people in
the pool; the game draws all the swimmers itself.** Bottom ~150 px a flat blue band (the game overlays
lane ropes, the two end walls and the swimmer sprites) — keep the deck / starting blocks just **above**
that band at the left, and the turn wall at the right, so the code-drawn walls line up with the art.
**Exactly 1250×540 (≈2.3∶1), a single fixed composition — do not make it seamless/tileable.**

**Suno:** [BLOCK] Flowing but propulsive NES loop with a buoyant, splashy feel — bubbly arpeggiated
square lead over a steady march bass, bright and energetic, ~150 BPM.

## 6 · Podium ceremony — `assets/stadium/podium.png` (960×540) + `assets/music/podium.ogg`

**Image:** [BLOCK] A medal-ceremony backdrop at dusk: tiered crowd, sweeping spotlights, hanging red
banners with gold-star motifs, a glowing sky; leave the lower-centre open (game draws podium blocks +
athletes) with room for confetti. **960×540.**

**Suno:** [BLOCK] Triumphant NES victory anthem — soaring square-lead fanfare, full triangle-bass
march, celebratory noise rolls, slow-to-mid tempo ~100 BPM. Grand and emotional (a short chiptune
"anthem" that could loop).

---

## Integration notes

- **Dimensions:** single-screen art = **960×540**; side-on **scrolling** backdrops (track / long_jump)
  = **1920×540** and must **tile horizontally**. The **swim** pool is the exception: **1250×540, a whole
  fixed pool, NOT tileable** — the race is a fixed-length there-and-back, so the pool has real start and
  turn ends that must not repeat. The game renders at 960×540 (×2 to 1080p), so don't exceed these —
  larger is wasted on the console.
- Backgrounds = **PNG**; music = **`.ogg`** (small, loops cleanly; `.mp3`/`.wav` also work).
- Leave the bottom **~150 px** of side-on backdrops flat — the game overlays the track/pool, lanes and
  the ~96 px sprites there for gameplay clarity.
- Music with the same key plays seamlessly across screens that share it (all menu screens = `menu`).
