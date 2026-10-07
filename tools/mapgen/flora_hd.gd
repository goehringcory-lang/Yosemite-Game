extends RefCounted
## Ahwahnee-style art for the generated hubs' flora atlas (assets/sprites/
## flora.png): the same 8x4 grid of 32x48 frames and the same ground line
## (the trunk base sits at (16, 44)) as tools/mapgen/art.gd, so the TileSet,
## collision shapes and map scenes need no change. Trees, shrubs and boulders
## are drawn with the shared ramp-shaded, dithered, rimmed helpers from
## tools/hubs/ahwahnee_flora_art.gd; the buildings use the pixel kit's
## shingles, siding and stone.
##
## Called from Art.paint_flora(). Light comes from the upper left.

const Terrain = preload("res://tools/mapgen/terrain.gd")
const FA = preload("res://tools/hubs/ahwahnee_flora_art.gd")
const K = preload("res://tools/hubs/pixel_kit.gd")
const W := 32
const H := 48
const BASE := 44

const BARK_SEQUOIA := ["3a1810", "5a2a1a", "7c3c24", "9c5232", "b86c40", "d08a56"]
const BARK_LODGEPOLE := ["3a2c22", "58463a", "76604e", "947c64", "b09a80"]
const BARK_MANZANITA := ["4a1a14", "6e2a1c", "913d28", "b25636", "cf7448"]
const GRAY_PINE_NEEDLE := ["38503f", "4c6a50", "658565", "82a07c", "a4bd96", "c4d6b4"]
const WHITEBARK_LEAF := ["24402f", "325a3d", "447650", "5c936a", "7ab084"]
const HEMLOCK_LEAF := ["1a3a30", "26503c", "34684a", "468258", "5c9c68", "7ab880"]
const LIVE_OAK_LEAF := ["20382a", "2c4a30", "3c6238", "507c40", "689a4c", "86b85c"]
const SHRUB_LEAF := ["24442e", "326038", "487c42", "62984e", "84b460", "a8d078"]
const CHAPARRAL_LEAF := ["3a5440", "4e7050", "688c62", "86a678", "a6c298"]
const WILLOW_RAMP := ["2f5238", "417146", "5b8f4f", "7aab5a", "9cc56d", "bfdc8b"]
const CANOPY_GRAY := ["76787a", "929496", "aeb0b2", "cbcdcf", "e4e6e8", "f8f9fa"]
## Window glass by day: a cool sky reflection, so nothing looks lit at noon.
## The lit windows are in a second atlas (paint_glow) that fades in after dusk.
const GLASS := "56707f"

## Window rectangles of each building frame, filled in as the frames are drawn.
var windows := {}
var _frame_id := -1


static func ramp(a: Array) -> Array[Color]:
	return FA.ramp(a)


func paint() -> Image:
	var cols := Terrain.FLORA_COLUMNS
	var rows := ceili(float(Terrain.Flora.COUNT) / cols)
	var atlas := K.make(W * cols, H * rows)
	for f in Terrain.Flora.COUNT:
		var frame := _frame(f)
		var at := Terrain.frame_coords(f)
		atlas.blit_rect(frame, Rect2i(0, 0, W, H), Vector2i(at.x * W, at.y * H))
	return atlas


## The lit windows of the building frames, in the layout of the flora atlas
## (assets/sprites/flora_glow.png): a warm pane with a soft halo round it.
func paint_glow() -> Image:
	var cols := Terrain.FLORA_COLUMNS
	var rows := ceili(float(Terrain.Flora.COUNT) / cols)
	var atlas := K.make(W * cols, H * rows)
	for f in range(Terrain.Flora.TENT_CABIN, Terrain.Flora.CAMP_TENT):
		_frame(f)
		var at := Terrain.frame_coords(f)
		for r: Rect2i in windows.get(f, []):
			var o := Vector2i(at.x * W, at.y * H)
			for ring in range(3, 0, -1):
				var a := 0.10 if ring == 3 else (0.16 if ring == 2 else 0.24)
				for yy in range(r.position.y - ring, r.end.y + ring):
					for xx in range(r.position.x - ring, r.end.x + ring):
						if not r.has_point(Vector2i(xx, yy)):
							K.px(atlas, o.x + xx, o.y + yy, Color(1.0, 0.72, 0.3, a))
			for yy in range(r.position.y, r.end.y):
				for xx in range(r.position.x, r.end.x):
					var t := float(yy - r.position.y) / maxi(1, r.size.y - 1)
					K.px(atlas, o.x + xx, o.y + yy, Color(1.0, 0.8 - t * 0.12, 0.38, 0.62 - t * 0.2))
	return atlas


