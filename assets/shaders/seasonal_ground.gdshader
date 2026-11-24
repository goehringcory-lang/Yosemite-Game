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
// pixels a second) also gets a living river, drawn over its painted water by
// river_flow.gdshaderinc: depth from the banks, the cobble bed in the
// shallows, current lines drifting downstream, riffles, and wet banks.

// With a normal map (tools/normals), real lights shade the painted ground's
// relief too (see lit.gdshaderinc). Without one the normal is flat and the
// ground is lit as before.
#include "res://assets/shaders/lit.gdshaderinc"
// Gusts cross the grass: a band of blades catching the light, moving with
// the wind (scripts/world/wind.gd). gust_grass is how bright (0 none).
#include "res://assets/shaders/wind.gdshaderinc"
// A river that runs (only where flow is set): see the include.
#include "res://assets/shaders/river_flow.gdshaderinc"

uniform float gust_grass : hint_range(0.0, 1.0) = 1.0;
// where in the world this pixel of ground lies
varying vec2 world_px;

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
// Rain on the ground (Seasons.wetness, 0 dry to 1 soaked): paving, dirt and
// sand darken and deepen in colour, puddles gather in blotches on the bare
// ground (never on grass) holding a dull sky, and while it is still raining
// (rain, how hard) rings spread on the puddles and on open water. Puddles
// linger the morning after a rainy day and dry out by late morning.
uniform float wet : hint_range(0.0, 1.0) = 0.0;
uniform float rain : hint_range(0.0, 1.0) = 0.0;
uniform vec3 puddle_sky : source_color = vec3(0.6, 0.63, 0.66);
const vec3 SNOW = vec3(0.95, 0.97, 1.0);
const vec3 SNOW_SHADE = vec3(0.76, 0.83, 0.93);
// Refracted light on the painted bed (0 leaves the water still).
uniform float water_shimmer : hint_range(0.0, 1.0) = 0.0;
uniform vec2 flow = vec2(0.0);


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

