shader_type canvas_item;
// A sprite shaded by real light through its normal map (see lit.gdshaderinc
// and scripts/world/lit_sprites.gd).

#include "res://assets/shaders/lit.gdshaderinc"

void fragment() {
	NORMAL_MAP = texture(normal_map, UV).rgb;
}

void light() {
	LIGHT = lit_light(NORMAL, LIGHT_DIRECTION, LIGHT_IS_DIRECTIONAL, LIGHT_COLOR, LIGHT_ENERGY, COLOR);
}
