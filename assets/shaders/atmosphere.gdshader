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
// In the high country (alpine = 1, scripts/world/high_country.gd) the thin air
// is clearer: colour a touch richer, shade lit by a deep blue sky, alpenglow
// stronger on the domes, nights darker and bluer; and before the afternoon
// storm (gloom) the light goes slate grey under the clouds.
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
// How much the shade cools under a low, warm sun (0 leaves the old wash).
uniform float low_sun : hint_range(0.0, 1.0) = 0.6;
uniform float alpenglow : hint_range(0.0, 1.0) = 0.0;
uniform vec3 alpen_color : source_color = vec3(1.0, 0.66, 0.58);
uniform float night : hint_range(0.0, 1.0) = 0.0;
uniform vec3 moon_color : source_color = vec3(0.62, 0.72, 1.0);
uniform float haze : hint_range(0.0, 1.0) = 0.0;
uniform vec3 haze_color : source_color = vec3(0.78, 0.82, 0.9);
uniform float alpine : hint_range(0.0, 1.0) = 0.0;
uniform float gloom : hint_range(0.0, 1.0) = 0.0;

float luma(vec3 c) {
	return dot(c, vec3(0.299, 0.587, 0.114));
}

// Each step below only runs when its uniform is on (most are off at any one
// hour: no golden hour at noon, no night by day, no alpine air in the
// Valley); a step that is off would leave the colour exactly as it was, so
// skipping it changes nothing but the cost.
void fragment() {
	vec3 c = texture(screen, SCREEN_UV).rgb;
	float lum = luma(c);
	float tint_lum = max(luma(tint), 0.05);
	float day = 1.0 - night;
	// How warm the day's tint is now (0 white or blue, 1 amber or orange).
	float warmth = smoothstep(0.12, 0.45, (tint.r - tint.b) / max(tint.r, 0.05));
	// Before sunrise and after sunset: the tint dim and not warm.
	float dusk = (1.0 - warmth) * day * (1.0 - smoothstep(0.7, 0.85, tint_lum));
	bool low = warmth * low_sun > 0.0;
	bool high = alpine * day > 0.0;
	bool pale_light = warmth > 0.0 || dusk > 0.0;
	// The colour of the thing itself, with today's light taken back out, and
	// whether a lamp or fire lights it (much brighter than the light around
	// it); only the steps below that need them work them out.
	vec3 base = vec3(0.0);
	float base_lum = 0.0;
	float base_sat = 0.0;
	float lit = 0.0;
	if (pale_light || low || high || alpenglow > 0.0 || gloom > 0.0 || night > 0.0) {
		base = c / max(tint, vec3(0.05));
		base_lum = luma(base);
		base_sat = max(base.r, max(base.g, base.b)) - min(base.r, min(base.g, base.b));
		lit = smoothstep(1.15, 1.7, lum / tint_lum);
	}

	// Full daylight (the tint near white, no night): crisper, as the high sun
	// gives hard light; the S-curve and the warm/cool split go a little
	// further than in the soft light of morning and evening.
	float mid = smoothstep(0.85, 0.97, tint_lum) * day;
	vec3 g = mix(c, c * c * (3.0 - 2.0 * c), 0.18 + 0.1 * mid);
	vec3 tone = mix(cool, warm, smoothstep(0.15, 0.75, lum));
	g = mix(g, g * tone * 1.04, 0.32 + 0.08 * mid);

	// Pale, nearly colourless things (paving, sand, granite, white paint) take
	// a coloured light most plainly, so they show what the light is like.
	if (pale_light) {
		float pale = smoothstep(0.45, 0.8, base_lum) * (1.0 - smoothstep(0.15, 0.35, base_sat)) * (1.0 - lit);

		// Golden hour: the low sun turns pale things cream and gold, not salmon.
		// The tint's orange stays in the midtones; the pale surfaces keep its
		// brightness but take a gold light (luma about 1, so nothing dims).
		g = mix(g, base * tint_lum * vec3(1.28, 1.07, 0.74), pale * warmth * 0.55);

		// After sunset and before sunrise, the light is the blue of the sky:
		// pale things go a dim cool blue rather than lilac or mauve.
		g = mix(g, base * tint_lum * vec3(0.9, 1.02, 1.24), pale * dusk * 0.7);
	}

	// Golden hour: warmer and a little richer.
	if (golden > 0.0) {
		float gl = luma(g);
		g = mix(g, mix(vec3(gl), g, 1.1) * vec3(1.03, 1.0, 0.96), golden * 0.4);
	}

	// Low sun: the day's tint lays its orange over everything alike, but the
	// low sun only reaches what stands in its light. What it doesn't (the
	// dark of the trees, asphalt, the long shadows) is lit by the blue sky
	// overhead, so the darks give the orange back and lean cool, and the
	// evening reads as warm light and cool shade, not as a pink wash.
	if (low) {
		float shade = 1.0 - smoothstep(0.12, 0.5, base_lum);
		vec3 sky_lit = base * tint_lum * vec3(0.88, 0.95, 1.16);
		g = mix(g, mix(sky_lit, sky_lit * sky_lit * (3.0 - 2.0 * sky_lit), 0.18), warmth * shade * low_sun * (1.0 - lit));
	}

	// High country by day: clear air, so colour is a touch richer, and the
	// shade (lit by the deep blue sky overhead, not the sun) leans blue.
	if (high) {
		float al = luma(g);
		g = mix(g, mix(vec3(al), g, 1.1), alpine * day * (1.0 - gloom));
		float shadow = 1.0 - smoothstep(0.1, 0.42, base_lum);
		g = mix(g, g * vec3(0.88, 0.95, 1.14), alpine * shadow * day * 0.4 * (1.0 - lit));
	}

	// Alpenglow on pale, colourless things: granite, snow, pale sand. It takes
	// the place of the tint's own colour rather than multiplying it (pink on
	// a mauve dusk made magenta), and in the valley it is only a blush on the
	// paving; up high the domes and snow catch it strongly.
	if (alpenglow > 0.0) {
		float rock = smoothstep(0.5, 0.72, base_lum) * (1.0 - smoothstep(0.1, 0.24, base_sat)) * (1.0 - lit);
		g = mix(g, base * tint_lum * alpen_color * 1.35, rock * alpenglow * (0.3 + alpine * 0.5));
	}

	// Storm light: under the thunderheads the colour goes out of the meadow
	// and the light turns slate.
	if (gloom > 0.0) {
		float sl = luma(g);
		g = mix(g, vec3(sl) * vec3(0.82, 0.88, 0.97), gloom * 0.38 * (1.0 - lit));
		g *= 1.0 - gloom * 0.1 * (1.0 - lit);
	}

	// Night: colour drains from what the lamps don't reach. Up high the
	// starlight is darker and bluer, with no valley haze to lift it.
	if (night > 0.0) {
		float nl = luma(g);
		vec3 moon = moon_color * mix(vec3(1.0), vec3(0.88, 0.95, 1.12), alpine);
		vec3 moonlit = vec3(nl) * moon * (1.08 - alpine * 0.14) + vec3(0.012, 0.016, 0.03);
		g = mix(g, moonlit, night * (0.55 + alpine * 0.15) * (1.0 - lit));
	}

	// Haze: the air softens the colour and lifts the deepest blacks a little,
	// without greying the whole picture.
	if (haze > 0.0) {
		g = mix(g, max(g, haze_color * 0.18 * tint_lum), haze * 0.5);
		g = mix(g, vec3(luma(g)), haze * 0.12);
		g = mix(g, haze_color * tint, haze * 0.06);
	}

	vec2 d = (SCREEN_UV - 0.5) * vec2(1.0, 0.78);
	float v = smoothstep(0.28, 0.72, length(d));
	g *= 1.0 - v * vignette * (1.0 + night * 0.6);

	COLOR = vec4(mix(c, g, strength), 1.0);
}
