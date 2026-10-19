extends RefCounted
## Trees and shrubs for the hubs outside the Valley, drawn with the Ahwahnee
## flora's helpers, ramps and light (ahwahnee_flora_art.gd): the foothill
## woodland of El Portal down the Merced canyon (interior live oak, blue oak,
## gray pine, California buckeye, western redbud, white alder by the river,
## chamise and toyon), and the Big Trees of Wawona's Mariposa Grove (mature
## giant sequoias, the Grizzly Giant, the California Tunnel Tree, the Fallen
## Monarch, and sugar pines).
##
## Written to assets/sprites/ahwahnee/ beside the Valley's trees, at the same
## 16px scale, so the hub builders scatter them with the same helpers. The
## deciduous ones also get their seasons in seasons/ (SeasonalDressing swaps
## them in by name): the blue oak and the alder go gold and then bare; the
## buckeye blooms in spring, browns by summer and stands bare with its big
## seeds hanging; the redbud is magenta in spring. Every sprite is anchored at
## its bottom center and sits on a ground line F.BASE_INSET px above its
## bottom edge.

const K = preload("res://tools/hubs/pixel_kit.gd")
const F = preload("res://tools/hubs/ahwahnee_flora_art.gd")
const DIR := F.DIR
const SEASON_DIR := F.DIR + "seasons/"

## Collision footprints (width, depth), as in F.TRUNKS.
const TRUNKS := {
	"tree_live_oak_a": Vector2(9, 5), "tree_live_oak_b": Vector2(9, 5),
	"tree_blue_oak_a": Vector2(7, 5), "tree_blue_oak_b": Vector2(7, 5),
	"tree_gray_pine_a": Vector2(6, 5), "tree_gray_pine_b": Vector2(6, 5),
	"tree_buckeye": Vector2(10, 5),
	"tree_redbud": Vector2(6, 4),
	"tree_alder_a": Vector2(5, 4), "tree_alder_b": Vector2(5, 4),
	"tree_sugar_pine_a": Vector2(8, 5), "tree_sugar_pine_b": Vector2(8, 5),
	"tree_sequoia_giant_a": Vector2(30, 10), "tree_sequoia_giant_b": Vector2(26, 9),
	"tree_sequoia_giant_c": Vector2(22, 8),
	"tree_grizzly_giant": Vector2(38, 12),
	"tree_fallen_monarch": Vector2(132, 12),
}
## The Tunnel Tree is solid either side of its tunnel, open in the middle.
const EXTRA_FOOTPRINTS := {
	"tree_tunnel": [Rect2(-21, -10, 12, 10), Rect2(9, -10, 12, 10)],
}
const FILES: Array[String] = [
	"tree_live_oak_a", "tree_live_oak_b", "tree_blue_oak_a", "tree_blue_oak_b", "tree_gray_pine_a", "tree_gray_pine_b",
	"tree_buckeye", "tree_redbud", "tree_alder_a", "tree_alder_b", "tree_sugar_pine_a", "tree_sugar_pine_b",
	"tree_sequoia_giant_a", "tree_sequoia_giant_b", "tree_sequoia_giant_c", "tree_grizzly_giant", "tree_tunnel",
	"tree_fallen_monarch", "plant_chamise_a", "plant_chamise_b", "plant_toyon",
]
const SEASON_NAMES := ["spring", "summer", "fall", "winter"]

# Ramps, dark to light, in the flora's manner: cool shadows, warm lights.
const LIVE_OAK_LEAF := ["13261c", "1b3424", "25442b", "315633", "41693a", "567f42", "70984c", "8fb25c"]
const BLUE_OAK_LEAF := ["1a2c2a", "263e38", "345444", "456a50", "5a805e", "74986e", "92b082", "b0c698"]
const BLUE_OAK_FALL := ["2e2418", "4a3820", "6a5028", "8a6a34", "a88642", "c4a456", "dcc072", "eed894"]
const BARK_PALE := ["2a2828", "454240", "64605c", "86807a", "a8a198", "c8c0b4"]
const GRAY_NEEDLE := ["1a2c22", "27402e", "355636", "466a3e", "5a7e48", "729456", "8ca866", "a8bc7a"]
const BARK_GRAY_PINE := ["22201e", "38322c", "52483e", "6c5e50", "887662", "a28e76"]
const BUCKEYE_LEAF := ["17301e", "214226", "2f5a2e", "407238", "568c42", "72a64e", "94c060", "b8d878"]
const BUCKEYE_DRY := ["2c1c14", "48301c", "684424", "8a5c2e", "a8763a", "c4924a", "dcb064"]
const REDBUD_LEAF := ["1a3220", "26462a", "345e34", "46783e", "5c904a", "78aa58", "9cc46c"]
const REDBUD_BLOOM := ["3e1430", "5c1c44", "7e2658", "a2346e", "c44a86", "de6ea0", "f096bc", "fcc0d8"]
const REDBUD_FALL := ["3a1c14", "5a2c18", "7e441e", "a46224", "c4842e", "dca43e", "f0c45a"]
const ALDER_LEAF := ["17301f", "223f27", "305430", "3f6a38", "538244", "6c9a52", "8cb466"]
const ALDER_FALL := ["2c2616", "46401e", "645a28", "827234", "9e8c42", "b8a656", "d0bf72"]
const SEQUOIA_LEAF := ["122a26", "1a3a30", "254c3a", "325f44", "427350", "58885e", "73a070", "93b884"]
const BARK_SEQUOIA := ["3a1a12", "58281a", "783820", "984a28", "b45e32", "cc7840", "e09654"]
const CHAR := ["120e0e", "1e1818", "2e2422", "40322c"]
const SILVER := ["3a3634", "57514c", "7a736a", "9e968a", "c2baac", "e0d8c8"]
const SUGAR_NEEDLE := ["17302a", "1f3e34", "2b503e", "3a6448", "4c7a54", "64905f", "82a872"]
const CHAMISE := ["1e2a1c", "2a3a24", "3a4c2c", "4c5e34", "62723e", "7c884c"]
const TOYON := ["12261a", "1a3422", "24462a", "305834", "406c3e", "56844a"]


