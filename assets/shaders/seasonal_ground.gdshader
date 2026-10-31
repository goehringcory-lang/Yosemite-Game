shader_type canvas_item;
// Seasonal grade for a region's painted ground (see scripts/world/seasonal_dressing.gd).
// Works per texture pixel, so the art stays crisp: grass is pulled toward the
// tint (gold in fall, cool blue-grey in winter), everything else is nudged,
// water is left alone, frost whitens scattered pixels, and lying snow
// (0 bare to 1 white, from Seasons.snow_cover) covers the ground in drifts
// that grow together as it deepens, leaving the ploughed asphalt and the
// open water dark.
//
// A region whose river should run (Region metadata "water_flow", in texture
// pixels a second) also gets moving water: current lines drift downstream
// over its deep water (the palette's two deep river blues, which
// tools/hubs/tuolumne_ground.gd paints there, replacing the still lines it
// painted, a pale blue one art pixel tall) and its sun glints twinkle.

// With a normal map (tools/normals), real lights shade the painted ground's
// relief too (see lit.gdshaderinc). Without one the normal is flat and the
// ground is lit as before.
#include "res://assets/shaders/lit.gdshaderinc"

uniform vec3 tint : source_color = vec3(1.0);
uniform float tint_amount : hint_range(0.0, 1.0) = 0.0;
uniform float desaturate : hint_range(0.0, 1.0) = 0.0;
uniform float frost : hint_range(0.0, 1.0) = 0.0;
// the painted wildflower dots are painted over with this colour (alpha 0 keeps them)
uniform vec4 flower_fill : source_color = vec4(0.0);
uniform vec3 frost_color : source_color = vec3(0.9, 0.94, 0.97);
uniform float snow : hint_range(0.0, 1.0) = 0.0;
// Water that dries up as the snowmelt runs out (see seasonal_falls.gd): in
// dry_rect (texture pixels), dry_amount of the painted water gives way to a
// bed of pale cobbles (dry_kind 0, a creek) or to sand and sedge meadow
// (dry_kind 1, Mirror Lake in late summer), leaving pools in the deepest spots.
uniform vec4 dry_rect = vec4(0.0);
uniform float dry_amount : hint_range(0.0, 1.0) = 0.0;
uniform int dry_kind = 0;
// A seam with the next area (see scripts/world/seam.gd): the two maps overlap
// in a band along the edge, and there each pixel of ground belongs to one map
// or the other, by a blotchy dither that gives this map less of the band the
// nearer its own edge, so the two grounds blend instead of meeting on a line.
// seam_band: x the coordinate across the edge (texture pixels) of this map's
// own edge, y of the band's inner side; seam_axis 0 for an east or west edge
// (x across), 1 for north or south. seam_span: where along the edge the other
// map has ground. seam_origin: one spot both maps agree on, so their dithers
// line up; seam_flip: one map takes the dither as it is, the other inverted.
uniform bool seam_on = false;
uniform vec2 seam_band = vec2(0.0);
uniform int seam_axis = 0;
uniform vec2 seam_span = vec2(0.0);
uniform vec2 seam_origin = vec2(0.0);
uniform bool seam_flip = false;
const vec3 SNOW = vec3(0.95, 0.97, 1.0);
const vec3 SNOW_SHADE = vec3(0.76, 0.83, 0.93);
// Moving light on the painted water: bands of brighter ripples drifting with
// the current and glints that wink on and off (0 leaves the water still).
uniform float water_shimmer : hint_range(0.0, 1.0) = 0.0;
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

// smooth value noise, for drifts with soft edges
float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
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

float waterness(vec3 c) {
	float w = clamp((c.b - c.g) * 10.0, 0.0, 1.0) * step(c.r, c.g);
	return max(w, clamp((c.b / max(c.g, 0.001) - 0.8) * 8.0, 0.0, 1.0) * step(c.r + 0.06, c.g) * step(c.r + 0.04, c.b));
}

// Does this map keep this pixel of a seam's band (see the uniforms)?
bool seam_keeps(vec2 tpx) {
	float across = seam_axis == 0 ? tpx.x : tpx.y;
	float along = seam_axis == 0 ? tpx.y : tpx.x;
	if (along < seam_span.x || along >= seam_span.y) return true;
	float f = (across - seam_band.x) / (seam_band.y - seam_band.x);
	if (f >= 1.0) return true;
	if (f < 0.0) return false;
	vec2 ap = floor((tpx - seam_origin) * 0.5);
	float t = clamp(vnoise(ap / 5.0) * 0.65 + hash(ap) * 0.35, 0.0, 0.999);
	return (seam_flip ? 1.0 - t : t) < f;
}

