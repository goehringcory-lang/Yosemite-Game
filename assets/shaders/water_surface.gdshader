shader_type canvas_item;
// The living surface of the painted water (scripts/world/water_surface.gd):
// the banks, trees, rocks and people beside it mirrored upside down in it,
// rippling; the sky's colour laid over open water (gold at sunset, deep blue
// after dark); and at night the stars, twinkling in the still places.
//
// It is drawn over the whole view and reads the screen. Which pixels are
// water comes from the region's painted ground (ground_tex), so a person or
// a boulder standing in the river is never mistaken for it: a pixel is only
// treated as water when the ground there is painted water and the screen
// still shows that water (nothing drawn over it). The screen holds colours
// already darkened by the day/night tint, so they are divided by [tint]
// before use, and the result is tinted again on the way out.
//
// Works in art pixels (2 world pixels), so the reflections stay crisp.

// the sun's lift on the canvas modulate (scripts/world/sun_light.gd)
global uniform vec3 sun_light;
uniform sampler2D screen : hint_screen_texture, filter_nearest;
uniform sampler2D ground_tex : filter_nearest, repeat_disable;
// The ground texture's top-left in world pixels and its size in pixels.
uniform vec2 ground_origin = vec2(0.0);
uniform vec2 ground_size = vec2(1.0);
// The view: its top-left in world pixels and its size in world pixels.
uniform vec2 view_origin = vec2(0.0);
uniform vec2 view_size = vec2(960.0, 540.0);
uniform vec3 tint : source_color = vec3(1.0);
// The sky over the water and how much of it the open water shows.
uniform vec3 sky : source_color = vec3(0.55, 0.75, 0.9);
uniform float sky_amount : hint_range(0.0, 1.0) = 0.1;
// 0 by day, 1 on a clear night (stars on the water).
uniform float stars : hint_range(0.0, 1.0) = 0.0;
// Sun on the water: 1 makes the reflections brightest and the ripples sharp;
// overcast and rain dull them.
uniform float clear : hint_range(0.0, 1.0) = 1.0;
// The sun's colour, and 0..1 how low and golden it is (more glints at dusk).
uniform vec3 sun : source_color = vec3(1.0, 0.97, 0.85);
uniform float glow : hint_range(0.0, 1.0) = 0.0;
uniform float daylight : hint_range(0.0, 1.0) = 1.0;
// How far below the bank the reflections reach, in art pixels.
uniform float reach = 30.0;
uniform float strength : hint_range(0.0, 1.0) = 0.78;
// The season's grade on the painted ground (seasonal_ground.gdshader's tint,
// tint_amount, desaturate and snow), so the bare ground on the screen can be
// told from the things standing on it.
uniform vec3 season_tint : source_color = vec3(1.0);
uniform float season_amount : hint_range(0.0, 1.0) = 0.0;
uniform float season_desaturate : hint_range(0.0, 1.0) = 0.0;
uniform float snow : hint_range(0.0, 1.0) = 0.0;
// The ground draws a running river over its painted water (its "flow").
uniform bool river_runs = false;
// On High graphics: adds shallow underwater caustics, lapping shoreline foam,
// and richer golden-hour sun-path glints.
uniform bool high_quality = false;

varying vec2 world_pos;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

// Crisp dual-wave underwater caustic web in art-pixel space.
float caustic_web(vec2 p, float t) {
	float a = sin(p.x * 0.24 + p.y * 0.18 + t * 1.35) + sin(p.x * 0.17 - p.y * 0.27 - t * 1.05);
	float b = sin(p.x * 0.31 - p.y * 0.14 + t * 0.92 + 1.7) + sin(p.x * 0.13 + p.y * 0.33 - t * 1.48);
	float ridge = 1.0 - abs(a * 0.25 + b * 0.25);
	return pow(clamp(ridge, 0.0, 1.0), 4.0);
}

// Painted water: cyan-blue, or the Merced's teal (as in seasonal_ground).
float waterness(vec3 c) {
	float w = clamp((c.b - c.g) * 10.0, 0.0, 1.0) * step(c.r, c.g);
	return max(w, clamp((c.b / max(c.g, 0.001) - 0.8) * 8.0, 0.0, 1.0) * step(c.r + 0.06, c.g) * step(c.r + 0.04, c.b));
}