func save_all() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SEASON_DIR))
	var base := {
		"tree_live_oak_a": live_oak(0), "tree_live_oak_b": live_oak(1),
		"tree_blue_oak_a": blue_oak(0), "tree_blue_oak_b": blue_oak(1),
		"tree_gray_pine_a": gray_pine(0), "tree_gray_pine_b": gray_pine(1),
		"tree_buckeye": buckeye(0), "tree_redbud": redbud(1),
		"tree_alder_a": alder(0), "tree_alder_b": alder(1),
		"tree_sugar_pine_a": sugar_pine(0), "tree_sugar_pine_b": sugar_pine(1),
		"tree_sequoia_giant_a": sequoia_giant(0), "tree_sequoia_giant_b": sequoia_giant(1),
		"tree_sequoia_giant_c": sequoia_giant(2), "tree_grizzly_giant": grizzly_giant(),
		"tree_tunnel": tunnel_tree(), "tree_fallen_monarch": fallen_monarch(),
		"plant_chamise_a": chamise(0), "plant_chamise_b": chamise(1), "plant_toyon": toyon(),
	}
	for sprite_name: String in base:
		_save(DIR + sprite_name, base[sprite_name])
	# The seasons of the deciduous trees (a season with no picture keeps the base).
	for v in 2:
		var n := "tree_blue_oak_" + "ab"[v]
		_save(SEASON_DIR + n + "_fall", blue_oak(v, 2))
		_save(SEASON_DIR + n + "_winter", blue_oak(v, 3))
		n = "tree_alder_" + "ab"[v]
		_save(SEASON_DIR + n + "_fall", alder(v, 2))
		_save(SEASON_DIR + n + "_winter", alder(v, 3))
	for s in [1, 2, 3]:
		_save(SEASON_DIR + "tree_buckeye_" + SEASON_NAMES[s], buckeye(s))
	for s in [0, 2, 3]:
		_save(SEASON_DIR + "tree_redbud_" + SEASON_NAMES[s], redbud(s))


func _save(path: String, im: Image) -> void:
	im.save_png(ProjectSettings.globalize_path(path + ".png"))


# ---------------------------------------------------------------- helpers

## A broadleaf crown of lit clumps over a dark mass, as on the black oak.
## [param gaps] above 0 skips some clumps and the dark mass, for an open crown.
static func crown(im: Image, cx: float, cy: float, rx: float, ry: float, leaf: Array[Color], sd: int, n: int, r0: float, r1: float, gaps := 0.0, specks := 6) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = sd
	var clumps: Array[Vector3] = []
	for i in n:
		var a := rng.randf() * TAU
		var d := 0.3 + 0.7 * sqrt(rng.randf())
		clumps.append(Vector3(cx + cos(a) * d * rx, cy + sin(a) * d * ry * (0.9 if sin(a) > 0.0 else 1.0), rng.randf_range(r0, r1)))
	clumps.sort_custom(func(a: Vector3, b: Vector3) -> bool: return a.y < b.y)
	if gaps <= 0.0:
		F.blob_orig(im, cx, cy + 2.0, rx * 0.84, ry * 0.76, leaf, sd + 1, -0.4, 0.1, 0.05)
	for i in clumps.size():
		if gaps > 0.0 and K.hash2(i, 7, sd) < gaps:
			continue
		var cl := clumps[i]
		var g := ((cx - cl.x) * 0.5 + (cy - cl.y) * 0.75) / maxf(rx, ry)
		var bias := clampf(g, -0.3, 0.16) - 0.34
		F.blob_orig(im, cl.x, cl.y, cl.z, cl.z * 0.82, leaf, sd + 9 * i, bias, 0.17, 0.17)
		F.leaf_specks(im, cl.x, cl.y, cl.z, cl.z * 0.82, leaf, sd + i * 5, specks)


