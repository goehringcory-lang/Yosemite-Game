shader_type canvas_item;
// Fades a sprite out toward its top and bottom edges, so white water laid
// on its side (Tuolumne Falls in Glen Aulin, a wall fall's frames turned
// along the river) melts into the river instead of ending in a hard line.

uniform float top_fade : hint_range(0.0, 0.5) = 0.18;
uniform float bottom_fade : hint_range(0.0, 0.5) = 0.3;

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	c.a *= smoothstep(0.0, top_fade, UV.y) * (1.0 - smoothstep(1.0 - bottom_fade, 1.0, UV.y));
	COLOR = c * COLOR;
}