## A window with dark day glass (see GLASS), noted for the glow atlas.
func _win(im: Image, x: int, y: int, w: int, h: int, frame: Color, curtain := Color(0, 0, 0, 0), shutter := Color(0, 0, 0, 0)) -> void:
	K.window(im, x, y, w, h, frame, c_hex(GLASS), curtain, shutter, false)
	if not windows.has(_frame_id):
		windows[_frame_id] = []
	windows[_frame_id].append(Rect2i(x, y, w, h))


func _frame(f: int) -> Image:
	var F := Terrain.Flora
	_frame_id = f
	windows[f] = []
	var im := K.make(W, H)
	var s := 4000 + f * 37
	match f:
		F.PONDEROSA:
			_pine(im, s, 10, 28, ramp(FA.PINE_NEEDLE), ramp(FA.BARK_PINE), 5)
		F.SUGAR_PINE:
			_pine(im, s, 6, 24, ramp(FA.PINE_NEEDLE), ramp(["2a1a14", "44322a", "5c4636", "76604a", "927a60"]), 4, true)
		F.JEFFREY_PINE:
			_pine(im, s, 9, 28, ramp(["1c3a34", "28503f", "386a4c", "4c8458", "66a066", "88bc7a"]), ramp(["3a1e16", "5a3220", "7a4a2c", "98643a", "b8804c"]), 5)
		F.GRAY_PINE:
			_gray_pine(im, s)
		F.INCENSE_CEDAR:
			_conifer(im, s, 3, 40, 8.5, 5.0, ramp(FA.CEDAR_LEAF), ramp(FA.BARK_CEDAR), 1.7)
		F.WHITE_FIR:
			_conifer(im, s, 3, 40, 10.5, 5.0, ramp(FA.FIR_LEAF), ramp(FA.BARK_FIR), 1.5)
		F.RED_FIR:
			_conifer(im, s, 1, 40, 11.5, 4.4, ramp(["12303a", "1c4440", "285a4a", "387458", "4c8e68", "6aaa80"]), ramp(["3a1a14", "5a2a20", "7a4030", "9a5a40"]), 1.3)
		F.HEMLOCK:
			_conifer(im, s, 2, 40, 9.0, 4.0, ramp(HEMLOCK_LEAF), ramp(FA.BARK_FIR), 1.2, true)
		F.LODGEPOLE:
			_lodgepole(im, s)
		F.BLACK_OAK_TRUNK:
			_trunk_only(im, s, ramp(FA.BARK_OAK), 20, 7.0, true)
		F.LIVE_OAK:
			_broadleaf(im, s, ramp(LIVE_OAK_LEAF), ramp(FA.BARK_OAK), 13.5, 18.0, 1.0)
		F.WHITEBARK:
			_broadleaf(im, s, ramp(WHITEBARK_LEAF), ramp(["2e2622", "4a3e36", "685a4e", "867666"]), 11.5, 15.0, 0.8, true)
		F.DOGWOOD:
			_dogwood(im, s)
		F.SNAG:
			_snag(im, s)
		F.SEQUOIA:
			_sequoia(im, s)
		F.MANZANITA:
			_manzanita(im, s)
		F.SHRUB:
			_shrub(im, s, ramp(SHRUB_LEAF), 12.5)
		F.WILLOW:
			_willow(im, s)
		F.BOULDER:
			_rock(im, s, 24, 18, 0.0)
		F.ERRATIC:
			_rock(im, s, 30, 28, 0.2)
		F.TENT_CABIN:
			_tent_cabin(im, s)
		F.CABIN:
			_cabin(im, s)
		F.HOUSE:
			_house(im, s)
		F.LODGE:
			_lodge(im, s)
		F.WHITE_HOUSE:
			_white_house(im, s)
		F.CAMP_TENT:
			_camp_tent(im, s)
		F.BLACK_OAK_CANOPY:
			_canopy(im, s)
	return im


func _ground_shadow(im: Image, rx: float, ry := 2.4, dx := 2.0) -> void:
	K.shadow(im, W / 2.0 + dx, BASE + 1.0, rx, ry, 0.27)


# ---------------------------------------------------------------- conifers