vec4 ground_at(vec2 wp) {
	vec2 uv = (wp - ground_origin) / ground_size;
	if (uv.x < 0.0 || uv.y < 0.0 || uv.x > 1.0 || uv.y > 1.0) return vec4(0.0);
	return texture(ground_tex, uv);
}

bool is_water(vec2 wp) {
	vec4 g = ground_at(wp);
	return g.a > 0.5 && waterness(g.rgb) > 0.5;
}

vec3 screen_at(vec2 wp) {
	vec2 uv = (wp - view_origin) / view_size;
	return texture(screen, clamp(uv, vec2(0.001), vec2(0.999))).rgb;
}

vec3 untint(vec3 c) {
	return clamp(c / max(tint, vec3(0.04)), 0.0, 1.0);
}

// The painted ground as the season leaves it (as in seasonal_ground, without
// its frost and snow).
vec3 graded(vec3 c) {
	float lum = dot(c, vec3(0.299, 0.587, 0.114));
	float grass = clamp((c.g - max(c.r, c.b)) * 10.0, 0.0, 1.0);
	vec3 rgb = mix(c, season_tint * (0.35 + lum * 1.05), season_amount * (0.3 + 0.7 * grass));
	return mix(rgb, vec3(dot(rgb, vec3(0.299, 0.587, 0.114))), season_desaturate);
}

// How much the screen at [wp] shows something standing there (a tree, a
// boulder, a person, a cliff) and not the flat ground: 0 bare ground, 1 a
// thing. Only things are mirrored. Flat banks don't show in real water, and
// mirroring bright grass or sand washed the water pale. Off the painted
// ground (the next area, a wall hung above the map) everything counts.
float standing(vec2 wp, vec3 seen) {
	vec4 g = ground_at(wp);
	if (g.a < 0.5) return 1.0;
	float away = distance(seen, graded(g.rgb));
	if (snow > 0.0) {
		// lying snow: white, or the blue of a drift's edge
		away = min(away, min(distance(seen, vec3(0.95, 0.97, 1.0)), distance(seen, vec3(0.76, 0.83, 0.93))) + (1.0 - snow) * 0.1);
	}
	return smoothstep(0.1, 0.24, away);
}

void vertex() {
	world_pos = VERTEX;
}