## Bare twigs fanning out from every limb tip, for a tree in winter.
static func twigs(im: Image, tips: Array, bark: Array[Color], sd: int, reach := 8.0) -> void:
	for p: Vector2 in tips:
		for t in 5:
			var ang := (t - 2.0) * 0.6 + (K.hash2(t, int(p.x), sd) - 0.5) * 0.5
			var r := reach * (0.7 + K.hash2(t, int(p.y), sd + 3) * 0.6)
			F.limb(im, p.x, p.y, p.x + sin(ang) * r, p.y - cos(ang) * r, 2.0, 0.8, bark, sd + t * 31 + int(p.y), 1.4)


## Limbs from a fork out to [param ends] (offsets from the fork); returns the tips.
static func limbs(im: Image, fx: float, fy: float, ends: Array, w0: float, bark: Array[Color], sd: int) -> Array:
	var tips := []
	for e: Vector2 in ends:
		F.limb(im, fx, fy, fx + e.x, fy + e.y, w0, maxf(1.2, w0 * 0.35), bark, sd + int(e.y * 7.0 + e.x), 2.5)
		tips.append(Vector2(fx + e.x, fy + e.y))
	return tips


# ---------------------------------------------------------------- the foothills

## An interior live oak: a low, dense, dark dome of glossy evergreen leaves
## on a short trunk that splits near the ground.
func live_oak(v: int) -> Image:
	var w := 80
	var h := 72
	var im := K.make(w, h)
	var sd := 2100 + v * 41
	var cx := w / 2.0 + (2.0 if v == 1 else -1.0)
	var base := h - 4
	var bark := F.ramp(F.BARK_OAK)
	var leaf := F.ramp(LIVE_OAK_LEAF)
	K.shadow(im, cx + 5.0, base + 0.5, 26.0, 4.6, 0.3)
	var fork := base - 14
	F.trunk(im, cx, base, fork, 10.0, 7.0, bark, sd, 1.0, 1.5 - v * 3.0, 5, 4.0)
	var fx := F.trunk_x(cx, fork, base, fork, sd, 1.0, 1.5 - v * 3.0)
	limbs(im, fx, fork + 2.0, [Vector2(-22, -18), Vector2(20, -20), Vector2(-4, -30), Vector2(-30, -8), Vector2(28, -10)], 6.0, bark, sd)
	crown(im, fx, 28.0 + v, 33.0 - v * 2.0, 21.0, leaf, sd, 58, 4.5, 8.0)
	# the skirt of leaves hanging low round the trunk
	for i in 4:
		F.blob_orig(im, fx + (i - 1.5) * 15.0, 46.0 + K.hash2(i, 1, sd) * 3.0, 7.0, 4.5, leaf, sd + 130 + i, -0.44, 0.15, 0.2)
	F.rim(im, 0.5)
	return im


## A blue oak: a rounded, open crown of small blue-gray leaves on the hottest,
## driest slopes, and pale gray bark. Gold in fall, bare in winter.
func blue_oak(v: int, season := 1) -> Image:
	var w := 64
	var h := 72
	var im := K.make(w, h)
	var sd := 2300 + v * 29
	var cx := w / 2.0
	var base := h - 4
	var bark := F.ramp(BARK_PALE)
	K.shadow(im, cx + 4.0, base + 0.5, 20.0, 4.0, 0.28)
	var fork := base - 22 + v * 3
	var lean := -1.5 if v == 0 else 2.0
	F.trunk(im, cx, base, fork, 7.0, 5.0, bark, sd, 1.2, lean, 4, 3.0)
	var fx := F.trunk_x(cx, fork, base, fork, sd, 1.2, lean)
	var tips := limbs(im, fx, fork + 2.0, [Vector2(-17, -20), Vector2(15, -22), Vector2(-2, -32), Vector2(-24, -6), Vector2(22, -8)], 4.5, bark, sd)
	if season == 3:
		twigs(im, tips, bark, sd, 7.0)
	else:
		crown(im, fx, 26.0, 24.0, 19.0, F.ramp(BLUE_OAK_FALL if season == 2 else BLUE_OAK_LEAF), sd, 42, 4.0, 6.5, 0.06, 7)
	F.rim(im, 0.5)
	return im


