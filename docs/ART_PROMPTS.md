# Podium '80 — Art Generation Prompts (SNES style)

Ready-to-paste prompts for generating the **background / stadium art** that is better produced as
images than programmed. The game already draws athletes, UI, flags, crowds and effects procedurally;
these prompts cover the large painted backdrops.

Drop finished images into the game at the paths listed — **no code changes needed**; each screen/event
auto-detects its image and falls back to procedural art if absent.

---

## Global style (paste at the top of every prompt)

> 16-bit **SNES-era pixel art**, early-1990s console sports game look (think *Super Track & Field* /
> *World Class Athletics*). Rich but limited palette (~64–128 colours), crisp dithering, chunky
> readable pixels, strong warm 1980s stadium mood, bright blue sky, colourful crowds. Clean flat
> shading with subtle gradients, no photorealism, no modern lighting, no gradients-that-look-3D.
> **No text, no logos, no numbers, no watermark.** **Do NOT include the Olympic rings, the word
> "Olympic", torches shaped like the official one, or any real mascot** — this is a *fictional*
> international games. Eastern-bloc 1980 atmosphere is welcome (concrete stands, red running track,
> tall floodlight pylons, rows of plain coloured pennants/flags) but keep all emblems generic and
> invented.

Output requirements: exact pixel dimensions given per asset, **16:9**, no border, fill the frame.

---

## 1. Title / menu background  →  `assets/menu/background.png`  (384×216)

*(One is already supplied. Use this to regenerate or make variants.)*

> [GLOBAL STYLE] A wide establishing shot inside a packed 1980s athletics stadium at midday. Bright
> blue sky with a few fluffy clouds, two tall floodlight pylons left and right, tiers of colourful
> crowd, rows of small plain pennants around the stand rail, a red running track across the lower
> third, a stylised city skyline silhouette on the horizon. Empty centre space suitable for a game
> logo. 384×216, 16:9, SNES pixel art.

## 2. Sprint & Hurdles stadium backdrop  →  `assets/stadium/track.png`  (768×216, tileable left↔right)

> [GLOBAL STYLE] A **side-on** view of an athletics stadium stand for a horizontally-scrolling race.
> Upper two-thirds only: bright sky, a long continuous tier of colourful seated crowd, a concrete
> stand structure, floodlight pylons at intervals, a rail of small coloured pennants. The bottom
> ~30% must be a **flat empty band** (the game draws the red track and lanes there) — leave it a
> simple dark apron colour. Must **tile seamlessly on the left and right edges** so it can repeat
> across a long track. 768×216, SNES pixel art, no track markings, no runners.

## 3. Long Jump venue  →  `assets/stadium/long_jump.png`  (768×216, tileable)

> [GLOBAL STYLE] Side-on stadium stand backdrop for a long-jump runway, same style and framing as a
> scrolling track backdrop: sky, tiered colourful crowd, floodlights, pennant rail. Bottom ~30% a
> flat empty apron band (the game draws the runway, take-off board and sand pit). Seamlessly tileable
> horizontally. 768×216, SNES pixel art, no foreground objects.

## 4. Hammer Throw infield  →  `assets/stadium/hammer.png`  (384×216)

> [GLOBAL STYLE] A single-screen view looking across a grass infield throwing sector inside a 1980s
> stadium. Green field with faint marked sector lines fanning outward, a safety cage frame suggestion
> at the left, tiered colourful crowd and floodlights behind, blue sky. Composition centred/left so a
> thrower and a wide throwing sector fit. 384×216, SNES pixel art, no athlete, no text.

## 5. Vault arena  →  `assets/stadium/vault.png`  (384×216)

> [GLOBAL STYLE] An indoor-ish gymnastics/vault arena at night inside the games complex: a spotlit
> vault runway and horse/table apparatus area, darker moody stands with a colourful seated crowd lit
> by spotlights, banners hanging. Cool blues and purples with warm spotlight pools — a dramatic
> rhythm-game stage. 384×216, SNES pixel art, no athlete, no text, no UI.

## 6. Podium ceremony backdrop  →  `assets/stadium/podium.png`  (384×216)

> [GLOBAL STYLE] A medal-ceremony stage at dusk: three empty podium blocks are NOT included (the game
> draws them); instead a grand backdrop of tiered crowd, sweeping spotlights, hanging plain coloured
> banners and a glowing sky. Celebratory, warm, confetti-friendly negative space in the centre.
> 384×216, SNES pixel art, no podium, no athletes, no text.

## 7. (Optional) Crowd tile  →  `assets/stadium/crowd_tile.png`  (64×48, tileable all edges)

> [GLOBAL STYLE] A small seamlessly-tiling texture of a packed stadium crowd seen from a distance:
> tiny colourful seated spectators in rows on concrete tiers. Tiles seamlessly on all four edges.
> 64×48, SNES pixel art, no faces detail, no text.

---

## Integration notes

- **Dimensions matter for TV/Pi:** the game renders into a **384×216** base canvas upscaled ×5 to
  1080p, so single-screen art should be **384×216** and scrolling backdrops **768×216** (2 screens
  wide, tileable). Anything larger is wasted memory on the console — downscale before importing.
- Save as **PNG**; keep files small (a few dozen KB each at these sizes).
- Scrolling backdrops (track / long jump) **must tile horizontally** — the stadium repeats them
  across the world width.
- Leave the **bottom ~30% empty** on side-scrolling track/runway art; the game overlays the red track
  and lane lines there for gameplay clarity.
- After adding a file at its path above, just run the game — the matching screen/event picks it up
  automatically (procedural art is the fallback).
