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
//
// The sun is not a Light2D: Godot runs a directional 2D light over every
// canvas item, whatever its light mask, which cost every sprite, the ground
// and every full-screen effect a light pass (and, on everything without a
// light() of its own, added the sun's colour once more: unlit sprites stood
// that much brighter in the sun). So SunLight (scripts/world/sun_light.gd)
// does both by hand, to the same picture: it lifts the canvas modulate (the
// day's tint) by 1 + the sun, and sets these two global uniforms, with which
// a lit shader shapes its own colour (LIT_SUN_VERTEX in vertex(), lit_sun()
// in fragment()) and takes that lift back out. The lamps (PointLight2D, only
// near them) still come in through light().

// the way toward the sun across the screen (unit, +y down), and its colour
// times its strength (no day tint; zero when it's out)
global uniform vec2 sun_toward;
global uniform vec3 sun_light;
// the sun's way in the sprite's own axes (as Godot turns a normal by the
// item's transform: columns normalised, so flips and mirrored scale count)
varying vec2 lit_sun_local;

#define LIT_SUN_VERTEX \
	lit_sun_local = vec2(dot(sun_toward, normalize(MODEL_MATRIX[0].xy)), dot(sun_toward, normalize(MODEL_MATRIX[1].xy)));

uniform sampler2D normal_map : hint_normal, filter_nearest;
// 0 shades like an unlit sprite, 1 is the full relief
uniform float relief : hint_range(0.0, 1.0) = 1.0;
// how much a full tilt toward the light brightens (and away darkens): the
// sun strongly, to model the day; lamps gently, since their light is already
// near white where it is brightest and would wash out painted detail
const float SUN_GAIN = 1.6;
const float LAMP_GAIN = 0.7;

// What the sun does to a pixel whose normal map reads [nmap] (what
// NORMAL_MAP is set to): the factor its colour is multiplied by, as the
// directional light's add shaded it, less the canvas lift. fragment() keeps
// it in lit_sun_gain and multiplies COLOR by it; light() hands lit_light()
// COLOR / lit_sun_gain, so the lamps light the painted colour as before.
varying vec3 lit_sun_gain;

vec3 lit_sun(vec3 nmap) {
	if (sun_light == vec3(0.0)) {
		return vec3(1.0);
	}
	vec3 n = normalize(nmap * vec3(2.0, -2.0, 1.0) - vec3(1.0, -1.0, 0.0));
	float tilt = dot(n.xy, lit_sun_local);
	// Warm directional diffuse on sun-facing slopes; cool sky-blue hemisphere
	// fill on shaded slopes so trunks, granite and stonework separate in 3D.
	float lit_side = max(tilt, 0.0);
	float shade_side = max(-tilt, 0.0);
	vec3 sky_fill = vec3(0.88, 0.94, 1.12);
	// Grazing sunlit rim / micro-specular along bevelled edges facing the sun.
	float rim = pow(lit_side, 3.0) * clamp(1.1 - n.z * 0.7, 0.2, 1.0) * 0.42;
	vec3 direct = sun_light * (lit_side * SUN_GAIN + rim) * relief;
	vec3 shadow_cut = sun_light * shade_side * SUN_GAIN * relief;
	vec3 shaded = max(vec3(1.0) + direct - shadow_cut, vec3(0.25));
	// Shift shaded slopes gently toward cool sky fill.
	shaded = mix(shaded, shaded * sky_fill, shade_side * relief * 0.48);
	return shaded / (1.0 + sun_light);
}

vec4 lit_light(vec3 normal, vec3 light_dir, bool directional, vec4 light_color, float light_energy, vec4 albedo) {
	vec2 across = light_dir.xy;
	float reach = length(across);
	float tilt = reach > 0.0001 ? dot(normal.xy, across / reach) : 0.0;
	if (directional) {
		// Godot carries a directional light's energy in its alpha, which the
		// blend multiplies by, so it isn't applied here a second time.
		return vec4(light_color.rgb * albedo.rgb * tilt * SUN_GAIN * relief, light_color.a);
	}
	float rim = pow(max(tilt, 0.0), 2.5) * 0.24 * relief;
	float shade = max(1.0 + tilt * LAMP_GAIN * relief + rim, 0.0);
	return vec4(light_color.rgb * albedo.rgb * light_energy * shade, light_color.a);
}