## A gray pine: a forked, leaning trunk and a thin, wispy crown of long
## gray-green needles you can see the sky through, with big cones.
func gray_pine(v: int) -> Image:
	var w := 52
	var h := 108
	var im := K.make(w, h)
	var sd := 2500 + v * 37
	var cx := w / 2.0
	var base := h - 4
	var bark := F.ramp(BARK_GRAY_PINE)
	var needles := F.ramp(GRAY_NEEDLE)
	var lean := 3.0 if v == 0 else -4.0
	K.shadow(im, cx + 3.0, base + 0.5, 12.0, 3.0, 0.24)
	var fork := 58 + v * 6
	F.trunk(im, cx, base, fork, 6.0, 4.5, bark, sd, 1.4, lean, 6, 2.6)
	var fx := F.trunk_x(cx, fork, base, fork, sd, 1.4, lean)
	# two leaders lean apart from the fork
	var leaders := [Vector2(fx - 9.0 - v * 2.0, 8.0), Vector2(fx + 8.0, 16.0 + v * 4.0)]
	var tufts: Array[Vector3] = []
	for li in leaders.size():
		var top: Vector2 = leaders[li]
		F.limb(im, fx, fork + 1.0, top.x, top.y, 4.0, 1.4, bark, sd + li * 13, 2.0)
		# short crooked branches all the way up, each ending in a wisp
		for k in 6:
			var t := 0.2 + k * 0.15
			var p := Vector2(lerpf(fx, top.x, t), lerpf(fork, top.y, t))
			var side := -1.0 if (k + li) % 2 == 0 else 1.0
			var tip := p + Vector2(side * (6.0 + K.hash2(k, li, sd) * 6.0), -3.0 - K.hash2(k, li, sd + 1) * 3.0)
			F.limb(im, p.x, p.y, tip.x, tip.y, 1.6, 0.8, bark, sd + k * 7 + li, 1.0)
			tufts.append(Vector3(tip.x, tip.y, 4.0 + K.hash2(k, li, sd + 2) * 2.0))
		tufts.append(Vector3(top.x, top.y + 1.0, 5.0))
	tufts.sort_custom(func(a: Vector3, b: Vector3) -> bool: return a.y < b.y)
	for i in tufts.size():
		var tf := tufts[i]
		F.tuft(im, tf.x, tf.y, tf.z, needles, sd + i * 3, 0.06)
	# the cones, as big as a fist, hanging under a few wisps
	for i in 3:
		var tf := tufts[(i * 5 + 2) % tufts.size()]
		var cxp := int(tf.x) + 1
		var cyp := int(tf.y) + 3
		K.rect(im, cxp - 1, cyp, 3, 4, Color("6a4a2a"))
		K.px(im, cxp - 1, cyp, Color("9a7444"))
		K.px(im, cxp + 1, cyp + 3, Color("3e2a18"))
	F.rim(im, 0.48)
	return im


## A California buckeye: a low, wide dome on several smooth gray trunks. In
## spring it holds up candles of white flowers; its leaves brown by
## midsummer, and it stands bare all fall and winter with its big seeds
## hanging like pears. Season -1 or 0 is the spring look.
func buckeye(season := 0) -> Image:
	var w := 64
	var h := 50
	var im := K.make(w, h)
	var sd := 2700
	var cx := w / 2.0
	var base := h - 4
	var bark := F.ramp(BARK_PALE)
	K.shadow(im, cx + 4.0, base + 0.5, 24.0, 3.8, 0.28)
	var tips := []
	for i in 3:
		var dx := (i - 1) * 9.0
		var top := Vector2(cx + dx * 2.2, 22.0 - absf(dx) * 0.3)
		F.limb(im, cx + dx * 0.4, base, top.x, top.y, 5.0, 2.4, bark, sd + i * 11, 2.0)
		tips.append(top)
		for j in 2:
			var e := top + Vector2((j * 2 - 1) * (7.0 + K.hash2(i, j, sd) * 4.0), -5.0)
			F.limb(im, top.x, top.y, e.x, e.y, 2.4, 1.0, bark, sd + i * 5 + j, 1.0)
			tips.append(e)
	if season >= 2:
		twigs(im, tips, bark, sd, 6.0)
		for i in tips.size():
			var p: Vector2 = tips[i]
			var sx := int(p.x + (K.hash2(i, 1, sd) - 0.5) * 6.0)
			var sy := int(p.y + 2.0)
			K.vline(im, sx, sy - 2, 2, Color("5a4630"))
			K.rect(im, sx - 1, sy, 3, 3, Color("7a5a3a"))
			K.px(im, sx - 1, sy, Color("a68058"))
	else:
		crown(im, cx, 20.0, 27.0, 14.0, F.ramp(BUCKEYE_DRY if season == 1 else BUCKEYE_LEAF), sd, 40, 4.5, 7.0)
		if season != 1:
			# candles of flowers stand up off the top of the crown
			var rng := RandomNumberGenerator.new()
			rng.seed = sd + 5
			for i in 18:
				var a := rng.randf_range(PI * 1.05, PI * 1.95)
				var d := 0.45 + rng.randf() * 0.5
				var x := int(cx + cos(a) * d * 25.0)
				var y := int(20.0 + sin(a) * d * 13.0) + 1
				for k in 5:
					var col := Color("fbf4e2") if k < 3 else Color("e8c8c8")
					if k == 0:
						col = Color("ffffff")
					K.px(im, x, y - k, col)
				K.px(im, x + 1, y - 1, Color("c8b8a8"))
	F.rim(im, 0.5)
	return im


