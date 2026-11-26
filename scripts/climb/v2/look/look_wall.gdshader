shader_type canvas_item;
// The v2 climbing wall, lit (thread 10's look). The picture it draws is the
// rock's height (LookWallPaint: L8 at PX_PER_M); tone and marks come in as
// their own textures. Light is worked out here every frame from the hour,
// the weather and the headlamp, so the paint never has to be redone:
//   - the slopes of the height face the sun or turn from it (holds read by
//     their lit tops and the shadow under their lips, as real ones do);
//   - a fine granite grain on top, at screen pixels;
//   - the result is stepped onto the rock's own ramp (ClimbRock.colors),
//     dithered only mid-step, so the face keeps the game's pixel-art tones;
//   - then chalk, lichen, black streaks, wet sheen, the night and the lamp.

uniform sampler2D tone_tex : filter_linear;
uniform sampler2D marks_tex : filter_linear;
uniform sampler2D sheets_tex : filter_linear;
// how much the exfoliation plates add to the height
uniform float sheet_depth = 0.22;
// The rock's ramp for this hour, dark to light (ClimbRock.colors(...).ramp).
uniform vec3 ramp[24];
uniform int ramp_count = 20;
// The same rock at midday: what the headlamp shows (its light is white,
// whatever the hour has done to the ramp).
uniform vec3 ramp_day[24];
// pixels of height from black to white
uniform float bump = 14.0;
// the sun's light as it travels across the picture (+y down), its colour
// and strength (0 = shade or night)
uniform vec2 sun_travel = vec2(0.6, 0.8);
uniform vec3 sun_color : source_color = vec3(1.0);
uniform float sun_strength = 0.7;
// how bright the face is in shade, 0..1
uniform float ambient = 0.62;
// 0 day .. 1 full night (moonlight only outside the lamp)
uniform float night = 0.0;
uniform float night_floor = 0.22;
// the headlamp, in this picture's pixels, and its radius in pixels
uniform vec2 lamp_pos = vec2(-9999.0);
uniform float lamp_radius = 156.0;
uniform vec3 lamp_color : source_color = vec3(1.0, 0.95, 0.86);
// rain on the rock, 0..1, on top of the painted wet streaks
uniform float wet = 0.0;
uniform vec3 chalk_color : source_color = vec3(0.96, 0.94, 0.88);
uniform vec3 lichen_color : source_color = vec3(0.62, 0.68, 0.36);
uniform vec3 streak_color : source_color = vec3(0.13, 0.12, 0.14);
uniform vec3 rim_color : source_color = vec3(1.0, 0.95, 0.85);
uniform float time = 0.0;

const int BAYER[16] = int[](0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5);

