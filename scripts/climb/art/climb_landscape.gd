class_name ClimbLandscape
extends RefCounted
## What you see past the edge of the wall: the real skyline of each route,
## painted as layers of ridgelines and landmarks (Half Dome, El Capitan, the
## Three Brothers, Cathedral Peak's neighbors...) with haze that grows with
## distance, and the valley floor far below. The layers slide at different
## speeds as you climb, so height feels like height.

const P := preload("res://scripts/climb/art/climb_paint.gd")
const SCREEN := Vector2i(480, 270)
## Extra picture above each layer, so tall landmarks aren't cut off as the
## layers sink.
const PAD := 110

## Base line of each depth layer (0 far .. 2 near) in the layer's picture,
## and how much haze it carries.
const LAYER_BASE := [176, 198, 220]
const LAYER_HAZE := [0.4, 0.26, 0.12]
const ROCK_BODY := Color("8c8492")

## width and height in pixels at scale 1, and the painter that shapes the
## landmark. See _profile().
const LANDMARKS := {
	"half_dome": {"w": 120, "h": 104, "trees": true},
	"north_dome": {"w": 110, "h": 58, "trees": true},
	"basket_dome": {"w": 72, "h": 40, "trees": true},
	"liberty_cap": {"w": 56, "h": 70, "trees": true},
	"mt_broderick": {"w": 100, "h": 44, "trees": true},
	"glacier_point": {"w": 150, "h": 96, "trees": true, "rail": true},
	"royal_arches": {"w": 150, "h": 82, "trees": true, "arches": true},
	"washington_column": {"w": 76, "h": 96, "trees": true},
	"sentinel_rock": {"w": 64, "h": 130, "trees": true, "fall": true},
	"cathedral_rocks": {"w": 150, "h": 100, "trees": true},
	"el_capitan": {"w": 176, "h": 150, "streaks": true},
	"three_brothers": {"w": 140, "h": 108, "trees": true},
	"yosemite_falls": {"w": 130, "h": 140, "trees": true, "fall": true},
	"bridalveil": {"w": 84, "h": 100, "trees": true, "fall": true},
	"nevada_fall": {"w": 90, "h": 78, "trees": true, "fall": true},
	"clouds_rest": {"w": 220, "h": 78, "trees": true},
	"cockscomb": {"w": 130, "h": 80, "trees": false},
	"unicorn_peak": {"w": 76, "h": 118, "trees": false, "snow": true},
	"echo_peaks": {"w": 130, "h": 96, "trees": false, "snow": true},
	"matthes_crest": {"w": 170, "h": 70, "trees": false},
	"mt_lyell": {"w": 150, "h": 128, "trees": false, "snow": true, "glacier": true},
	"mt_maclure": {"w": 116, "h": 104, "trees": false, "snow": true, "glacier": true},
	"donohue_pass": {"w": 200, "h": 56, "trees": false, "snow": true},
	"sierra_crest": {"w": 480, "h": 70, "trees": false, "snow": true},
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
	for spec: Dictionary in profile.get("view", []):
		var kind: String = spec.k
		var l := int(spec.get("l", 1))
		var info: Dictionary = LANDMARKS.get(kind, {})
		if info.is_empty():
			continue
		var found := _paint_landmark(images[l], kind, info, int(spec.x), float(spec.get("s", 1.0)), l, pal, rng)
		for f: Dictionary in found:
			f["layer"] = l
			falls.append(f)
	for l in 3:
		layers.append({"image": images[l], "sink": sinks[l], "pad": PAD})
	# The valley floor, far below.
	var ground := P.make(SCREEN.x, SCREEN.y + 200 + PAD)
	_floor(ground, profile.get("ground", "valley_forest"), pal, rng)
	layers.append({"image": ground, "sink": 150.0, "pad": PAD})
	return {"layers": layers, "falls": falls}


## The haze color a layer fades toward, and the rock color at that depth.
static func _body(pal: Dictionary, l: int) -> Dictionary:
	var haze: Color = (pal.low as Color).lerp(pal.mid, 0.45)
	var lum: float = pal.get("lum", 1.0)
	var base: Color = Color(ROCK_BODY.r * lum, ROCK_BODY.g * lum, ROCK_BODY.b * lum).lerp(pal.tint, 0.25)
	var fade: float = LAYER_HAZE[l]
	var body := base.lerp(haze, fade)
	return {
		"body": body,
		"lit": body.lerp(pal.rim, 0.35).lightened(0.12),
		"shade": body.darkened(0.2 + 0.1 * (1.0 - fade)).lerp(pal.top, 0.15),
		"deep": body.darkened(0.38).lerp(pal.top, 0.2),
		"tree": Color("2e5a3c").lerp(haze, fade * 0.9).darkened(0.05),
		"tree_lit": Color("4a8050").lerp(haze, fade * 0.85),
		"snow": Color("f2f6fa").lerp(haze, fade * 0.5).lerp(pal.tint, 0.2),
		"snow_shade": Color("b8c8e0").lerp(haze, fade * 0.5),
		"haze": haze,
	}


static func _ridge(im: Image, l: int, pal: Dictionary, rng: RandomNumberGenerator, alpine: bool) -> void:
	var c := _body(pal, l)
	var base: int = LAYER_BASE[l] + 6 + PAD
	var amp: float = [30.0, 22.0, 14.0][l]
	var p1 := rng.randf() * TAU
	var p2 := rng.randf() * TAU
	var f: float = [0.011, 0.018, 0.028][l]
	var prev := 0.0
	for x in SCREEN.x:
		var top: float = base - amp * (0.55 + 0.3 * sin(x * f + p1) + 0.18 * sin(x * f * 2.7 + p2) + 0.08 * sin(x * f * 6.3))
		if l == 2:
			top += 8.0
		_column(im, x, int(top), im.get_height(), c, int(top) - int(prev) if x > 0 else 0, l >= 1 and not alpine, rng)
		prev = top


## One column of a silhouette, from [param top] down: a lit rim on rising
## ground, shade on falling, trees speckled below the crest.
static func _column(im: Image, x: int, top: int, bottom: int, c: Dictionary, slope: int, trees: bool, rng: RandomNumberGenerator) -> void:
	if top >= bottom:
		return
	var col: Color = c.lit if slope < 0 else (c.shade if slope > 0 else c.body)
	im.fill_rect(Rect2i(x, top, 1, bottom - top), c.body)
	im.fill_rect(Rect2i(x, top, 1, mini(3, bottom - top)), col)
	if trees and top + 8 < bottom:
		var y := top + 6
		if (x * 7 + top) % 5 < 3:
			im.fill_rect(Rect2i(x, y, 1, mini(10, bottom - y)), c.tree if (x & 1) == 0 else c.tree_lit)


static func _paint_landmark(im: Image, kind: String, info: Dictionary, cx: int, s: float, l: int, pal: Dictionary, rng: RandomNumberGenerator) -> Array[Dictionary]:
	var c := _body(pal, l)
	var w := int(info.w * s)
	var h := int(info.h * s)
	var base: int = LAYER_BASE[l] + 10 + PAD
	var x0 := cx - w / 2
	var tops := PackedInt32Array()
	tops.resize(w)
	for i in w:
		var u := (float(i) / maxf(w - 1, 1)) * 2.0 - 1.0
		tops[i] = base - int(_profile(kind, u, i, rng) * h)
	var falls: Array[Dictionary] = []
	var snow: bool = info.get("snow", false)
	_shade_landmark(im, kind, x0, w, h, tops, base, c, info, rng)
	if info.get("streaks", false):
		# El Capitan's dark water stains, and its sunlit buttress.
		for k in 7:
			var sx := x0 + int(w * (0.12 + 0.11 * k)) + rng.randi_range(-3, 3)
			var top := base - int(h * 0.97)
			for y in range(top + 12, base, 1):
				if (y + k) % 4 != 0 and sx >= 0 and sx < im.get_width():
					im.set_pixel(sx, y, c.deep)
					if y % 3 == 0:
						im.set_pixel(sx + 1, y, c.shade)
		# The prow: a lit edge down the left.
		for y in range(base - int(h * 0.97), base):
			im.set_pixel(clampi(x0 + 4, 0, im.get_width() - 1), y, c.lit)
	if info.get("arches", false):
		# Royal Arches: great curved recesses in the wall.
		for k in 3:
			var ax := x0 + int(w * (0.22 + 0.27 * k))
			var ay := base - int(h * 0.55)
			for t in range(0, 180, 6):
				var rad := 12.0 + k * 3
				var px := int(ax + cos(deg_to_rad(t)) * rad)
				var py := int(ay - sin(deg_to_rad(t)) * rad * 0.9)
				if px >= 0 and px < im.get_width():
					im.set_pixel(px, py, c.deep)
					im.set_pixel(px, py + 1, c.shade)
	if info.get("rail", false):
		# Glacier Point's rim: a thin dark line with a tiny railing.
		var rail_x0 := x0 + int(w * 0.18)
		for i in int(w * 0.5):
			var x := rail_x0 + i
			var top := tops[clampi(int(w * 0.18) + i, 0, w - 1)]
			if x >= 0 and x < im.get_width() and (i % 3) != 2:
				im.set_pixel(x, top - 2, c.deep)
	if snow:
		_snow(im, x0, w, tops, base, c, info.get("glacier", false), rng)
	if info.get("fall", false):
		# A waterfall ribbon from a notch near the top.
		var fx := x0 + int(w * (0.5 if kind != "sentinel_rock" else 0.78))
		var ftop := base - int(h * 0.82)
		var fbot := base - int(h * 0.05)
		if kind == "bridalveil":
			fx = x0 + int(w * 0.55)
			ftop = base - int(h * 0.88)
		for y in range(ftop, fbot):
			var drift := int(sin(y * 0.06) * 1.0) + (int((y - ftop) * 0.04) if kind == "bridalveil" else 0)
			var xx := fx + drift
			if xx >= 0 and xx < im.get_width():
				im.set_pixel(xx, y, Color("eaf4fa").lerp(c.haze, 0.2))
				if y % 5 < 3:
					im.set_pixel(xx + 1, y, Color("b8d8ec").lerp(c.haze, 0.3))
		falls.append({"x": fx, "y0": ftop, "y1": fbot})
	return falls


## Lights a landmark: a dome-like gradient from the sunny left to the shaded
## right, darker toward its foot, lit and shaded flanks where the outline
## rises and falls, a rim light on top, and a band of forest at its base.
static func _shade_landmark(im: Image, kind: String, x0: int, w: int, h: int, tops: PackedInt32Array, base: int, c: Dictionary, info: Dictionary, rng: RandomNumberGenerator) -> void:
	var ramp: Array[Color] = [c.lit, c.lit.lerp(c.body, 0.5), c.body, c.shade, c.deep]
	var treeline := PackedInt32Array()
	treeline.resize(w)
	for i in w:
		treeline[i] = base - int(h * 0.12) - int(P.smooth_noise(i * 0.12, 3.0, 17) * h * 0.12) - (i % 5) / 2
	var face_from := 0.22 if kind == "half_dome" else 2.0
	for i in w:
		var x := x0 + i
		if x < 0 or x >= im.get_width():
			continue
		var top := tops[i]
		if top >= base:
			continue
		var u := (float(i) / maxf(w - 1, 1)) * 2.0 - 1.0
		var d := 0
		if i > 2 and i < w - 3:
			d = tops[i - 2] - tops[i + 2]
		var height := maxi(base - top, 1)
		for y in range(top, base + 24):
			var depth := float(y - top) / height
			var s := 0.55 - u * 0.42 + clampf(d * 0.07, -0.4, 0.4) + depth * 0.22
			s += (P.smooth_noise(x * 0.09, y * 0.05, 5) - 0.5) * 0.24
			if u > face_from:
				s += 0.35
			if y - top < 3:
				s -= 0.5
			# Pixel-art bands: five tones, dithered at the seams.
			var q := clampf(s, 0.0, 0.999) * 4.0
			var k := int(q)
			var f := q - k
			var pick := k + (1 if P.dither(x, y, f) else 0)
			var col: Color = ramp[mini(pick, 4)]
			if info.get("trees", false) and y >= treeline[i]:
				var tcol: Color = c.tree if (x + y) % 4 != 0 else c.tree_lit
				if (x / 3 + (y / 3)) % 2 == 0 and y < treeline[i] + 6:
					tcol = c.tree_lit
				col = tcol
			im.set_pixel(x, y, col)
		# Trees poke up along the treeline.
		if info.get("trees", false) and i % 4 == 0:
			var ty := treeline[i]
			for k in 4:
				im.set_pixel(clampi(x - 1 + (k % 3), 0, im.get_width() - 1), ty - 1 - k / 2, c.tree)
	if kind == "half_dome":
		# The sheer face: dark vertical stains and a lit crack line.
		for k in 5:
			var sx := x0 + int(w * (0.62 + 0.014 * k))
			for y in range(base - int(h * 0.92), base - int(h * 0.15)):
				if (y + k * 3) % 5 != 0:
					im.set_pixel(clampi(sx, 0, im.get_width() - 1), y, c.deep)


## A sawtooth ridge: pointed teeth of random heights, 0..1.
static func _teeth(i: int, period: float, seed_value: int) -> float:
	var cell := floori(i / period)
	var f := fmod(i, period) / period
	var peak := 0.35 + 0.65 * P.noise(cell, seed_value, 12)
	return peak * (1.0 - absf(f * 2.0 - 1.0)) + 0.15 * P.noise(i, seed_value, 13)


## How tall a landmark is at normalized position [param u] (-1..1), 0..1.
static func _profile(kind: String, u: float, i: int, rng: RandomNumberGenerator) -> float:
	match kind:
		"half_dome":
			# A rounded dome on the left, a sheer face on the right.
			if u > 0.38:
				return 0.0
			var d := (u + 0.2) / 0.92
			return sqrt(maxf(1.0 - d * d, 0.0))
		"north_dome", "basket_dome":
			return sqrt(maxf(1.0 - u * u, 0.0)) * (0.92 + 0.08 * sin(u * 9.0))
		"liberty_cap":
			return pow(maxf(1.0 - u * u, 0.0), 0.7)
		"mt_broderick":
			return pow(maxf(1.0 - u * u, 0.0), 0.8) * (0.9 + 0.1 * sin(u * 7.0))
		"glacier_point", "nevada_fall":
			if u > 0.55:
				return 0.0
			return clampf((u + 1.0) * 1.6, 0.0, 1.0) * (0.96 + 0.04 * sin(u * 11.0))
		"royal_arches":
			return clampf((u + 1.0) * 3.0, 0.0, 1.0) * (0.84 + 0.16 * smoothstep(-1.0, 0.5, u)) * (1.0 if u < 0.92 else 0.0)
		"washington_column":
			var e := clampf(1.0 - pow(absf(u), 6.0), 0.0, 1.0)
			return pow(e, 0.4) * (0.95 + 0.05 * u)
		"sentinel_rock":
			var s := clampf(1.0 - pow(absf(u + 0.08), 4.0), 0.0, 1.0)
			return pow(s, 0.45) * (0.78 + 0.22 * (u * 0.5 + 0.5))
		"cathedral_rocks":
			var a := pow(maxf(1.0 - pow(absf(u + 0.55) * 2.5, 2.0), 0.0), 0.5) * 0.7
			var b := pow(maxf(1.0 - pow(absf(u) * 2.2, 2.0), 0.0), 0.5) * 1.0
			var c2 := pow(maxf(1.0 - pow(absf(u - 0.55) * 2.5, 2.0), 0.0), 0.5) * 0.8
			return maxf(maxf(a, b), maxf(c2, 0.2 * (1.0 - absf(u))))
		"el_capitan":
			if u < -0.97:
				return 0.0
			var prow := smoothstep(-0.99, -0.88, u)
			return prow * (0.98 - 0.04 * u) * (1.0 if u < 0.97 else 0.0)
		"three_brothers":
			var step := 0.42 + 0.58 * clampf((u + 0.9) / 1.7, 0.0, 1.0)
			var st := floorf(step * 3.0) / 3.0 + (step * 3.0 - floorf(step * 3.0)) * 0.12
			return clampf(st + 0.12, 0.0, 1.0) * (1.0 if u < 0.9 else 0.0)
		"yosemite_falls", "bridalveil":
			var plateau := smoothstep(-1.0, -0.82, u) * (1.0 - smoothstep(0.82, 1.0, u))
			var notch := 0.06 if absf(u) < 0.07 else 0.0
			return maxf(plateau * 0.96 - notch, 0.0) * (0.94 + 0.06 * sin(u * 8.0))
		"clouds_rest":
			return pow(maxf(1.0 - absf(u - 0.35) * 0.9, 0.0), 1.6) * (0.9 + 0.1 * sin(u * 13.0))
		"cockscomb":
			return clampf(0.5 + 0.38 * _teeth(i, 9.0, 3) + 0.1 * sin(u * 5.0), 0.0, 1.0) * clampf((1.0 - absf(u)) * 6.0, 0.0, 1.0)
		"unicorn_peak":
			return pow(maxf(1.0 - absf(u) * 1.1, 0.0), 1.5)
		"echo_peaks":
			var p1 := pow(maxf(1.0 - absf(u + 0.5) * 2.4, 0.0), 1.2) * 0.8
			var p2 := pow(maxf(1.0 - absf(u - 0.05) * 2.0, 0.0), 1.2) * 1.0
			var p3 := pow(maxf(1.0 - absf(u - 0.6) * 2.6, 0.0), 1.2) * 0.7
			return maxf(maxf(p1, p2), maxf(p3, 0.18))
		"matthes_crest":
			return clampf(0.55 + 0.3 * _teeth(i, 13.0, 8) + 0.08 * sin(u * 9.0), 0.0, 1.0) * clampf((1.0 - absf(u)) * 3.0, 0.0, 1.0) + 0.06
		"mt_lyell":
			return pow(maxf(1.0 - absf(u - 0.1) * 1.05, 0.0), 1.15) * (0.93 + 0.07 * sin(u * 17.0))
		"mt_maclure":
			return pow(maxf(1.0 - absf(u + 0.1) * 1.1, 0.0), 1.2) * (0.92 + 0.08 * sin(u * 15.0))
		"donohue_pass":
			return pow(maxf(1.0 - u * u, 0.0), 0.9) * (0.7 + 0.3 * sin(u * 5.0 + 1.0))
		"sierra_crest":
			var t := 0.42 + 0.22 * sin(u * 7.0) + 0.12 * sin(u * 17.0 + 1.0) + 0.2 * _teeth(i, 17.0, 2)
			return clampf(t, 0.05, 1.0)
	return 0.0


static func _snow(im: Image, x0: int, w: int, tops: PackedInt32Array, base: int, c: Dictionary, glacier: bool, rng: RandomNumberGenerator) -> void:
	for i in w:
		var x := x0 + i
		if x < 0 or x >= im.get_width() or tops[i] >= base:
			continue
		var depth := base - tops[i]
		var cap := int(depth * (0.18 if not glacier else 0.14))
		# Snow lies on the lit slopes near the crest, patchy.
		for k in cap:
			if P.noise(i, k, 31) < 0.78 - float(k) / maxf(cap, 1) * 0.5:
				im.set_pixel(x, tops[i] + 2 + k, c.snow if (i + k) % 3 != 0 else c.snow_shade)
		if glacier and i > w * 0.18 and i < w * 0.55:
			# A tongue of ice down the north face.
			var gt := tops[i] + int(depth * 0.4)
			for k in int(depth * 0.3):
				if P.noise(i, k, 41) < 0.8:
					im.set_pixel(x, gt + k, c.snow_shade if k % 3 == 0 else c.snow.lerp(Color("a8d0f0"), 0.35))


# ---------------------------------------------------------------- the floor

## The valley floor (or high-country basin) far below: forest canopy, meadow,
## river glints, roads. Painted dark and soft, as seen from a long way up.
static func _floor(im: Image, kind: String, pal: Dictionary, rng: RandomNumberGenerator) -> void:
	var w := im.get_width()
	var h := im.get_height()
	var lum: float = pal.get("lum", 1.0)
	var haze: Color = pal.low
	var forest := Color("2e5a3c").lerp(pal.tint, 0.15).darkened(0.1 + (1.0 - lum) * 0.2).lerp(haze, 0.18)
	var forest_lit := Color("4a8050").lerp(pal.tint, 0.2).lerp(haze, 0.2)
	var meadow := Color("8aa850").lerp(pal.tint, 0.3).lerp(haze, 0.25)
	var water := Color("6aa8d8").lerp(pal.low, 0.3)
	var top := 130 + PAD
	var alpine := kind in ["tuolumne", "moraine"]
	if alpine:
		forest = Color("3a5a40").lerp(haze, 0.2)
		meadow = Color("a0a860").lerp(haze, 0.3)
	if kind == "moraine":
		forest = Color("7a7a82").lerp(haze, 0.25)
		meadow = Color("a8a8b0").lerp(haze, 0.3)
		forest_lit = Color("c8ccd8").lerp(haze, 0.2)
	for x in w:
		var edge := top + int(sin(x * 0.02) * 10.0 + sin(x * 0.07) * 4.0)
		im.fill_rect(Rect2i(x, edge, 1, h - edge), forest)
		im.fill_rect(Rect2i(x, edge, 1, 2), forest_lit)
	# Canopy: speckled treetops.
	for i in w * (h - top) / 40:
		var x := rng.randi_range(0, w - 1)
		var y := rng.randi_range(top + 4, h - 2)
		var r := rng.randi_range(1, 3)
		var col := forest_lit if rng.randf() < 0.4 else forest.darkened(0.15)
		im.fill_rect(Rect2i(x, y, r + 1, r), col)
	# Meadows and the river (and Curry Village's cabins when it's there).
	if kind != "moraine":
		for i in 5:
			var mx := rng.randi_range(20, w - 120)
			var my := rng.randi_range(top + 30, top + 110)
			P.ellipse(im, mx, my, rng.randi_range(30, 70), rng.randi_range(6, 12), meadow)
	var ry := top + 70
	for x in w:
		var y := ry + int(sin(x * 0.03 + 1.0) * 10.0 + sin(x * 0.011) * 18.0)
		P.px(im, x, y, water)
		P.px(im, x, y + 1, water.darkened(0.12))
		if x % 11 == 0:
			P.px(im, x, y - 1, Color("f4f8fa").lerp(haze, 0.2))
	match kind:
		"curry", "camp4", "ahwahnee":
			# A scatter of cabin roofs and tents.
			for i in 26:
				var x := rng.randi_range(40, w - 50)
				var y := rng.randi_range(top + 40, top + 90)
				var roof: Color = [Color("a8602e"), Color("d8c8a0"), Color("8a4a2a"), Color("e8e0c8")][rng.randi() % 4].lerp(haze, 0.15)
				P.rect(im, x, y, 4, 2, roof)
				P.rect(im, x, y + 2, 4, 1, roof.darkened(0.3))
		"el_cap_meadow":
			# A pale road across the meadow with a few cars.
			for x in w:
				var y := top + 54 + int(sin(x * 0.015) * 6.0)
				P.px(im, x, y, Color("b8b0a0").lerp(haze, 0.2))
				if x % 37 == 0:
					P.rect(im, x, y - 1, 3, 2, [Color("c84a3a"), Color("4a78c8"), Color("e8e0c8")][(x / 37) % 3])
		"tuolumne":
			# Tuolumne Meadows: a long pale meadow with a winding river.
			for i in 3:
				P.ellipse(im, 140 + i * 110, top + 60, 80, 10, meadow.lightened(0.1))
		"moraine":
			for i in 14:
				P.ellipse(im, rng.randi_range(20, w - 20), rng.randi_range(top + 30, top + 140), 8, 3, Color("6a98c8").lerp(haze, 0.3))
