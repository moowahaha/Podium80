shader_type canvas_item;
// Grainy CRT post-process for Podium '80: subtle screen curvature, scanlines, mild colour bleed
// (chromatic aberration), phosphor-ish bloom/persistence glow, vignette and animated film grain.
// Applied by a full-screen ColorRect on the topmost CanvasLayer, sampling the rendered frame.
// Tuned to stay READABLE — the pixel art must remain crisp, so effects are gentle by default.

uniform sampler2D screen_tex : hint_screen_texture, filter_linear, repeat_disable;

uniform float curvature : hint_range(0.0, 0.5) = 0.10;      // barrel distortion amount
uniform float scanline_strength : hint_range(0.0, 1.0) = 0.15;
uniform float scanline_count = 216.0;                        // one dark line per base pixel row
uniform float aberration : hint_range(0.0, 4.0) = 0.7;      // colour bleed in screen pixels
uniform float vignette_strength : hint_range(0.0, 2.0) = 0.55;
uniform float grain_strength : hint_range(0.0, 1.0) = 0.06;
uniform float bloom_strength : hint_range(0.0, 1.0) = 0.22; // phosphor glow / persistence feel
uniform float brightness = 1.06;

// Barrel-distort UVs around the centre to fake a curved tube.
vec2 curve_uv(vec2 uv, float amt) {
	uv = uv * 2.0 - 1.0;
	vec2 offset = abs(uv.yx) / vec2(1.0 / amt + 2.0);
	uv = uv + uv * offset * offset;
	return uv * 0.5 + 0.5;
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec2 uv = curve_uv(SCREEN_UV, curvature);

	// Outside the curved tube -> black bezel.
	if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) {
		COLOR = vec4(0.0, 0.0, 0.0, 1.0);
	} else {
		vec2 px = SCREEN_PIXEL_SIZE * aberration;
		// Colour bleed: shift R and B channels slightly apart.
		vec3 col;
		col.r = texture(screen_tex, uv + vec2(px.x, 0.0)).r;
		col.g = texture(screen_tex, uv).g;
		col.b = texture(screen_tex, uv - vec2(px.x, 0.0)).b;

		// Cheap phosphor bloom / persistence glow: average a few nearby taps and add back.
		vec3 glow = vec3(0.0);
		glow += texture(screen_tex, uv + vec2(px.x * 2.0, 0.0)).rgb;
		glow += texture(screen_tex, uv - vec2(px.x * 2.0, 0.0)).rgb;
		glow += texture(screen_tex, uv + vec2(0.0, px.y * 2.0)).rgb;
		glow += texture(screen_tex, uv - vec2(0.0, px.y * 2.0)).rgb;
		col += (glow * 0.25) * bloom_strength;

		// Scanlines.
		float sl = sin(uv.y * scanline_count * 3.14159265);
		col *= 1.0 - scanline_strength * (0.5 + 0.5 * sl) * (0.5 + 0.5 * sl);

		// Aperture-grille-ish subtle vertical mask.
		float mask = 0.90 + 0.10 * sin(uv.x * SCREEN_PIXEL_SIZE.x * 0.0);
		col *= mask;

		// Vignette.
		vec2 vd = uv - 0.5;
		float vig = 1.0 - dot(vd, vd) * vignette_strength;
		col *= clamp(vig, 0.0, 1.0);

		// Animated film grain.
		float g = hash(uv * vec2(640.0, 360.0) + fract(TIME) * 100.0);
		col += (g - 0.5) * grain_strength;

		col *= brightness;
		COLOR = vec4(clamp(col, 0.0, 1.0), 1.0);
	}
}
