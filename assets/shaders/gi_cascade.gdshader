shader_type canvas_item;
render_mode blend_disabled;
// One Radiance Cascade level (scripts/world/radiance_gi.gd), merged coarse to
// fine (cascade 3 -> 2 -> 1 -> 0) over a 256x144 probe-ray atlas.
//
// At cascade c:
//   spacing   = 2^(c + 1)         -> 2, 4, 8, 16 texels between probes
//   num_rays  = spacing * spacing -> 4, 16, 64, 256 angular bins per probe
//   interval  = [t_start, t_end]  -> [0,2], [2,8], [8,32], [32,128] texels
//
// Each ray sphere-traces the JFA distance field over its interval. If it hits
// an emitter or occluder, it collects that surface's HDR emission (and subtle
// bounce tint) and marks visibility = 0. If it stays clear through the
// interval, it bilinearly merges the 4 corresponding finer-angle sub-rays from
// the upper cascade (or adds sky/ambient radiance at the top cascade).

uniform sampler2D scene_tex : filter_nearest, repeat_disable;
uniform sampler2D sdf_tex : filter_nearest, repeat_disable;
uniform sampler2D upper_tex : filter_nearest, repeat_disable;

uniform vec2 resolution = vec2(256.0, 144.0);
uniform float max_dist = 256.0;
uniform int cascade_index = 0;
uniform int cascade_count = 4;
uniform float base_length = 2.0;
// Sky/ambient radiance gathered by rays that escape the top cascade (used for
// daytime sky-occlusion AO and subtle outdoor bounce).
uniform vec3 sky_radiance = vec3(0.0);
// How much sky visibility to record in .a when escaping the top cascade (1.0).
uniform float sky_ao_weight = 1.0;

const float PI_VAL = 3.14159265359;
const float TAU_VAL = 6.28318530718;
const int MAX_STEPS = 18;

// Sample one specific ray index [r_idx] from an integer probe [probe] in the
// upper cascade (spacing = [u_spacing], grid = [u_grid]).
vec4 fetch_upper_ray(vec2 probe, float r_idx, float u_spacing, vec2 u_grid) {
	vec2 clamped = clamp(probe, vec2(0.0), u_grid - vec2(1.0));
	float lx = mod(r_idx, u_spacing);
	float ly = floor(r_idx / u_spacing);
	vec2 px = clamped * u_spacing + vec2(lx, ly) + vec2(0.5);
	return texture(upper_tex, px / resolution);
}

void fragment() {
	float c = float(cascade_index);
	float spacing = exp2(c + 1.0);
	float num_rays = spacing * spacing;

	vec2 px = floor(SCREEN_UV * resolution);
	vec2 probe_id = floor(px / spacing);
	vec2 local_id = mod(px, spacing);
	float ray_idx = local_id.y * spacing + local_id.x;

	vec2 probe_pos = (probe_id + vec2(0.5)) * spacing;
	float angle = (ray_idx + 0.5) / num_rays * TAU_VAL;
	vec2 dir = vec2(cos(angle), sin(angle));

	float t_start = (cascade_index == 0) ? 0.0 : base_length * exp2(2.0 * c - 2.0);
	float t_end = base_length * exp2(2.0 * c);

	vec3 rad = vec3(0.0);
	float vis = 1.0;

	// If the probe itself sits inside an emitter, collect its glow immediately
	// on cascade 0 so lights don't leave dark cores.
	vec4 origin_scene = texture(scene_tex, probe_pos / resolution);
	if (cascade_index == 0 && origin_scene.a > 0.5 && dot(origin_scene.rgb, vec3(1.0)) > 0.01) {
		rad = origin_scene.rgb;
		vis = 0.0;
	} else {
		float t = t_start;
		// Slight start bias on cascade 0 when starting right next to an occluder
		// prevents self-shadowing from swallowing the front face of lit props.
		if (cascade_index == 0 && origin_scene.a > 0.5) {
			t = 1.1;
		}
		for (int i = 0; i < MAX_STEPS; i++) {
			if (t >= t_end) {
				break;
			}
			vec2 pos = probe_pos + dir * t;
			vec2 suv = pos / resolution;
			if (suv.x < 0.0 || suv.y < 0.0 || suv.x > 1.0 || suv.y > 1.0) {
				break;
			}
			float d = texture(sdf_tex, suv).r * max_dist;
			if (d < 0.55) {
				vec4 hit = texture(scene_tex, suv);
				if (hit.a > 0.5) {
					// Gentle 2D falloff so campfires, lamps and windows cast wide,
					// lush occluded light pools and soft penumbra shadows.
					float falloff = 1.0 / (1.0 + t * 0.012 + t * t * 0.00014);
					rad = hit.rgb * falloff;
					vis = 0.0;
					break;
				}
			}
			t += max(d * 0.85, 0.75);
		}
	}

	// Merge unoccluded rays with the upper cascade (or sky ambient at the top).
	if (vis > 0.5) {
		if (cascade_index >= cascade_count - 1) {
			rad += sky_radiance;
			vis = sky_ao_weight;
		} else {
			float u_spacing = spacing * 2.0;
			vec2 u_grid = resolution / u_spacing;
			vec2 u_coord = (probe_pos / u_spacing) - vec2(0.5);
			vec2 p00 = floor(u_coord);
			vec2 f = clamp(u_coord - p00, vec2(0.0), vec2(1.0));

			vec4 merged = vec4(0.0);
			float base_r = ray_idx * 4.0;
			for (int k = 0; k < 4; k++) {
				float r_k = base_r + float(k);
				vec4 s00 = fetch_upper_ray(p00, r_k, u_spacing, u_grid);
				vec4 s10 = fetch_upper_ray(p00 + vec2(1.0, 0.0), r_k, u_spacing, u_grid);
				vec4 s01 = fetch_upper_ray(p00 + vec2(0.0, 1.0), r_k, u_spacing, u_grid);
				vec4 s11 = fetch_upper_ray(p00 + vec2(1.0, 1.0), r_k, u_spacing, u_grid);
				vec4 top = mix(s00, s10, f.x);
				vec4 bot = mix(s01, s11, f.x);
				merged += mix(top, bot, f.y);
			}
			merged *= 0.25;
			rad += merged.rgb;
			vis = merged.a;
		}
	}

	COLOR = vec4(rad, vis);
}