## A western redbud: a many-stemmed little tree. Magenta flowers cover the
## bare twigs in early spring, then heart-shaped leaves; yellow and rust in
## fall, and pods hang on the bare twigs all winter.
func redbud(season := 1) -> Image:
	var w := 40
	var h := 38
	var im := K.make(w, h)
	var sd := 2900
	var cx := w / 2.0
	var base := h - 4
	var bark := F.ramp(F.BARK_OAK)
	K.shadow(im, cx + 3.0, base + 0.5, 13.0, 2.8, 0.26)
	var tips := []
	for i in 5:
		var dx := (i - 2) * 4.0
		var top := Vector2(cx + dx * 2.6, 13.0 + absf(dx) * 0.6)
		F.limb(im, cx + dx * 0.3, base, top.x, top.y, 2.4, 1.0, bark, sd + i * 7, 1.5)
		tips.append(top)
	if season == 3:
		twigs(im, tips, bark, sd, 5.0)
		for i in 12:
			var p: Vector2 = tips[i % tips.size()]
			var x := int(p.x + (K.hash2(i, 1, sd) - 0.5) * 10.0)
			var y := int(p.y - K.hash2(i, 2, sd) * 6.0)
			K.vline(im, x, y, 3, Color("6a3a38"))
			K.px(im, x, y + 3, Color("4a2826"))
	elif season == 0:
		twigs(im, tips, bark, sd, 5.0)
		crown(im, cx, 14.0, 15.0, 10.0, F.ramp(REDBUD_BLOOM), sd + 3, 26, 2.6, 4.2, 0.25, 9)
	else:
		crown(im, cx, 14.0, 15.0, 10.0, F.ramp(REDBUD_FALL if season == 2 else REDBUD_LEAF), sd + 3, 26, 3.0, 4.8, 0.1, 6)
	F.rim(im, 0.5)
	return im


## A white alder by the river: a straight pale trunk and a tall oval crown.
func alder(v: int, season := 1) -> Image:
	var w := 42
	var h := 88
	var im := K.make(w, h)
	var sd := 3100 + v * 23
	var cx := w / 2.0
	var base := h - 4
	var bark := F.ramp(BARK_PALE)
	K.shadow(im, cx + 3.0, base + 0.5, 11.0, 2.8, 0.26)
	var lean := 1.5 if v == 0 else -2.0
	F.trunk(im, cx, base, 14, 5.0, 2.0, bark, sd, 0.8, lean, 8, 2.0)
	var tips := []
	for k in 7:
		var y := 18.0 + k * 7.0
		var side := -1.0 if k % 2 == 0 else 1.0
		var sx := F.trunk_x(cx, int(y), base, 14, sd, 0.8, lean)
		var e := Vector2(sx + side * (8.0 + K.hash2(k, 1, sd) * 4.0), y - 6.0)
		F.limb(im, sx, y, e.x, e.y, 2.0, 0.9, bark, sd + k * 3, 1.0)
		tips.append(e)
	if season == 3:
		twigs(im, tips, bark, sd, 5.0)
		for i in tips.size():
			var p: Vector2 = tips[i]
			K.vline(im, int(p.x), int(p.y) + 1, 3, Color("7a5440"))
	else:
		crown(im, cx + lean * 0.5, 38.0, 16.0, 30.0, F.ramp(ALDER_FALL if season == 2 else ALDER_LEAF), sd, 34, 4.5, 7.0, 0.0, 6)
	F.rim(im, 0.5)
	return im


## Chamise: a dense, dark, needle-leaved chaparral shrub frothed with tiny
## white flowers.
func chamise(v: int) -> Image:
	var w := 28 if v == 0 else 22
	var h := 20 if v == 0 else 17
	var im := K.make(w, h)
	var sd := 3300 + v * 11
	K.shadow(im, w / 2.0, h - 3.0, w / 2.0 - 2.0, 2.0, 0.24)
	crown(im, w / 2.0, h - 9.0, w / 2.0 - 4.0, h / 2.0 - 4.0, F.ramp(CHAMISE), sd, 14, 3.0, 4.5, 0.0, 4)
	for i in 14:
		var x := int(K.hash2(i, 1, sd) * (w - 8)) + 4
		var y := int(K.hash2(i, 2, sd) * (h - 10)) + 3
		if im.get_pixel(x, y).a > 0.5:
			K.px(im, x, y, Color("f2ead8"))
	F.rim(im, 0.5)
	return im


## Toyon: a glossy dark shrub with bunches of red berries.
func toyon() -> Image:
	var w := 30
	var h := 24
	var im := K.make(w, h)
	var sd := 3400
	K.shadow(im, w / 2.0, h - 3.0, 12.0, 2.2, 0.24)
	crown(im, w / 2.0, h - 11.0, 11.0, 8.0, F.ramp(TOYON), sd, 16, 3.5, 5.0, 0.0, 5)
	for i in 6:
		var x := int(5 + K.hash2(i, 1, sd) * 20.0)
		var y := int(5 + K.hash2(i, 2, sd) * 10.0)
		for b: Vector2i in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1)]:
			K.px(im, x + b.x, y + b.y, Color("c43a2c") if (b.x + b.y) % 2 == 0 else Color("8a2420"))
		K.px(im, x, y, Color("f07858"))
	F.rim(im, 0.5)
	return im


