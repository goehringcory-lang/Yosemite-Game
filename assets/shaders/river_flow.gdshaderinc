// A running river drawn over its painted water, for a region whose ground has
// a "water_flow" (seasonal_ground.gdshader; the settings come from
// scripts/world/river_flow.gd). The painted water only says where the river
// is; its look is worked out here, per art pixel (2 texture pixels), from how
// far each pixel lies from the banks above and below it:
//
// - Depth. The shallows show the cobble bed through clear water, with light
//   (caustics) wavering over it; the river deepens toward its channel, which
//   hugs the cut bank (sod or a dark earth face) and shoals over a gravel bar.
//   Along the river it swells into dark pools and thins into runs.
// - Current. Lines drift downstream, faster out in the channel than by the
//   banks, and sun glints ride on them.
// - Riffles. Where the river narrows, or in a stretch marked rough (a fork
//   tumbling in), white water breaks in little crests that run with the
//   current and in standing waves that flicker in place.
// - Banks. Wavelets lap at a gravel bar's edge and wash up onto it, and the
//   bar's stones are dark and wet a pixel or two back from the water; a sod
//   bank throws a band of shade on the water below it.
//
// Every colour is one of the palette's water blues (and the bar's own greys
// and tans, darkened a step), so the river reads as the painted art does.

// Stretches of water that run another way, or not at all: rect in texture
// pixels (x, y, w, h; w 0 unused) and its flow (xy, texture pixels a second;
// zero is still water) and roughness (z, 0 calm to 1 white water).
uniform vec4 flow_zone[4];
uniform vec4 flow_zone_dir[4];
// Where the river and its banks lie (texture pixels); banks are only looked
// for in here, so the rest of the ground pays nothing.
uniform vec4 river_box = vec4(0.0);

const vec3 RW0 = vec3(0.078, 0.184, 0.278);   // 142f47
const vec3 RW1 = vec3(0.137, 0.337, 0.475);   // 235679
const vec3 RW2 = vec3(0.227, 0.525, 0.659);   // 3a86a8
const vec3 RW3 = vec3(0.388, 0.702, 0.776);   // 63b3c6
const vec3 RW4 = vec3(0.624, 0.847, 0.851);   // 9fd8d9
const vec3 RW5 = vec3(0.839, 0.945, 0.933);   // d6f1ee
// how many art pixels up and down to look for a bank, and where to look
// (Low graphics, the Compatibility renderer, looks in fewer places and
// leaves out the light on the bed and the wet stones on the bars.)
const int RV_REACH = 18;
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
#define RV_LITE
const int RV_N = 6;
const float RV_STEPS[6] = float[](1.0, 2.0, 3.0, 5.0, 9.0, 15.0);
#else
const int RV_N = 9;
const float RV_STEPS[9] = float[](1.0, 2.0, 3.0, 4.0, 6.0, 8.0, 11.0, 14.0, 18.0);
#endif

float rv_hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

float rv_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(rv_hash(i), rv_hash(i + vec2(1.0, 0.0)), f.x), mix(rv_hash(i + vec2(0.0, 1.0)), rv_hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

// painted water (as waterness() in seasonal_ground and water_surface)
bool rv_water(vec3 c) {
	float w = clamp((c.b - c.g) * 10.0, 0.0, 1.0) * step(c.r, c.g);
	w = max(w, clamp((c.b / max(c.g, 0.001) - 0.8) * 8.0, 0.0, 1.0) * step(c.r + 0.06, c.g) * step(c.r + 0.04, c.b));
	return w > 0.5;
}

// a bank of sod (green turf, or the dark earth face the river has cut into
// it) rather than a bar of gravel and sand
bool rv_sod(vec3 c) {
	float lum = dot(c, vec3(0.299, 0.587, 0.114));
	return (c.g > c.r + 0.03 && c.g > c.b) || lum < 0.26;
}

vec3 rv_at(sampler2D tex, vec2 ap, vec2 tp) {
	return texture(tex, (ap * 2.0 + 1.0) * tp).rgb;
}

// the flow here (xy) and how rough the water is (z)
vec3 rv_flow(vec2 tpx, vec2 base) {
	for (int i = 0; i < 4; i++) {
		vec4 r = flow_zone[i];
		if (r.z > 0.0 && tpx.x >= r.x && tpx.y >= r.y && tpx.x < r.x + r.z && tpx.y < r.y + r.w) {
			return flow_zone_dir[i].xyz;
		}
	}
	return vec3(base, 0.0);
}

// Worley noise: x the distance to the nearest point, y to the second, z the
// nearest cell's hash.
vec3 rv_cells(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	float d1 = 9.0;
	float d2 = 9.0;
	float id = 0.0;
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 o = vec2(float(x), float(y));
			float h = rv_hash(i + o);
			float k = rv_hash(i + o + 17.0);
			vec2 pt = o + vec2(h, k);
			float d = length(pt - f);
			if (d < d1) {
				d2 = d1;
				d1 = d;
				id = h;
			} else if (d < d2) {
				d2 = d;
			}
		}
	}
	return vec3(d1, d2, id);
}

