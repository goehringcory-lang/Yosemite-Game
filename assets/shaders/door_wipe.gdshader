shader_type canvas_item;
// Going through a door: the place you left (a picture of the last frame
// there) opens up from where you stand in the new one, in the same pixel
// diamonds as the wipe between places (pixel_wipe.gdshader), so you step
// straight into the room with no dark screen between.

// 0 the old place covers everything, 1 it has opened away entirely.
uniform float progress : hint_range(0.0, 1.0) = 0.0;
// Where it opens from, in UV.
uniform vec2 center = vec2(0.5);
// The rect's size in pixels, and one diamond's cell.
uniform vec2 rect_size = vec2(960.0, 540.0);
uniform float cell = 16.0;
// How much of the opening the diamonds trail behind each other.
uniform float lag = 0.7;

void fragment() {
	vec2 px = floor(UV * rect_size);
	vec2 grid = floor(px / cell);
	vec2 mid = (grid + 0.5) * cell;
	// 0 at the cell where it opens, 1 at the farthest corner
	vec2 far = max(center, 1.0 - center) * rect_size;
	float sweep = clamp(length(mid - center * rect_size) / max(length(far), 1.0), 0.0, 1.0);
	vec2 local = (px - grid * cell + 0.5) / cell - 0.5;
	float diamond = abs(local.x) + abs(local.y);
	float radius = clamp(progress * (1.0 + lag) - sweep * lag, 0.0, 1.0) * 1.02;
	float open = progress >= 0.999 ? 1.0 : step(diamond, radius) * step(0.001, progress);
	COLOR = texture(TEXTURE, UV);
	COLOR.a *= 1.0 - open;
}