# ---------------------------------------------------------------- the Big Trees

## A sugar pine: a tall straight trunk, long level limbs high up, more on one
## side, and the longest cones of any pine hanging from their tips.
func sugar_pine(v: int) -> Image:
	var w := 64
	var h := 160
	var im := K.make(w, h)
	var sd := 3600 + v * 19
	var cx := w / 2.0 + (3.0 if v == 0 else -3.0)
	var base := h - 4
	var bark := F.ramp(F.BARK_PINE)
	var needles := F.ramp(SUGAR_NEEDLE)
	K.shadow(im, cx + 3.0, base + 0.5, 14.0, 3.2, 0.27)
	F.trunk(im, cx, base, 6, 9.0, 2.2, bark, sd, 0.6, 0.0, 8, 4.0)
	var tufts: Array[Vector3] = []
	var cones := []
	for k in 9:
		var y := 14.0 + k * 9.0
		var side := (-1.0 if k % 2 == 0 else 1.0) * (1.0 if v == 0 else -1.0)
		# the limbs reach farther on the sunny side and near the top
		var length := 9.0 + k * 1.6 + (8.0 if side < 0.0 else 0.0) * (1.0 if k < 5 else 0.4)
		var sx := F.trunk_x(cx, int(y), base, 6, sd, 0.6, 0.0)
		var tip := Vector2(sx + side * length, y - 2.0 + K.hash2(k, 1, sd) * 3.0)
		F.limb(im, sx, y, tip.x, tip.y, 3.0, 1.2, bark, sd + k * 5, -1.0)
		for s in 3:
			var t := 0.45 + s * 0.27
			if K.hash2(k, s, sd + 9) < 0.15:
				continue
			tufts.append(Vector3(lerpf(sx, tip.x, t) + (K.hash2(k, s, sd + 4) - 0.5) * 3.0, lerpf(y, tip.y, t) - 1.5 - K.hash2(k, s, sd + 5) * 3.0, 5.0 + s * 0.9 + K.hash2(k, s, sd) * 2.0))
		if k < 5:
			cones.append(tip)
	tufts.append(Vector3(cx, 7.0, 4.5))
	tufts.sort_custom(func(a: Vector3, b: Vector3) -> bool: return a.y < b.y)
	for i in tufts.size():
		var tf := tufts[i]
		F.tuft(im, tf.x, tf.y, tf.z, needles, sd + i * 3, -0.06 * tf.y / 90.0)
	for p: Vector2 in cones:
		var x := int(p.x)
		var y := int(p.y) + 3
		K.vline(im, x, y, 8, Color("8a643a"))
		K.vline(im, x + 1, y + 1, 6, Color("5a3e24"))
		K.px(im, x, y, Color("b88e58"))
	# a few dead stubs on the long bare trunk below the crown
	for i in 3:
		var y := 100 + i * 14
		var sx := F.trunk_x(cx, y, base, 6, sd, 0.6, 0.0)
		F.limb(im, sx, y, sx + (4.0 if i % 2 == 0 else -4.0), y - 2.0, 1.8, 1.0, bark, sd + 300 + i, 0.0)
	F.rim(im, 0.5)
	return im


## The crown of a mature giant sequoia: big limbs reaching out and up from
## high on the trunk, each holding rounded clumps of blue-green foliage, with
## gaps where the trunk shows through.
static func sequoia_crown(im: Image, cx: float, top: float, bottom: float, rx: float, sd: int, trunk_top_w: float, broken_top := false) -> void:
	var leaf := F.ramp(SEQUOIA_LEAF)
	var bark := F.ramp(BARK_SEQUOIA)
	var rng := RandomNumberGenerator.new()
	rng.seed = sd
	var clumps: Array[Vector3] = []
	var n_limbs := 7
	for k in n_limbs:
		var t := float(k) / (n_limbs - 1)
		var y := lerpf(bottom - 4.0, top + 14.0, t)
		var side := -1.0 if k % 2 == 0 else 1.0
		var reach := rx * (0.55 + 0.45 * sin(PI * (0.25 + t * 0.6))) * (0.8 + rng.randf() * 0.3)
		var end := Vector2(cx + side * reach, y - 6.0 - rng.randf() * 6.0)
		F.limb(im, cx + side * trunk_top_w * 0.3, y, end.x, end.y, lerpf(5.0, 2.8, t), 1.6, bark, sd + k * 17, 3.0)
		for c in 5:
			var p := Vector2(cx, y).lerp(end, 0.3 + c * 0.17)
			clumps.append(Vector3(p.x + rng.randf_range(-3.0, 3.0), p.y - 2.0 - rng.randf() * 5.0, rng.randf_range(6.5, 10.5) * (1.0 - t * 0.2)))
	# filler clumps, so the crown is one lumpy mass with only a few gaps
	for c in 14:
		var t := rng.randf()
		var y := lerpf(bottom - 8.0, top + 10.0, t)
		var half := rx * (0.35 + 0.4 * sin(PI * (0.2 + t * 0.7)))
		clumps.append(Vector3(cx + rng.randf_range(-half, half), y, rng.randf_range(6.0, 9.0)))
	# a rounded top
	for c in 4:
		clumps.append(Vector3(cx + rng.randf_range(-rx * 0.3, rx * 0.3), top + 6.0 + rng.randf() * 10.0, rng.randf_range(6.0, 8.0)))
	clumps.sort_custom(func(a: Vector3, b: Vector3) -> bool: return a.y < b.y)
	for i in clumps.size():
		var cl := clumps[i]
		var g := ((cx - cl.x) * 0.5 + (top - cl.y) * 0.3) / rx
		F.blob_orig(im, cl.x, cl.y, cl.z, cl.z * 0.78, leaf, sd + 9 * i, clampf(g, -0.3, 0.2) - 0.26, 0.2, 0.22)
		F.leaf_specks(im, cl.x, cl.y, cl.z, cl.z * 0.78, leaf, sd + i * 5, 8)
	if broken_top:
		# the dead, broken spike of the old top above the living crown
		var silver := F.ramp(SILVER)
		F.limb(im, cx, top + 14.0, cx - 3.0, top - 6.0, 5.0, 1.4, silver, sd + 900, 1.0)
		F.limb(im, cx - 2.0, top + 2.0, cx + 6.0, top - 4.0, 2.0, 0.8, silver, sd + 901, 0.5)


