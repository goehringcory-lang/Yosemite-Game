shader_type canvas_item;
render_mode blend_disabled;
// Jump Flood Algorithm seed pass for 2D Radiance Cascades GI (scripts/world/radiance_gi.gd).
// Any pixel in the scene buffer with alpha > 0.5 (an occluder footprint or an
// emitter) seeds itself with its own SCREEN_UV (a = 1); empty air stores a = 0.

uniform sampler2D scene_tex : filter_nearest, repeat_disable;

void fragment() {
	vec4 s = texture(scene_tex, SCREEN_UV);
	if (s.a > 0.5) {
		COLOR = vec4(SCREEN_UV, 0.0, 1.0);
	} else {
		COLOR = vec4(0.0, 0.0, 0.0, 0.0);
	}
}
