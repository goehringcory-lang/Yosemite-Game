shader_type canvas_item;
// HD-2D cinematic post-processing pass (scripts/world/hd2d_post.gd), running on
// CanvasLayer 2 right after Atmosphere and below all UI/HUD layers (High
// graphics only).
//
// Delivers the signature HD-2D diorama polish while keeping the playable center
// 100% razor-sharp pixel art:
//  1. Tilt-shift miniature Depth-of-Field (8-tap disk) gently softening only
//     the extreme top and bottom bands of the viewport.
//  2. Subtle aerial perspective haze near the top of outdoor views (cool sky
//     blue by day, warm gold at sunrise/sunset, deep indigo at night).
//  3. Subtle micro-contrast clarity in the focused center band.
//  4. Gentle filmic highlight compression so firelight, snow and golden-hour
//     glints stay rich without clipping.

uniform sampler2D screen : hint_screen_texture, filter_nearest;

uniform float dof_strength : hint_range(0.0, 1.0) = 0.72;
uniform float dof_radius : hint_range(0.0, 6.0) = 2.6;
// Aerial perspective mist near the top of outdoor views (0 indoors).
uniform float aerial_strength : hint_range(0.0, 0.5) = 0.0;
uniform vec3 aerial_color : source_color = vec3(0.76, 0.85, 0.96);
// Subtle clarity / micro-contrast in the focused playable band.
uniform float clarity : hint_range(0.0, 0.5) = 0.14;
// Master blend (0 = passthrough).
uniform float strength : hint_range(0.0, 1.0) = 1.0;

vec3 filmic_soft(vec3 c) {
	vec3 base = min(c, vec3(0.84));
	vec3 excess = max(c - vec3(0.84), vec3(0.0));
	vec3 compressed = base + excess / (vec3(1.0) + excess * 1.4);
	return mix(c, compressed, 0.6);
}

vec3 sample_screen(vec2 uv) {
	return texture(screen, clamp(uv, vec2(0.001), vec2(0.999))).rgb;
}

void fragment() {
	vec2 px = SCREEN_PIXEL_SIZE;
	vec3 center = sample_screen(SCREEN_UV);

	// Tilt-shift focus band: center ~68% (y in [0.16..0.85]) stays 100% sharp.
	float top_blur = 1.0 - smoothstep(0.0, 0.17, SCREEN_UV.y);
	float bot_blur = smoothstep(0.85, 1.0, SCREEN_UV.y);
	float coc = max(top_blur, bot_blur * 0.85) * dof_strength;

	vec3 col = center;
	if (coc > 0.01) {
		float r = coc * dof_radius;
		vec3 acc = center * 0.20;
		acc += sample_screen(SCREEN_UV + vec2( r,  0.0) * px) * 0.10;
		acc += sample_screen(SCREEN_UV + vec2(-r,  0.0) * px) * 0.10;
		acc += sample_screen(SCREEN_UV + vec2( 0.0,  r) * px) * 0.10;
		acc += sample_screen(SCREEN_UV + vec2( 0.0, -r) * px) * 0.10;
		float d = r * 0.7071;
		acc += sample_screen(SCREEN_UV + vec2( d,  d) * px) * 0.10;
		acc += sample_screen(SCREEN_UV + vec2(-d,  d) * px) * 0.10;
		acc += sample_screen(SCREEN_UV + vec2( d, -d) * px) * 0.10;
		acc += sample_screen(SCREEN_UV + vec2(-d, -d) * px) * 0.10;
		col = acc;

		// Ultra-subtle optical chromatic fringe only at out-of-focus corners.
		vec2 radial = SCREEN_UV - vec2(0.5);
		float edge = smoothstep(0.32, 0.72, length(radial)) * coc;
		if (edge > 0.02) {
			vec2 ca_off = radial * edge * 1.4 * px;
			col.r = mix(col.r, sample_screen(SCREEN_UV + ca_off).r, 0.35);
			col.b = mix(col.b, sample_screen(SCREEN_UV - ca_off).b, 0.35);
		}
	} else if (clarity > 0.001) {
		// Subtle micro-contrast clarity in the sharp playable band.
		vec3 blur4 = (
			sample_screen(SCREEN_UV + vec2( px.x,  px.y) * 1.5) +
			sample_screen(SCREEN_UV + vec2(-px.x,  px.y) * 1.5) +
			sample_screen(SCREEN_UV + vec2( px.x, -px.y) * 1.5) +
			sample_screen(SCREEN_UV + vec2(-px.x, -px.y) * 1.5)
		) * 0.25;
		vec3 detail = clamp(center - blur4, vec3(-0.08), vec3(0.08));
		col = clamp(center + detail * clarity * 1.6, vec3(0.0), vec3(1.5));
	}

	// Aerial perspective haze near the distant top edge of outdoor scenes.
	if (aerial_strength > 0.001) {
		float dist_band = 1.0 - smoothstep(0.0, 0.26, SCREEN_UV.y);
		col = mix(col, aerial_color, dist_band * aerial_strength);
	}

	col = filmic_soft(col);
	COLOR = vec4(mix(center, col, strength), 1.0);
}
