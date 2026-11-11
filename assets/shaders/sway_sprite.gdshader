shader_type canvas_item;
// A tree or plant that sways in the wind but has no normal map, or stands in
// the Low graphics level, where sprites aren't shaded by real light (see
// sway.gdshaderinc and scripts/world/wind.gd).

#include "res://assets/shaders/sway.gdshaderinc"

void vertex() {
	SWAY_VERTEX
}

void fragment() {
	vec2 uv = sway_uv(UV, TEXTURE_PIXEL_SIZE, sway_foot, TIME);
	COLOR = texture(TEXTURE, uv) * sway_inside(uv) * sway_modulate;
}
