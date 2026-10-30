shader_type canvas_item;
// Real light on a picture painted at run time, which has no normal map made
// ahead (the climbing wall, see scripts/climb/art/climb_light.gd): the
// relief is read from the picture's own shading as it draws, the way
// tools/normals reads it from the sprites, so brighter stone stands a little
// proud and cracks and edges catch the light.

#include "res://assets/shaders/lit.gdshaderinc"

// pixels of height from full black to full white
uniform float bump = 2.5;
// The sun, worked out here rather than by a light: the way its light
// travels across the picture (+y down), its colour and strength. Slopes
// facing it brighten and slopes facing away dim, as lit.gdshaderinc does.
uniform vec2 sun_travel = vec2(0.0, 1.0);
uniform vec3 sun_color : source_color = vec3(1.0);
uniform float sun_strength = 0.0;

float shade_at(sampler2D tex, vec2 uv) {
	return dot(texture(tex, uv).rgb, vec3(0.299, 0.587, 0.114));
}

void fragment() {
	// two texels apart, so the fine grain doesn't make the face fizz
	vec2 step = TEXTURE_PIXEL_SIZE * 2.0;
	float left = shade_at(TEXTURE, UV - vec2(step.x, 0.0));
	float right = shade_at(TEXTURE, UV + vec2(step.x, 0.0));
	float above = shade_at(TEXTURE, UV - vec2(0.0, step.y));
	float below = shade_at(TEXTURE, UV + vec2(0.0, step.y));
	// red right, green up the picture, as the normal maps store them
	vec3 n = normalize(vec3((left - right) * bump * 0.5, (below - above) * bump * 0.5, 1.0));
	NORMAL_MAP = n * 0.5 + 0.5;
	// facing the sun: a normal pointing back along its light (+y down here)
	float tilt = dot(vec2(n.x, -n.y), -normalize(sun_travel));
	COLOR.rgb += COLOR.rgb * sun_color * tilt * SUN_GAIN * relief * sun_strength;
}

void light() {
	LIGHT = lit_light(NORMAL, LIGHT_DIRECTION, LIGHT_IS_DIRECTIONAL, LIGHT_COLOR, LIGHT_ENERGY, COLOR);
}
