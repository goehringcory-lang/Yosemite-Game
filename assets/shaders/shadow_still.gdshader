shader_type canvas_item;
// The still shadows' baked picture (scripts/world/sun_shadows.gd), laid on the
// ground: white where a shadow lies, drawn in the shadow's colour, as strong
// as the sprite's alpha (the hour's shadow strength).
//
// On High graphics (high_quality = true): softens shadow edges with a 9-tap
// penumbra kernel that widens when the sun is low, and adds subtle wind-dappled
// light variation inside deep canopy shade.

global uniform float wind_strength;
uniform vec3 shade : source_color = vec3(0.1, 0.11, 0.22);
uniform bool high_quality = false;
// Penumbra filter radius in baked texture pixels (grows at low sun).
uniform float penumbra = 1.6;
// World-space origin of the baked texture, for seamless wind-dappled shade.
uniform vec2 bake_origin = vec2(0.0);
uniform vec2 bake_size = vec2(1.0);

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(
		mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x),
		mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x),
		f.y
	);
}

void fragment() {
	if (!high_quality) {
		COLOR = vec4(shade, COLOR.a);
	} else {
		// 9-tap soft penumbra filter over the baked shadow mask.
		vec2 step_uv = TEXTURE_PIXEL_SIZE * penumbra;
		float a = texture(TEXTURE, UV).a * 0.28;
		a += texture(TEXTURE, UV + vec2(step_uv.x, 0.0)).a * 0.11;
		a += texture(TEXTURE, UV - vec2(step_uv.x, 0.0)).a * 0.11;
		a += texture(TEXTURE, UV + vec2(0.0, step_uv.y)).a * 0.11;
		a += texture(TEXTURE, UV - vec2(0.0, step_uv.y)).a * 0.11;
		a += texture(TEXTURE, UV + vec2(step_uv.x, step_uv.y) * 0.72).a * 0.07;
		a += texture(TEXTURE, UV + vec2(-step_uv.x, step_uv.y) * 0.72).a * 0.07;
		a += texture(TEXTURE, UV + vec2(step_uv.x, -step_uv.y) * 0.72).a * 0.07;
		a += texture(TEXTURE, UV + vec2(-step_uv.x, -step_uv.y) * 0.72).a * 0.07;

		if (a <= 0.001) {
			COLOR = vec4(shade, 0.0);
		} else {
			// Subtle wind-dappled canopy light variation inside deep shadows.
			vec2 wp = bake_origin + UV * bake_size;
			float dapple = vnoise(wp * 0.055 + vec2(TIME * (0.25 + wind_strength * 0.25), TIME * 0.12));
			float dapple_mod = mix(0.90, 1.06, dapple);
			float out_a = clamp(a * dapple_mod, 0.0, 1.0) * COLOR.a;
			COLOR = vec4(shade, out_a);
		}
	}
}