## A tiered fir, cedar or hemlock: layered fans over a short trunk.
func _conifer(im: Image, s: int, top: int, bottom: int, half_w: float, trunk_w: float, leaf: Array[Color], bark: Array[Color], step: float, droop := false) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = s
	var cx := 16.0
	_ground_shadow(im, half_w * 0.8)
	FA.trunk(im, cx, BASE, bottom - 4, trunk_w, trunk_w * 0.7, bark, s, 0.2, 0.0, 6, 1.6)
	var y := float(top) + 2.0
	var tier := 0
	while y < bottom:
		var t := (y - top) / float(bottom - top)
		var hw := 1.2 + (half_w - 1.2) * pow(t, 0.85)
		var n := maxi(1, int(hw / 3.0))
		for k in n:
			var bx := cx - hw + (float(k) + 0.5) / n * hw * 2.0 + (rng.randf() - 0.5) * 1.0
			var edge := absf(bx - cx) / maxf(hw, 1.0)
			var by := y + edge * edge * (3.0 if droop else 2.0) + rng.randf() * 1.0
			var bias := -(bx - cx) / 14.0 * 0.15 - t * 0.06 - 0.05
			FA.fan(im, bx, by, hw / n + 1.7, 2.3, leaf, s + tier * 7 + k, bias)
		y += step * 2.1 + t * 0.4
		tier += 1
	for i in 4:
		FA.fan(im, cx, float(top) + i * 0.9, 1.0 + i * 0.3, 1.7, leaf, s + 601 + i, 0.1)
	FA.leaf_specks(im, cx - 1.0, (top + bottom) / 2.0, half_w * 0.6, (bottom - top) * 0.45, leaf, s + 31, 12)
	FA.rim(im, 0.52)


## A tall bare trunk with needle tufts out on its branches (ponderosa, sugar
## and Jeffrey pine).
func _pine(im: Image, s: int, top: int, crown_bottom: int, needles: Array[Color], bark: Array[Color], branches: int, sugar := false) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = s
	var cx := 16.0
	_ground_shadow(im, 8.0)
	var lean := rng.randf_range(-0.8, 0.8)
	FA.trunk(im, cx, BASE, top + 4, 4.6, 2.0, bark, s, 0.5, lean, 5, 2.2)
	var tufts: Array[Vector3] = []
	for i in branches:
		var t := float(i) / maxf(1.0, branches - 1.0)
		var y0 := lerpf(float(crown_bottom), float(top + 6), t)
		var side := 1 if i % 2 == 0 else -1
		var length := 3.0 + (y0 - top) * 0.12 + rng.randf() * 2.0
		if sugar:
			length += 4.0
		var sx := FA.trunk_x(cx, int(y0), BASE, top + 4, s, 0.5, lean)
		var tip := Vector2(sx + side * length, y0 - length * 0.25)
		FA.limb(im, sx, y0, tip.x, tip.y, 1.6, 1.0, bark, s + i, 0.5)
		tufts.append(Vector3(tip.x, tip.y - 1.0, 3.6 + rng.randf() * 1.6 + (1.0 if sugar else 0.0)))
	tufts.sort_custom(func(a: Vector3, b: Vector3) -> bool: return a.y < b.y)
	for i in tufts.size():
		FA.tuft(im, tufts[i].x, tufts[i].y, tufts[i].z, needles, s + i * 3, -0.12 - 0.1 * float(i) / branches)
	FA.tuft(im, FA.trunk_x(cx, top + 4, BASE, top + 4, s, 0.5, lean), float(top) + 2.0, 4.2, needles, s + 99, 0.05)
	FA.rim(im, 0.5)


