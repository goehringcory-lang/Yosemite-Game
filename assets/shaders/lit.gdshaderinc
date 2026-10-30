// Shared by the shaders of sprites that real lights shade (see
// scripts/world/lit_sprites.gd): the sun's DirectionalLight2D by day, the
// lamps' and fires' PointLight2Ds after dark.
//
// A lamp's light on a surface facing it the way flat ground does is exactly
// the lamp's usual amount, so a lit picture is as bright overall as an
// unlit one; a slope toward the lamp gets up to twice that, a slope away
// none. The sun (the one directional light) only shapes: it adds light to
// slopes facing it and takes it from slopes facing away, and leaves flat
// ground as painted, since the day's tint (DayNight) already lights it. The
// relief comes from the sprite's normal map (tools/normals).

uniform sampler2D normal_map : hint_normal, filter_nearest;
// 0 shades like an unlit sprite, 1 is the full relief
uniform float relief : hint_range(0.0, 1.0) = 1.0;

vec4 lit_light(vec3 normal, vec3 light_dir, bool directional, vec4 light_color, float light_energy, vec4 albedo) {
	vec3 l = normalize(light_dir);
	float flat_ndl = max(abs(l.z), 0.2);
	float ndl = clamp(max(dot(normal, l), 0.0) / flat_ndl, 0.0, 2.0);
	ndl = mix(1.0, ndl, relief);
	if (directional) {
		ndl -= 1.0;
	}
	return vec4(light_color.rgb * albedo.rgb * light_energy * ndl, light_color.a);
}
