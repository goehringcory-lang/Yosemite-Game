class_name ClimbLandscape
extends RefCounted
## What you see past the edge of the wall: the real skyline of each route,
## painted as layers of ridgelines and landmarks (Half Dome, El Capitan, the
## Three Brothers, Cathedral Peak's neighbors...) with haze that grows with
## distance, and the valley floor far below. The layers slide at different
## speeds as you climb, so height feels like height.
##
## Granite is painted in five flat tones (cream, tan, body, blue shade, deep
## shade) laid down a column at a time, with a narrow ordered-dither seam where
## one tone gives way to the next, vertical fluting, ledge lines, forest bands
## with conifer tops, and snow on the high peaks.

const P := preload("res://scripts/climb/art/climb_paint.gd")
const SCREEN := Vector2i(480, 270)
## Extra picture above each layer, so tall landmarks aren't cut off as the
## layers sink.
const PAD := 110

## Base line of each depth layer (0 far .. 2 near) in the layer's picture,
## and how much haze it carries.
const LAYER_BASE := [176, 198, 220]
const LAYER_HAZE := [0.4, 0.24, 0.09]
## Warm granite, lit to deep shade: cream, tan, body, blue shade, deep.
const GRANITE := ["f6e2b0", "dcb886", "b09478", "7f7ea0", "524f78"]
## How much of the sky's tint each tone takes.
const GRANITE_TINT := [0.32, 0.22, 0.12, 0.08, 0.06]

## width and height in pixels at scale 1, and the painter that shapes the
## landmark. See _profile().
const LANDMARKS := {
	"half_dome": {"w": 120, "h": 104, "trees": true, "lr": 1.0, "t0": 0.6, "flute": 0.3},
	"north_dome": {"w": 110, "h": 58, "trees": true},
	"basket_dome": {"w": 72, "h": 40, "trees": true},
	"liberty_cap": {"w": 56, "h": 70, "trees": true},
	"mt_broderick": {"w": 100, "h": 44, "trees": true},
	"glacier_point": {"w": 150, "h": 96, "trees": true, "rail": true, "lr": 1.5},
	"royal_arches": {"w": 150, "h": 82, "trees": true, "arches": true, "lr": 1.3},
	"washington_column": {"w": 76, "h": 96, "trees": true, "lr": 1.8},
	"sentinel_rock": {"w": 64, "h": 130, "trees": true, "fall": true, "lr": 1.8},
	"cathedral_rocks": {"w": 150, "h": 100, "trees": true, "gully": true},
	"el_capitan": {"w": 176, "h": 150, "streaks": true, "trees": true, "lr": 1.6, "t0": 1.1, "flute": 0.4},
	"three_brothers": {"w": 140, "h": 108, "trees": true, "lr": 1.2},
	"yosemite_falls": {"w": 130, "h": 140, "trees": true, "fall": true, "lr": 1.3, "t0": 1.0},
	"bridalveil": {"w": 84, "h": 100, "trees": true, "fall": true, "lr": 1.3, "t0": 1.0},
	"nevada_fall": {"w": 90, "h": 78, "trees": true, "fall": true, "lr": 1.3},
	"clouds_rest": {"w": 220, "h": 78, "trees": true, "lr": 1.8},
	"cockscomb": {"w": 130, "h": 80, "trees": false, "lr": 1.8, "flute": 0.7},
	"unicorn_peak": {"w": 76, "h": 118, "trees": false, "snow": true, "lr": 1.8, "flute": 0.7},
	"echo_peaks": {"w": 130, "h": 96, "trees": false, "snow": true, "lr": 1.8, "flute": 0.7},
	"matthes_crest": {"w": 170, "h": 70, "trees": false, "lr": 1.6, "flute": 0.7},
	"mt_lyell": {"w": 150, "h": 128, "trees": false, "snow": true, "glacier": true, "lr": 1.8, "flute": 0.6},
	"mt_maclure": {"w": 116, "h": 104, "trees": false, "snow": true, "glacier": true, "lr": 1.8, "flute": 0.6},
	"donohue_pass": {"w": 200, "h": 56, "trees": false, "snow": true, "lr": 1.8},
	"sierra_crest": {"w": 480, "h": 70, "trees": false, "snow": true, "lr": 1.6, "flute": 0.6},
}


