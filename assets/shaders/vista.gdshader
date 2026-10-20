shader_type canvas_item;
// The far view past an overlook's rim (Tunnel View, Glacier Point). The
// sprite is the drop: transparent over the land, the lit lip and the cliff's
// shadow drawn in, and everywhere else the marker color, where this shows a
// painting of the view instead. The painting hangs nearly still on the
// screen as you walk, the way something miles off does: it slides by only
// [parallax] of the camera's movement, measured from [anchor], the camera's
// top-left at the overlook, where the screen's top-left shows the painting's
// pixel [offset]. Its waterfalls shimmer, like the title painting's.

uniform sampler2D painting : filter_nearest, repeat_disable;
// The game's screen in world pixels.
uniform vec2 screen_size = vec2(960.0, 540.0);
uniform vec2 anchor;
uniform vec2 offset;
uniform vec2 parallax = vec2(0.0, 0.2);
// Where the painting shows (the view's haze, merced 235679).
uniform vec3 marker : source_color = vec3(0.137, 0.337, 0.475);
// Up to six falls in painting pixels: top xy, bottom xy; and the half width
// at the top and bottom.
uniform vec4 falls[6];
uniform vec2 fall_widths[6];
uniform int fall_count = 0;

varying vec2 world;

void vertex() {
	world = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

float hash(float n) {
	return fract(sin(n * 12.9898) * 43758.5453);
}

void fragment() {
	vec4 own = texture(TEXTURE, UV);
	if (own.a > 0.5 && distance(own.rgb, marker) < 0.03) {
		vec2 screen = SCREEN_UV * screen_size;
		vec2 cam = world - screen;
		vec2 size = vec2(textureSize(painting, 0));
		vec2 p = clamp(screen + offset + (cam - anchor) * parallax, vec2(0.5), size - 0.5);
		vec3 col = texture(painting, p / size).rgb;
		// the painting is drawn two screen pixels to its pixel
		vec2 q = floor(p / 2.0) * 2.0 + 1.0;
		for (int i = 0; i < fall_count; i++) {
			vec4 f = falls[i];
			float t = (q.y - f.y) / (f.w - f.y);
			float mid = mix(f.x, f.z, t);
			float half_w = mix(fall_widths[i].x, fall_widths[i].y, t);
			if (t < 0.0 || t > 1.0 || abs(q.x - mid) > half_w) {
				continue;
			}
			float stream = floor((q.x - mid) / 3.0);
			float phase = fract(TIME * 0.8 - q.y * 0.018 + hash(stream + float(i) * 7.0));
			if (phase < 0.18) {
				col = mix(col, vec3(0.961, 0.933, 0.878), 0.85);
			} else if (phase < 0.32) {
				col = mix(col, vec3(0.624, 0.847, 0.851), 0.6);
			}
		}
		COLOR = vec4(col, 1.0);
	} else {
		COLOR = own;
	}
}
