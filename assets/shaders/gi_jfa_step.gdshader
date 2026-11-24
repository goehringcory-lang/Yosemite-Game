shader_type canvas_item;
render_mode blend_disabled;
// One Jump Flood Algorithm step (scripts/world/radiance_gi.gd).
// Checks a 3x3 neighbourhood at [step_size] texels and keeps the seed closest
// in isotropic texel space (so the 16:9 buffer has circular distances).

uniform sampler2D prev_tex : filter_nearest, repeat_disable;
uniform vec2 resolution = vec2(256.0, 144.0);
uniform float step_size = 128.0;

void fragment() {
	vec2 my_px = SCREEN_UV * resolution;
	vec2 texel = 1.0 / resolution;
	vec2 best_uv = vec2(0.0);
	float best_d2 = 1e20;
	bool found = false;

	for (int dy = -1; dy <= 1; dy++) {
		for (int dx = -1; dx <= 1; dx++) {
			vec2 sample_uv = SCREEN_UV + vec2(float(dx), float(dy)) * step_size * texel;
			if (sample_uv.x < 0.0 || sample_uv.y < 0.0 || sample_uv.x > 1.0 || sample_uv.y > 1.0) {
				continue;
			}
			vec4 seed = texture(prev_tex, sample_uv);
			if (seed.a < 0.5) {
				continue;
			}
			vec2 delta = seed.xy * resolution - my_px;
			float d2 = dot(delta, delta);
			if (d2 < best_d2) {
				best_d2 = d2;
				best_uv = seed.xy;
				found = true;
			}
		}
	}

	COLOR = vec4(best_uv, 0.0, found ? 1.0 : 0.0);
}