// one step lighter on the water ramp
vec3 rv_lighter(vec3 c) {
	if (distance(c, RW0) < 0.03) return RW1;
	if (distance(c, RW1) < 0.03) return RW2;
	if (distance(c, RW2) < 0.03) return RW3;
	return RW4;
}

// The river's colour at texture coordinate [uv] (painted water there).
vec3 river_water(sampler2D tex, vec2 uv, vec2 tp, vec2 base_flow, float t) {
	vec2 tpx = uv / tp;
	vec2 ap = floor(tpx * 0.5);
	vec3 f = rv_flow(tpx, base_flow);
	bool runs = f.xy != vec2(0.0);
	// the banks above and below, and what they are
	float up = float(RV_REACH + 1);
	float dn = float(RV_REACH + 1);
	bool up_sod = false;
	bool dn_sod = false;
	// a step at a time near the water's edge, then in longer strides (the
	// depth stops changing out in the channel, and every look costs)
	for (int i = 0; i < RV_N; i++) {
		float r = RV_STEPS[i];
		vec3 c = rv_at(tex, ap - vec2(0.0, r), tp);
		if (!rv_water(c)) {
			up = r;
			up_sod = rv_sod(c);
			break;
		}
	}
	for (int i = 0; i < RV_N; i++) {
		float r = RV_STEPS[i];
		vec3 c = rv_at(tex, ap + vec2(0.0, r), tp);
		if (!rv_water(c)) {
			dn = r;
			dn_sod = rv_sod(c);
			break;
		}
	}
	float width = up + dn - 1.0;
	// depth from the nearer bank: a gravel bar shoals out gently, a cut bank
	// drops away at once; a narrow river is shallow all the way across
	bool near_up = up <= dn;
	float bank = near_up ? up : dn;
	bool sod = near_up ? up_sod : dn_sod;
	float across = smoothstep(0.0, sod ? 6.0 : 16.0, bank - 0.5);
	// pools and runs along the river
	float pool = rv_noise(ap / vec2(34.0, 6.0) + vec2(3.7, 1.3));
	float depth = across * (0.45 + 0.55 * smoothstep(4.0, 16.0, width)) * (0.8 + 0.4 * pool);
	if (!runs) {
		depth = across * (0.5 + 0.5 * smoothstep(3.0, 12.0, width));
	}
	// ragged in 2x2 clusters, not ruled
	float d = depth + (rv_hash(floor(ap * 0.5) + 5.0) - 0.5) * 0.1;
	vec2 dir = runs ? normalize(f.xy) : vec2(-1.0, 0.0);
	vec2 nrm = vec2(-dir.y, dir.x);
	float speed = length(f.xy) * 0.5;   // art pixels a second
	float along = floor(dot(ap, dir) + 0.5);
	float row = floor(dot(ap, nrm) + 0.5);
	vec3 col;
	if (d < 0.2) {
		// the cobble bed, seen through a skin of water
		vec3 v = rv_cells(ap / 3.0);
		col = RW3;
		if (v.y - v.x < 0.18) {
			col = RW2;
		} else if (v.z > 0.55 && v.x < 0.4) {
			col = RW4;
		}
	} else if (d < 0.42) {
		col = RW2;
		vec3 v = rv_cells(ap / 3.5);
		if (v.z > 0.72 && v.x < 0.33) {
			col = RW3;
		}
	} else if (d < 0.95 || pool < 0.74) {
		col = RW1;
	} else {
		col = RW0;
	}
#ifndef RV_LITE
	if (d < 0.42) {
		// sunlight wavering over the bed: where two slowly drifting fields
		// cross, a thin bright line
		float w = runs ? 1.0 : 0.5;
		float n1 = rv_noise((ap - dir * t * speed * 0.15) / 4.0 + vec2(t * 0.21, 0.0) * w);
		float n2 = rv_noise(ap / 3.5 + vec2(7.3, t * 0.17 * w + 2.1));
		if (abs(n1 - n2) < 0.035) {
			col = rv_lighter(col);
		}
	}
#endif
	// shade on the water under a sod bank, a lit edge along a bar
	if (dn < 1.5 && dn_sod) {
		col = d > 0.5 ? RW0 : RW1;
	} else if (up < 1.5 && up_sod && d > 0.3) {
		col = RW1;
	}
	if (runs) {
		// current lines: thin streaks drifting downstream, every third row,
		// faster out in the channel than near the banks
		if (mod(row, 3.0) == 0.0 && d >= 0.2 && up > 1.5 && dn > 1.5) {
			float fast = across > 0.4 ? 1.0 : 0.6;
			float xs = along + floor(rv_hash(vec2(0.0, row)) * 40.0) - floor(t * speed * fast);
			float cell = floor(xs / 23.0);
			float lx = xs - cell * 23.0;
			if (rv_hash(vec2(cell, row)) < 0.24 + 0.1 * across && lx < 5.0 + floor(rv_hash(vec2(cell + 7.0, row)) * 10.0)) {
				col = d > 0.5 ? rv_lighter(rv_lighter(col)) : rv_lighter(col);
			}
		}
		// white water where the river narrows or a rough stretch tumbles:
		// aerated water a shade paler, and little V-shaped crests where the
		// current breaks over stones, opening upstream, breaking on and off
		float rough = max(f.z, smoothstep(9.0, 4.0, width) * 0.75) * smoothstep(0.05, 0.3, d);
		if (rough > 0.0) {
			if (rv_noise(ap / 5.0 - dir * t * speed * 0.2) < rough * 0.7 && rv_hash(floor(ap * 0.5) + 23.0) < 0.6) {
				col = rv_lighter(col);
			}
			float a2 = along - floor(t * speed * 0.25);
			vec2 cid = vec2(floor((a2 + floor(rv_hash(vec2(floor(row / 5.0), 8.0)) * 9.0)) / 9.0), floor(row / 5.0));
			float h = rv_hash(cid + 51.0);
			if (h < rough * 0.85 && rv_hash(cid + floor(t * 2.5 + h * 7.0)) < 0.8) {
				float tip = cid.x * 9.0 - floor(rv_hash(vec2(floor(row / 5.0), 8.0)) * 9.0) + 3.0 + floor(h * 3.0);
				float da = a2 - tip;
				float dr = abs(row - (cid.y * 5.0 + 2.0));
				if (dr <= 2.0 && da == -dr) {
					col = dr < 0.5 ? RW5 : RW4;
				}
			}
		}
	}
	// wavelets lapping at a gravel bar
	if ((up < 1.5 && !up_sod) || (dn < 1.5 && !dn_sod)) {
		float lap = sin(t * 1.7 + along * 0.33 + rv_hash(vec2(floor(along / 9.0), 2.0)) * 4.0);
		col = lap > 0.55 ? RW5 : (lap > -0.2 ? RW4 : col);
	} else if ((up < 2.5 && !up_sod) || (dn < 2.5 && !dn_sod)) {
		float lap = sin(t * 1.7 + along * 0.33 + rv_hash(vec2(floor(along / 9.0), 2.0)) * 4.0 - 0.9);
		if (lap > 0.7) {
			col = RW4;
		}
	}
	// glints of sun riding the current: one pixel in a cell now and then
	if (d >= 0.3) {
		vec2 q = ap - dir * floor(t * speed);
		vec2 gp = floor(q / 7.0);
		vec2 spot = floor(vec2(rv_hash(gp + 2.0), rv_hash(gp + 4.0)) * 7.0);
		if (q - gp * 7.0 == spot && rv_hash(gp + floor(t * 1.5 + rv_hash(gp) * 5.0)) > 0.9) {
			col = RW5;
		}
	}
	return col;
}

