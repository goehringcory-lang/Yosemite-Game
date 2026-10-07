shader_type canvas_item;
// Soft shadows of clouds drifting over the ground (see scripts/world/cloud_shadows.gd).
// Works in world pixels, so it stays as crisp as the art: the noise is sampled
// once per world pixel and the shade comes in two flat steps, never a
// smooth blend.

uniform vec2 drift = vec2(0.0);
// 0 clear sky .. 1 overcast
uniform float coverage : hint_range(0.0, 1.0) = 0.4;
uniform float strength : hint_range(0.0, 1.0) = 0.14;
uniform float scale = 150.0;
uniform vec3 shade : source_color = vec3(0.1, 0.13, 0.24);

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

void vertex() {
	world = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
	vec2 px = floor(world);
	vec2 p = (px + drift) / scale;
	// stretched along the wind, like real cumulus shadows
	p.y *= 1.4;
	float n = vnoise(p) * 0.62 + vnoise(p * 2.3 + 7.1) * 0.28 + vnoise(p * 5.1 + 3.7) * 0.1;
	float edge = 1.0 - coverage;
	float d = smoothstep(edge - 0.06, edge + 0.1, n);
	// two flat steps of shade, a lighter rim and the core, with hard pixel
	// edges (dithering would put a checkerboard over people and signs)
	float level = floor(d * 2.0 + 0.5) / 2.0;
	COLOR = vec4(shade, level * strength);
}
