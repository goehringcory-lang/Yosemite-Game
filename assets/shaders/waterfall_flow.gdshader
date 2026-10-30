shader_type canvas_item;
// A waterfall's ribbon thinned to the season's flow (see
// scripts/world/seasonal_falls.gd). Each row of the drawing is cut down to
// the middle part of its own ribbon, so the fall keeps its shape and its
// animation and just carries less water. A dry fall leaves the dark streak
// that years of water have stained down the granite.

// 1 is the full spring fall, 0 the thinnest trickle
uniform float flow : hint_range(0.0, 1.0) = 1.0;
uniform bool dry = false;
const vec4 STAIN = vec4(0.16, 0.15, 0.15, 0.42);

void fragment() {
	// COLOR comes in as the texture times the sprite's modulate
	int w = textureSize(TEXTURE, 0).x;
	float left = 2.0;
	float right = -1.0;
	for (int i = 0; i < w; i += 2) {
		float x = (float(i) + 1.0) / float(w);
		if (texture(TEXTURE, vec2(x, UV.y)).a > 0.1) {
			left = min(left, x);
			right = max(right, x);
		}
	}
	float mid = (left + right) * 0.5;
	float half_width = (right - left) * 0.5;
	// whole art pixels (2 texture pixels), so the edge stays crisp
	float art = 2.0 / float(w);
	float off = floor(abs(UV.x - mid) / art) * art;
	if (dry) {
		COLOR = right >= left && off <= max(half_width * 0.18, art) ? STAIN : vec4(0.0);
	} else if (right < left || off > max(half_width * mix(0.12, 1.0, flow), art)) {
		COLOR = vec4(0.0);
	} else {
		COLOR.a *= mix(0.6, 1.0, flow);
	}
}
