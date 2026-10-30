shader_type canvas_item;
render_mode blend_premul_alpha;
// What hangs in the valley air (scripts/world/valley_air.gd): banks of morning
// mist drifting low over the ground, and shafts of low sun slanting through
// it. Works in world pixels like the cloud shadows, so it stays put on the
// ground as you walk, and comes in flat steps of whole 2x2 pixels to match the
// art. The mist is laid over the picture; the light shafts are added to it.

uniform vec2 drift = vec2(0.0);
uniform float mist : hint_range(0.0, 1.0) = 0.0;
uniform vec3 mist_color : source_color = vec3(0.86, 0.9, 0.96);
uniform float rays : hint_range(0.0, 1.0) = 0.0;
uniform vec3 ray_color : source_color = vec3(1.0, 0.86, 0.6);
// The way the light travels across the ground (away from the sun).
uniform vec2 ray_dir = vec2(-1.0, -0.3);
uniform float time = 0.0;

varying vec2 world;

float hash(vec2 p) {
	p = fract(p * vec2(0.1031, 0.1030));
	p += dot(p, p.yx + 33.33);
	return fract((p.x + p.y) * p.x);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float fbm(vec2 p) {
	return vnoise(p) * 0.55 + vnoise(p * 2.1 + 5.3) * 0.28 + vnoise(p * 4.3 + 1.7) * 0.17;
}

void vertex() {
	world = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
	vec2 px = floor(world * 0.5) * 2.0;

	// Mist: long, low banks stretched east-west, thinning at their edges, with
	// slower wisps rolling through them.
	vec2 mp = (px + drift) / vec2(420.0, 190.0);
	float bank = fbm(mp);
	float wisp = fbm((px + drift * 1.7) / vec2(150.0, 70.0) + 11.0);
	float m = smoothstep(0.55 - mist * 0.35, 0.85 - mist * 0.2, bank * 0.75 + wisp * 0.35);
	m = floor(m * 4.0 + 0.5) / 4.0;
	float mist_a = m * min(mist * 1.1, 0.6);

	// Light shafts: bands along the light's direction, slowly breathing, that
	// fade in and out along their length.
	vec2 dir = normalize(ray_dir);
	vec2 across = vec2(-dir.y, dir.x);
	float a = dot(px, across);
	float along = dot(px, dir);
	float band = vnoise(vec2(a / 38.0, time * 0.05)) * 0.65 + vnoise(vec2(a / 14.0 + 3.1, time * 0.08)) * 0.35;
	float shaft = smoothstep(0.58, 0.85, band);
	shaft *= smoothstep(0.25, 0.7, vnoise(vec2(a / 90.0, along / 260.0 + time * 0.02)));
	shaft = floor(shaft * 3.0 + 0.5) / 3.0;
	// Shafts show best through mist.
	float ray_a = shaft * rays * (0.065 + mist_a * 0.4);

	vec3 rgb = mist_color * mist_a + ray_color * ray_a;
	COLOR = vec4(rgb, mist_a);
}
