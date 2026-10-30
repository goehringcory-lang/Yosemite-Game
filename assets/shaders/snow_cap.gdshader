shader_type canvas_item;
// Snow lying on the tops of things: roofs, cars, boulders, logs, signs and
// benches (see scripts/world/seasonal_dressing.gd). Every opaque pixel with
// open air a few art pixels above it is snow, so a cap follows each shape's
// upper edge and grows thicker as the snow deepens. The art is drawn at 2x,
// so it works in whole art pixels and stays crisp.

uniform float snow : hint_range(0.0, 1.0) = 0.0;
const vec3 SNOW = vec3(0.95, 0.97, 1.0);
const vec3 SNOW_SHADE = vec3(0.77, 0.84, 0.94);

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	// COLOR comes in as the texture times the sprite's modulate
	if (snow > 0.0 && texture(TEXTURE, UV).a > 0.5) {
		vec2 art = TEXTURE_PIXEL_SIZE * 2.0;
		vec2 px = floor(UV / art);
		// one art pixel deep in a dusting, up to three in deep snow, a little
		// uneven along the edge
		float depth = ceil(snow * 3.0) - step(0.7, hash(vec2(px.x, 1.0)));
		for (int k = 1; k <= 3; k++) {
			if (float(k) > depth) {
				break;
			}
			vec2 up = UV - vec2(0.0, art.y * float(k));
			if (up.y < 0.0 || texture(TEXTURE, up).a < 0.5) {
				// the bottom row of a cap is in shadow
				bool bottom = depth > 1.0 && float(k) >= depth;
				vec3 s = bottom ? SNOW_SHADE : SNOW;
				COLOR.rgb = s * (0.94 + 0.06 * hash(px));
				break;
			}
		}
	}
}
