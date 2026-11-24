shader_type canvas_item;
render_mode blend_disabled;
// Composites the resolved 2D Radiance Cascades Global Illumination onto the
// rendered world (scripts/world/radiance_gi.gd), sitting on CanvasLayer 0
// right above the world canvas (so DayNight/RoomLight don't double-tint it,
// AirGlow still blooms its bright cores, and Atmosphere grades it on layer 1).
//
// - Night & indoor emissive GI: occluded light pools and warm bounce from
//   campfires, lamps, lit windows, string lights, hearths, and headlamps.
// - Daytime ambient occlusion & warm bounce: subtle sky-visibility darkening
//   under dense tree stands, beside boulders and building walls, plus soft
//   warm light in open sunlit clearings.

uniform sampler2D screen : hint_screen_texture, filter_nearest;
uniform sampler2D gi_tex : filter_linear, repeat_disable;

// Active world tint (DayNight indoors-off -> RoomLight or white), used to
// recover un-tinted albedo so warm GI lights reveal surface colour naturally.
uniform vec3 tint : source_color = vec3(1.0);
// Strength of additive occluded GI light (strong at night and indoors).
uniform float gi_strength : hint_range(0.0, 2.0) = 1.0;
// Strength of daytime sky-occlusion ambient darkening (strong outdoors by day).
uniform float ao_strength : hint_range(0.0, 1.0) = 0.0;
// Cool tint for occluded ambient pockets (matches blue Yosemite sky shade).
uniform vec3 ao_color : source_color = vec3(0.74, 0.80, 0.94);
// Subtle warm bounce tint in sunlit high-visibility areas (golden hour / granite).
uniform vec3 bounce_tint : source_color = vec3(1.0, 0.92, 0.78);
uniform float bounce_strength : hint_range(0.0, 0.5) = 0.0;
// Overall master blend (0 = passthrough).
uniform float strength : hint_range(0.0, 1.0) = 1.0;

void fragment() {
	vec3 c = texture(screen, SCREEN_UV).rgb;
	vec4 gi = texture(gi_tex, SCREEN_UV);

	vec3 out_col = c;

	// 1. Daytime ambient occlusion + subtle warm sky/granite bounce.
	if (ao_strength > 0.001) {
		float sky_vis = clamp(gi.a, 0.0, 1.0);
		float occ = smoothstep(0.15, 0.85, sky_vis);
		vec3 ao_factor = mix(ao_color, vec3(1.0), occ);
		out_col *= mix(vec3(1.0), ao_factor, ao_strength * 0.36);
	}

	// 2. Occluded emissive GI (fires, lamps, windows, hearths, headlamps).
	if (gi_strength > 0.001) {
		vec3 rad = max(gi.rgb, vec3(0.0));
		// Recover approximate surface albedo so firelight reveals true colours
		// under the dark blue night tint without turning dark bark neon.
		vec3 albedo = clamp(c / max(tint, vec3(0.14)), vec3(0.0), vec3(1.25));
		// Filmic shoulder: boosts wide, soft mid-range bounce while keeping
		// emitter cores rich golden-amber instead of blowing out to flat white.
		vec3 soft_rad = (rad * 1.55) / (vec3(1.0) + rad * 1.15);
		vec3 lit_surface = albedo * soft_rad * gi_strength;
		// Subtle atmospheric scatter in the air around bright emitters.
		vec3 air_scatter = soft_rad * gi_strength * 0.06;
		out_col += lit_surface + air_scatter;
	}

	// 3. Subtle warm granite/golden-hour indirect bounce outdoors.
	if (bounce_strength > 0.001) {
		float bounce_vis = smoothstep(0.25, 0.95, clamp(gi.a, 0.0, 1.0));
		out_col += out_col * bounce_tint * bounce_vis * bounce_strength * 0.14;
	}

	COLOR = vec4(mix(c, out_col, strength), 1.0);
}
