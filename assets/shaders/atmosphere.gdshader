shader_type canvas_item;
// The outdoor grade (scripts/world/atmosphere.gd): the light of a valley
// afternoon over the whole picture. Shadows lean cool and lights lean warm, a
// gentle S-curve gives the midtones body, and the corners fall off a little,
// as through a lens. It reads the screen pixel for pixel, so the art stays crisp.

uniform sampler2D screen : hint_screen_texture, filter_nearest;
uniform float strength : hint_range(0.0, 1.0) = 1.0;
uniform vec3 warm : source_color = vec3(1.0, 0.93, 0.8);
uniform vec3 cool : source_color = vec3(0.78, 0.86, 1.0);
uniform float vignette : hint_range(0.0, 1.0) = 0.22;

void fragment() {
	vec3 c = texture(screen, SCREEN_UV).rgb;
	float lum = dot(c, vec3(0.299, 0.587, 0.114));
	vec3 g = mix(c, c * c * (3.0 - 2.0 * c), 0.18);
	vec3 tone = mix(cool, warm, smoothstep(0.15, 0.75, lum));
	g = mix(g, g * tone * 1.04, 0.32);
	vec2 d = (SCREEN_UV - 0.5) * vec2(1.0, 0.78);
	float v = smoothstep(0.28, 0.72, length(d));
	g *= 1.0 - v * vignette;
	COLOR = vec4(mix(c, g, strength), 1.0);
}