float hash(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

// Granite's small relief at screen pixels: grain stretched up the face and
// a finer crystal layer.
float grain(vec2 p) {
	return vnoise(p * vec2(0.18, 0.08)) * 0.5 + vnoise(p * vec2(0.45, 0.25) + 17.0) * 0.32 + vnoise(p * 0.9 + 41.0) * 0.18;
}

// The relief's extra layers at a spot: exfoliation plates and fine grain
// (the painted height itself is read in fragment(), where TEXTURE lives).
float extra_at(vec2 uv, vec2 px) {
	return texture(sheets_tex, uv).r * sheet_depth + (grain(px) - 0.5) * 0.1;
}

void fragment() {
	vec2 tsize = 1.0 / TEXTURE_PIXEL_SIZE;
	vec2 px = floor(UV * tsize);
	vec4 tone = texture(tone_tex, UV);
	// Past the arete: sky (the backdrop shows through).
	if (tone.g < 0.5) {
		discard;
	}
	vec2 d = TEXTURE_PIXEL_SIZE;
	float hl = texture(TEXTURE, UV - vec2(d.x, 0.0)).r + extra_at(UV - vec2(d.x, 0.0), px - vec2(1.0, 0.0));
	float hr = texture(TEXTURE, UV + vec2(d.x, 0.0)).r + extra_at(UV + vec2(d.x, 0.0), px + vec2(1.0, 0.0));
	float hu = texture(TEXTURE, UV - vec2(0.0, d.y)).r + extra_at(UV - vec2(0.0, d.y), px - vec2(0.0, 1.0));
	float hd = texture(TEXTURE, UV + vec2(0.0, d.y)).r + extra_at(UV + vec2(0.0, d.y), px + vec2(0.0, 1.0));
	float h = texture(TEXTURE, UV).r;
	// normal: x right, y up the picture, z out of the rock
	vec3 n = normalize(vec3((hl - hr) * bump, (hd - hu) * bump, 1.0));
	vec3 sun = normalize(vec3(-sun_travel.x, sun_travel.y, 0.9));
	float facing = dot(n, sun);
	float lit = ambient + sun_strength * (facing - sun.z * 0.85);
	// crevices hold shadow: cracks and pockets go dark whatever the sun
	float cavity = smoothstep(0.32, 0.12, h);
	lit *= 1.0 - cavity * 0.75;
	// how pale the stone is, then lit
	float level = clamp(tone.r * 1.45 * lit + (h - 0.45) * 0.35, 0.0, 1.0);
	vec4 marks = texture(marks_tex, UV);
	float wetness = clamp(marks.a + wet * 0.8, 0.0, 1.0);
	level *= 1.0 - wetness * 0.3 - marks.r * 0.45;
	// the arete's rim catches light on its very edge
	float rim = smoothstep(0.75, 0.5, tone.g);
	level += rim * 0.25 * (1.0 - night);
	// onto the ramp: the two tones either side, dithered mid-step
	float idx = clamp(level, 0.0, 1.0) * float(ramp_count - 1);
	int lo = int(floor(idx));
	int hi = min(lo + 1, ramp_count - 1);
	float f = clamp((fract(idx) - 0.3) / 0.4, 0.0, 1.0);
	ivec2 bp = ivec2(px) & ivec2(3);
	float b = (float(BAYER[bp.y * 4 + bp.x]) + 0.5) / 16.0;
	// granite's salt and pepper: the odd dark mica and pale feldspar crystal
	float speck = hash(px + 7.1);
	if (speck > 0.978) {
		lo = max(lo - 3, 0);
		hi = lo;
	} else if (speck < 0.02) {
		lo = min(lo + 2, ramp_count - 1);
		hi = lo;
	}
	vec3 col = f > b ? ramp[hi] : ramp[lo];
	vec3 day_col = f > b ? ramp_day[hi] : ramp_day[lo];
	col *= mix(vec3(1.0), sun_color, clamp(sun_strength * max(facing, 0.0), 0.0, 1.0) * 0.35);
	// black streaks run darker and a little blue; lichen; chalk on top
	col = mix(col, streak_color, marks.r * 0.35);
	col = mix(col, lichen_color * (0.55 + 0.45 * lit), clamp(marks.g, 0.0, 1.0) * 0.55);
	col = mix(col, chalk_color * clamp(lit + 0.15, 0.4, 1.1), clamp(marks.b, 0.0, 1.0) * 0.8);
	// wet rock glints where it faces the light
	float glint = pow(max(facing, 0.0), 24.0) * wetness * (0.5 + 0.5 * sin(time * 2.0 + px.y * 0.3));
	col += vec3(glint) * 0.35 * (1.0 - night);
	// night: moonlight outside the lamp, the lamp's warm pool inside
	if (night > 0.0) {
		float r = length(px - lamp_pos) / lamp_radius;
		float pool = clamp(1.0 - r * r, 0.0, 1.0);
		float keep = mix(1.0, night_floor, night);
		vec3 moon = col * vec3(0.75, 0.82, 1.1);
		vec3 dark = mix(col, moon, night) * keep;
		vec3 lamp = day_col * lamp_color * (0.75 + 0.3 * max(facing, 0.0) + 0.15 * max(n.z, 0.0));
		lamp = mix(lamp, chalk_color, clamp(marks.b, 0.0, 1.0) * 0.6);
		col = mix(dark, lamp, pool * night);
	}
	COLOR = vec4(col, 1.0);
}
