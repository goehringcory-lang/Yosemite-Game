shader_type canvas_item;
// Seasonal grade for a region's painted ground (see scripts/world/seasonal_dressing.gd).
// Works per texture pixel, so the art stays crisp: grass is pulled toward the
// tint (gold in fall, cool blue-grey in winter), everything else is nudged,
// water is left alone, and frost whitens scattered pixels.
//
// A region whose river should run (Region metadata "water_flow", in texture
// pixels a second) also gets moving water: current lines drift downstream
// over its deep water (the palette's two deep river blues, which
// tools/hubs/tuolumne_ground.gd paints there, replacing the still lines it
// painted, a pale blue one art pixel tall) and its sun glints twinkle.

uniform vec3 tint : source_color = vec3(1.0);
uniform float tint_amount : hint_range(0.0, 1.0) = 0.0;
uniform float desaturate : hint_range(0.0, 1.0) = 0.0;
uniform float frost : hint_range(0.0, 1.0) = 0.0;
// the painted wildflower dots are painted over with this colour (alpha 0 keeps them)
uniform vec4 flower_fill : source_color = vec4(0.0);
uniform vec3 frost_color : source_color = vec3(0.9, 0.94, 0.97);
uniform vec2 flow = vec2(0.0);

const vec3 DEEP_A = vec3(0.137, 0.337, 0.475);   // 235679
const vec3 DEEP_B = vec3(0.078, 0.184, 0.278);   // 142f47
const vec3 LINE_A = vec3(0.388, 0.702, 0.776);   // 63b3c6
const vec3 LINE_B = vec3(0.624, 0.847, 0.851);   // 9fd8d9
const vec3 GLINT = vec3(0.839, 0.945, 0.933);    // d6f1ee

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

float hue_of(vec3 c) {
	float mx = max(c.r, max(c.g, c.b));
	float d = mx - min(c.r, min(c.g, c.b));
	if (d < 0.0001) return 0.0;
	float h = mx == c.r ? mod((c.g - c.b) / d, 6.0) : (mx == c.g ? (c.b - c.r) / d + 2.0 : (c.r - c.g) / d + 4.0);
	return fract(h / 6.0);
}

bool near(vec3 a, vec3 b) {
	return distance(a, b) < 0.03;
}

bool deep(vec3 c) {
	return near(c, DEEP_A) || near(c, DEEP_B);
}

// A current line painted on deep water: a pale pixel with deep water an art
// pixel above and below.
bool current_line(sampler2D tex, vec2 uv, vec2 tp) {
	vec3 c = texture(tex, uv).rgb;
	if (!(near(c, LINE_A) || near(c, LINE_B))) return false;
	return deep(texture(tex, uv - vec2(0.0, 2.0 * tp.y)).rgb) && deep(texture(tex, uv + vec2(0.0, 2.0 * tp.y)).rgb);
}

bool open_water(sampler2D tex, vec2 uv, vec2 tp) {
	vec3 c = texture(tex, uv).rgb;
	return deep(c) || current_line(tex, uv, tp);
}

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	if (flow != vec2(0.0)) {
		vec2 tp = TEXTURE_PIXEL_SIZE;
		bool here_line = current_line(TEXTURE, UV, tp);
		if (deep(c.rgb) || here_line) {
			// the painted lines give way to lines drawn here that drift with the
			// current: one art pixel tall, every third row, in whole art pixels
			// (2 texture pixels) so they stay crisp, only where open water lies
			// above and below
			vec3 base = here_line ? DEEP_A : c.rgb;
			c.rgb = base;
			vec2 ap = floor(UV / tp * 0.5);
			if (mod(ap.y, 3.0) == 0.0 && open_water(TEXTURE, UV - vec2(0.0, 2.0 * tp.y), tp) && open_water(TEXTURE, UV + vec2(0.0, 2.0 * tp.y), tp)) {
				float xs = ap.x + floor(hash(vec2(0.0, ap.y)) * 40.0) - floor(TIME * flow.x * 0.5);
				float cell = floor(xs / 23.0);
				float lx = xs - cell * 23.0;
				float hc = hash(vec2(cell, ap.y));
				if (hc < 0.22 && lx < 6.0 + floor(hash(vec2(cell + 7.0, ap.y)) * 10.0)) {
					c.rgb = LINE_A;
				}
			}
		} else if (near(c.rgb, GLINT)) {
			vec2 cell = floor(UV / tp / 8.0);
			if (hash(cell + floor(TIME * 1.7 + hash(cell) * 4.0)) < 0.45) {
				c.rgb = texture(TEXTURE, UV + vec2(0.0, 4.0 * tp.y)).rgb;
			}
		}
	}
	float lum = dot(c.rgb, vec3(0.299, 0.587, 0.114));
	float grass = clamp((c.g - max(c.r, c.b)) * 10.0, 0.0, 1.0);
	float water = clamp((c.b - c.g) * 10.0, 0.0, 1.0) * step(c.r, c.g); // cyan-blue only, not purple or pink
	vec3 rgb = c.rgb;
	float mx = max(c.r, max(c.g, c.b));
	float sat = (mx - min(c.r, min(c.g, c.b))) / max(mx, 0.001);
	float hue = hue_of(c.rgb);
	// vivid, and neither green nor the browns of paths and bark: a wildflower dot
	float flower = step(0.4, sat) * step(0.035, abs(hue - 0.09)) * step(0.5, 1.0 - grass) * (1.0 - water);
	// grass takes the tint at full strength, paths and rock at a third
	float k = tint_amount * (0.3 + 0.7 * grass) * (1.0 - water);
	rgb = mix(rgb, tint * (0.35 + lum * 1.05), k);
	rgb = mix(rgb, vec3(dot(rgb, vec3(0.299, 0.587, 0.114))), desaturate * (1.0 - water * 0.7));
	// frost: small clumps of whitened pixels, mostly on grass, hardly on paving
	// the art is drawn at 2x, so work in 2x2 blocks of texture pixels
	vec2 px = floor(floor(UV / TEXTURE_PIXEL_SIZE) * 0.5);
	float n = hash(floor(px / 3.0)) * 0.65 + hash(px) * 0.35;
	float cover = frost * (0.08 + 0.92 * grass) * (1.0 - water);
	float f = step(1.0 - cover, n);
	rgb = mix(rgb, frost_color * (0.85 + lum * 0.25), f * 0.6);
	if (flower > 0.5 && flower_fill.a > 0.0) {
		rgb = flower_fill.rgb * (0.9 + 0.2 * hash(px));
	}
	COLOR = vec4(rgb, c.a);
}
