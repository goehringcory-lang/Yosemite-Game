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
// How far below the bank the reflections reach, in art pixels.
uniform float reach = 30.0;
uniform float strength : hint_range(0.0, 1.0) = 0.78;

varying vec2 world_pos;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
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

void vertex() {
	world_pos = VERTEX;
}

void fragment() {
	// whole art pixels, sampled at their centres
	vec2 ap = floor(world_pos * 0.5);
	vec2 wp = ap * 2.0 + 1.0;
	vec4 g = ground_at(wp);
	vec3 here = untint(screen_at(wp));
	bool open = g.a > 0.5 && waterness(g.rgb) > 0.5 && distance(here, g.rgb) < 0.2;
	if (!open) {
		COLOR = vec4(0.0);
	} else {
		float t = TIME;
		vec3 c = here;
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
			float wob = sin(ap.y * 0.9 - t * 2.6 + sin(ap.x * 0.13 + t * 0.7) * 1.4);
			float sway = floor(wob * (0.6 + d * 0.06) + 0.5);
			vec2 bank = wp - vec2(0.0, d * 2.0);
			vec2 src = bank - vec2(-sway * 2.0, (d - 1.0) * 2.0);
			vec3 r = untint(screen_at(src));
			// broken into rows by the ripples: every few rows a row goes missing
			float row = hash(vec2(floor(ap.y), floor(t * 3.0 + ap.y * 0.37)));
			float fade = 1.0 - smoothstep(reach * 0.45, reach, d);
			float a = strength * fade * mix(0.55, 1.0, clear) * (row < 0.12 + d / reach * 0.25 ? 0.35 : 1.0);
			// reflections are darker than what they mirror and take the water's colour
			vec3 refl = mix(r * vec3(0.74, 0.8, 0.84), c, 0.16);
			// a pale line of light where the water meets the bank
			if (d < 1.5) {
				refl = mix(refl, vec3(0.85, 0.95, 0.95), 0.25 * clear);
			}
			c = mix(c, refl, a);
		}
		// sparkles of sun moving with the ripples
		float glint = step(0.993 - glow * 0.014, hash(ap + vec2(floor(t * 2.0 + hash(ap) * 3.0), 0.0)));
		c += sun * (0.34 + glow * 0.2) * glint * clear * (1.0 - stars);
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
		COLOR = vec4(c, 1.0);
	}
}