## The landscape for [param route_id]'s profile, as layers back to front:
## [{"image": Image, "sink": float}] (sink = pixels the layer drops over the
## whole climb) plus "falls": waterfalls to shimmer {"x", "y0", "y1", "layer"}.
static func build(profile: Dictionary, pal: Dictionary, seed_value: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var layers: Array[Dictionary] = []
	var falls: Array[Dictionary] = []
	var sinks := [8.0, 18.0, 34.0]
	var images: Array[Image] = []
	for l in 3:
		images.append(P.make(SCREEN.x, SCREEN.y + 150 + PAD))
	# A faint generic ridge in each layer so the horizon is never empty.
	for l in 3:
		_ridge(images[l], l, pal, rng, profile.get("alpine", false))
	# The far Sierra crest goes in first and rides the farthest layer, so
	# nearer landmarks stand in front of it.
	var specs: Array[Dictionary] = []
	for spec: Dictionary in profile.get("view", []):
		if spec.k == "sierra_crest":
			specs.append(spec)
	for spec: Dictionary in profile.get("view", []):
		if spec.k != "sierra_crest":
			specs.append(spec)
	for spec: Dictionary in specs:
		var kind: String = spec.k
		var l := int(spec.get("l", 1))
		var info: Dictionary = LANDMARKS.get(kind, {})
		if info.is_empty():
			continue
		var into := 0 if kind == "sierra_crest" else l
		var found := _paint_landmark(images[into], kind, info, int(spec.x), float(spec.get("s", 1.0)), l, into, pal, rng)
		for f: Dictionary in found:
			f["layer"] = into
			falls.append(f)
	for l in 3:
		layers.append({"image": images[l], "sink": sinks[l], "pad": PAD})
	# The valley floor, far below.
	var ground := P.make(SCREEN.x, SCREEN.y + 200 + PAD)
	_floor(ground, profile.get("ground", "valley_forest"), pal, rng)
	layers.append({"image": ground, "sink": 150.0, "pad": PAD})
	return {"layers": layers, "falls": falls}


# ------------------------------------------------------------------ colors

## Lights a base color for the time of day: dimmed, tinted by the sky, and
## faded toward the haze.
static func _lit(col: Color, pal: Dictionary, tint: float, fade: float) -> Color:
	var lum: float = pal.get("lum", 1.0)
	var out := Color(col.r * lum, col.g * lum, col.b * lum)
	out = out.lerp(pal.tint, tint * minf(lum, 1.0))
	# Distance is bluer as well as paler: the haze leans toward sky blue.
	var haze: Color = _haze(pal)
	return out.lerp(haze, fade)


## The air between the valley and the far walls: pale, and a little blue.
static func _haze(pal: Dictionary) -> Color:
	return (pal.low as Color).lerp(pal.mid, 0.45).lerp(Color("a4c8ec"), 0.22)


## The haze color a layer fades toward, and the rock tones at that depth.
static func _body(pal: Dictionary, l: int) -> Dictionary:
	var haze: Color = _haze(pal)
	var fade: float = LAYER_HAZE[l]
	var ramp: Array[Color] = []
	for k in 5:
		var col := _lit(Color(GRANITE[k]), pal, GRANITE_TINT[k], fade)
		# Alpenglow on the sunlit faces, less on the distant ones.
		var glow: float = pal.get("glow", 0.0)
		if glow > 0.0 and k < 3:
			var glow_col: Color = pal.get("glow_col", Color.WHITE)
			var v := col.r * 0.3 + col.g * 0.55 + col.b * 0.15
			col = col.lerp(Color(glow_col.r * v * 1.3, glow_col.g * v * 1.3, glow_col.b * v * 1.3).clamp(), glow * [0.65, 0.5, 0.3][k] * (1.0 - fade * 0.6))
		if k == 0:
			col = col.lerp(pal.rim, 0.3 * (1.0 - fade))
		ramp.append(col)
	return {
		"ramp": ramp,
		"hi": ramp[0], "lit": ramp[1], "body": ramp[2], "shade": ramp[3], "deep": ramp[4],
		"tree_dk": _lit(Color("173826"), pal, 0.06, fade * 0.6),
		"tree": _lit(Color("24502f"), pal, 0.08, fade * 0.6),
		"tree_lit": _lit(Color("4f8a48"), pal, 0.2, fade * 0.6),
		"snow": _lit(Color("fbfdff"), pal, 0.3, fade * 0.4),
		"snow_shade": _lit(Color("b4c6e4"), pal, 0.1, fade * 0.45),
		"ice": _lit(Color("8cc4ec"), pal, 0.1, fade * 0.45),
		"ice_dk": _lit(Color("5c92cc"), pal, 0.05, fade * 0.45),
		"water": _lit(Color("f4fbff"), pal, 0.3, fade * 0.5),
		"water_edge": _lit(Color("a8d0ec"), pal, 0.1, fade * 0.5),
		"haze": haze,
		"fade": fade,
	}


# ------------------------------------------------------------ painting kit

## One column of rock from [param y0] to [param y1], its tone running from
## [param t0] at the top to [param t1] at the bottom (0 = cream .. 4 = deep).
## Tones are flat; where one gives way to the next a narrow band dithers.
static func _band_col(im: Image, x: int, y0: int, y1: int, t0: float, t1: float, ramp: Array[Color]) -> void:
	var n := y1 - y0
	if n <= 0 or x < 0 or x >= im.get_width():
		return
	var slope := (t1 - t0) / float(n)
	var ys: Array[int] = [y0]
	if absf(slope) > 0.0001:
		var lo := clampf(minf(t0, t1), -0.4, 4.4)
		var hi := clampf(maxf(t0, t1), -0.4, 4.4)
		var cuts: Array[int] = []
		var m := floori(lo) - 1
		while m <= ceili(hi):
			for off: float in [0.35, 0.65]:
				var tv: float = m + off
				if tv > lo and tv < hi:
					cuts.append(y0 + roundi((tv - t0) / slope))
			m += 1
		if slope < 0.0:
			cuts.reverse()
		ys.append_array(cuts)
	ys.append(y1)
	for j in ys.size() - 1:
		var a := ys[j]
		var b := ys[j + 1]
		if b <= a:
			continue
		var tm := clampf(t0 + slope * ((a + b) * 0.5 - y0), 0.0, 4.0)
		var k := int(tm)
		var f := tm - k
		if f < 0.35:
			im.fill_rect(Rect2i(x, a, 1, b - a), ramp[k])
		elif f > 0.65:
			im.fill_rect(Rect2i(x, a, 1, b - a), ramp[mini(k + 1, 4)])
		else:
			var ratio := (f - 0.35) / 0.3
			var kk := mini(k + 1, 4)
			for y in range(maxi(a, 0), mini(b, im.get_height())):
				im.set_pixel(x, y, ramp[kk] if P.dither(x, y, ratio) else ramp[k])


static func _px(im: Image, x: int, y: int, col: Color) -> void:
	if x >= 0 and y >= 0 and x < im.get_width() and y < im.get_height():
		im.set_pixel(x, y, col)


static func _rect(im: Image, x: int, y: int, w: int, h: int, col: Color) -> void:
	im.fill_rect(Rect2i(x, y, w, h), col)


## A filled ellipse, one fill_rect per row.
static func _ell(im: Image, cx: int, cy: int, rx: int, ry: int, col: Color) -> void:
	for dy in range(-ry, ry + 1):
		var k := 1.0 - (float(dy) * dy) / maxf(float(ry) * ry, 1.0)
		var half := int(rx * sqrt(maxf(k, 0.0)) + 0.5)
		im.fill_rect(Rect2i(cx - half, cy + dy, half * 2 + 1, 1), col)


## A little conifer: tip at ([param cx], [param ty]), [param th] rows tall.
static func _conifer(im: Image, cx: int, ty: int, th: int, c: Dictionary, lit_side: bool) -> void:
	for r in th:
		var half := r / 2
		im.fill_rect(Rect2i(cx - half, ty + r, half * 2 + 1, 1), c.tree if r < th - 1 else c.tree_dk)
		if lit_side and r >= 1 and r < th - 1:
			_px(im, cx - half, ty + r, c.tree_lit)


## The forest at a landmark's foot: a solid canopy from [param treeline]
## down, darker toward the bottom, with conifer tips against the rock.
static func _forest(im: Image, x0: int, tops: PackedInt32Array, treeline: PackedInt32Array, base: int, c: Dictionary, th: int, rng: RandomNumberGenerator) -> void:
	var n := tops.size()
	var bottom := base + 26
	for i in n:
		var x := x0 + i
		if x < 0 or x >= im.get_width() or tops[i] >= base:
			continue
		var tl := maxi(treeline[i], tops[i] + 2)
		if tl >= bottom:
			continue
		var mid := tl + (bottom - tl) * 2 / 5
		im.fill_rect(Rect2i(x, tl, 1, mid - tl), c.tree)
		im.fill_rect(Rect2i(x, mid, 1, bottom - mid), c.tree_dk)
	var i := 1
	while i < n - 1:
		var x := x0 + i
		if tops[i] < base and x >= 0 and x < im.get_width():
			var tl := maxi(treeline[i], tops[i] + 2)
			var t := th - 1 + rng.randi_range(0, 2)
			_conifer(im, x, tl - t + 1, t + 1, c, true)
			# A lit tuft low in the canopy.
			if i % 3 == 0:
				_px(im, x + 1, tl + t / 2 + 2, c.tree_lit)
				_px(im, x - 1, tl + t + 3, c.tree_lit)
		i += rng.randi_range(2, 4)


## Shapes a treeline for a landmark: trees climb higher where the ground is
## gentle and stop short of steep granite.
static func _treeline(tops: PackedInt32Array, base: int, h: int, rise: float) -> PackedInt32Array:
	var n := tops.size()
	var out := PackedInt32Array()
	out.resize(n)
	for i in n:
		var a := tops[maxi(i - 3, 0)]
		var b := tops[mini(i + 3, n - 1)]
		var steep := clampf(absf(a - b) / 6.0, 0.0, 1.0)
		var line := float(base) - h * (0.10 + rise * (1.0 - steep))
		line += (P.noise(i / 2, 3, 17) - 0.5) * h * 0.07 - (i % 5) * 0.4
		out[i] = int(line)
	return out


## Horizontal ledge lines on a face: a dark crack with a lit lip above it on
## the sunny side.
static func _ledges(im: Image, x0: int, tops: PackedInt32Array, base: int, h: int, c: Dictionary, rng: RandomNumberGenerator, count: int, ymin: float, ymax: float, len_lo: int, len_hi: int) -> void:
	var w := tops.size()
	for k in count:
		var i0 := rng.randi_range(2, maxi(w - 3, 3))
		var ln := rng.randi_range(len_lo, len_hi)
		var y := base - int(h * rng.randf_range(ymin, ymax))
		var sunny := i0 < w * 0.6
		for j in range(i0, mini(i0 + ln, w - 2)):
			if tops[j] + 4 >= y:
				break
			if (j + k) % 6 == 0:
				continue
			var yy := y + (1 if (j / 6 + k) % 3 == 0 else 0)
			_px(im, x0 + j, yy, c.body.darkened(0.2) if sunny else c.deep)
			if sunny:
				_px(im, x0 + j, yy - 1, c.lit)


## Dark vertical streaks (water stains) as broken runs.
static func _streaks(im: Image, x0: int, tops: PackedInt32Array, base: int, c: Dictionary, rng: RandomNumberGenerator, from_i: int, to_i: int, count: int, col: Color, reach_lo: float, reach_hi: float, wide: bool) -> void:
	var w := tops.size()
	for k in count:
		var i := clampi(rng.randi_range(from_i, to_i), 0, w - 1)
		var y := tops[i] + rng.randi_range(2, 8)
		var bottom := base - int((base - tops[i]) * rng.randf_range(1.0 - reach_hi, 1.0 - reach_lo))
		var wd := 2 if (wide and k % 3 == 0) else 1
		while y < bottom:
			var run := rng.randi_range(5, 16)
			_rect(im, x0 + i, y, wd, mini(run, bottom - y), col)
			if wd == 1 and k % 2 == 0:
				_px(im, x0 + i + 1, y + 1, col.lerp(c.body, 0.5))
			y += run + rng.randi_range(1, 2)


## A waterfall ribbon. Returns its shimmer entry.
static func _fall(im: Image, x: int, y0: int, y1: int, c: Dictionary, drift: float, wide: int, mist: bool) -> Dictionary:
	var span := maxi(y1 - y0, 1)
	for y in range(y0, y1):
		var xx := x + int(drift * (y - y0) / span) + int(sin(y * 0.07) * 0.8)
		var wd := wide if y - y0 > span / 5 else 1
		_rect(im, xx, y, wd, 1, c.water)
		_px(im, xx + wd, y, c.water_edge if y % 4 < 3 else c.haze)
		if wd > 1 and y % 3 == 0:
			_px(im, xx - 1, y, c.water_edge)
	if mist:
		var mx := x + int(drift)
		_rect(im, mx - 2, y1, 5, 1, c.water)
		_rect(im, mx - 4, y1 + 1, 9, 1, c.water_edge)
		_rect(im, mx - 6, y1 + 2, 13, 1, c.haze.lerp(c.water, 0.5))
	return {"x": x, "y0": y0, "y1": y1}


# ------------------------------------------------------------- ridge lines

static func _ridge(im: Image, l: int, pal: Dictionary, rng: RandomNumberGenerator, alpine: bool) -> void:
	var c := _body(pal, l)
	var ramp: Array[Color] = c.ramp
	var base: int = LAYER_BASE[l] + 6 + PAD
	var amp: float = [30.0, 22.0, 14.0][l]
	var p1 := rng.randf() * TAU
	var p2 := rng.randf() * TAU
	var f: float = [0.011, 0.018, 0.028][l]
	var tops := PackedInt32Array()
	tops.resize(SCREEN.x)
	for x in SCREEN.x:
		var top: float = base - amp * (0.55 + 0.3 * sin(x * f + p1) + 0.18 * sin(x * f * 2.7 + p2) + 0.08 * sin(x * f * 6.3))
		if l == 2:
			top += 8.0
		tops[x] = int(top)
	var bottom := im.get_height()
	for x in SCREEN.x:
		var top := tops[x]
		var d := tops[maxi(x - 2, 0)] - tops[mini(x + 2, SCREEN.x - 1)]
		var t0 := 1.9 - clampf(d * 0.35, -1.0, 1.0) + (P.noise(x / 2, l, 5) - 0.5) * 0.5
		_band_col(im, x, top, base + 12, t0, t0 + 0.9, ramp)
		im.fill_rect(Rect2i(x, base + 12, 1, bottom - base - 12), ramp[3])
		_px(im, x, top, ramp[0] if d > 0 else ramp[1])
	if l >= 1 and not alpine:
		var tl := PackedInt32Array()
		tl.resize(SCREEN.x)
		for x in SCREEN.x:
			tl[x] = tops[x] + 5 + int(P.noise(x / 3, 9, l) * 3.0) + l * 2
		_forest(im, 0, tops, tl, base + 4, c, 3 + l, rng)
	elif l == 0 and not alpine:
		# The far ridge: a thin band of forest low on the slope.
		for x in SCREEN.x:
			var y := base - 6 + int(P.noise(x / 4, 4, 2) * 3.0)
			_rect(im, x, y, 1, 24, c.tree)
	elif alpine and l >= 1:
		# Talus and a few snow patches high up.
		for x in range(0, SCREEN.x, 3):
			if P.noise(x, l, 71) > 0.62:
				_rect(im, x, tops[x] + 2, 2 + int(P.noise(x, 3, 3) * 3.0), 1, c.snow)


# --------------------------------------------------------------- landmarks

static func _paint_landmark(im: Image, kind: String, info: Dictionary, cx: int, s: float, l: int, into: int, pal: Dictionary, rng: RandomNumberGenerator) -> Array[Dictionary]:
	var c := _body(pal, maxi(into, 0))
	if kind == "sierra_crest":
		c = _body(pal, 0)
	var w := int(info.w * s)
	var h := int(info.h * s)
	var base: int = LAYER_BASE[l] + 10 + PAD
	var x0 := cx - w / 2
	var tops := PackedInt32Array()
	tops.resize(w)
	for i in w:
		var u := (float(i) / maxf(w - 1, 1)) * 2.0 - 1.0
		tops[i] = base - int(_profile(kind, u, int(i / s), rng) * h)
	var falls: Array[Dictionary] = []
	var tree_h := 3 + int(s * 1.6) + (1 if l == 2 else 0)
	var treeline := _treeline(tops, base, h, 0.14 if kind != "glacier_point" else 0.3)
	_mass(im, kind, x0, w, h, tops, base, c, info, rng)
	_details(im, kind, x0, w, h, tops, base, c, info, rng)
	if info.get("snow", false):
		_snow(im, x0, w, tops, base, c, info.get("glacier", false), rng)
	if info.get("trees", false):
		_forest(im, x0, tops, treeline, base, c, tree_h, rng)
	_after_trees(im, kind, x0, w, h, tops, base, c, info, rng, falls)
	return falls


## Lights a landmark: tones from sunny left to shaded right, darker toward
## the foot, lit and shaded flanks where the outline rises and falls, a rim
## light on top and fluting down the face.
static func _mass(im: Image, kind: String, x0: int, w: int, h: int, tops: PackedInt32Array, base: int, c: Dictionary, info: Dictionary, rng: RandomNumberGenerator) -> void:
	var ramp: Array[Color] = c.ramp
	var lr: float = info.get("lr", 1.9)
	var t_start: float = info.get("t0", 0.85)
	var flute: float = info.get("flute", 0.5)
	var bottom := base + 26
	var seed_value := 11 + kind.length()
	for i in w:
		var x := x0 + i
		if x < 0 or x >= im.get_width():
			continue
		var top := tops[i]
		if top >= base:
			continue
		var f := float(i) / maxf(w - 1, 1)
		var d := 0
		if i > 2 and i < w - 3:
			d = tops[i - 2] - tops[i + 2]
		var hfrac := float(base - top) / maxf(h, 1)
		var t0 := t_start + f * lr - clampf(d * 0.10, -1.0, 1.0)
		# Fluting: columns that catch the light or sink into shadow.
		t0 += (P.noise(i / 3, 0, seed_value) - 0.5) * flute * 0.8 + (P.noise(i, 1, seed_value) - 0.5) * flute * 0.3
		t0 += _extra_tone(kind, f, hfrac)
		var dk := 1.15 if hfrac > 0.3 else 0.8
		var t1 := t0 + dk * float(bottom - top) / maxf(base - top, 1)
		_band_col(im, x, top, bottom, t0, minf(t1, 4.6), ramp)
		# Crisp rim: bright on lit slopes, a quieter edge on shaded ones.
		_px(im, x, top, ramp[0] if t0 < 1.6 else ramp[1])
		if t0 < 1.0:
			_px(im, x, top + 1, ramp[1])


## Shape-specific shading, added to the tone of the whole column (0..1 across).
static func _extra_tone(kind: String, f: float, hfrac: float) -> float:
	match kind:
		"half_dome":
			# The sheer face: a shaded plane that begins at a soft curved edge.
			return smoothstep(0.50, 0.54, f) * 1.9
		"el_capitan":
			# A bright prow, then the shadow it throws, then the long sunlit wall.
			if f < 0.05:
				return -1.0
			if f < 0.095:
				return 0.9
			return -0.2 * smoothstep(0.1, 0.4, f)
		"cathedral_rocks", "three_brothers":
			return clampf(0.4 - hfrac, 0.0, 1.0) * 1.3
		"yosemite_falls", "bridalveil":
			return 0.35 * smoothstep(0.7, 1.0, f)
		"sentinel_rock":
			return 0.6 * smoothstep(0.55, 0.75, f)
		"washington_column":
			return 0.6 * smoothstep(0.62, 0.8, f)
	return 0.0


## Strata, stains and other marks laid over the granite.
static func _details(im: Image, kind: String, x0: int, w: int, h: int, tops: PackedInt32Array, base: int, c: Dictionary, info: Dictionary, rng: RandomNumberGenerator) -> void:
	match kind:
		"half_dome":
			# Dark water streaks down the sheer face, from the lip.
			var a := int(w * 0.55)
			var b := int(w * 0.73)
			_streaks(im, x0, tops, base, c, rng, a, b, 10, c.deep.darkened(0.25), 0.1, 0.6, true)
			# A pale crack down the face edge, and gentle ledges on the back.
			var edge := x0 + int(w * 0.515)
			for y in range(base - int(h * 0.9), base - int(h * 0.2)):
				if y % 4 != 0:
					_px(im, edge + int(sin(y * 0.09) * 1.0), y, c.hi.lerp(c.lit, 0.4))
			_ledges(im, x0, tops, base, h, c, rng, 5, 0.3, 0.8, 5, 14)
			# Reflected light down the face's far edge.
			var fe := x0 + int(w * 0.73) - 1
			for y in range(tops[clampi(int(w * 0.72), 0, w - 1)] + 3, base):
				if y % 5 != 0:
					_px(im, fe, y, c.shade.lerp(c.lit, 0.35))
		"el_capitan":
			# The black stains: long streaks from the roof of the wall.
			_streaks(im, x0, tops, base, c, rng, int(w * 0.15), w - 8, 15, c.deep.darkened(0.3), 0.1, 0.5, true)
			_streaks(im, x0, tops, base, c, rng, int(w * 0.2), w - 8, 8, c.shade, 0.2, 0.7, false)
			_ledges(im, x0, tops, base, h, c, rng, 8, 0.25, 0.85, 6, 18)
			# A bright edge down the prow, with its crack just inside.
			for y in range(tops[int(w * 0.03)] + 1, base - 2):
				_px(im, x0 + int(w * 0.047), y, c.hi if y % 9 != 0 else c.lit)
		"yosemite_falls", "bridalveil", "sentinel_rock", "washington_column", "glacier_point", "three_brothers", "cathedral_rocks", "royal_arches", "clouds_rest", "north_dome", "liberty_cap", "nevada_fall":
			var n := 4 if kind != "north_dome" else 2
			_ledges(im, x0, tops, base, h, c, rng, n, 0.25, 0.8, 5, 16)
			if kind in ["yosemite_falls", "bridalveil", "sentinel_rock", "glacier_point"]:
				_streaks(im, x0, tops, base, c, rng, int(w * 0.1), int(w * 0.9), 5, c.shade, 0.15, 0.5, false)
		"cockscomb", "unicorn_peak", "echo_peaks", "matthes_crest", "mt_lyell", "mt_maclure":
			# Gullies and joints between the spires.
			_streaks(im, x0, tops, base, c, rng, 4, w - 5, 7 + w / 30, c.deep, 0.1, 0.5, false)
			_ledges(im, x0, tops, base, h, c, rng, 4, 0.2, 0.7, 4, 10)
	if info.get("arches", false):
		# Royal Arches: great stacked arches in the wall, each a recess with a
		# lit lip and a dark inner curve.
		for k in 3:
			var ax := x0 + int(w * (0.28 + 0.24 * k))
			var ay := base - int(h * (0.42 + 0.05 * k))
			for j in 3:
				var rx := 16.0 - j * 4.5 + k * 2.0
				var col: Color = [c.body.darkened(0.1), c.shade, c.deep][j]
				for y in range(int(ay - rx), ay + 16 + j * 3):
					var half := rx
					if y < ay:
						half = rx * sqrt(maxf(1.0 - pow((ay - y) / rx, 2.0), 0.0))
					var hw := int(half)
					_rect(im, ax - hw, y, hw * 2 + 1, 1, col)
					if y >= ay and (y - ay) % 4 == 0:
						_px(im, ax - hw, y, c.hi.lerp(c.lit, 0.5))
				# A lit lip along the upper-left curve of each recess.
				for t in range(60, 181, 4):
					_px(im, int(ax + cos(deg_to_rad(t)) * rx), int(ay - sin(deg_to_rad(t)) * rx) - 1, c.hi if j == 0 else c.lit)
	if info.get("rail", false):
		# Glacier Point's rim: a dark line, a lit lip and a tiny railing.
		var i0 := int(w * 0.2)
		for i in range(i0, int(w * 0.76)):
			var x := x0 + i
			var top := tops[clampi(i, 0, w - 1)]
			if top < base:
				_px(im, x, top - 1, c.deep)
				if i % 3 != 2:
					_px(im, x, top - 2, c.deep)
		# The little hut on the point.
		var hx := x0 + int(w * 0.66)
		var hy := tops[clampi(int(w * 0.66), 0, w - 1)]
		_rect(im, hx, hy - 4, 5, 3, c.shade)
		_rect(im, hx - 1, hy - 5, 7, 1, c.deep)


## Forest-hiding finishing: water ribbons and anything that sits in front of
## the trees.
static func _after_trees(im: Image, kind: String, x0: int, w: int, h: int, tops: PackedInt32Array, base: int, c: Dictionary, info: Dictionary, rng: RandomNumberGenerator, falls: Array[Dictionary]) -> void:
	if not info.get("fall", false):
		return
	match kind:
		"yosemite_falls":
			# Upper fall from the rim, a run of cascades, then the lower fall.
			var fx := x0 + int(w * 0.46)
			var rim := tops[clampi(fx - x0, 0, w - 1)]
			var top := rim + int(h * 0.04)
			var ledge := base - int(h * 0.42)
			var low_top := base - int(h * 0.3)
			# The wet streak the fall leaves on the wall.
			_rect(im, fx + 2, top + 4, 1, ledge - top, c.shade)
			falls.append(_fall(im, fx, top, ledge, c, 1.0, 2, false))
			# Cascades between: a zigzag of short pale strokes.
			var cx_ := fx + 1
			for y in range(ledge, low_top, 2):
				cx_ += 1 if (y / 4) % 2 == 0 else -1
				_rect(im, cx_, y, 1, 2, c.water)
				_px(im, cx_ + 1, y, c.water_edge)
			falls.append(_fall(im, cx_, low_top, base - int(h * 0.04), c, 0.0, 1, true))
		"bridalveil":
			var fx2 := x0 + int(w * 0.5)
			var ft := tops[clampi(fx2 - x0, 0, w - 1)] + int(h * 0.03)
			# A single drop that the wind blows to the side, spreading as it falls.
			_rect(im, fx2 - 1, ft - 1, 3, 2, c.shade)
			falls.append(_fall(im, fx2, ft, base - int(h * 0.04), c, -2.0, 2, true))
		"sentinel_rock":
			var fx3 := x0 + int(w * 0.76)
			var ft3 := tops[clampi(fx3 - x0, 0, w - 1)] + int(h * 0.08)
			falls.append(_fall(im, fx3, ft3, base - int(h * 0.06), c, 1.0, 1, true))
		"nevada_fall":
			var fx4 := x0 + int(w * 0.52)
			var lip := tops[clampi(fx4 - x0, 0, w - 1)]
			# The river reaches the lip, then drops with a bend halfway.
			_rect(im, fx4 - 10, lip - 1, 11, 1, c.water_edge)
			falls.append(_fall(im, fx4, lip, base - int(h * 0.04), c, 2.0, 2, true))


## A sawtooth ridge: pointed teeth of random heights, 0..1.
static func _teeth(i: int, period: float, seed_value: int) -> float:
	var cell := floori(i / period)
	var f := fmod(i, period) / period
	var peak := 0.35 + 0.65 * P.noise(cell, seed_value, 12)
	return peak * (1.0 - absf(f * 2.0 - 1.0)) + 0.15 * P.noise(i, seed_value, 13)


## A single rounded hump of half-width [param r] centered at [param c0].
static func _hump(u: float, c0: float, r: float, power: float) -> float:
	var d := absf(u - c0) / r
	if d >= 1.0:
		return 0.0
	return pow(1.0 - pow(d, 2.4), power)


## How tall a landmark is at normalized position [param u] (-1..1), 0..1.
static func _profile(kind: String, u: float, i: int, rng: RandomNumberGenerator) -> float:
	match kind:
		"half_dome":
			# A long rounded back that rises to the summit, then the sheer face.
			if u > 0.46:
				return 0.0
			var d := (u + 1.0) / 1.46
			var back := pow(1.0 - pow(1.0 - d, 2.3), 0.7)
			return clampf(back, 0.0, 1.0) * (1.0 - 0.03 * smoothstep(0.8, 1.0, d) - 0.1 * pow(smoothstep(0.92, 1.0, d), 3.0))
		"north_dome", "basket_dome":
			return sqrt(maxf(1.0 - u * u, 0.0)) * (0.92 + 0.08 * sin(u * 9.0))
		"liberty_cap":
			# A smooth bullet, steeper on the right.
			var lc := pow(maxf(1.0 - pow(absf(u + 0.1), 2.0 if u < -0.1 else 3.0), 0.0), 0.65)
			return lc
		"mt_broderick":
			return pow(maxf(1.0 - u * u, 0.0), 0.8) * (0.9 + 0.1 * sin(u * 7.0))
		"glacier_point":
			if u > 0.55:
				return 0.0
			var q := clampf((u + 1.0) / 1.05, 0.0, 1.0)
			return pow(q, 0.8) * (0.95 + 0.05 * sin(u * 11.0))
		"nevada_fall":
			if u > 0.55:
				return 0.0
			var q2 := clampf((u + 1.0) / 0.9, 0.0, 1.0)
			return smoothstep(0.0, 1.0, q2) * (0.82 + 0.18 * q2) * (0.97 + 0.03 * sin(u * 9.0))
		"royal_arches":
			return clampf((u + 1.0) * 3.0, 0.0, 1.0) * (0.84 + 0.16 * smoothstep(-1.0, 0.5, u)) * (1.0 if u < 0.92 else 0.0) * (0.97 + 0.03 * sin(u * 15.0))
		"washington_column":
			var e := clampf(1.0 - pow(absf(u), 6.0), 0.0, 1.0)
			return pow(e, 0.4) * (0.95 + 0.05 * u) * (0.97 + 0.03 * sin(u * 8.0))
		"sentinel_rock":
			# Tall and slender: a steep rounded left side and a sheer right.
			var su := (u + 0.1) * (1.0 if u < -0.1 else 1.5)
			var s := clampf(1.0 - pow(absf(su), 3.0), 0.0, 1.0)
			return pow(s, 0.5) * (0.82 + 0.18 * (u * 0.5 + 0.5))
		"cathedral_rocks":
			# Rounded buttresses, shouldered into one another.
			var hh := maxf(_hump(u, -0.62, 0.42, 0.55) * 0.72, maxf(_hump(u, -0.08, 0.5, 0.55), _hump(u, 0.62, 0.42, 0.55) * 0.82))
			return maxf(hh, 0.3 * clampf(1.0 - absf(u) * 0.95, 0.0, 1.0))
		"el_capitan":
			if u < -0.97:
				return 0.0
			var prow := smoothstep(-0.99, -0.9, u)
			var run_ := (0.98 - 0.03 * u) * (1.0 - 0.06 * smoothstep(0.82, 1.0, u))
			return prow * run_ * (1.0 if u < 0.97 else 0.0)
		"three_brothers":
			# Three stepped summits rising to the east: each a tilted block with
			# a steep west face.
			var seg := clampf((u + 1.0) / 2.0 * 3.0, 0.0, 2.999)
			var bi := floorf(seg)
			var within := seg - bi
			var hts := [0.5, 0.74, 0.98]
			var ht: float = hts[int(bi)]
			var shape := ht - 0.1 + 0.1 * smoothstep(0.0, 0.85, within)
			shape *= smoothstep(0.0, 0.05, within) * 0.15 + 0.85
			if u > 0.93:
				return 0.0
			return clampf(shape, 0.0, 1.0)
		"yosemite_falls":
			# The north rim: a stepped plateau with a notch where the creek spills.
			var plateau := smoothstep(-1.0, -0.85, u) * (1.0 - smoothstep(0.85, 1.0, u))
			var notch := 0.07 * (1.0 - smoothstep(0.0, 0.12, absf(u + 0.08)))
			var step := 0.96 - 0.07 * smoothstep(0.3, 0.45, u) + 0.03 * smoothstep(-0.8, -0.6, u)
			return maxf(plateau * step - notch, 0.0) * (0.97 + 0.03 * sin(u * 8.0))
		"bridalveil":
			# Cathedral rocks to the left, the Leaning Tower slab to the right,
			# and the notch where the creek leaps.
			var left := smoothstep(-1.0, -0.78, u)
			var right := 1.0 - smoothstep(0.78, 1.0, u)
			var lean := 0.92 + 0.08 * smoothstep(0.3, 0.7, u)
			var notch2 := 0.09 * (1.0 - smoothstep(0.0, 0.14, absf(u)))
			return maxf(left * right * lean * (0.98 - 0.06 * smoothstep(-0.3, -0.9, u)) - notch2, 0.0)
		"clouds_rest":
			# A long whaleback that climbs to a rounded summit and breaks off in a
			# sheer face to the east.
			var cr := pow(maxf(1.0 - absf(u - 0.35) * 0.9, 0.0), 1.6) * (0.9 + 0.1 * sin(u * 13.0))
			if u > 0.5:
				cr *= 1.0 - 0.55 * smoothstep(0.5, 0.62, u) * 0.5
				if u > 0.78:
					cr *= 1.0 - 0.5 * smoothstep(0.78, 0.84, u)
			return cr
		"cockscomb":
			# A comb of narrow needles.
			var cc := 0.28 + 0.6 * _teeth(i, 14.0, 3) + 0.08 * sin(u * 5.0)
			return clampf(cc, 0.0, 1.0) * clampf((1.0 - absf(u)) * 6.0, 0.0, 1.0)
		"unicorn_peak":
			# One slender horn: concave flanks and a sharp tip, a smaller horn at its foot.
			var uh := pow(maxf(1.0 - absf(u) * 1.1, 0.0), 1.9)
			var small := pow(maxf(1.0 - absf(u + 0.55) * 4.0, 0.0), 1.4) * 0.38
			return maxf(uh, small)
		"echo_peaks":
			var p1 := pow(maxf(1.0 - absf(u + 0.5) * 2.4, 0.0), 1.5) * 0.8
			var p2 := pow(maxf(1.0 - absf(u - 0.05) * 2.0, 0.0), 1.5) * 1.0
			var p3 := pow(maxf(1.0 - absf(u - 0.6) * 2.6, 0.0), 1.5) * 0.7
			return maxf(maxf(p1, p2), maxf(p3, 0.16))
		"matthes_crest":
			return clampf(0.38 + 0.5 * _teeth(i, 15.0, 8) + 0.1 * sin(u * 9.0), 0.0, 1.0) * clampf((1.0 - absf(u)) * 3.0, 0.0, 1.0) + 0.06
		"mt_lyell":
			# The park's highest peak: a broad glaciated summit with a shoulder.
			var ly := pow(maxf(1.0 - absf(u - 0.1) * 1.05, 0.0), 1.15) * (0.93 + 0.07 * sin(u * 17.0))
			var sh := pow(maxf(1.0 - absf(u + 0.5) * 2.0, 0.0), 1.2) * 0.62
			return maxf(ly, sh)
		"mt_maclure":
			return pow(maxf(1.0 - absf(u + 0.1) * 1.1, 0.0), 1.2) * (0.92 + 0.08 * sin(u * 15.0))
		"donohue_pass":
			return pow(maxf(1.0 - u * u, 0.0), 0.9) * (0.7 + 0.3 * sin(u * 5.0 + 1.0))
		"sierra_crest":
			var t := 0.42 + 0.22 * sin(u * 7.0) + 0.12 * sin(u * 17.0 + 1.0) + 0.2 * _teeth(i, 17.0, 2)
			return clampf(t, 0.05, 1.0)
	return 0.0


## Snow lying on the high ground: thick on lit slopes near the crest, thinner
## and bluer on the shaded side, running down the gullies, with glacier ice
## on the north faces.
static func _snow(im: Image, x0: int, w: int, tops: PackedInt32Array, base: int, c: Dictionary, glacier: bool, rng: RandomNumberGenerator) -> void:
	for i in w:
		var x := x0 + i
		if x < 0 or x >= im.get_width() or tops[i] >= base:
			continue
		var depth := base - tops[i]
		var d := 0
		if i > 2 and i < w - 3:
			d = tops[i - 2] - tops[i + 2]
		var cap := int(depth * (0.11 if not glacier else 0.09) * (0.5 + 1.0 * P.noise(i / 3, 2, 31)))
		if d > 1:
			cap = int(cap * 1.3)
		elif d < -1:
			cap = int(cap * 0.6)
		var gully := P.noise(i, 7, 33) > 0.9
		if gully:
			cap = int(depth * 0.3)
		if cap < 1:
			continue
		var f := float(i) / maxf(w - 1, 1)
		var col: Color = c.snow if f < 0.6 else c.snow_shade
		_rect(im, x, tops[i] + 1, 1, cap, col)
		if f < 0.6 and cap > 3:
			_rect(im, x, tops[i] + cap - 1, 1, 2, c.snow_shade)
		elif cap > 2:
			_px(im, x, tops[i] + cap, c.snow_shade)
		if gully:
			_px(im, x, tops[i] + cap + 1, c.snow_shade)
		if glacier and i > w * 0.14 and i < w * 0.52:
			# A tongue of blue ice down the north face, crevassed.
			var gt := tops[i] + int(depth * 0.4)
			var gl := int(depth * 0.26 * (0.6 + 0.4 * sin(i * 0.25)))
			_rect(im, x, gt, 1, gl, c.ice if i % 5 != 0 else c.snow)
			_px(im, x, gt, c.snow)
			if i % 7 < 3:
				for k in range(4 + (i / 7) % 3 * 2, gl, 9):
					_px(im, x, gt + k, c.ice_dk)


# ---------------------------------------------------------------- the floor

## The valley floor (or high-country basin) far below: forest canopy, meadow,
## river glints, roads, buildings. Painted as seen from a long way up: small
## and hazy at the far edge, bigger and richer toward the bottom.
static func _floor(im: Image, kind: String, pal: Dictionary, rng: RandomNumberGenerator) -> void:
	var w := im.get_width()
	var h := im.get_height()
	var top := 130 + PAD
	var alpine := kind in ["tuolumne", "moraine"]
	var night: bool = pal.get("lum", 1.0) < 0.8
	# Colors, far (hazy) to near (rich).
	var f_far := _lit(Color("386a3e"), pal, 0.15, 0.26)
	var f_mid := _lit(Color("2c5434"), pal, 0.12, 0.12)
	var f_near := _lit(Color("234630"), pal, 0.1, 0.04)
	var f_lit := _lit(Color("4f8650"), pal, 0.22, 0.14)
	var f_dk := _lit(Color("163122"), pal, 0.08, 0.06)
	var meadow := _lit(Color("a2b858"), pal, 0.3, 0.16)
	var meadow_lit := _lit(Color("c4d070"), pal, 0.35, 0.12)
	var meadow_dk := _lit(Color("7a9446"), pal, 0.2, 0.12)
	var water := _lit(Color("5e9ed4"), pal, 0.2, 0.15)
	var water_dk := _lit(Color("3e78b4"), pal, 0.1, 0.1)
	var spark := _lit(Color("f4fbff"), pal, 0.3, 0.08)
	var sand := _lit(Color("d8c898"), pal, 0.3, 0.12)
	if alpine:
		f_far = _lit(Color("3c5a40"), pal, 0.15, 0.4)
		f_mid = _lit(Color("34523a"), pal, 0.12, 0.2)
		f_near = _lit(Color("2c4832"), pal, 0.1, 0.08)
		f_lit = _lit(Color("668e58"), pal, 0.2, 0.14)
		meadow = _lit(Color("b4b868"), pal, 0.3, 0.16)
		meadow_lit = _lit(Color("d2d27c"), pal, 0.35, 0.12)
		meadow_dk = _lit(Color("8c9a50"), pal, 0.2, 0.12)
	if kind == "moraine":
		f_far = _lit(Color("8c8c94"), pal, 0.2, 0.4)
		f_mid = _lit(Color("7a7a84"), pal, 0.15, 0.22)
		f_near = _lit(Color("686874"), pal, 0.1, 0.08)
		f_lit = _lit(Color("c4c8d4"), pal, 0.3, 0.14)
		f_dk = _lit(Color("4c4c58"), pal, 0.08, 0.06)
		meadow = _lit(Color("a8a89c"), pal, 0.25, 0.16)
		meadow_lit = _lit(Color("d4d4cc"), pal, 0.3, 0.12)
		meadow_dk = _lit(Color("84847c"), pal, 0.15, 0.12)
	# The forest floor, in depth bands, over an undulating far edge.
	var edges := PackedInt32Array()
	edges.resize(w)
	for x in w:
		var edge := top + int(sin(x * 0.02) * 10.0 + sin(x * 0.07) * 4.0)
		edges[x] = edge
		var span := h - edge
		var b1 := edge + span / 6
		var b2 := edge + span / 2
		im.fill_rect(Rect2i(x, edge, 1, b1 - edge), f_far)
		im.fill_rect(Rect2i(x, b1, 1, b2 - b1), f_mid)
		im.fill_rect(Rect2i(x, b2, 1, h - b2), f_near)
		im.fill_rect(Rect2i(x, edge, 1, 1), f_lit)
	# The valley's far wall base: a darker, bluer line where forest meets haze.
	# Meadows (drawn before canopy so trees ring them).
	var meadow_list: Array[Vector3i] = []
	match kind:
		"el_cap_meadow":
			meadow_list = [Vector3i(250, top + 62, 150), Vector3i(400, top + 84, 100), Vector3i(330, top + 120, 90)]
		"tuolumne":
			meadow_list = [Vector3i(110, top + 55, 110), Vector3i(250, top + 70, 130), Vector3i(390, top + 56, 100), Vector3i(230, top + 120, 90)]
		"moraine":
			meadow_list = [Vector3i(120, top + 90, 40), Vector3i(330, top + 120, 50)]
		"curry", "camp4", "ahwahnee":
			meadow_list = [Vector3i(320, top + 90, 60), Vector3i(300, top + 52, 50), Vector3i(430, top + 100, 50), Vector3i(120, top + 70, 60)]
		_:
			for i in 4:
				meadow_list.append(Vector3i(rng.randi_range(40, w - 80), rng.randi_range(top + 40, top + 110), rng.randi_range(30, 64)))
	for m: Vector3i in meadow_list:
		var sc := 0.6 + float(m.y - top) / 140.0
		var ry := maxi(int(m.z * 0.13 * sc) + 3, 4)
		_ell(im, m.x, m.y, m.z, ry, meadow_dk)
		_ell(im, m.x - 1, m.y - 1, m.z - 2, ry - 1, meadow)
		_ell(im, m.x - m.z / 4, m.y - ry / 2, m.z / 2, maxi(ry / 2 - 1, 1), meadow_lit)
		# Grass tufts and wildflowers.
		for k in m.z / 3:
			var gx := m.x + rng.randi_range(-m.z, m.z) * 3 / 4
			var gy := m.y + rng.randi_range(-ry, ry) * 2 / 3
			_px(im, gx, gy, meadow_dk if k % 3 else meadow_lit)
			if k % 9 == 0 and not alpine:
				_px(im, gx, gy - 1, _lit(Color("f4d848") if k % 2 == 0 else Color("f0f0e8"), pal, 0.2, 0.1))
	# Canopy: round treetops, small and hazy far, big and dark near.
	var count := 500 + w * (h - top) / 180
	for i in count:
		var x := rng.randi_range(0, w - 2)
		var y := rng.randi_range(edges[x] + 3, h - 2)
		var depth := clampf(float(y - top) / 170.0, 0.0, 1.0)
		var r := 2 + int(depth * 2.5) + rng.randi_range(0, 1)
		var body: Color = f_mid.lerp(f_near, depth) if rng.randf() < 0.7 else f_near.lerp(f_dk, depth * 0.5)
		_rect(im, x + 1, y, r - 1, r - 1, body)
		_rect(im, x, y + 1, r + 1, maxi(r - 2, 1), body)
		_px(im, x + 1, y + 1, f_lit)
		if r > 3:
			_px(im, x + 2, y, f_lit)
		_rect(im, x + 1, y + r - 1, r - 1, 1, f_dk.lerp(body, 0.4))
	# Tree trunks' shadows and clearings near meadows are implied by canopy
	# gaps; now the river.
	var river_y := top + 74
	var amp := 14.0 if kind != "tuolumne" else 26.0
	var rw := 3 if kind != "tuolumne" else 4
	var last_y := 0
	for x in w:
		var y := river_y + int(sin(x * 0.03 + 1.0) * 9.0 + sin(x * 0.011) * amp)
		if kind == "el_cap_meadow":
			y = river_y + 26 + int(sin(x * 0.022 + 0.6) * 12.0)
		var dy := absi(y - last_y) if x > 0 else 0
		var hh := rw + mini(dy, 3)
		_px(im, x, y - 1, sand if P.noise(x, 1, 5) > 0.5 else meadow_dk)
		im.fill_rect(Rect2i(x, y, 1, hh), water)
		im.fill_rect(Rect2i(x, y + hh - 1, 1, 1), water_dk)
		if P.noise(x, 2, 9) > 0.84 or x % 17 == 0:
			_px(im, x, y + 1, spark)
		if x % 29 == 0 and not night:
			_px(im, x + 1, y, spark)
		last_y = y
	if kind == "tuolumne":
		# A second oxbow channel.
		for x in range(60, w - 60):
			var y2 := top + 126 + int(sin(x * 0.05 + 2.0) * 6.0)
			_px(im, x, y2, water)
			_px(im, x, y2 + 1, water_dk)
	match kind:
		"curry":
			_roads(im, top + 38, pal, w)
			_curry(im, top, pal, night, rng)
		"camp4":
			_roads(im, top + 38, pal, w)
			_camp4(im, top, pal, night, rng)
		"ahwahnee":
			_roads(im, top + 40, pal, w)
			_ahwahnee(im, top, pal, night, rng)
		"el_cap_meadow":
			_roads(im, top + 48, pal, w)
			_el_cap_meadow(im, top, pal, rng)
		"tuolumne":
			_roads(im, top + 28, pal, w)
			# A scatter of tents at a campground edge.
			for i in 7:
				_tent(im, 330 + i * 9, top + 24 + (i % 2) * 3, [Color("c84a3a"), Color("e8c040"), Color("4a78c8"), Color("e8e0c8")][i % 4], pal, night)
		"moraine":
			# Meltwater pools and boulders.
			for i in 16:
				var px_ := rng.randi_range(20, w - 20)
				var py_ := rng.randi_range(top + 30, top + 150)
				var tarn := i % 4 == 0
				if tarn:
					_ell(im, px_, py_, 7, 3, water_dk)
					_ell(im, px_, py_, 6, 2, water)
					_px(im, px_ - 2, py_ - 1, spark)
				else:
					_rect(im, px_, py_, 3, 2, f_lit)
					_rect(im, px_ + 1, py_ + 2, 2, 1, f_dk)
		"bridalveil_talus":
			# Boulders spilled from the cliffs.
			for i in 90:
				var tx := rng.randi_range(0, w - 5)
				var ty := rng.randi_range(top + 20, top + 150)
				var tz := rng.randi_range(2, 4)
				_rect(im, tx, ty, tz, tz - 1, _lit(Color("a8a0a0"), pal, 0.25, 0.1))
				_rect(im, tx + 1, ty + tz - 1, tz, 1, _lit(Color("5c5864"), pal, 0.1, 0.08))
		"mist_wall":
			# Spray drifting through the dark trees.
			for i in 22:
				var mx := rng.randi_range(0, w - 40)
				var my := rng.randi_range(top + 20, top + 140)
				_ell(im, mx, my, rng.randi_range(14, 30), 1, spark.lerp(f_mid, 0.55))
		"half_dome_forest":
			# Granite boulders in the pines.
			for i in 40:
				var bx := rng.randi_range(0, w - 5)
				var by := rng.randi_range(top + 30, top + 150)
				_rect(im, bx, by, 3, 2, _lit(Color("c0b4a0"), pal, 0.3, 0.1))
				_rect(im, bx + 1, by + 2, 3, 1, _lit(Color("6a647a"), pal, 0.1, 0.08))
	# Cloud shadows drifting over the floor, by day.
	if not night and pal.get("lum", 1.0) > 0.9:
		var sh := P.make(110, 24)
		var dark := Color(0.05, 0.1, 0.2, 0.16)
		for dy in range(-10, 11):
			var k := 1.0 - float(dy * dy) / 100.0
			var half := int(52.0 * sqrt(maxf(k, 0.0)))
			sh.fill_rect(Rect2i(55 - half, 12 + dy, half * 2, 1), dark)
		for pos: Vector2i in [Vector2i(60, top + 60), Vector2i(300, top + 112)]:
			im.blend_rect(sh, Rect2i(0, 0, 110, 24), pos)


## Two roads along the valley, the Southside and Northside Drives.
static func _roads(im: Image, y0: int, pal: Dictionary, w: int) -> void:
	var road := _lit(Color("a8a094"), pal, 0.25, 0.14)
	var edge := _lit(Color("5c5a58"), pal, 0.1, 0.1)
	for x in w:
		var y := y0 + int(sin(x * 0.015 + 0.5) * 6.0)
		_px(im, x, y, road)
		_px(im, x, y + 1, edge)
		if x % 8 < 3:
			_px(im, x, y, _lit(Color("e8e0b0"), pal, 0.3, 0.1))


static func _roof_cols(pal: Dictionary) -> Array[Color]:
	return [_lit(Color("a8602e"), pal, 0.2, 0.12), _lit(Color("8a4a2a"), pal, 0.15, 0.1), _lit(Color("b87848"), pal, 0.2, 0.12), _lit(Color("7a5a40"), pal, 0.15, 0.1)]


## A tiny tent-cabin or cabin: roof ridge, roof shade, wall and a door.
static func _cabin(im: Image, x: int, y: int, roof: Color, wall: Color, night: bool, pal: Dictionary) -> void:
	_rect(im, x + 1, y, 4, 1, roof.lightened(0.18))
	_rect(im, x, y + 1, 6, 1, roof)
	_rect(im, x, y + 2, 6, 3, wall)
	_rect(im, x + 5, y + 2, 1, 3, wall.darkened(0.25))
	_px(im, x + 2, y + 3, _lit(Color("5a3a28"), pal, 0.1, 0.05) if not night else Color("ffd870"))
	_rect(im, x + 1, y + 5, 6, 1, _lit(Color("163122"), pal, 0.1, 0.05))


static func _tent(im: Image, x: int, y: int, col: Color, pal: Dictionary, night: bool) -> void:
	var c := _lit(col, pal, 0.2, 0.1)
	_px(im, x + 1, y, c.lightened(0.15))
	_rect(im, x, y + 1, 3, 1, c)
	_rect(im, x, y + 2, 3, 1, c.darkened(0.25))
	if night:
		_px(im, x + 1, y + 2, Color("ffd870"))


## Curry Village: tidy rows of canvas tent-cabins under the pines, with the
## dining pavilion and a lit window or two at night.
static func _curry(im: Image, top: int, pal: Dictionary, night: bool, rng: RandomNumberGenerator) -> void:
	var roofs := _roof_cols(pal)
	var canvas := _lit(Color("e8e0c8"), pal, 0.3, 0.1)
	var tan := _lit(Color("c8b090"), pal, 0.2, 0.1)
	for row in 3:
		for k in 8:
			var x := 300 + k * 9 + row * 3
			var y := top + 56 + row * 12
			var rc: Color = roofs[(k + row) % 4]
			_cabin(im, x, y, rc, canvas if (k + row) % 2 == 0 else tan, night, pal)
		# Paths between the rows.
		_rect(im, 297 + row * 3, top + 62 + row * 12, 84, 1, _lit(Color("c8b898"), pal, 0.25, 0.12))
	# The pavilion and the Village store, bigger roofs near the road.
	_rect(im, 392, top + 44, 16, 2, roofs[1])
	_rect(im, 390, top + 46, 20, 4, tan)
	_rect(im, 394, top + 47, 2, 2, Color("ffd870") if night else _lit(Color("4a6a8a"), pal, 0.1, 0.1))
	_rect(im, 398, top + 47, 2, 2, Color("ffd870") if night else _lit(Color("4a6a8a"), pal, 0.1, 0.1))
	_rect(im, 390, top + 50, 20, 1, _lit(Color("163122"), pal, 0.1, 0.05))
	# Parked cars.
	for k in 5:
		_rect(im, 420 + k * 5, top + 52, 3, 2, [Color("c84a3a"), Color("e8e0c8"), Color("4a78c8"), Color("3a3a40"), Color("e8c040")][k])


## Camp 4: a clearing of small colorful tents, picnic tables and fire pits.
static func _camp4(im: Image, top: int, pal: Dictionary, night: bool, rng: RandomNumberGenerator) -> void:
	var cols := [Color("c84a3a"), Color("e8c040"), Color("4a78c8"), Color("e8e0c8"), Color("58a050"), Color("d8782a")]
	# The clearing.
	var clear := _lit(Color("a09060"), pal, 0.25, 0.14)
	_ell(im, 365, top + 66, 66, 10, clear)
	for i in 22:
		var x := 310 + rng.randi_range(0, 110)
		var y := top + 58 + rng.randi_range(0, 16)
		_tent(im, x, y, cols[i % cols.size()], pal, night)
		if i % 4 == 0:
			_px(im, x + 4, y + 2, Color("ff9a30") if night else _lit(Color("5a4a40"), pal, 0.1, 0.1))
	for i in 4:
		var rc: Color = _roof_cols(pal)[i % 4]
		_cabin(im, 410 + i * 11 - 20 * (i / 3), top + 48 + (i % 2) * 3 + (i / 3) * 14, rc, _lit(Color("a08868"), pal, 0.2, 0.1), night, pal)


## The Ahwahnee: a long, many-gabled lodge of stone and timber with its
## lawns, and an avenue of pines.
static func _ahwahnee(im: Image, top: int, pal: Dictionary, night: bool, rng: RandomNumberGenerator) -> void:
	var lawn := _lit(Color("78b050"), pal, 0.3, 0.12)
	var roof := _lit(Color("8a5a40"), pal, 0.2, 0.1)
	var roof_lit := _lit(Color("b07a58"), pal, 0.25, 0.1)
	var stone := _lit(Color("a89478"), pal, 0.25, 0.1)
	var stone_dk := _lit(Color("6a5a4c"), pal, 0.12, 0.08)
	var win := Color("ffd870") if night else _lit(Color("4a6888"), pal, 0.1, 0.1)
	var x := 306
	var y := top + 50
	_ell(im, x + 40, y + 12, 70, 9, lawn)
	_ell(im, x + 36, y + 11, 48, 5, lawn.lightened(0.1))
	# Main block, two wings and the gables.
	_rect(im, x + 12, y - 1, 56, 2, roof)
	_rect(im, x + 12, y - 2, 56, 1, roof_lit)
	_rect(im, x + 10, y + 1, 60, 6, stone)
	_rect(im, x + 10, y + 6, 60, 1, stone_dk)
	_rect(im, x, y + 3, 18, 4, stone)
	_rect(im, x - 1, y + 2, 20, 1, roof)
	_rect(im, x + 62, y + 3, 18, 4, stone)
	_rect(im, x + 61, y + 2, 20, 1, roof)
	for k in 12:
		var wx := x + 12 + k * 5
		_rect(im, wx, y + 3, 2, 2, win)
	for k in 3:
		_rect(im, x + 22 + k * 14, y - 4, 6, 3, roof)
		_px(im, x + 24 + k * 14, y - 5, roof_lit)
	# A shadow along the foot and pines flanking it.
	_rect(im, x - 1, y + 7, 82, 1, _lit(Color("163122"), pal, 0.1, 0.05))
	for k in 6:
		_conifer(im, x - 8 + k * 2, y - 2 + (k % 2), 7, _body(pal, 2), true)
		_conifer(im, x + 88 - k * 2, y - 2 + (k % 2), 7, _body(pal, 2), true)
	# Parking.
	for k in 8:
		_rect(im, x + 14 + k * 4, y + 17, 3, 2, [Color("c84a3a"), Color("e8e0c8"), Color("4a78c8"), Color("3a3a40")][k % 4])


## El Cap Meadow: the long road with a line of tiny cars pulled over, and
## the boardwalk with little people looking up.
static func _el_cap_meadow(im: Image, top: int, pal: Dictionary, rng: RandomNumberGenerator) -> void:
	var cols := [Color("c84a3a"), Color("e8e0c8"), Color("4a78c8"), Color("3a3a40"), Color("e8c040"), Color("58a050")]
	var glass := _lit(Color("304860"), pal, 0.1, 0.08)
	for x in range(10, 470, 1):
		var y := top + 48 + int(sin(x * 0.015 + 0.5) * 6.0)
		if x % 24 == 5:
			var cc := _lit(cols[(x / 24) % cols.size()], pal, 0.2, 0.08)
			_rect(im, x, y - 2, 4, 2, cc)
			_px(im, x + 1, y - 2, glass)
			_px(im, x + 2, y - 2, glass)
			_px(im, x, y, _lit(Color("20201c"), pal, 0.05, 0.05))
	# The boardwalk and the people on it.
	var wood := _lit(Color("c0a070"), pal, 0.25, 0.1)
	for x in range(180, 360):
		var y2 := top + 76 + int(sin(x * 0.04) * 3.0)
		_px(im, x, y2, wood)
	for i in 12:
		var x2 := 190 + i * 14 + rng.randi_range(-3, 3)
		var y3 := top + 75 + int(sin(x2 * 0.04) * 3.0)
		_px(im, x2, y3 - 1, _lit(cols[i % cols.size()], pal, 0.2, 0.08))
		_px(im, x2, y3 - 2, _lit(Color("e8c8a0"), pal, 0.2, 0.08))