void vertex() {
	world_px = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
	LIT_SUN_VERTEX
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
		// the river runs: depth, current, riffles and wet banks (river_flow.gdshaderinc)
		if (waterness(c.rgb) > 0.5) {
			c.rgb = river_water(TEXTURE, UV, TEXTURE_PIXEL_SIZE, flow, TIME);
		} else {
			c.rgb = river_bank(TEXTURE, UV, TEXTURE_PIXEL_SIZE, c.rgb, TIME);
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
	// grass takes the tint at full strength, paths and rock at a third
	float k = tint_amount * (0.3 + 0.7 * grass) * (1.0 - water);
	rgb = mix(rgb, tint * (0.35 + lum * 1.05), k);
	rgb = mix(rgb, vec3(dot(rgb, vec3(0.299, 0.587, 0.114))), desaturate * (1.0 - water * 0.7));
	if (gust_grass > 0.0 && wind_strength > 0.0 && grass > 0.5) {
		// in whole art pixels of the world, so the band is the same one on
		// both sides of a seam; the blades that turn are short streaks lying
		// along the wind, more of them the harder it blows
		vec2 wp = floor(world_px * 0.5);
		float gust = wind_gust(wp * 2.0, TIME) * min(wind_strength, 1.5);
		float blade = hash(vec2(floor((wp.x + mod(wp.y, 2.0)) / 3.0), wp.y));
		float turned = step(1.0 - gust * 0.38, blade);
		rgb = mix(rgb, rgb * vec3(1.22, 1.18, 1.0) + vec3(0.02, 0.03, 0.0), turned * gust_grass);
		rgb *= 1.0 + 0.06 * gust * gust_grass;
	}
	vec2 px = vec2(0.0);
	bool has_px = frost > 0.0 || snow > 0.0 || flower_fill.a > 0.0;
	if (has_px) {
		// the art is drawn at 2x, so work in 2x2 blocks of texture pixels
		px = floor(floor(UV / TEXTURE_PIXEL_SIZE) * 0.5);
	}
	if (frost > 0.0) {
		// frost: small clumps of whitened pixels, mostly on grass, hardly on paving
		float n = hash(floor(px / 3.0)) * 0.65 + hash(px) * 0.35;
		float cover = frost * (0.08 + 0.92 * grass) * (1.0 - water);
		float f = step(1.0 - cover, n);
		rgb = mix(rgb, frost_color * (0.85 + lum * 0.25), f * 0.6);
	}
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
	if (wet > 0.0 && snow < 0.05) {
		float bare = (1.0 - grass) * (1.0 - water);
		// soaked ground: darker and a little richer (grass hardly)
		float soak = wet * (0.35 + 0.65 * bare);
		float l2 = dot(rgb, vec3(0.299, 0.587, 0.114));
		rgb = mix(vec3(l2), rgb, 1.0 + 0.25 * soak) * (1.0 - 0.2 * soak);
		// puddles: rounded pools in whole art pixels of the world (so they
		// line up across a seam), on bare, not-too-vivid ground, more of them
		// the wetter it is; a darker rim of mud round each, and the top row
		// of a pool catches the sky (that bright edge is what reads as water)
		vec2 wpx = floor(world_px * 0.5);
		float pd = vnoise(wpx * vec2(1.0, 1.5) / 12.0) * 0.97 + vnoise(wpx / 4.0) * 0.03;
		float level = 0.88 - 0.1 * wet;
		bool can_pool = grass < 0.3 && water < 0.3 && sat < 0.5;
		if (can_pool && pd > level) {
			float pd_up = vnoise((wpx - vec2(0.0, 1.0)) * vec2(1.0, 1.5) / 12.0) * 0.97 + vnoise((wpx - vec2(0.0, 1.0)) / 4.0) * 0.03;
			vec3 deepened = rgb * 0.7;
			vec3 pool = mix(deepened, puddle_sky * 0.8, 0.28);
			if (pd_up <= level) pool = mix(pool, puddle_sky, 0.6);
			rgb = pool;
			// rain rings: in each 8 art pixel cell now and then a drop lands and
			// a one-pixel ring spreads out from it
			if (rain > 0.0) {
				vec2 cell = floor(wpx / 8.0);
				float ph = hash(cell + 3.1);
				float cycle = floor(TIME * 1.6 + ph);
				float t = fract(TIME * 1.6 + ph);
				vec2 drop = cell * 8.0 + 3.0 + floor(vec2(hash(cell + cycle), hash(cell + cycle + 9.0)) * 2.0);
				float d = length(wpx - drop);
				if (hash(cell + cycle * 1.37) < 0.35 + 0.5 * rain && abs(d - t * 2.5) < 0.55 && t < 0.85) {
					rgb = mix(rgb, puddle_sky * 1.15, 0.6 * (1.0 - t));
				}
			}
		} else if (can_pool && pd > level - 0.025) {
			// a dark wet rim of mud round each puddle
			rgb *= 0.85;
		}
		if (rain > 0.0 && water > 0.5) {
			vec2 wpx = floor(world_px * 0.5);
			vec2 cell = floor(wpx / 8.0);
			float ph = hash(cell + 5.7);
			float cycle = floor(TIME * 1.3 + ph);
			float t = fract(TIME * 1.3 + ph);
			vec2 drop = cell * 8.0 + 3.0 + floor(vec2(hash(cell + cycle), hash(cell + cycle + 4.0)) * 2.0);
			float r = t * 2.5;
			float d = length(wpx - drop);
			if (hash(cell + cycle * 1.71) < 0.25 + 0.45 * rain && abs(d - r) < 0.55 && t < 0.85) {
				rgb += vec3(0.09, 0.11, 0.12) * (1.0 - t);
			}
		}
	}
	if (water_shimmer > 0.0 && water > 0.5 && sun_light.r > 0.0) {
		// Crossing ripples focus the light into thin, wandering lines on
		// the pale stones. In the dark channel only surface reflections show.
		vec2 ap = floor(world_px * 0.5);
		float swell = sin(ap.x * 0.057 + ap.y * 0.073 + TIME * 0.48);
		float a = sin(ap.x * 0.17 + ap.y * 0.12 + swell * 2.3 - TIME * 0.85);
		float b = sin(ap.y * 0.32 - ap.x * 0.09 + swell * 1.7 + TIME * 0.63);
		float caustic = 1.0 - smoothstep(0.055, 0.23, abs(a + b * 0.76));
		float bed = smoothstep(0.27, 0.62, lum);
		rgb += sun_light * vec3(0.19, 0.21, 0.16) * caustic * bed * water_shimmer;
	}
	if (flower_fill.a > 0.0) {
		float hue = hue_of(c.rgb);
		// vivid, and neither green nor the browns of paths and bark: a wildflower dot
		float flower = step(0.4, sat) * step(0.035, abs(hue - 0.09)) * step(0.5, 1.0 - grass) * (1.0 - water);
		if (flower > 0.5) {
			rgb = flower_fill.rgb * (0.9 + 0.2 * hash(px));
		}
	}
	lit_sun_gain = lit_sun(NORMAL_MAP);
	COLOR = vec4(rgb * lit_sun_gain, c.a);
}


void light() {
	LIGHT = lit_light(NORMAL, LIGHT_DIRECTION, LIGHT_IS_DIRECTIONAL, LIGHT_COLOR, LIGHT_ENERGY, vec4(COLOR.rgb / lit_sun_gain, COLOR.a));
}