func _gray_pine(im: Image, s: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = s
	_ground_shadow(im, 8.0)
	var bark := ramp(FA.BARK_OAK)
	var needles := ramp(GRAY_PINE_NEEDLE)
	# a leaning, forked trunk
	FA.trunk(im, 16.0, BASE, 26, 4.0, 2.4, bark, s, 0.6, -1.2, 5, 2.0)
	FA.limb(im, 16.0, 29.0, 23.0, 16.0, 2.2, 1.2, bark, s + 1, 1.0)
	FA.limb(im, 15.0, 27.0, 9.0, 14.0, 2.2, 1.2, bark, s + 2, 1.0)
	for tf: Array in [[23.0, 14.0, 5.0], [9.0, 12.0, 5.2], [15.0, 22.0, 5.0], [16.0, 7.0, 4.4], [21.0, 22.0, 3.6], [11.0, 21.0, 3.6]]:
		FA.tuft(im, tf[0], tf[1], tf[2], needles, s + int(tf[0]), 0.0)
	FA.rim(im, 0.5)


func _lodgepole(im: Image, s: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = s
	_ground_shadow(im, 5.5, 2.0)
	var bark := ramp(BARK_LODGEPOLE)
	var needles := ramp(["1e3e2a", "2a5430", "3a6c38", "508442", "6c9e4c", "8cb85a"])
	FA.trunk(im, 16.0, BASE, 6, 3.2, 1.4, bark, s, 0.3, 0.0, 6, 1.4)
	var y := 8.0
	var i := 0
	while y < 32.0:
		var side := 1 if i % 2 == 0 else -1
		var arm := 2.0 + (y - 6.0) * 0.11
		FA.tuft(im, 16.0 + side * arm, y, 2.6 + (y - 6.0) * 0.045, needles, s + i, -0.04 * i)
		y += 3.4
		i += 1
	FA.tuft(im, 16.0, 5.0, 3.2, needles, s + 77, 0.05)
	FA.rim(im, 0.5)


# ---------------------------------------------------------------- broadleaf

func _trunk_only(im: Image, s: int, bark: Array[Color], top: int, w_base: float, forked: bool) -> void:
	# The black oak's canopy is a separate (seasonal) layer drawn over this.
	_ground_shadow(im, 9.0)
	FA.trunk(im, 16.0, BASE, top + 4, w_base, 4.6, bark, s, 0.6, 0.0, 6, 2.6)
	if forked:
		FA.limb(im, 16.0, top + 8.0, 10.0, top - 2.0, 3.0, 1.6, bark, s + 1, 0.8)
		FA.limb(im, 16.0, top + 8.0, 23.0, top - 3.0, 3.0, 1.6, bark, s + 2, 0.8)
		FA.limb(im, 16.0, top + 10.0, 16.0, top - 6.0, 2.8, 1.4, bark, s + 3, 0.5)
	FA.rim(im, 0.5)


func _broadleaf(im: Image, s: int, leaf: Array[Color], bark: Array[Color], rx: float, cy: float, lift: float, light := false) -> void:
	_ground_shadow(im, rx * 0.8)
	FA.trunk(im, 16.0, BASE, int(cy + 6.0), 4.8, 3.4, bark, s, 0.5, 0.0, 6, 2.2)
	var clumps := [[0.0, 0.0, 1.0, 0.8], [-0.55, 0.28, 0.6, 0.55], [0.55, 0.3, 0.6, 0.55], [-0.28, -0.42, 0.55, 0.5], [0.3, -0.38, 0.55, 0.5]]
	for i in clumps.size():
		var cl: Array = clumps[i]
		var g := -float(cl[1]) * 0.25 - float(cl[0]) * 0.1
		FA.blob(im, 16.0 + cl[0] * rx * 0.6, cy + cl[1] * 8.0 * lift, rx * cl[2] * 0.62, 6.0 + 4.0 * float(cl[3]) * lift, leaf, s + i * 5, g, 0.16, 0.2)
		FA.leaf_specks(im, 16.0 + cl[0] * rx * 0.6, cy + cl[1] * 8.0, rx * 0.5, 6.0, leaf, s + i, 4)
	FA.rim(im, 0.5)


func _dogwood(im: Image, s: int) -> void:
	_ground_shadow(im, 6.0)
	FA.trunk(im, 16.0, BASE, 30, 3.2, 2.2, ramp(["3a2c28", "54443c", "725e50", "927c68"]), s, 0.4, 0.0, 6, 1.6)
	var leaf := ramp(["24462e", "33603a", "487c44", "649a50", "86b862"])
	for cl: Array in [[16.0, 27.0, 7.5, 5.0], [10.0, 31.0, 5.0, 3.8], [22.0, 31.0, 5.0, 3.8], [14.0, 24.0, 4.5, 3.5]]:
		FA.blob(im, cl[0], cl[1], cl[2], cl[3], leaf, s + int(cl[0]), 0.0, 0.16, 0.2)
	for i in 14:
		var a := K.hash2(i, 1, s) * TAU
		var d := sqrt(K.hash2(i, 2, s)) * 0.9
		var fx := int(16.0 + cos(a) * d * 9.0)
		var fy := int(27.0 + sin(a) * d * 5.5)
		K.px(im, fx, fy, c_hex("fbf6ec"))
		K.px(im, fx + 1, fy, c_hex("e2d8d0"))
		K.px(im, fx, fy + 1, c_hex("d8c4d0"))
	FA.rim(im, 0.5)


func c_hex(h: String) -> Color:
	return Color(h)


func _snag(im: Image, s: int) -> void:
	_ground_shadow(im, 4.5, 1.8)
	var bark := ramp(FA.BARK_DEAD)
	FA.trunk(im, 16.0, BASE, 6, 3.6, 1.6, bark, s, 0.3, 0.4, 6, 1.6)
	for st: Array in [[34.0, -1, 6.0], [26.0, 1, 7.0], [18.0, -1, 5.0], [11.0, 1, 4.0]]:
		var sx := FA.trunk_x(16.0, int(st[0]), BASE, 6, s, 0.3, 0.4)
		FA.limb(im, sx, st[0], sx + st[1] * st[2], st[0] - 4.0, 1.8, 0.8, bark, s + int(st[0]), 0.5)
	FA.rim(im, 0.5)


func _sequoia(im: Image, s: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = s
	_ground_shadow(im, 11.0, 2.8)
	var bark := ramp(BARK_SEQUOIA)
	FA.trunk(im, 16.0, BASE, 10, 11.0, 7.0, bark, s, 0.2, 0.0, 9, 4.0, true)
	var needles := ramp(["1c3a2a", "28502f", "386a3a", "4c8444", "689e52", "88b862"])
	for cl: Array in [[16.0, 6.0, 7.5, 5.0], [9.0, 11.0, 5.0, 3.6], [23.0, 11.0, 5.0, 3.6], [16.0, 15.0, 6.0, 3.4], [12.0, 3.0, 4.5, 3.0], [20.0, 4.0, 4.5, 3.0]]:
		FA.blob(im, cl[0], cl[1], cl[2], cl[3], needles, s + int(cl[0] * 3.0), -0.04, 0.17, 0.2)
	FA.rim(im, 0.52)


# ---------------------------------------------------------------- shrubs, rocks

func _shrub(im: Image, s: int, leaf: Array[Color], rx: float) -> void:
	K.shadow(im, 17.0, BASE + 0.0, rx * 0.8, 2.4, 0.25)
	for cl: Array in [[16.0, 38.0, 7.0, 5.5], [10.0, 40.0, 5.0, 4.0], [22.0, 40.0, 5.0, 4.0], [14.0, 35.0, 4.6, 3.6], [19.0, 36.0, 4.2, 3.4]]:
		var g: float = (16.0 - cl[0]) * 0.014 + (38.0 - cl[1]) * 0.03
		FA.blob(im, cl[0], cl[1], cl[2], cl[3], leaf, s + int(cl[0]), clampf(g, -0.2, 0.22) - 0.04, 0.17, 0.2)
		FA.leaf_specks(im, cl[0], cl[1], cl[2], cl[3], leaf, s + int(cl[1]), 3)
	FA.rim(im, 0.5)


func _manzanita(im: Image, s: int) -> void:
	K.shadow(im, 17.0, BASE, 9.0, 2.4, 0.25)
	var bark := ramp(BARK_MANZANITA)
	for st: Array in [[11.0, 37.0, 7.0], [16.0, 36.0, 4.0], [21.0, 37.0, 25.0]]:
		FA.limb(im, 16.0, BASE, st[0] + (st[0] - 16.0) * 0.2, st[1], 1.8, 1.0, bark, s + int(st[0]), 0.8)
	var leaf := ramp(CHAPARRAL_LEAF)
	for cl: Array in [[16.0, 33.0, 7.5, 4.6], [9.0, 36.0, 5.0, 3.6], [23.0, 36.0, 5.0, 3.6], [13.0, 30.0, 4.5, 3.2], [20.0, 31.0, 4.0, 3.0]]:
		FA.blob(im, cl[0], cl[1], cl[2], cl[3], leaf, s + int(cl[0]), 0.0, 0.17, 0.2)
	for i in 5:
		K.px(im, 11 + i * 3, 31 + (i % 2) * 3, c_hex("d9604a"))
	FA.rim(im, 0.5)


func _willow(im: Image, s: int) -> void:
	K.shadow(im, 17.0, BASE, 9.0, 2.4, 0.25)
	var leaf := ramp(WILLOW_RAMP)
	for sx in [12.0, 16.0, 20.0]:
		FA.limb(im, sx, BASE, sx + (sx - 16.0) * 0.4, 32.0, 1.6, 1.0, ramp(["3a2e22", "5a4a38", "7a6850"]), s + int(sx), 0.5)
	for cl: Array in [[16.0, 27.0, 9.0, 5.0], [9.0, 31.0, 5.0, 4.5], [23.0, 31.0, 5.0, 4.5], [16.0, 33.0, 8.0, 4.0]]:
		FA.blob(im, cl[0], cl[1], cl[2], cl[3], leaf, s + int(cl[0]), 0.0, 0.16, 0.2)
	# drooping wands
	for i in 12:
		var wx := 6 + i * 2
		var wl := 5 + int(K.hash2(i, 1, s) * 5.0)
		for k in wl:
			K.px(im, wx, 31 + k, leaf[2 + (k + i) % 3])
	FA.rim(im, 0.5)


func _rock(im: Image, s: int, rw: int, rh: int, moss: float) -> void:
	var rock: Image = FA.new().rock(rw, rh, s, moss, 0.5)
	# rock() puts its ground line 4 px above the bottom; match BASE
	K.stamp(im, rock, (W - rw) / 2, BASE + 4 - rh)


# ---------------------------------------------------------------- buildings

func _roof_peaked(im: Image, x: int, y: int, w: int, h: int, base: Color, s: int, cap := true) -> void:
	## A front-gable roof: shingle courses narrowing to the ridge.
	K.shingles(im, x, y, w, h, base, s, 0.5 * float(w) / maxf(1.0, 2.0 * h))
	if cap:
		K.hline(im, x + w / 2 - 1, y, 2, base.lightened(0.4))


func _tent_cabin(im: Image, s: int) -> void:
	var x0 := 8
	K.shadow(im, 17.0, BASE + 1.0, 10.0, 2.4, 0.27)
	# plank deck
	K.boards(im, x0 - 1, 41, 18, 4, c_hex("9a7a50"), s, 3)
	K.hline(im, x0 - 1, 41, 18, c_hex("c4a272"))
	# canvas walls and roof
	K.rect(im, x0, 31, 16, 10, c_hex("e8e0cc"))
	for y in range(31, 41):
		K.hline(im, x0, y, 16, c_hex("e8e0cc").lerp(c_hex("c9bfa6"), float(y - 31) / 10.0 * 0.5))
	K.vline(im, x0 + 15, 31, 10, c_hex("b4aa90"))
	K.vline(im, x0, 31, 10, c_hex("f4eedc"))
	for r in 9:
		var inset := 8 - r
		K.hline(im, x0 - 1 + (8 - r) / 2 * 0 + (8 - r), 22 + r, 18 - (8 - r) * 2, c_hex("f0ead8").lerp(c_hex("cfc5aa"), float(r) / 9.0))
	K.hline(im, x0 + 7, 21, 2, c_hex("fffaf0"))
	# door flap and window
	K.rect(im, x0 + 5, 33, 6, 8, c_hex("6a5036"))
	K.rect(im, x0 + 6, 34, 4, 7, c_hex("2f2418"))
	K.rect(im, x0 + 5, 33, 6, 1, c_hex("8a6c48"))
	# guy ropes and an unlit lantern
	K.px(im, x0 + 11, 36, c_hex("8a7a5a"))
	K.hline(im, x0 - 2, 40, 2, c_hex("7a6446"))
	K.hline(im, x0 + 16, 40, 2, c_hex("7a6446"))
	FA.rim(im, 0.5)


func _cabin(im: Image, s: int) -> void:
	var x0 := 8
	K.shadow(im, 17.0, BASE + 1.0, 10.0, 2.4, 0.27)
	K.stones(im, x0, 41, 16, 4, c_hex("857b6c"), s)
	K.boards(im, x0, 31, 16, 10, c_hex("7c5638"), s + 1, 4)
	_roof_peaked(im, x0 - 2, 22, 20, 10, c_hex("6a4a32"), s + 2)
	K.hline(im, x0 - 2, 31, 20, c_hex("3a281c"))
	K.door(im, x0 + 6, 35, 4, 6, c_hex("5a3c26"), c_hex("2e2018"))
	_win(im, x0 + 1, 34, 3, 3, c_hex("3a2a20"))
	_win(im, x0 + 12, 34, 3, 3, c_hex("3a2a20"))
	# stovepipe
	K.rect(im, x0 + 11, 17, 2, 7, c_hex("4a4a50"))
	K.px(im, x0 + 11, 17, c_hex("7a7a82"))
	FA.rim(im, 0.5)


func _house(im: Image, s: int) -> void:
	var x0 := 7
	K.shadow(im, 17.0, BASE + 1.0, 11.0, 2.4, 0.27)
	K.stones(im, x0, 41, 18, 4, c_hex("8a8478"), s)
	K.lap(im, x0, 31, 18, 10, c_hex("b8a888"), s + 1)
	_roof_peaked(im, x0 - 2, 21, 22, 11, c_hex("4a6a48"), s + 2)
	K.hline(im, x0 - 2, 31, 22, c_hex("243a28"))
	K.door(im, x0 + 7, 35, 4, 6, c_hex("5a3c26"), c_hex("3a2a20"))
	_win(im, x0 + 1, 34, 3, 3, c_hex("e8e0d0"), c_hex("d9c9a0"))
	_win(im, x0 + 14, 34, 3, 3, c_hex("e8e0d0"), c_hex("d9c9a0"))
	K.rect(im, x0 + 13, 17, 3, 7, c_hex("8a5a48"))
	K.hline(im, x0 + 13, 17, 3, c_hex("b07a62"))
	FA.rim(im, 0.5)


func _lodge(im: Image, s: int) -> void:
	var x0 := 5
	K.shadow(im, 17.0, BASE + 1.0, 13.0, 2.6, 0.27)
	K.stones(im, x0, 36, 22, 9, c_hex("8c8678"), s)
	K.boards(im, x0, 30, 22, 7, c_hex("6a4630"), s + 1, 4)
	_roof_peaked(im, x0 - 3, 17, 28, 14, c_hex("5a3e2a"), s + 2)
	K.hline(im, x0 - 3, 30, 28, c_hex("2a1c14"))
	K.door(im, x0 + 9, 37, 4, 7, c_hex("4a3020"), c_hex("2e2018"))
	for wx in [x0 + 2, x0 + 16]:
		_win(im, wx, 38, 3, 4, c_hex("3a2a20"))
	K.rect(im, x0 + 17, 11, 4, 10, c_hex("807a6e"))
	K.hline(im, x0 + 17, 11, 4, c_hex("b0a898"))
	FA.rim(im, 0.5)


func _white_house(im: Image, s: int) -> void:
	var x0 := 6
	K.shadow(im, 17.0, BASE + 1.0, 12.0, 2.4, 0.27)
	K.rect(im, x0, 41, 20, 4, c_hex("9a948a"))
	K.lap(im, x0, 31, 20, 10, c_hex("ece8dc"), s + 1)
	_roof_peaked(im, x0 - 2, 21, 24, 11, c_hex("3f5a44"), s + 2)
	K.hline(im, x0 - 2, 31, 24, c_hex("1e3224"))
	K.door(im, x0 + 8, 35, 4, 6, c_hex("3a5a48"), c_hex("f4f0e4"))
	for wx in [x0 + 1, x0 + 15]:
		_win(im, wx, 34, 3, 3, c_hex("f4f0e4"), Color(0, 0, 0, 0), c_hex("3f5a44"))
	K.rect(im, x0 + 15, 17, 3, 7, c_hex("a86a50"))
	K.hline(im, x0 + 15, 17, 3, c_hex("c88a6c"))
	FA.rim(im, 0.5)


func _camp_tent(im: Image, s: int) -> void:
	K.shadow(im, 17.0, BASE + 1.0, 8.0, 2.0, 0.27)
	var a := ramp(["7a3a14", "a85a1e", "d2802c", "ee9c38", "ffbc58"])
	for y in range(34, 45):
		var half := int((y - 33) * 0.78)
		for x in range(16 - half, 16 + half + 1):
			var u := float(x - 16) / maxf(1.0, half)
			var t := 0.72 - u * 0.5 + float(y - 34) / 24.0 * -0.2
			K.px(im, x, y, FA.shade(a, t, x, y))
	K.rect(im, 15, 40, 3, 5, c_hex("26180e"))
	K.px(im, 16, 33, c_hex("3a2616"))
	FA.rim(im, 0.5)


func _canopy(im: Image, s: int) -> void:
	# Light grays; the layer's modulate tints them per season.
	var leaf := ramp(CANOPY_GRAY)
	for i in 6:
		var cl: Array = [[16.0, 17.0, 10.0, 8.0], [8.0, 21.0, 6.5, 5.5], [24.0, 21.0, 6.5, 5.5], [11.0, 11.0, 6.5, 5.5], [21.0, 11.0, 6.5, 5.5], [16.0, 25.0, 8.0, 4.5]][i]
		FA.blob(im, cl[0], cl[1], cl[2], cl[3], leaf, s + i * 7, 0.08, 0.16, 0.2)
		FA.leaf_specks(im, cl[0], cl[1], cl[2], cl[3], leaf, s + i, 6)
	FA.rim(im, 0.6)


# ---------------------------------------------------------------- signs

const POST := ["2a1a12", "44301f", "5f4429", "7c5a36", "9a7444"]


func _post(im: Image, x: int, y0: int, y1: int, w: int, s: int) -> void:
	for y in range(y0, y1 + 1):
		for dx in w:
			var t := 0.82 - float(dx) / maxf(1.0, w - 1.0) * 0.7 + (K.hash2(x + dx, y / 2, s) - 0.5) * 0.25
			K.px(im, x + dx, y, FA.shade(ramp(POST), t, x + dx, y))


func _plank(im: Image, x: int, y: int, w: int, h: int, s: int) -> void:
	var r := ramp(POST)
	K.rect(im, x, y, w, h, r[3])
	K.hline(im, x, y, w, r[4])
	K.hline(im, x, y + h - 1, w, r[1])
	K.vline(im, x + w - 1, y, h, r[2])
	for i in 3:
		K.px(im, x + 1 + int(K.hash2(i, 1, s) * (w - 3)), y + 1 + int(K.hash2(i, 2, s) * (h - 2)), r[2])


func info_sign() -> Image:
	var im := K.make(16, 16)
	K.shadow(im, 8.0, 15.0, 6.0, 1.2, 0.26)
	_post(im, 3, 9, 14, 2, 11)
	_post(im, 11, 9, 14, 2, 12)
	_plank(im, 1, 2, 14, 8, 13)
	# routed face with cream lettering and a green park badge
	K.rect(im, 2, 3, 12, 6, c_hex("2f2218"))
	K.hline(im, 2, 3, 12, c_hex("1a120c"))
	for y in [4, 6]:
		K.hline(im, 3, y, 7 if y == 4 else 5, c_hex("e4d8b8"))
	K.hline(im, 3, 7, 3, c_hex("b8ac90"))
	K.rect(im, 11, 4, 2, 3, c_hex("6c9a48"))
	K.px(im, 11, 4, c_hex("9cc86c"))
	FA.rim(im, 0.5)
	return im


func trailhead() -> Image:
	var im := K.make(16, 24)
	K.shadow(im, 8.0, 23.0, 5.5, 1.2, 0.26)
	_post(im, 7, 3, 22, 3, 21)
	# two arrow planks pointing opposite ways
	var r := ramp(POST)
	for row: Array in [[3, 2, 11, 1], [10, 5, 10, -1]]:
		var y: int = row[0]
		var x: int = row[1]
		var w: int = row[2]
		_plank(im, x, y, w, 5, 30 + y)
		if row[3] > 0:
			for k in 3:
				K.vline(im, x + w + k, y + k, 5 - k * 2, r[3])
				K.px(im, x + w + k, y + k, r[4])
		else:
			for k in 3:
				K.vline(im, x - 1 - k, y + k, 5 - k * 2, r[2])
		K.hline(im, x + 2, y + 2, w - 4, c_hex("e4d8b8"))
	FA.rim(im, 0.5)
	return im


func map_kiosk() -> Image:
	var im := K.make(16, 24)
	K.shadow(im, 8.0, 23.0, 7.0, 1.4, 0.26)
	_post(im, 2, 12, 22, 2, 41)
	_post(im, 12, 12, 22, 2, 42)
	# the notice board: a frame around a little painted map
	var r := ramp(POST)
	K.rect(im, 1, 5, 14, 10, r[2])
	K.hline(im, 1, 5, 14, r[4])
	K.vline(im, 1, 5, 10, r[3])
	K.hline(im, 1, 14, 14, r[0])
	K.rect(im, 3, 6, 10, 8, c_hex("b8c88a"))
	for y in range(6, 14):
		for x in range(3, 13):
			if K.hash2(x, y, 43) > 0.82:
				K.px(im, x, y, c_hex("9db070"))
	K.hline(im, 3, 10, 6, c_hex("5a96c8"))
	K.px(im, 9, 9, c_hex("5a96c8"))
	K.px(im, 10, 8, c_hex("5a96c8"))
	K.vline(im, 6, 6, 8, c_hex("d4b878"))
	K.px(im, 10, 12, c_hex("d8323c"))
	K.px(im, 10, 11, c_hex("f06a6a"))
	# a little shingled roof
	K.shingles(im, 0, 1, 16, 5, c_hex("5a3e2a"), 44, 0.18, 2)
	K.hline(im, 0, 5, 16, c_hex("2a1a10"))
	FA.rim(im, 0.5)
	return im
