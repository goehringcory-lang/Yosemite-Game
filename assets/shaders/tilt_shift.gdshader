shader_type canvas_item;
// Tilt-shift: the top and bottom of the picture go softly out of focus, the
// way a camera lens sees a model, so the valley reads as a lit diorama and
// the eye rests on the middle band where the player is. Reads the screen
// with its mipmaps (Forward+ only; see scripts/world/tilt_shift.gd).

uniform sampler2D screen : hint_screen_texture, filter_linear_mipmap;
// how far into the soft bands the blur reaches at most (mip levels)
uniform float strength : hint_range(0.0, 3.0) = 1.1;
// the sharp band: from this far down the screen to this far down
uniform float focus_top : hint_range(0.0, 1.0) = 0.2;
uniform float focus_bottom : hint_range(0.0, 1.0) = 0.84;

void fragment() {
	float y = SCREEN_UV.y;
	float soft = max(smoothstep(focus_top, 0.0, y), smoothstep(focus_bottom, 1.0, y));
	float lod = soft * soft * strength;
	vec3 sharp = textureLod(screen, SCREEN_UV, 0.0).rgb;
	// a few taps round the point at that level smooth the mip's blocks
	vec2 px = SCREEN_PIXEL_SIZE * exp2(lod) * 0.5;
	vec3 blurred = (textureLod(screen, SCREEN_UV + vec2(px.x, px.y), lod).rgb
		+ textureLod(screen, SCREEN_UV + vec2(-px.x, px.y), lod).rgb
		+ textureLod(screen, SCREEN_UV + vec2(px.x, -px.y), lod).rgb
		+ textureLod(screen, SCREEN_UV + vec2(-px.x, -px.y), lod).rgb) * 0.25;
	COLOR = vec4(mix(sharp, blurred, clamp(lod, 0.0, 1.0)), 1.0);
}
