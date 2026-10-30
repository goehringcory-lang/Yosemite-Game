shader_type canvas_item;
// The outdoor grade (scripts/world/atmosphere.gd): the light of the valley over
// the whole picture, changing through the day. Shadows lean cool and lights
// lean warm, a gentle S-curve gives the midtones body, and the corners fall
// off a little, as through a lens. On top of that, from the sun's place in the
// sky (scripts/world/sun.gd):
//  - golden hour warms and richens the colour;
//  - alpenglow turns bare granite and snow pink and lifts it, after sunset;
//  - at night the unlit world goes silver-blue (the eye loses colour in the
//    dark), while lamplight keeps its warmth;
//  - haze (summer heat, fall smoke) softens the blacks.
// It reads the screen pixel for pixel, so the art stays crisp. (The halos
// round lamps and fires are NightLight's own.)

uniform sampler2D screen : hint_screen_texture, filter_nearest;
uniform float strength : hint_range(0.0, 1.0) = 1.0;
uniform vec3 warm : source_color = vec3(1.0, 0.93, 0.8);
uniform vec3 cool : source_color = vec3(0.78, 0.86, 1.0);
uniform float vignette : hint_range(0.0, 1.0) = 0.22;
// The day and night tint (DayNight) right now, so the shader can tell a
// grey rock from a grey dusk.
uniform vec3 tint : source_color = vec3(1.0);
uniform float golden : hint_range(0.0, 1.0) = 0.0;
uniform float alpenglow : hint_range(0.0, 1.0) = 0.0;
uniform vec3 alpen_color : source_color = vec3(1.0, 0.66, 0.58);
uniform float night : hint_range(0.0, 1.0) = 0.0;
uniform vec3 moon_color : source_color = vec3(0.62, 0.72, 1.0);
uniform float haze : hint_range(0.0, 1.0) = 0.0;
uniform vec3 haze_color : source_color = vec3(0.78, 0.82, 0.9);

float luma(vec3 c) {
	return dot(c, vec3(0.299, 0.587, 0.114));
}

void fragment() {
	vec3 c = texture(screen, SCREEN_UV).rgb;
	float lum = luma(c);
	float tint_lum = max(luma(tint), 0.05);
	// The colour of the thing itself, with today's light taken back out.
	vec3 base = c / max(tint, vec3(0.05));
	float base_lum = luma(base);
	float base_sat = max(base.r, max(base.g, base.b)) - min(base.r, min(base.g, base.b));
	// Lit by a lamp or fire: much brighter than the light around it.
	float lit = smoothstep(1.15, 1.7, lum / tint_lum);

	vec3 g = mix(c, c * c * (3.0 - 2.0 * c), 0.18);
	vec3 tone = mix(cool, warm, smoothstep(0.15, 0.75, lum));
	g = mix(g, g * tone * 1.04, 0.32);

	// Golden hour: warmer and a little richer.
	float gl = luma(g);
	g = mix(g, mix(vec3(gl), g, 1.1) * vec3(1.05, 1.0, 0.94), golden * 0.4);

	// Alpenglow on pale, colourless things: granite, snow, pale sand.
	float rock = smoothstep(0.4, 0.62, base_lum) * (1.0 - smoothstep(0.1, 0.24, base_sat));
	g = mix(g, g * alpen_color * 1.4, rock * alpenglow * 0.62);

	// Night: colour drains from what the lamps don't reach.
	float nl = luma(g);
	vec3 moonlit = vec3(nl) * moon_color * 1.08 + vec3(0.012, 0.016, 0.03);
	g = mix(g, moonlit, night * 0.55 * (1.0 - lit));

	// Haze: the blacks lift toward the colour of the air.
	g = mix(g, max(g, haze_color * 0.32), haze * 0.5);
	g = mix(g, haze_color * tint, haze * 0.06);

	vec2 d = (SCREEN_UV - 0.5) * vec2(1.0, 0.78);
	float v = smoothstep(0.28, 0.72, length(d));
	g *= 1.0 - v * vignette * (1.0 + night * 0.6);

	COLOR = vec4(mix(c, g, strength), 1.0);
}
