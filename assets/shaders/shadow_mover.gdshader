shader_type canvas_item;
// A moving caster's shadow (scripts/world/sun_shadows.gd), left out wherever a
// still shadow already lies in the bake, so the two don't darken the ground
// twice.

uniform sampler2D still : filter_nearest, repeat_disable;
// The bake's top-left and size in world pixels.
uniform vec2 still_origin = vec2(0.0);
uniform vec2 still_size = vec2(1.0);

varying vec2 world;

void vertex() {
	world = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
	vec2 uv = (world - still_origin) / still_size;
	if (uv.x >= 0.0 && uv.y >= 0.0 && uv.x < 1.0 && uv.y < 1.0 && texture(still, uv).a > 0.5) {
		discard;
	}
}
