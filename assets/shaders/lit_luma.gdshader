shader_type canvas_item;
// Real light on a picture painted at run time, which has no normal map made
// ahead (the climbing wall, see scripts/climb/art/climb_light.gd): the
// relief is read from the picture's own shading as it draws, the way
// tools/normals reads it from the sprites, so brighter stone stands a little
// proud and cracks and edges catch the light.
//
// The wall is painted in its granite's own ramp (ClimbRock.ramp), which the
// palette snap lets through untouched. So the sun here doesn't brighten a
// stone pixel freely: it moves it up or down that ramp, dithered in the
// wall's own pixels, and the face stays on its tones as the light swings.

#include "res://assets/shaders/lit.gdshaderinc"

// pixels of height from full black to full white
uniform float bump = 2.5;
// The sun, worked out here rather than by a light: the way its light
// travels across the picture (+y down), its colour and strength. Slopes
// facing it brighten and slopes facing away dim, as lit.gdshaderinc does.
uniform vec2 sun_travel = vec2(0.0, 1.0);
uniform vec3 sun_color : source_color = vec3(1.0);
uniform float sun_strength = 0.0;
// the wall's granite ramp, dark to light, and each tone's lightness
uniform vec3 ramp[24];
uniform float ramp_luma[24];
uniform int ramp_count = 0;

// How many ramp steps the fine relief may move a pixel (0 turns it off).
// The wall is painted on the 480 x 270 menu grid and doubled; this carves
// the stone's own small facets and crystals at the doubled grid, one screen
// pixel each, so the granite reads twice as finely as anything painted.
uniform float micro = 1.5;
// the doubled wall's size in pixels, for the fine relief's grid
uniform vec2 micro_scale = vec2(1.0);

const int BAYER[16] = int[](0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5);

float hash(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

// Small-scale relief in wall pixels: grain stretched up and down the face
// as granite weathers, a finer crystal layer, and the odd sharp crystal.
float grain_at(vec2 p) {
	float r = value_noise(p * vec2(0.16, 0.07)) * 0.55;
	r += value_noise(p * vec2(0.36, 0.2) + 17.0) * 0.3;
	r += value_noise(p * 0.8 + 41.0) * 0.15;
	return r;
}

float shade_at(sampler2D tex, vec2 uv) {
	return dot(texture(tex, uv).rgb, vec3(0.299, 0.587, 0.114));
}

void fragment() {
	// two texels apart, so the fine grain doesn't make the face fizz
	vec2 dt = TEXTURE_PIXEL_SIZE * 2.0;
	float left = shade_at(TEXTURE, UV - vec2(dt.x, 0.0));
	float right = shade_at(TEXTURE, UV + vec2(dt.x, 0.0));
	float above = shade_at(TEXTURE, UV - vec2(0.0, dt.y));
	float below = shade_at(TEXTURE, UV + vec2(0.0, dt.y));
	// red right, green up the picture, as the normal maps store them
	vec3 n = normalize(vec3((left - right) * bump * 0.5, (below - above) * bump * 0.5, 1.0));
	NORMAL_MAP = n * 0.5 + 0.5;
	// facing the sun: a normal pointing back along its light (+y down here)
	float tilt = dot(vec2(n.x, -n.y), -normalize(sun_travel));
	float gain = tilt * SUN_GAIN * relief * sun_strength;
	int at = -1;
	for (int i = 0; i < ramp_count; i++) {
		if (all(lessThan(abs(COLOR.rgb - ramp[i]), vec3(0.75 / 255.0)))) {
			at = i;
			break;
		}
	}
	if (at < 0) {
		COLOR.rgb += COLOR.rgb * sun_color * gain;
	} else {
		// the fine relief, lit from the upper left like the painted face:
		// how much higher the stone is here than one step toward the light
		vec2 wp = floor(UV * micro_scale);
		float fine = grain_at(wp) - grain_at(wp - vec2(1.0, 1.0));
		float crystal = step(0.985, hash(wp + 3.7)) * (hash(wp + 9.1) - 0.4);
		// the darkest tones (crack insides, deep shadow) keep still
		float give = smoothstep(1.0, 4.0, float(at));
		float shift = (fine * 9.0 + crystal * 2.5) * micro * give;
		// the lightness the sun asks for, then the ramp tones either side
		float stepped = ramp_luma[clamp(at + int(round(shift)), 0, ramp_count - 1)];
		float want = stepped * (1.0 + gain);
		int lo = at;
		while (lo > 0 && ramp_luma[lo] > want) {
			lo--;
		}
		while (lo < ramp_count - 2 && ramp_luma[lo + 1] <= want) {
			lo++;
		}
		int hi = min(lo + 1, ramp_count - 1);
		float f = hi == lo ? 0.0 : clamp((want - ramp_luma[lo]) / max(ramp_luma[hi] - ramp_luma[lo], 1e-4), 0.0, 1.0);
		// dither only the middle of the step, as ClimbHiRes.quantize does
		f = clamp((f - 0.3) / 0.4, 0.0, 1.0);
		ivec2 p = ivec2(floor(UV / TEXTURE_PIXEL_SIZE)) & ivec2(3);
		float b = (float(BAYER[p.y * 4 + p.x]) + 0.5) / 16.0;
		COLOR.rgb = f > b ? ramp[hi] : ramp[lo];
	}
}

void light() {
	LIGHT = lit_light(NORMAL, LIGHT_DIRECTION, LIGHT_IS_DIRECTIONAL, LIGHT_COLOR, LIGHT_ENERGY, COLOR);
}
