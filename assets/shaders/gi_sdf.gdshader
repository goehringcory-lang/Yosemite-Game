shader_type canvas_item;
render_mode blend_disabled;
// Extracts a normalized 2D Euclidean distance field from the final JFA seed
// texture (scripts/world/radiance_gi.gd). Stored in .r as (dist_in_texels / max_dist).

uniform sampler2D jfa_tex : filter_nearest, repeat_disable;
uniform vec2 resolution = vec2(256.0, 144.0);
uniform float max_dist = 256.0;

void fragment() {
	vec4 seed = texture(jfa_tex, SCREEN_UV);
	float dist = max_dist;
	if (seed.a > 0.5) {
		dist = length(seed.xy * resolution - SCREEN_UV * resolution);
	}
	COLOR = vec4(clamp(dist / max_dist, 0.0, 1.0), 0.0, 0.0, 1.0);
}
