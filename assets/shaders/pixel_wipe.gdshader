shader_type canvas_item;
// The screen transition between places: rather than a flat fade, the
// screen fills with pixel diamonds that grow in a sweep from the top left
// and shrink away the same way, as cozy pixel games wipe between scenes.
// The ColorRect's alpha is the progress (0 clear, 1 covered), so code that
// tweens the fade's color.a drives it unchanged.

// The rect's size in UI pixels (the 480 x 270 menu screen).
uniform vec2 rect_size = vec2(480.0, 270.0);
// Width of one diamond's cell, in UI pixels.
uniform float cell = 16.0;
// How much of the sweep the diamonds trail behind each other.
uniform float lag = 0.7;

void fragment() {
	float progress = COLOR.a;
	vec2 px = floor(UV * rect_size);
	vec2 grid = floor(px / cell);
	vec2 cells = ceil(rect_size / cell);
	// 0 at the top left cell, 1 at the bottom right one
	float sweep = (grid.x / max(cells.x - 1.0, 1.0) + grid.y / max(cells.y - 1.0, 1.0)) * 0.5;
	vec2 local = (px - grid * cell + 0.5) / cell - 0.5;
	float diamond = abs(local.x) + abs(local.y);
	float radius = clamp(progress * (1.0 + lag) - sweep * lag, 0.0, 1.0) * 1.02;
	float covered = progress >= 0.999 ? 1.0 : step(diamond, radius) * step(0.001, progress);
	COLOR = vec4(COLOR.rgb, covered);
}