void fragment() {
	// whole art pixels, sampled at their centres
	vec2 ap = floor(world_pos * 0.5);
	vec2 wp = ap * 2.0 + 1.0;
	vec4 g = ground_at(wp);
	vec3 here = untint(screen_at(wp));
	// a running river (river_flow.gdshaderinc) redraws its painted water in
	// other blues, so there any water still showing counts
	bool open = g.a > 0.5 && waterness(g.rgb) > 0.5 && (distance(here, g.rgb) < 0.2 || (river_runs && waterness(here) > 0.5));
	if (!open) {
		COLOR = vec4(0.0);
	} else {
		float t = TIME;
		vec3 c = here;
		// Long, broken wave fronts. The same moving slope bends the bank
		// reflection and catches the light along its crest.
		float bend = sin(ap.x * 0.065 + ap.y * 0.093 - t * 0.52);
		float wave = sin(ap.y * 0.74 + ap.x * 0.038 + 1.8 * bend - t * 1.8);
		float cross_wave = sin(ap.x * 0.17 - ap.y * 0.23 + t * 0.81);
		float crest = smoothstep(0.76, 0.99, wave) * smoothstep(0.32, 0.91, cross_wave);
		// how far below the bank this is: walk up the painted water
		float d = 0.0;
		bool found = false;
		for (int i = 1; i <= 40; i++) {
			if (float(i) > reach) break;
			if (!is_water(wp - vec2(0.0, float(i) * 2.0))) {
				d = float(i);
				found = true;
				break;
			}
		}
		// the open water takes the sky's colour, a little more out in the middle
		float sky_k = sky_amount * (found ? smoothstep(0.0, reach, d) : 1.0);
		c = mix(c, c * 0.55 + sky * 0.55, sky_k);
		if (found) {
			// the reflection: the bank's own pixels mirrored about the waterline,
			// pulled side to side by the ripples (more the further out)
			float sway = floor(wave * (0.6 + d * 0.06) + 0.5);
			vec2 bank = wp - vec2(0.0, d * 2.0);
			vec2 src = bank - vec2(-sway * 2.0, (d - 1.0) * 2.0);
			vec3 r = untint(screen_at(src));
			float fade = 1.0 - smoothstep(reach * 0.45, reach, d);
			float a = strength * fade * mix(0.55, 1.0, clear) * (1.0 - crest * 0.65);
			// reflections are darker than what they mirror and take the water's colour
			vec3 refl = mix(r * vec3(0.74, 0.8, 0.84), c, 0.16);
			c = mix(c, refl, a * standing(src, r));
			// a pale line of light where the water meets the bank
			if (d < 1.5) {
				c = mix(c, vec3(0.85, 0.95, 0.95), 0.25 * clear * a);
			}
		}
		// A few crests in each patch face the sun. Build up a streak of
		// colour and a short bright tip as the light travels over them.
		float patch = sin(ap.x * 0.033 + ap.y * 0.059 - t * 0.33 + bend);
		float sheen = crest * smoothstep(0.12, 0.96, patch);
		c += sun * (sheen * 0.10 + smoothstep(0.8, 0.99, sheen) * (0.15 + glow * 0.19)) * clear * daylight;
		if (high_quality) {
			// Sunlit underwater caustics dancing in the shallows near banks.
			float shallow = found ? (1.0 - smoothstep(2.0, 18.0, d)) : 0.18;
			float caust = caustic_web(ap + vec2(bend * 1.5, wave * 0.8), t);
			vec3 caust_col = mix(vec3(0.75, 0.95, 0.98), sun, 0.45 + glow * 0.4);
			c += caust_col * caust * shallow * clear * daylight * 0.24;
			// Lapping shoreline foam line modulated by the arriving wave crest.
			if (found && d < 3.0) {
				float lap = 1.0 - smoothstep(0.8, 3.0, d + wave * 0.55);
				float foam_break = smoothstep(0.15, 0.85, sin(ap.x * 0.28 + t * 0.9) * 0.5 + 0.5);
				vec3 foam_col = mix(vec3(0.86, 0.95, 0.96), sun * 1.05, glow * 0.45);
				c = mix(c, foam_col, lap * (0.22 + 0.24 * foam_break) * mix(0.4, 1.0, daylight));
			}
			// Extra golden-hour Fresnel shimmer streaks across open water.
			float open_k = found ? smoothstep(2.0, 12.0, d) : 1.0;
			float streak = smoothstep(0.82, 0.99, sin(ap.y * 0.92 + bend * 2.2 - t * 2.1)) * smoothstep(0.3, 0.95, patch);
			c += sun * streak * open_k * clear * daylight * (0.14 + glow * 0.28);
		}
		// stars on still water after dark, each twinkling on its own beat
		if (stars > 0.0) {
			vec2 cell = floor(ap / 3.0);
			float h = hash(cell + 41.0);
			if (h > 0.93 && ap == cell * 3.0 + floor(vec2(hash(cell + 3.0), hash(cell + 9.0)) * 3.0)) {
				float tw = 0.55 + 0.45 * sin(t * (1.5 + h * 3.0) + h * 40.0 + ap.x * 0.3);
				vec3 sc = h > 0.985 ? vec3(1.0, 0.86, 0.7) : vec3(0.85, 0.92, 1.0);
				// bright enough to read through the night tint
				c = mix(c, sc / max(tint, vec3(0.15)), stars * tw * 0.85);
			}
		}
		// SunLight lifts the canvas modulate by 1 + the sun (see
		// lit.gdshaderinc) to stand in for the light's add, which this
		// shader never took (its light() adds nothing): take the lift out
		COLOR = vec4(c / (1.0 + sun_light), 1.0);
	}
}


// The colours read from the screen are already lit: the lamps, the fires and
// the sun have had their say on the ground and on everything mirrored. Left
// to the default, each light in reach would be added a second time and wash
// the water pale (the day/night tint still applies).
void light() {
	LIGHT = vec4(0.0);
}