## A blackened fire scar up one side of the base, from fires the bark survived.
static func fire_scar(im: Image, cx: float, base: int, half: float, side: float, height: int, sd: int) -> void:
	var char_r := F.ramp(CHAR)
	for y in range(base - height, base + 1):
		var t := float(base - y) / height
		var width := half * 0.7 * sqrt(1.0 - t)
		var x0 := cx + side * half * 0.35 - width * 0.5
		for x in range(floori(x0), ceili(x0 + width)):
			if im.get_pixel(clampi(x, 0, im.get_width() - 1), y).a < 0.5:
				continue
			var n := K.hash2(x, y / 2, sd)
			K.px(im, x, y, char_r[clampi(int(n * 3.0 + (1.0 - t) * 0.6), 0, 3)])


## A mature giant sequoia: a massive, fluted cinnamon trunk with a buttressed
## foot, bare of limbs for a long way up, under a rounded crown.
func sequoia_giant(v: int) -> Image:
	var w := [104, 92, 80][v] as int
	var h := [214, 196, 176][v] as int
	var bw := [30.0, 26.0, 22.0][v] as float
	var im := K.make(w, h)
	var sd := 3800 + v * 31
	var cx := w / 2.0
	var base := h - 4
	var top := 4
	var crown_bottom := int(h * 0.48)
	var bark := F.ramp(BARK_SEQUOIA)
	K.shadow(im, cx + 6.0, base + 0.5, bw * 1.1, 5.0, 0.32)
	F.trunk(im, cx, base, top + 18, bw, bw * 0.36, bark, sd, 0.4, 0.0, 9, bw * 0.4, true)
	if v != 1:
		fire_scar(im, cx, base - 1, bw * 0.5, -1.0 if v == 0 else 1.0, int(bw * 1.1), sd)
	sequoia_crown(im, cx, top, crown_bottom, w * 0.34, sd, bw * 0.36)
	F.rim(im, 0.5)
	return im


## The Grizzly Giant: the grove's oldest tree, about 2,000 years old. Its
## trunk leans, its top is long dead and broken, and one huge limb, thicker
## than most trees, juts out and up from its side.
func grizzly_giant() -> Image:
	var w := 136
	var h := 230
	var im := K.make(w, h)
	var sd := 1857
	var cx := 62.0
	var base := h - 4
	var top := 14
	var bark := F.ramp(BARK_SEQUOIA)
	K.shadow(im, cx + 8.0, base + 0.5, 42.0, 6.0, 0.34)
	F.trunk(im, cx, base, top + 20, 38.0, 13.0, bark, sd, 0.6, 5.0, 10, 16.0, true)
	fire_scar(im, cx, base - 1, 19.0, -1.0, 44, sd)
	fire_scar(im, cx + 6.0, base - 1, 14.0, 1.0, 26, sd + 1)
	# the great limb, out to the right two-thirds of the way up
	var lx := F.trunk_x(cx, 96, base, top + 20, sd, 0.6, 5.0)
	F.limb(im, lx + 4.0, 98.0, lx + 44.0, 58.0, 11.0, 5.0, bark, sd + 7, 4.0)
	F.limb(im, lx + 44.0, 58.0, lx + 52.0, 36.0, 5.0, 2.4, bark, sd + 8, 1.0)
	var leaf := F.ramp(SEQUOIA_LEAF)
	for i in 6:
		var p := Vector2(lx + 30.0 + i * 4.0, 66.0 - i * 6.0)
		F.blob_orig(im, p.x + (K.hash2(i, 1, sd) - 0.5) * 8.0, p.y, 8.0, 6.0, leaf, sd + 40 + i, -0.2 + i * 0.04, 0.2, 0.22)
	var tx := F.trunk_x(cx, top + 20, base, top + 20, sd, 0.6, 5.0)
	sequoia_crown(im, tx, top + 6, 120.0, 44.0, sd + 3, 13.0, true)
	F.rim(im, 0.5)
	return im


