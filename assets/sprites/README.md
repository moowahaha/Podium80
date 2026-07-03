# assets/sprites — athlete sprites (48×72)

Drop athlete sprite sheets here (48×72 px per frame). Currently athletes are drawn procedurally
(`src/common/Athlete.gd`); when real sprites arrive they replace that draw with an `AnimatedSprite2D`
behind the same public API (set_country / state / facing), so gameplay code is untouched.

Suggested per-nation, per-state frames (origin at the feet, figure ~72 px tall):
`idle, ready, run (cycle), jump, land, throw, fall, stumble, celebrate`.

Kit colours per nation come from `CountryData` (USSR red · GDR gold · GBR white · AUS green/gold), so
sprites can be a single neutral/white kit tinted at runtime, or one sheet per nation — either works.
