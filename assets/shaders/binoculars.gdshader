shader_type canvas_item;
// The two lenses of a coin-operated viewer, over whatever is drawn beneath
// (BinocularView's picture): black outside two overlapping circles, a soft
// dithered vignette inside their rims with a faint cool coating tint, a glint
// on each lens, and an optional focus blur. Worked out on the 480x270 menu
// grid, so the edges step in whole UI pixels like the rest of the art.

uniform sampler2D screen_tex : hint_screen_texture, filter_nearest;
uniform vec2 screen_px = vec2(480.0, 270.0);
uniform vec2 left_center = vec2(182.0, 116.0);
uniform vec2 right_center = vec2(298.0, 116.0);
uniform float radius = 100.0;
// 0 shut .. 1 fully open.
uniform float iris : hint_range(0.0, 1.0) = 1.0;
// 0 sharp .. 1 well out of focus.
uniform float blur : hint_range(0.0, 1.5) = 0.0;

const float BAYER[16] = float[](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);

float bayer(vec2 p) {
	ivec2 q = ivec2(mod(p, 4.0));
	return (BAYER[q.y * 4 + q.x] + 0.5) / 16.0;
}

void fragment() {
	vec2 p = floor(SCREEN_UV * screen_px) + 0.5;
	float r = max(radius * iris, 0.001);
	float dl = distance(p, left_center) / r;
	float dr = distance(p, right_center) / r;
	float d = min(dl, dr);
	if (d >= 1.0) {
		COLOR = vec4(0.0, 0.0, 0.0, 1.0);
	} else {
		vec2 uv = (p) / screen_px;
		vec3 col = texture(screen_tex, uv).rgb;
		if (blur > 0.01) {
			// A ring of taps, wider as it goes out of focus.
			vec2 step = blur * 2.5 / screen_px;
			vec3 sum = col;
			float n = 1.0;
			for (int i = 0; i < 8; i++) {
				float a = float(i) * 0.7854;
				vec2 o = vec2(cos(a), sin(a)) * step;
				sum += texture(screen_tex, uv + o).rgb;
				sum += texture(screen_tex, uv + o * 2.0).rgb;
				n += 2.0;
			}
			col = mix(col, sum / n, clamp(blur, 0.0, 1.0));
		}
		// The coated glass: cooler toward the rim.
		float rim = smoothstep(0.62, 1.0, d);
		col = mix(col, col * vec3(0.9, 0.96, 1.06), rim * 0.6);
		// Vignette in three dithered steps.
		float v = clamp((d - 0.8) / 0.2, 0.0, 1.0);
		float level = floor(v * 3.0 + bayer(p) - 0.15) / 3.0;
		col *= 1.0 - clamp(level, 0.0, 1.0) * 0.8;
		// A thin dark ring where the barrel meets the glass.
		if (d > 0.975) {
			col *= 0.35;
		}
		// The glint: a short pale arc high on each lens's left side.
		vec2 c = dl < dr ? left_center : right_center;
		vec2 rel = (p - c) / r;
		float ang = atan(rel.y, rel.x);
		float rr = length(rel);
		if (rr > 0.84 && rr < 0.885 && ang > -2.55 && ang < -1.95 && bayer(p) < 0.6) {
			col = mix(col, vec3(1.0, 0.98, 0.92), 0.28);
		}
		COLOR = vec4(col, 1.0);
	}
}
