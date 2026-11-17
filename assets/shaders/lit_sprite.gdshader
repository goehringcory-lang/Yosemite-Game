shader_type canvas_item;
// A sprite shaded by real light through its normal map (see lit.gdshaderinc
// and scripts/world/lit_sprites.gd), which sways in the wind if it is a tree
// or a plant (see sway.gdshaderinc and scripts/world/wind.gd).

#include "res://assets/shaders/lit.gdshaderinc"
#include "res://assets/shaders/sway.gdshaderinc"

void vertex() {
	SWAY_VERTEX
	LIT_SUN_VERTEX
}

void fragment() {
	vec2 uv = sway_uv(UV, TEXTURE_PIXEL_SIZE, sway_foot, TIME);
	COLOR = texture(TEXTURE, uv) * sway_inside(uv) * sway_modulate;
	NORMAL_MAP = texture(normal_map, uv).rgb;
	lit_sun_gain = lit_sun(NORMAL_MAP);
	COLOR.rgb *= lit_sun_gain;
}

void light() {
	LIGHT = lit_light(NORMAL, LIGHT_DIRECTION, LIGHT_IS_DIRECTIONAL, LIGHT_COLOR, LIGHT_ENERGY, vec4(COLOR.rgb / lit_sun_gain, COLOR.a));
}
