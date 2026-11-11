// A tree or plant swaying in the wind (see wind.gdshaderinc and
// scripts/world/wind.gd): each row of the picture slides sideways, the top
// the farthest and the foot not at all, so trunks stay rooted. Needs a sprite
// that draws its whole texture with its foot on the bottom edge. A shader
// that includes this puts SWAY_VERTEX in vertex() and reads its texture at
// sway_uv(...), times sway_inside(...) and sway_modulate.

#include "res://assets/shaders/wind.gdshaderinc"

// How far the top leans in a full gust, in texture pixels (0 stands still).
uniform float sway = 0.0;

// Room either side of the picture for the lean, in texture pixels.
const float SWAY_PAD = 16.0;

// Where in the world the plant stands, and the sprite's modulate.
varying flat vec2 sway_foot;
varying vec4 sway_modulate;

// Widens the quad so a leaning top isn't cut off.
#define SWAY_VERTEX \
	sway_modulate = COLOR; \
	sway_foot = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xy; \
	if (sway > 0.0) { \
		float sway_side = UV.x < 0.5 ? -1.0 : 1.0; \
		VERTEX.x += sway_side * SWAY_PAD; \
		UV.x += sway_side * SWAY_PAD * TEXTURE_PIXEL_SIZE.x; \
	}

// Where to read the texture for the pixel at uv.
vec2 sway_uv(vec2 uv, vec2 texel, vec2 foot, float t) {
	if (sway <= 0.0) {
		return uv;
	}
	float row = floor(uv.y / texel.y);
	return uv - vec2(sway_offset(sway, 1.0 - uv.y, row, foot, t) * texel.x, 0.0);
}

// 1 inside the picture, 0 in the room the widened quad leaves either side.
float sway_inside(vec2 uv) {
	return step(0.0, uv.x) * step(uv.x, 1.0);
}
