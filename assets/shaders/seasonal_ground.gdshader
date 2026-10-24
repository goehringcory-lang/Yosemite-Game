shader_type canvas_item;
// Seasonal grade for a region's painted ground (see scripts/world/seasonal_dressing.gd).
// Works per texture pixel, so the art stays crisp: grass is pulled toward the
// tint (gold in fall, cool blue-grey in winter), everything else is nudged,
// water is left alone, and frost whitens scattered pixels.

uniform vec3 tint : source_color = vec3(1.0);
uniform float tint_amount : hint_range(0.0, 1.0) = 0.0;
uniform float desaturate : hint_range(0.0, 1.0) = 0.0;
uniform float frost : hint_range(0.0, 1.0) = 0.0;
// the painted wildflower dots are painted over with this colour (alpha 0 keeps them)
uniform vec4 flower_fill : source_color = vec4(0.0);
uniform vec3 frost_color : source_color = vec3(0.9, 0.94, 0.97);
// Moving light on the painted water: bands of brighter ripples drifting with
// the current and glints that wink on and off (0 leaves the water still).
uniform float water_shimmer : hint_range(0.0, 1.0) = 0.0;

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

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float lum = dot(c.rgb, vec3(0.299, 0.587, 0.114));
	float grass = clamp((c.g - max(c.r, c.b)) * 10.0, 0.0, 1.0);
	float water = clamp((c.b - c.g) * 10.0, 0.0, 1.0) * step(c.r, c.g); // cyan-blue only, not purple or pink
	// the Merced's teal: blue nearly as strong as green, both well above red
	water = max(water, clamp((c.b / max(c.g, 0.001) - 0.8) * 8.0, 0.0, 1.0) * step(c.r + 0.06, c.g) * step(c.r + 0.04, c.b));
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
	if (water_shimmer > 0.0 && water > 0.5) {
		float t = TIME;
		float band = sin(px.x * 0.19 - t * 1.4 + sin(px.y * 0.31 + t * 0.5) * 2.2) * sin(px.y * 0.47 + t * 0.8 + px.x * 0.05);
		float lit = step(0.8, band) * (0.5 + 0.5 * step(0.5, hash(px + floor(t * 3.0))));
		float dark = step(band, -0.88);
		float glint = step(0.996, hash(px + vec2(floor(t * 2.5), 0.0))) * step(0.38, lum);
		rgb += (vec3(0.07, 0.09, 0.08) * lit - vec3(0.025) * dark + vec3(0.35) * glint) * water_shimmer;
	}
	if (flower > 0.5 && flower_fill.a > 0.0) {
		rgb = flower_fill.rgb * (0.9 + 0.2 * hash(px));
	}
	COLOR = vec4(rgb, c.a);
}