// darker by a step, for wet stones: the bar's greys and tans
vec3 rv_wet(vec3 c) {
	float lum = dot(c, vec3(0.299, 0.587, 0.114));
	if (abs(c.r - c.b) < 0.08) {
		// grey: e4ddcc bdb8ae 93918f 6a6a70 47464d
		return lum > 0.8 ? vec3(0.741, 0.722, 0.682) : (lum > 0.66 ? vec3(0.576, 0.569, 0.561) : (lum > 0.5 ? vec3(0.416, 0.416, 0.439) : vec3(0.278, 0.275, 0.302)));
	}
	// tan: d6bd88 b0925f 86694b 6b4829
	return lum > 0.68 ? vec3(0.69, 0.573, 0.373) : (lum > 0.52 ? vec3(0.525, 0.412, 0.294) : vec3(0.42, 0.282, 0.161));
}

// A bank pixel by the river (painted land at [uv], [c]): a gravel bar's
// stones wet a pixel or two back, and the wash running up onto it.
vec3 river_bank(sampler2D tex, vec2 uv, vec2 tp, vec3 c, float t) {
#ifdef RV_LITE
	return c;
#endif
	vec2 tpx = uv / tp;
	if (tpx.x < river_box.x || tpx.y < river_box.y || tpx.x >= river_box.x + river_box.z || tpx.y >= river_box.y + river_box.w) {
		return c;
	}
	if (rv_sod(c)) {
		return c;
	}
	vec2 ap = floor(tpx * 0.5);
	// two art pixels off first: the river is never thinner than that, so
	// with no water there, there is none nearer either (most pixels stop here)
	if (!rv_water(rv_at(tex, ap + vec2(0.0, 2.0), tp)) && !rv_water(rv_at(tex, ap - vec2(0.0, 2.0), tp))) {
		return c;
	}
	bool w1 = rv_water(rv_at(tex, ap + vec2(0.0, 1.0), tp)) || rv_water(rv_at(tex, ap - vec2(0.0, 1.0), tp));
	float lap = sin(t * 1.7 + ap.x * -0.33 + rv_hash(vec2(floor(-ap.x / 9.0), 2.0)) * 4.0);
	if (w1 && lap > 0.8) {
		return RW4;
	}
	if (w1 || rv_hash(floor(ap * 0.5) + 9.0) < 0.5) {
		return rv_wet(c);
	}
	return c;
}