## The California Tunnel Tree: a living sequoia with a tunnel cut through its
## foot in 1895 for the stages. You can walk through it.
func tunnel_tree() -> Image:
	var w := 100
	var h := 200
	var im := K.make(w, h)
	var sd := 1895
	var cx := w / 2.0
	var base := h - 4
	var bark := F.ramp(BARK_SEQUOIA)
	K.shadow(im, cx + 6.0, base + 0.5, 36.0, 5.0, 0.32)
	F.trunk(im, cx, base, 22, 34.0, 11.0, bark, sd, 0.4, -2.0, 9, 12.0, true)
	sequoia_crown(im, F.trunk_x(cx, 22, base, 22, sd, 0.4, -2.0), 6, 96.0, 34.0, sd + 5, 11.0)
	# the tunnel: an arch 18 px wide and 22 tall, dark inside, the daylight
	# at the far end, and the pale cut wood round its edge
	var tw := 18.0
	var th := 22.0
	for y in range(int(base - th), base + 1):
		for x in range(int(cx - tw / 2.0 - 1.0), int(cx + tw / 2.0 + 2.0)):
			var dx := (x + 0.5 - cx) / (tw / 2.0)
			var up := float(base - y) / th
			var inside := up < 0.6 or dx * dx + pow((up - 0.6) / 0.4, 2.0) < 1.0
			inside = inside and absf(dx) < 1.0
			var edge := absf(dx) < 1.18 and (up < 0.62 or dx * dx + pow((up - 0.6) / 0.46, 2.0) < 1.0)
			if inside:
				var far := absf(dx) < 0.42 and up < 0.5
				var col := Color("1a1210").lerp(Color("2e2018"), 1.0 - up)
				if far:
					col = Color("8a9a5a") if up < 0.18 else Color("c8d8c0")
				K.px(im, x, y, col)
			elif edge:
				K.px(im, x, y, Color("d8a878") if dx < 0.0 else Color("a87048"))
	F.rim(im, 0.5)
	return im


## The Fallen Monarch: a sequoia that fell centuries ago and hardly rotted,
## its root plate standing on end and its trunk lying straight along the
## ground. (In an 1899 photograph a troop of cavalry stands on top of it.)
func fallen_monarch() -> Image:
	var w := 150
	var h := 52
	var im := K.make(w, h)
	var sd := 1899
	var bark := F.ramp(BARK_SEQUOIA)
	K.shadow(im, w / 2.0 + 4.0, h - 5.0, w / 2.0 - 6.0, 4.0, 0.32)
	# the trunk, thick at the root end (left), lying left to right
	for x in range(16, w - 2):
		var u := float(x - 16) / (w - 18)
		var half := lerpf(14.0, 7.0, u)
		var cy := h - 6.0 - half
		for y in range(int(cy - half), int(cy + half) + 1):
			var v := (y - (cy - half)) / (half * 2.0)
			var t := 0.85 - v * 0.75 + (K.hash2(x / 4, y, sd) - 0.5) * 0.18
			if (y + x / 9) % 3 == 0:
				t -= 0.14
			K.px(im, x, y, F.shade(bark, t, x, y))
	# the broken top end, pale and splintered
	for y in range(h - 20, h - 5):
		K.px(im, w - 3, y, Color("c89870"))
		if K.hash2(y, 1, sd) < 0.5:
			K.px(im, w - 2, y, Color("a87850"))
	# the root plate on end: a dark disc of roots and earth
	var soil := F.ramp(["241812", "3a281c", "524030", "6a5642", "84705a"])
	for y in range(2, h - 3):
		for x in range(0, 30):
			var dx := (x + 0.5 - 17.0) / 15.0
			var dy := (y + 0.5 - 26.0) / 23.0
			var d := dx * dx + dy * dy
			if d > 1.0 + (K.hash2(x / 2, y / 2, sd) - 0.5) * 0.4:
				continue
			var t := 0.7 - dx * 0.3 - dy * 0.4 + (K.hash2(x, y, sd + 3) - 0.5) * 0.4
			var col := F.shade(soil, t, x, y)
			if K.hash2(x, y, sd + 5) < 0.08:
				col = Color("9a8a72")
			K.px(im, x, y, col)
	# roots curling out of the plate
	for i in 7:
		var a := float(i) / 7.0 * TAU
		var p := Vector2(17.0, 26.0) + Vector2(cos(a) * 15.0, sin(a) * 22.0)
		F.limb(im, p.x, p.y, p.x + cos(a) * 5.0, p.y + sin(a) * 5.0, 2.0, 0.8, soil, sd + i, 1.0)
	F.rim(im, 0.5)
	return im
