// Shared by the shaders of sprites that real lights shade (see
// scripts/world/lit_sprites.gd): the sun's DirectionalLight2D by day, the
// lamps' and fires' PointLight2Ds after dark.
//
// The relief comes from the sprite's normal map (tools/normals): how far a
// pixel's surface tilts toward the light, seen from above (-1 facing away,
// 0 flat, 1 facing it). Flat ground gets exactly the light's usual amount,
// so a lit picture is as bright overall as an unlit one; a slope toward a
// lamp gets more, a slope away less. The sun (the one directional light)
// only shapes: it adds light to slopes facing it and takes it from slopes
// facing away, and leaves flat ground as painted, since the day's tint
// (DayNight) already lights it.

uniform sampler2D normal_map : hint_normal, filter_nearest;
// 0 shades like an unlit sprite, 1 is the full relief
uniform float relief : hint_range(0.0, 1.0) = 1.0;
// how much a full tilt toward the light brightens (and away darkens): the
// sun strongly, to model the day; lamps gently, since their light is already
// near white where it is brightest and would wash out painted detail
const float SUN_GAIN = 1.6;
const float LAMP_GAIN = 0.7;

vec4 lit_light(vec3 normal, vec3 light_dir, bool directional, vec4 light_color, float light_energy, vec4 albedo) {
	vec2 across = light_dir.xy;
	float reach = length(across);
	float tilt = reach > 0.0001 ? dot(normal.xy, across / reach) : 0.0;
	if (directional) {
		// Godot carries a directional light's energy in its alpha, which the
		// blend multiplies by, so it isn't applied here a second time.
		return vec4(light_color.rgb * albedo.rgb * tilt * SUN_GAIN * relief, light_color.a);
	}
	float shade = max(1.0 + tilt * LAMP_GAIN * relief, 0.0);
	return vec4(light_color.rgb * albedo.rgb * light_energy * shade, light_color.a);
}
