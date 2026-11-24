shader_type canvas_item;
render_mode blend_disabled;
// Resolves Cascade 0 (256x144, 128x72 probes x 2x2 angular bins) into a
// 128x72 HDR irradiance + sky-visibility map (scripts/world/radiance_gi.gd).
// Applies a gentle 3x3 Gaussian tent across neighbouring probes to remove any
// probe-grid ringing while preserving crisp occluded shadow edges.

uniform sampler2D cascade0_tex : filter_nearest, repeat_disable;
uniform vec2 c0_resolution = vec2(256.0, 144.0);
uniform vec2 probe_grid = vec2(128.0, 72.0);

vec4 probe_irradiance(vec2 pid) {
	vec2 p = clamp(pid, vec2(0.0), probe_grid - vec2(1.0));
	vec2 base = p * 2.0;
	vec4 r0 = texture(cascade0_tex, (base + vec2(0.5, 0.5)) / c0_resolution);
	vec4 r1 = texture(cascade0_tex, (base + vec2(1.5, 0.5)) / c0_resolution);
	vec4 r2 = texture(cascade0_tex, (base + vec2(0.5, 1.5)) / c0_resolution);
	vec4 r3 = texture(cascade0_tex, (base + vec2(1.5, 1.5)) / c0_resolution);
	return (r0 + r1 + r2 + r3) * 0.25;
}

void fragment() {
	vec2 pid = floor(SCREEN_UV * probe_grid);
	vec4 center = probe_irradiance(pid);
	vec4 n = probe_irradiance(pid + vec2(0.0, -1.0));
	vec4 s = probe_irradiance(pid + vec2(0.0, 1.0));
	vec4 w = probe_irradiance(pid + vec2(-1.0, 0.0));
	vec4 e = probe_irradiance(pid + vec2(1.0, 0.0));
	COLOR = center * 0.5 + (n + s + w + e) * 0.125;
}
