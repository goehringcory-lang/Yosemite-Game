shader_type canvas_item;
// A room's window glass (RoomWindows), drawn over the painted noon view:
// the sky in the glass takes the hour's colors (ClimbSky's palette), with
// stars at night, and the land beyond darkens to a silhouette after sunset.
// Stained glass just goes dark when there's no daylight behind it.

uniform vec2 pane_size = vec2(64.0, 64.0);
uniform vec3 sky_top : source_color = vec3(0.24, 0.47, 0.78);
uniform vec3 sky_mid : source_color = vec3(0.5, 0.7, 0.88);
uniform vec3 sky_low : source_color = vec3(0.86, 0.92, 0.94);
// How much of the hour's sky replaces the painted one (0 at midday).
uniform float sky_mix = 0.0;
// What the land beyond the glass is multiplied by.
uniform vec3 land_tint : source_color = vec3(1.0);
// 0 by day, 1 at full night: stars.
uniform float night = 0.0;
// How overcast it is: the sky goes grey.
uniform float clouds = 0.0;
uniform bool stained = false;

varying vec2 pane_px;

void vertex() {
	pane_px = VERTEX;
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec4 base = texture(TEXTURE, UV);
	vec3 c = base.rgb;
	if (stained) {
		COLOR = vec4(c * land_tint, base.a);
	} else {
		float v = clamp(pane_px.y / pane_size.y, 0.0, 1.0);
		float lum = dot(c, vec3(0.299, 0.587, 0.114));
		// sky: blue over red, or the near-white reflections high in the glass
		float sky = smoothstep(0.03, 0.1, c.b - c.r) * step(0.45, lum);
		sky = max(sky, step(0.82, lum) * (1.0 - smoothstep(0.35, 0.55, v)));
		vec3 grad = v < 0.5 ? mix(sky_top, sky_mid, v * 2.0) : mix(sky_mid, sky_low, v * 2.0 - 1.0);
		// the night sky a little lifted, so the ridgeline still reads
		grad *= 1.0 + 1.1 * night;
		grad = mix(grad, vec3(dot(grad, vec3(0.333))), clouds * 0.7);
		// stars, a few to a pane, twinkling
		vec2 cell = floor(pane_px);
		float star = step(0.985, hash(cell)) * (0.6 + 0.4 * sin(TIME * 2.0 + hash(cell + 3.1) * 6.28));
		grad += vec3(star) * night * (1.0 - clouds) * (1.0 - v);
		vec3 sky_c = mix(c, grad, sky_mix);
		vec3 land_c = c * land_tint;
		COLOR = vec4(mix(land_c, sky_c, sky), base.a);
	}
}