void fragment() {
	if (seam_on && !seam_keeps(UV / TEXTURE_PIXEL_SIZE)) {
		discard;
	}
	NORMAL_MAP = texture(normal_map, UV).rgb;
	vec4 c = texture(TEXTURE, UV);
	if (dry_amount > 0.0) {
		vec2 tpx = UV / TEXTURE_PIXEL_SIZE;
		if (tpx.x >= dry_rect.x && tpx.y >= dry_rect.y && tpx.x < dry_rect.x + dry_rect.z && tpx.y < dry_rect.y + dry_rect.w && waterness(c.rgb) > 0.5) {
			// how far this is from the shore: the share of water around it at
			// three distances (shallows dry first, the deepest middle last)
			float depth = 0.0;
			for (int r = 0; r < 3; r++) {
				float reach = 12.0 * pow(2.6, float(r));
				for (int i = 0; i < 8; i++) {
					float a = float(i) * 0.785398 + float(r) * 0.4;
					vec2 at = UV + vec2(cos(a), sin(a)) * reach * TEXTURE_PIXEL_SIZE;
					depth += waterness(texture(TEXTURE, at).rgb) > 0.5 ? 1.0 / 24.0 : 0.0;
				}
			}
			vec2 ap = floor(tpx * 0.5);
			float wobble = vnoise(ap / 6.0) * 0.16 - 0.08;
			// open water all round reads about 1, the shallows by the shore about
			// a half; and the drying fades out toward the area's edges, so a
			// creek running in narrows instead of stopping at a line
			float inner = clamp((depth - 0.45) / 0.55, 0.0, 1.0);
			vec2 to_edge = min(tpx - dry_rect.xy, dry_rect.xy + dry_rect.zw - tpx);
			float fade = clamp(min(to_edge.x, to_edge.y) / 64.0, 0.0, 1.0);
			float exposed = dry_amount * fade * 1.1 - (inner + wobble);
			if (exposed > 0.0) {
				float h = hash(floor(ap / 2.0));
				if (dry_kind == 0) {
					c.rgb = h < 0.4 ? vec3(0.63, 0.61, 0.56) : (h < 0.75 ? vec3(0.52, 0.5, 0.47) : vec3(0.74, 0.72, 0.66));
				} else if (exposed < 0.14) {
					// a band of damp sand and mud along the shrinking pool
					c.rgb = exposed < 0.05 ? vec3(0.55, 0.49, 0.37) : (h < 0.6 ? vec3(0.76, 0.69, 0.52) : vec3(0.69, 0.62, 0.46));
				} else {
					// sedge meadow, with the odd patch of sand
					c.rgb = vnoise(ap / 5.0) > 0.78 ? vec3(0.72, 0.65, 0.49) : (h < 0.5 ? vec3(0.42, 0.55, 0.27) : vec3(0.36, 0.49, 0.23));
				}
			}
		}
	}
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
	if (snow > 0.0) {
		// drifts lie deepest on grass; asphalt (dark and grey) is ploughed, and
		// so are the lines painted on it (asphalt an art pixel either side)
		float asphalt = step(lum, 0.32) * step(sat, 0.18);
		if (asphalt < 0.5) {
			vec2 tp = TEXTURE_PIXEL_SIZE * 4.0;
			vec3 a = texture(TEXTURE, UV - vec2(0.0, tp.y)).rgb;
			vec3 b = texture(TEXTURE, UV + vec2(0.0, tp.y)).rgb;
			asphalt = step(dot(a, vec3(0.299, 0.587, 0.114)), 0.3) * step(dot(b, vec3(0.299, 0.587, 0.114)), 0.3) * step(distance(a, b), 0.08);
		}
		float lie = snow * mix(0.8, 1.0, grass) * (1.0 - water) * (1.0 - 0.85 * asphalt);
		float d = vnoise(px / 14.0) * 0.62 + vnoise(px / 4.0) * 0.28 + hash(px) * 0.1;
		// about a fifth of the ground at 0.2, half at 0.5, nearly all at 1
		float edge = d - (0.78 - 0.62 * lie);
		if (lie > 0.0 && edge > 0.0) {
			// a blue shadow along each drift's edge, softer hollows in deep
			// snow, and the odd glint
			vec3 s = edge < 0.05 ? SNOW_SHADE : mix(SNOW, SNOW_SHADE, floor(clamp(0.62 - d, 0.0, 0.6) * 5.0) / 3.0 * 0.45);
			if (hash(px + 17.0) > 0.992) s = vec3(1.0);
			rgb = s * (0.92 + lum * 0.1);
		}
	}
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


void light() {
	LIGHT = lit_light(NORMAL, LIGHT_DIRECTION, LIGHT_IS_DIRECTIONAL, LIGHT_COLOR, LIGHT_ENERGY, COLOR);
}
