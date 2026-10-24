shader_type canvas_item;
// A black-and-white print, for the sighting in Ansel Adams's negative
// (scripts/story/story_vista.gd): grey with a touch of warmth, deeper
// blacks, and a faint grain in 2x2 blocks so the pixel art stays crisp.

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec4 c = COLOR;
	float lum = dot(c.rgb, vec3(0.299, 0.587, 0.114));
	// Adams printed for full blacks and clean whites
	lum = smoothstep(0.06, 0.94, lum);
	vec2 cell = floor(FRAGCOORD.xy / 4.0);
	lum += (hash(cell) - 0.5) * 0.035;
	COLOR = vec4(vec3(lum) * vec3(1.02, 1.0, 0.96), c.a);
}
