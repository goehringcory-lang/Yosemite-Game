extends RefCounted
## Stardew-style art for the generated hubs' flora atlas (assets/sprites/
## flora.png): the same 8x4 grid of 32x48 frames and the same ground line
## (the trunk base sits at (16, 44)) as tools/mapgen/art.gd, so the TileSet,
## collision shapes and map scenes need no change.
##
## Broadleaf trees are overlapping round leaf clumps: a shadow pass offset to
## the lower right, then lit clumps with blue-green pockets between them, a
## broken dark outline and a few sky gaps. Conifers are layered drooping tiers,
## lit on the left and cool on the right. Buildings get shingle courses, lap
## siding, stone foundations, window frames and doors. Every frame gets a soft
## oval contact shadow.
##
## Called from Art.paint_flora(). Light comes from the upper left.

const Terrain = preload("res://tools/mapgen/terrain.gd")
const K = preload("res://tools/hubs/pixel_kit.gd")
const W := 32
const H := 48
const BASE := 44

## Leaf ramps, dark to light (the lit tones; shadow passes are derived from them).
const PONDEROSA_LIT := ["3a5a2c", "4f7436", "6e9046", "8eaa58", "b0c674"]
const SUGAR_LIT := ["2c5044", "3c6a52", "56886a", "76a47c", "9cc08e"]
const JEFFREY_LIT := ["1c3c3a", "245450", "326e5c", "4a8a6c", "6aa67e"]
const GRAY_PINE_LIT := ["3c4e40", "52684f", "6c8560", "8ea074", "b2bc92"]
const CEDAR_LIT := ["2e4a2c", "3e6036", "587a44", "7a9a52", "a2b866"]
const WHITEFIR_LIT := ["263e3c", "385a52", "4e7a64", "6e9a7a", "98bc96"]
const REDFIR_LIT := ["163a3a", "22504a", "34684e", "4e8460", "74a87a"]
const HEMLOCK_LIT := ["1e4236", "2c5e46", "3f7a56", "5e9866", "82b878"]
const LODGEPOLE_LIT := ["1e3e2a", "2d5a34", "44763e", "649650", "8ab466"]
const SEQUOIA_LIT := ["1c3a2a", "2a5634", "3c7040", "5a8e4c", "7eaa62"]
const LIVE_OAK_LIT := ["1f4a44", "2c6450", "4a8048", "76a44c", "a4c664"]
const WHITEBARK_LIT := ["24402f", "3a5c44", "557a5a", "76977a", "9ab59a"]
const DOGWOOD_LIT := ["24483e", "37684a", "558a4e", "7cac5a", "a6cc78"]
const WILLOW_LIT := ["2f5a4a", "43765a", "63945a", "88b262", "b2d07c"]
const SHRUB_LIT := ["1f4a44", "2f6446", "4f8443", "7aa84c", "a8c868"]
const CHAPARRAL_LIT := ["3a5440", "4e7050", "688c62", "86a678", "a6c298"]
const CANOPY_GRAY_LIT := ["6c7478", "8a9294", "a8aeaa", "c6cbc4", "e2e6dc"]
const ORANGE_LIT := ["7a3a14", "a85a1e", "d2802c", "ee9c38", "ffbc58"]

## Bark ramps, dark to light.
const BARK_PONDEROSA := ["3e2418", "5e3220", "7e4628", "a25c32", "c27a44"]
const BARK_SUGAR := ["2a1a14", "44322a", "5c4636", "76604a", "927a60"]
const BARK_SEQUOIA := ["4a1a12", "6a2618", "8c3620", "ad4c2c", "c8683c"]
const BARK_FIR := ["3a3028", "574a3e", "766456", "948270", "b0a088"]
const BARK_RED_FIR := ["2e1a16", "4a2a20", "6a3e2a", "8a5638", "a86e48"]
const BARK_CEDAR := ["3a2a22", "56402f", "745a40", "8e7252", "aa8c68"]
const BARK_OAK := ["2e2a24", "4a4238", "665c4e", "837666", "a09480"]
const BARK_LODGEPOLE := ["3a2c22", "58463a", "76604e", "947c64", "b09a80"]
const BARK_DEAD := ["4a4640", "6a645c", "8a8478", "a8a092", "c4bcaa"]
const BARK_MANZANITA := ["4a1a14", "6e2a1c", "913d28", "b25636", "cf7448"]
const BARK_DOGWOOD := ["3a2c28", "54443c", "725e50", "927c68"]
const BARK_WILLOW := ["3a2e22", "5a4a38", "7a6850"]
const ROCK_LIT := ["3c4048", "535962", "6c737c", "8a9298", "a9b0b2"]
const MOSS := ["3c6a34", "57883f", "76a24e"]
const POST := ["2a1a12", "44301f", "5f4429", "7c5a36", "9a7444"]

## Dark, saturated outlines (never pure black), one per material.
const OUT_LEAF := "1a3426"
const OUT_NEEDLE := "152e24"
const OUT_SEQ := "3a1610"
const OUT_BARK := "2a1c14"
const OUT_GRAY := "3e4448"
const OUT_ROCK := "262a33"

## Window glass by day: a cool sky reflection, so nothing looks lit at noon.
## The lit windows are in a second atlas (paint_glow) that fades in after dusk.
const GLASS := "56707f"

## Window rectangles of each building frame, filled in as the frames are drawn.
var windows := {}
var _frame_id := -1


static func ramp(hexes: Array) -> Array[Color]:
	var out: Array[Color] = []
	for h in hexes:
		out.append(Color(h))
	return out


## A hue-shifted ramp from one base color: shadows toward blue, lights toward
## yellow, with the value spread from dark to light.
static func tones(base: Color, n := 5) -> Array[Color]:
	var out: Array[Color] = []
	for i in n:
		var t := float(i) / (n - 1)
		var hue := fposmod(base.h + lerpf(0.04, -0.03, t), 1.0)
		var sat := clampf(base.s * lerpf(1.05, 0.9, t), 0.0, 1.0)
		var val := clampf(base.v * lerpf(0.5, 1.12, t), 0.0, 1.0)
		out.append(Color.from_hsv(hue, sat, val))
	return out


## The same ramp pushed toward blue-green and darker: the shadow pass.
static func dim(r: Array[Color], k: float) -> Array[Color]:
	var out: Array[Color] = []
	for c in r:
		out.append(Color.from_hsv(fposmod(c.h + 0.03, 1.0), c.s, c.v * k))
	return out


static func _put(im: Image, x: int, y: int, col: Color) -> void:
	if x >= 0 and y >= 0 and x < im.get_width() and y < im.get_height():
		im.set_pixel(x, y, col)


static func _idx(n: int, v: float) -> int:
	return clampi(int(floorf(v * float(n))), 0, n - 1)


static func _opaque(im: Image, x: int, y: int) -> bool:
	return x >= 0 and y >= 0 and x < im.get_width() and y < im.get_height() and im.get_pixel(x, y).a > 0.05


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
	if shutter.a > 0.0:
		K.rect(im, x - 3, y, 2, h, shutter)
		K.rect(im, x + w + 1, y, 2, h, shutter)
	K.rect(im, x - 1, y - 1, w + 2, h + 2, frame)
	var glass := Color(GLASS)
	K.rect(im, x, y, w, h, glass)
	K.hline(im, x, y, w, glass.lightened(0.25))
	K.px(im, x, y + 1, glass.lightened(0.12))
	if w >= 5:
		K.vline(im, x + w / 2, y, h, frame)
	if h >= 4:
		K.hline(im, x, y + h / 2, w, frame)
	if curtain.a > 0.0:
		K.rect(im, x, y, maxi(1, w / 4), h, curtain)
		K.rect(im, x + w - maxi(1, w / 4), y, maxi(1, w / 4), h, curtain)
	K.hline(im, x - 1, y + h + 1, w + 2, frame.lightened(0.22))
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
			_ponderosa(im, s)
		F.SUGAR_PINE:
			_sugar_pine(im, s)
		F.JEFFREY_PINE:
			_conifer(im, s, 4, 37, 8.6, 6, 0.5, ramp(JEFFREY_LIT), ramp(BARK_PONDEROSA), 3.4)
		F.GRAY_PINE:
			_gray_pine(im, s)
		F.INCENSE_CEDAR:
			_conifer(im, s, 2, 41, 9.5, 6, 1.4, ramp(CEDAR_LIT), ramp(BARK_CEDAR), 2.6)
		F.WHITE_FIR:
			_conifer(im, s, 4, 41, 10.8, 6, 0.2, ramp(WHITEFIR_LIT), ramp(BARK_FIR), 2.4)
		F.RED_FIR:
			_conifer(im, s, 1, 41, 9.2, 11, 0.7, ramp(REDFIR_LIT), ramp(BARK_RED_FIR), 2.4)
		F.HEMLOCK:
			_conifer(im, s, 2, 42, 8.8, 7, 1.7, ramp(HEMLOCK_LIT), ramp(BARK_CEDAR), 2.0, 2.4)
		F.LODGEPOLE:
			_lodgepole(im, s)
		F.BLACK_OAK_TRUNK:
			_black_oak_trunk(im, s)
		F.LIVE_OAK:
			_live_oak(im, s)
		F.WHITEBARK:
			_whitebark(im, s)
		F.DOGWOOD:
			_dogwood(im, s)
		F.SNAG:
			_snag(im, s)
		F.SEQUOIA:
			_sequoia(im, s)
		F.MANZANITA:
			_manzanita(im, s)
		F.SHRUB:
			_shrub(im, s)
		F.WILLOW:
			_willow(im, s)
		F.BOULDER:
			_rock(im, s, 24, 18, 0.25)
		F.ERRATIC:
			_rock(im, s, 30, 26, 0.5)
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
			_black_oak_canopy(im, s)
	return im


# ---------------------------------------------------------------- shared pieces

## One round leaf clump, lit from the upper left, shaded along its lower-right
## rim, with 2x2 leaf dabs so the texture reads as clusters, not noise.
static func _clump(im: Image, cx: float, cy: float, rx: float, ry: float, r: Array[Color], s: int, rim := 0.3) -> void:
	var n := r.size()
	for y in range(maxi(0, floori(cy - ry) - 1), mini(H, ceili(cy + ry) + 2)):
		for x in range(maxi(0, floori(cx - rx) - 1), mini(W, ceili(cx + rx) + 2)):
			var dx := (x + 0.5 - cx) / rx
			var dy := (y + 0.5 - cy) / ry
			var d := sqrt(dx * dx + dy * dy)
			if d > 1.0:
				continue
			var diag := (dx + dy) * 0.5
			var v := 0.56 - diag * 0.34
			if d > 1.0 - rim and diag > -0.1:
				v -= 0.3 * (d - (1.0 - rim)) / rim + 0.08
			v += (K.hash2(x >> 1, y >> 1, s) - 0.5) * 0.22
			if diag < -0.45 and K.hash2(x >> 1, y >> 1, s + 9) > 0.8:
				v += 0.22
			_put(im, x, y, r[_idx(n, v)])


## A canopy of overlapping clumps. The shadow pass goes first, offset to the
## lower right, so blue-green pockets show between and under the lit clumps.
static func _canopy(im: Image, lobes: Array, lit: Array[Color], s: int) -> void:
	var dark := dim(lit, 0.78)
	for i in lobes.size():
		var l: Vector4 = lobes[i]
		_clump(im, l.x + 1.4, l.y + 1.6, l.z, l.w, dark, s + i * 5, 0.4)
	for i in lobes.size():
		var l: Vector4 = lobes[i]
		_clump(im, l.x, l.y, l.z, l.w, lit, s + i * 5 + 2, 0.3)


## Sky gaps: a few pixels punched out of the canopy so light shows through.
static func _gaps(im: Image, pts: Array) -> void:
	for p: Vector2i in pts:
		_put(im, p.x, p.y, Color(0, 0, 0, 0))
		_put(im, p.x + 1, p.y, Color(0, 0, 0, 0))


## A broken outline: a dark, saturated shade on the far side of the silhouette
## (lower right). On the lit upper-left edge only some pixels are drawn.
static func _outline(im: Image, col_hex: String) -> void:
	var col := Color(col_hex)
	var src := im.duplicate() as Image
	for y in im.get_height():
		for x in im.get_width():
			if src.get_pixel(x, y).a > 0.05:
				continue
			var lit_edge := _opaque(src, x + 1, y) or _opaque(src, x, y + 1)
			var shade_edge := _opaque(src, x - 1, y) or _opaque(src, x, y - 1)
			if not (lit_edge or shade_edge):
				continue
			if lit_edge and not shade_edge and K.hash2(x, y, 77) < 0.6:
				continue
			im.set_pixel(x, y, col)


## A soft oval contact shadow, drawn only on empty pixels so it sits under the
## object.
static func _ground(im: Image, cx: float, cy: float, rx: float, ry: float, alpha := 0.42) -> void:
	for y in range(maxi(0, floori(cy - ry)), mini(im.get_height(), ceili(cy + ry) + 1)):
		for x in range(maxi(0, floori(cx - rx)), mini(im.get_width(), ceili(cx + rx) + 1)):
			var dx := (x + 0.5 - cx) / rx
			var dy := (y + 0.5 - cy) / ry
			var d := dx * dx + dy * dy
			if d >= 1.0 or im.get_pixel(x, y).a > 0.05:
				continue
			im.set_pixel(x, y, Color(0.11, 0.18, 0.17, alpha * pow(1.0 - d, 0.6)))


## A tapered trunk: lit on the left, cool on the right, long bark streaks and a
## root flare at the foot. lean is how far the top sits right of the foot.
static func _trunk(im: Image, cx: float, base_y: int, top_y: int, w_base: float, w_top: float, r: Array[Color], s: int, lean := 0.0, flare := 2.0, fluted := false) -> void:
	var n := r.size()
	for y in range(top_y, base_y + 1):
		var t := float(base_y - y) / maxf(1.0, float(base_y - top_y))
		var foot := maxf(0.0, 1.0 - float(base_y - y) / 3.0)
		var w := lerpf(w_top, w_base, t) + flare * foot * 2.0
		var xc := cx + lean * (1.0 - t)
		var left := xc - w * 0.5
		for x in range(floori(left), ceili(left + w) + 1):
			var f := (x + 0.5 - left) / maxf(w, 1.0)
			var v := 0.66 - (f - 0.5) * 0.9
			if f > 0.82:
				v -= 0.12
			if K.hash2(x, y / 3, s) > 0.8:
				v -= 0.2
			if fluted and (x - floori(left)) % 3 == 0:
				v -= 0.14
			if K.hash2(x, y, s + 5) > 0.93:
				v += 0.12
			if foot > 0.2 and y >= base_y - 1:
				v -= 0.18
			_put(im, x, y, r[_idx(n, v)])


## A thick branch between two points, shaded like the trunk.
static func _limb(im: Image, x0: float, y0: float, x1: float, y1: float, w0: float, w1: float, r: Array[Color], s: int) -> void:
	var n := r.size()
	var steps := ceili(Vector2(x1 - x0, y1 - y0).length() * 1.5) + 1
	for i in steps + 1:
		var t := float(i) / steps
		var bx := lerpf(x0, x1, t)
		var by := lerpf(y0, y1, t)
		var rad := maxf(lerpf(w0, w1, t) * 0.5, 0.5)
		for y in range(floori(by - rad), ceili(by + rad) + 1):
			for x in range(floori(bx - rad), ceili(bx + rad) + 1):
				var dx := (x + 0.5 - bx) / rad
				var dy := (y + 0.5 - by) / rad
				if dx * dx + dy * dy > 1.0:
					continue
				var v := 0.62 - (dx + dy) * 0.3 + (K.hash2(x, y, s) - 0.5) * 0.12
				_put(im, x, y, r[_idx(n, v)])


## Layered drooping tiers of a conifer, drawn top to bottom so each lower tier
## overlaps the one above. Lit from the left, with a shadowed tip edge under
## each tier and a darker top edge where it tucks under the tier above.
static func _tiers(im: Image, cx: float, top: float, bottom: float, half_w: float, count: int, droop: float, r: Array[Color], s: int, lean := 0.0) -> void:
	var n := r.size()
	var span := bottom - top
	var step := span / count
	var th := step * 1.7
	for k in count:
		var t := (float(k) + 0.5) / count
		var yc := top + step * k
		var hw := half_w * (0.32 + 0.68 * pow(t, 0.9))
		var tx := cx + lean * (1.0 - t)
		for y in range(maxi(0, floori(yc)), mini(H, ceili(yc + th * 1.6) + 1)):
			for x in range(maxi(0, floori(tx - hw)), mini(W, ceili(tx + hw) + 1)):
				var dx := (x + 0.5 - tx) / hw
				if absf(dx) > 1.0:
					continue
				var yy := y + 0.5
				var top_e := yc + th * 0.22 * pow(absf(dx), 1.3)
				# ragged, drooping tips: each sprig of the tier ends a little lower or higher
				var sprig := (K.hash2(k, int(absf(dx) * 6.0), s) - 0.5) * 1.5
				var bot_e := yc + th * (0.8 + droop * 0.45 * dx * dx) + sprig
				if yy < top_e or yy > bot_e:
					continue
				var v := 0.64 - dx * 0.36 - (yy - yc) / th * 0.14 + (0.05 if k % 2 == 0 else -0.04)
				if dx > 0.25:
					v -= 0.12
				if yy > bot_e - 1.4:
					v -= 0.26
				if yy < top_e + 2.0:
					v -= 0.3
				v += (K.hash2(x >> 1, y >> 1, s + k * 7) - 0.5) * 0.2
				_put(im, x, y, r[_idx(n, v)])
	_clump(im, cx + lean, top + 1.0, 1.4, 2.6, r, s + 99, 0.5)


## A shingled gable roof seen from the front: courses of tabs, a darker line
## under each course, a highlight at the ridge and an eave shadow at the foot.
static func _roof(im: Image, x0: int, y0: int, w: int, h: int, base: Color, s: int) -> void:
	var t := tones(base)
	var n := t.size()
	var cx := x0 + w * 0.5
	for r in h:
		var f := float(r) / maxf(1.0, h - 1.0)
		var half := lerpf(w * 0.2, w * 0.5, pow(f, 0.8))
		var course := r / 3
		for x in range(floori(cx - half), ceili(cx + half)):
			var phase := x - floori(cx) + 1000 + course * 2
			var v := 0.5 + (K.hash2(phase / 4, course, s) - 0.5) * 0.22
			v += 0.12 if x < floori(cx) else -0.06
			v -= f * 0.06
			if phase % 4 == 0:
				v -= 0.1
			if r % 3 == 2:
				v -= 0.2
			if r == 0:
				v += 0.2
			if r == h - 1:
				v -= 0.3
			_put(im, x, y0 + r, t[_idx(n, v)])


## Siding boards, vertical, with a dark seam between each board.
static func _boards(im: Image, x0: int, y0: int, w: int, h: int, base: Color, s: int, board_w: int) -> void:
	var t := tones(base)
	var n := t.size()
	for x in range(x0, x0 + w):
		var b := (x - x0) / board_w
		var seam := (x - x0) % board_w == 0
		var bo := (K.hash2(b, 3, s) - 0.5) * 0.16
		for y in range(y0, y0 + h):
			var f := float(x - x0) / w
			var v := 0.56 - (f - 0.5) * 0.14 + bo
			if seam:
				v -= 0.26
			if y - y0 == h - 1:
				v -= 0.12
			if K.hash2(x, y >> 1, s + 1) > 0.9:
				v += 0.08
			_put(im, x, y, t[_idx(n, v)])


## Lap siding: horizontal courses, each lit along its top edge.
static func _lap(im: Image, x0: int, y0: int, w: int, h: int, base: Color, s: int) -> void:
	var t := tones(base)
	var n := t.size()
	for y in range(y0, y0 + h):
		for x in range(x0, x0 + w):
			var f := float(x - x0) / w
			var v := 0.56 - (f - 0.5) * 0.14
			v += 0.14 if (y - y0) % 2 == 0 else -0.12
			v += (K.hash2(x >> 2, y, s) - 0.5) * 0.12
			if y == y0 + h - 1:
				v -= 0.14
			_put(im, x, y, t[_idx(n, v)])


## Stone blocks, staggered rows with mortar lines and a lit top edge per stone.
static func _stones(im: Image, x0: int, y0: int, w: int, h: int, base: Color, s: int) -> void:
	var t := tones(base)
	var n := t.size()
	for y in range(y0, y0 + h):
		var row := (y - y0) / 3
		var off := (row % 2) * 2
		for x in range(x0, x0 + w):
			var cell := (x - x0 + off) / 5
			var mortar := (x - x0 + off) % 5 == 0 or (y - y0) % 3 == 2
			var v := 0.56 + (K.hash2(cell, row, s) - 0.5) * 0.3
			if (y - y0) % 3 == 0:
				v += 0.14
			if mortar:
				v = 0.08
			_put(im, x, y, t[_idx(n, v)])


## A plank door with a frame, a knob and a stone step.
func _door(im: Image, x: int, y: int, w: int, h: int, wood: Color, frame: Color) -> void:
	K.rect(im, x - 1, y - 1, w + 2, h + 1, frame)
	var t := tones(wood)
	var n := t.size()
	for yy in range(y, y + h):
		for xx in range(x, x + w):
			var f := float(xx - x) / w
			var v := 0.56 - (f - 0.5) * 0.2
			if (xx - x) % 2 == 0:
				v -= 0.06
			_put(im, xx, yy, t[_idx(n, v)])
	_put(im, x + w - 1, y + h / 2, Color("e0c060"))
	K.hline(im, x - 2, y + h, w + 4, Color("8a8072"))
	K.hline(im, x - 2, y + h, w + 4, Color("b0a692").lerp(Color("8a8072"), 0.3))


## A planter box with a row of flowers and a few leaves.
static func _planter(im: Image, x: int, y: int, w: int, s: int) -> void:
	var t := tones(Color("7c5a36"))
	var n := t.size()
	for xx in range(x, x + w):
		_put(im, xx, y, t[_idx(n, 0.62)])
		_put(im, xx, y + 1, t[_idx(n, 0.3)])
	var flowers := [Color("e0605a"), Color("f0c850"), Color("f2f0e8"), Color("d070a0")]
	for i in range(1, w - 1, 2):
		var fx := x + i
		_put(im, fx, y - 1, flowers[(i + s) % flowers.size()])
		_put(im, fx - 1, y - 1, Color("5a8a3e"))
		_put(im, fx + 1, y - 1, Color("6c9e4c"))


## Stacked split logs with pale ends.
static func _woodpile(im: Image, x0: int, y0: int) -> void:
	var t := ramp(BARK_CEDAR)
	var n := t.size()
	for row in 2:
		for i in 3 - row:
			var lx := x0 + i * 4 + row * 2
			var ly := y0 - row * 3
			for yy in 3:
				for xx in 4:
					_put(im, lx + xx, ly + yy, t[_idx(n, 0.62 - (float(xx) / 3.0 - 0.5) * 0.2 - (float(yy) / 2.0 - 0.5) * 0.14)])
			_put(im, lx, ly, Color("d8b07a"))
			_put(im, lx, ly + 2, Color("c49a64"))


# ---------------------------------------------------------------- conifers

## A tiered conifer: layered fans over a short trunk.
func _conifer(im: Image, s: int, top: int, bottom: int, half_w: float, count: int, droop: float, lit: Array[Color], bark: Array[Color], trunk_w: float, lean := 0.0) -> void:
	_trunk(im, 16.0, BASE, bottom - 3, trunk_w, trunk_w * 0.5, bark, s, 0.0, 1.5)
	_tiers(im, 16.0, float(top), float(bottom), half_w, count, droop, lit, s, lean)
	_outline(im, OUT_NEEDLE)
	_ground(im, 16.0, BASE + 1.0, half_w * 0.7, 2.2)


## Ponderosa: a bare orange-barked trunk under an open, flat-topped crown of
## warm needle clumps on heavy limbs.
func _ponderosa(im: Image, s: int) -> void:
	var bark := ramp(BARK_PONDEROSA)
	_trunk(im, 16.0, BASE, 12, 4.0, 2.4, bark, s, 1.5, 2.0)
	var lobes := [Vector4(9, 13, 4.8, 3.2), Vector4(17, 9, 5.4, 3.4), Vector4(24, 12, 4.6, 3.1), Vector4(13, 17, 4.0, 2.6), Vector4(21, 18, 3.8, 2.5)]
	for i in lobes.size():
		var l: Vector4 = lobes[i]
		_limb(im, 16.6, 26.0, l.x, l.y + 1.0, 1.8, 1.1, bark, s + i)
	_canopy(im, lobes, ramp(PONDEROSA_LIT), s)
	_outline(im, OUT_NEEDLE)
	_ground(im, 16.0, BASE + 1.0, 8.0, 2.4)


## Sugar pine: a slender trunk with long, sparse arms that end in drooping tufts.
func _sugar_pine(im: Image, s: int) -> void:
	var bark := ramp(BARK_SUGAR)
	_trunk(im, 16.0, BASE, 4, 3.4, 1.6, bark, s, 0.0, 1.6)
	var lobes := [Vector4(6, 11, 4.4, 2.2), Vector4(27, 12, 4.4, 2.2), Vector4(7, 19, 4.6, 2.3), Vector4(26, 20, 4.6, 2.3), Vector4(9, 27, 3.6, 2.0), Vector4(24, 28, 3.6, 2.0), Vector4(16, 5, 3.2, 2.2)]
	var arms := [[9.0, 11.0, 6.0, 11.0], [23.0, 12.0, 26.0, 12.0], [9.0, 19.0, 7.0, 19.0], [23.0, 20.0, 25.0, 20.0], [11.0, 27.0, 9.0, 27.0], [21.0, 28.0, 24.0, 28.0]]
	for i in arms.size():
		var a: Array = arms[i]
		_limb(im, 16.0, float(a[1]) + 6.0, float(a[0]), float(a[1]), 1.6, 1.0, bark, s + i)
	_canopy(im, lobes, ramp(SUGAR_LIT), s)
	_outline(im, OUT_NEEDLE)
	_ground(im, 16.0, BASE + 1.0, 8.0, 2.4)


## Gray pine: a leaning, forked trunk with sparse, sage-gray tufts.
func _gray_pine(im: Image, s: int) -> void:
	var bark := ramp(BARK_OAK)
	_trunk(im, 16.0, BASE, 26, 4.0, 2.4, bark, s, -1.5, 1.8)
	_limb(im, 16.0, 29.0, 23.0, 16.0, 2.2, 1.2, bark, s + 1)
	_limb(im, 15.0, 27.0, 9.0, 14.0, 2.2, 1.2, bark, s + 2)
	var lobes := [Vector4(23, 13, 4.8, 3.4), Vector4(9, 11, 5.0, 3.4), Vector4(15, 21, 5.0, 3.0), Vector4(16, 6, 4.2, 3.0), Vector4(21, 22, 3.6, 2.8), Vector4(11, 20, 3.6, 2.8)]
	_canopy(im, lobes, ramp(GRAY_PINE_LIT), s)
	_outline(im, OUT_NEEDLE)
	_ground(im, 16.0, BASE + 1.0, 8.0, 2.4)


## Lodgepole: a slender pole with small, yellow-green tufts climbing it.
func _lodgepole(im: Image, s: int) -> void:
	var bark := ramp(BARK_LODGEPOLE)
	_trunk(im, 16.0, BASE, 6, 2.8, 1.2, bark, s, 0.0, 1.4)
	var lobes := [Vector4(16, 5, 2.6, 2.4)]
	for i in 7:
		var side := 1.0 if i % 2 == 0 else -1.0
		lobes.append(Vector4(16.0 + side * (2.2 + float(i) * 0.12), 9.0 + float(i) * 4.0, 2.8, 1.7))
	_canopy(im, lobes, ramp(LODGEPOLE_LIT), s)
	_outline(im, OUT_NEEDLE)
	_ground(im, 16.0, BASE + 1.0, 5.5, 2.0)


## Sequoia: a huge, very red, fluted trunk with a dark blue-green crown on top.
func _sequoia(im: Image, s: int) -> void:
	var bark := ramp(BARK_SEQUOIA)
	_trunk(im, 16.0, BASE, 12, 13.0, 8.0, bark, s, 0.0, 2.6, true)
	var lobes := [Vector4(16, 8, 8.2, 5.0), Vector4(7, 13, 6.0, 4.4), Vector4(25, 13, 6.0, 4.4), Vector4(16, 16, 7.6, 3.6), Vector4(11, 7, 5.0, 3.6), Vector4(21, 7, 5.0, 3.6)]
	_canopy(im, lobes, ramp(SEQUOIA_LIT), s)
	_gaps(im, [Vector2i(14, 10), Vector2i(20, 12)])
	_outline(im, OUT_SEQ)
	_ground(im, 16.0, BASE + 1.0, 11.0, 2.8)


# ---------------------------------------------------------------- broadleaf

## A trunk that forks under a round canopy, with the canopy, sky gaps and outline.
func _broadleaf(im: Image, s: int, lit: Array[Color], bark: Array[Color], lobes: Array, fork_y: int, trunk_w: float, gaps: Array, shadow_rx: float) -> void:
	_trunk(im, 16.0, BASE, fork_y, trunk_w, trunk_w * 0.6, bark, s, 0.0, 2.2)
	_limb(im, 16.0, float(fork_y + 4), 9.0, float(fork_y - 2), 2.4, 1.6, bark, s + 1)
	_limb(im, 16.0, float(fork_y + 4), 23.0, float(fork_y - 2), 2.4, 1.6, bark, s + 2)
	_canopy(im, lobes, lit, s)
	_gaps(im, gaps)
	_outline(im, OUT_LEAF)
	_ground(im, 16.0, BASE + 1.0, shadow_rx, 2.4)


func _live_oak(im: Image, s: int) -> void:
	_broadleaf(im, s, ramp(LIVE_OAK_LIT), ramp(BARK_OAK), [Vector4(16, 13, 10, 7), Vector4(8, 18, 6.2, 5), Vector4(24, 18, 6.2, 5), Vector4(11, 10, 6, 4.6), Vector4(21, 10, 6, 4.6), Vector4(16, 21, 8.5, 4)], 22, 5.0, [Vector2i(12, 9), Vector2i(19, 8), Vector2i(7, 16)], 11.0)


func _whitebark(im: Image, s: int) -> void:
	_broadleaf(im, s, ramp(WHITEBARK_LIT), ramp(BARK_FIR), [Vector4(16, 14, 9, 6.4), Vector4(9, 19, 5.8, 4.4), Vector4(23, 19, 5.8, 4.4), Vector4(13, 9, 5.4, 4.0), Vector4(20, 9, 5.4, 4.0)], 24, 4.0, [Vector2i(16, 11)], 9.0)


func _dogwood(im: Image, s: int) -> void:
	var lit := ramp(DOGWOOD_LIT)
	var bark := ramp(BARK_DOGWOOD)
	_trunk(im, 16.0, BASE, 28, 3.2, 2.2, bark, s, 0.0, 1.6)
	_limb(im, 16.0, 30.0, 10.0, 26.0, 1.8, 1.2, bark, s + 1)
	_limb(im, 16.0, 30.0, 22.0, 26.0, 1.8, 1.2, bark, s + 2)
	var lobes := [Vector4(16, 25, 7.4, 5.0), Vector4(9, 29, 5.0, 3.8), Vector4(23, 29, 5.0, 3.8), Vector4(14, 21, 4.6, 3.6)]
	_canopy(im, lobes, lit, s)
	# white bracts scattered over the crown, each with a yellow centre
	for i in 14:
		var a := K.hash2(i, 1, s) * TAU
		var d := sqrt(K.hash2(i, 2, s)) * 0.9
		var fx := int(16.0 + cos(a) * d * 9.0)
		var fy := int(25.0 + sin(a) * d * 5.5)
		_put(im, fx, fy, Color("fbf6ec"))
		_put(im, fx + 1, fy, Color("e2d8d0"))
		_put(im, fx, fy + 1, Color("d8c4d0"))
	_outline(im, OUT_LEAF)
	_ground(im, 16.0, BASE + 1.0, 6.0, 2.4)


func _willow(im: Image, s: int) -> void:
	var lit := ramp(WILLOW_LIT)
	var bark := ramp(BARK_WILLOW)
	_limb(im, 14.0, BASE, 13.0, 22.0, 2.8, 1.8, bark, s)
	_limb(im, 18.0, BASE, 19.0, 22.0, 2.8, 1.8, bark, s + 1)
	_canopy(im, [Vector4(16, 21, 9, 5.2), Vector4(8, 25, 5.4, 4.4), Vector4(24, 25, 5.4, 4.4), Vector4(16, 28, 8, 3.8)], lit, s)
	# drooping wands hanging from the crown
	for i in 13:
		var wx := 5 + i * 2
		var wl := 5 + int(K.hash2(i, 1, s) * 6.0)
		var y0 := 26 + absi(wx - 16) / 4
		for k in wl:
			_put(im, wx, y0 + k, lit[2 + (k + i) % 3])
	_outline(im, OUT_LEAF)
	_ground(im, 16.0, BASE + 1.0, 9.0, 2.4)


func _manzanita(im: Image, s: int) -> void:
	var bark := ramp(BARK_MANZANITA)
	for st: Array in [[11.0, 37.0, 7.0], [16.0, 36.0, 4.0], [21.0, 37.0, 25.0]]:
		_limb(im, 16.0, BASE, st[0] + (st[0] - 16.0) * 0.2, st[1], 2.0, 1.2, bark, s + int(st[0]))
	_canopy(im, [Vector4(16, 33, 7.5, 4.6), Vector4(9, 36, 5.0, 3.6), Vector4(23, 36, 5.0, 3.6), Vector4(13, 30, 4.5, 3.2), Vector4(20, 31, 4.0, 3.0)], ramp(CHAPARRAL_LIT), s)
	for i in 5:
		_put(im, 11 + i * 3, 31 + (i % 2) * 3, Color("d9604a"))
	_outline(im, OUT_LEAF)
	_ground(im, 16.0, BASE + 1.0, 9.0, 2.4)


func _shrub(im: Image, s: int) -> void:
	var lobes := [Vector4(16, 38, 7, 5.2), Vector4(9, 40, 5, 4), Vector4(23, 40, 5, 4), Vector4(13, 34, 4.6, 3.6), Vector4(20, 35, 4.2, 3.4), Vector4(16, 42, 6.4, 2.8)]
	_canopy(im, lobes, ramp(SHRUB_LIT), s)
	_outline(im, OUT_LEAF)
	_ground(im, 16.0, BASE + 1.0, 10.5, 2.4, 0.4)


func _snag(im: Image, s: int) -> void:
	var bark := ramp(BARK_DEAD)
	_trunk(im, 16.0, BASE, 6, 3.6, 1.6, bark, s, 0.4, 1.6)
	for st: Array in [[34.0, -1, 6.0], [26.0, 1, 7.0], [18.0, -1, 5.0], [11.0, 1, 4.0]]:
		var sx: float = 16.0 + 0.4 * (BASE - float(st[0])) / (BASE - 6.0)
		_limb(im, sx, st[0], sx + st[1] * st[2], st[0] - 4.0, 1.8, 0.8, bark, s + int(st[0]))
	_outline(im, OUT_GRAY)
	_ground(im, 16.0, BASE + 1.0, 4.5, 1.8)


func _black_oak_trunk(im: Image, s: int) -> void:
	# The black oak's canopy is a separate (seasonal) layer drawn over this.
	var bark := ramp(BARK_OAK)
	_trunk(im, 16.0, BASE, 28, 7.0, 4.6, bark, s, 0.0, 2.6)
	_limb(im, 16.0, 28.0, 10.0, 18.0, 3.0, 1.6, bark, s + 1)
	_limb(im, 16.0, 28.0, 23.0, 17.0, 3.0, 1.6, bark, s + 2)
	_limb(im, 16.0, 26.0, 16.0, 14.0, 2.8, 1.4, bark, s + 3)
	_outline(im, OUT_BARK)
	_ground(im, 16.0, BASE + 1.0, 9.0, 2.4)


func _black_oak_canopy(im: Image, s: int) -> void:
	# Light grays; the layer's modulate tints them per season.
	var lobes := [Vector4(16, 17, 10, 8), Vector4(8, 21, 6.5, 5.5), Vector4(24, 21, 6.5, 5.5), Vector4(11, 11, 6.5, 5.5), Vector4(21, 11, 6.5, 5.5), Vector4(16, 25, 8, 4.5)]
	_canopy(im, lobes, ramp(CANOPY_GRAY_LIT), s)
	_outline(im, OUT_GRAY)


# ---------------------------------------------------------------- rocks

## A rounded boulder, lit from the upper left, with cracks, moss on the top
## and a few lichen dabs. Its ground line sits at BASE + 1.
func _rock(im: Image, s: int, rw: int, rh: int, moss_amount: float) -> void:
	var lit := ramp(ROCK_LIT)
	var n := lit.size()
	var mossy := ramp(MOSS)
	var bottom := float(BASE + 1)
	var rx := rw * 0.5
	var ry := float(rh) * 0.5
	var cx := 16.0
	var cy := bottom - ry
	for y in range(maxi(0, floori(cy - ry) - 1), mini(H, ceili(bottom) + 1)):
		for x in range(maxi(0, floori(cx - rx) - 1), mini(W, ceili(cx + rx) + 2)):
			if float(y) + 0.5 > bottom:
				continue
			var dx := (x + 0.5 - cx) / rx
			var dy := (y + 0.5 - cy) / ry
			var edge := (K.hash2(x >> 1, y >> 1, s) - 0.5) * 0.22
			if dx * dx + dy * dy > 1.0 + edge:
				continue
			var diag := (dx + dy) * 0.5
			var v := 0.6 - diag * 0.38
			if dy > 0.35:
				v -= 0.14
			if diag > 0.2:
				v -= 0.12
			v += (K.hash2(x >> 1, y >> 1, s + 3) - 0.5) * 0.2
			var col := lit[_idx(n, v)]
			if dy < -0.25 and K.hash2(x >> 1, y >> 1, s + 11) < moss_amount:
				col = mossy[_idx(3, K.hash2(x, y, s + 13))]
			elif K.hash2(x, y, s + 17) > 0.98:
				col = Color("c8c040")
			_put(im, x, y, col)
	# two cracks, drawn in the shadow tone
	var crack := lit[0].darkened(0.1)
	var k := int(rx * 0.4)
	_put(im, floori(cx) - k, floori(cy) - 2, crack)
	_put(im, floori(cx) - k + 1, floori(cy) - 1, crack)
	_put(im, floori(cx) - k + 2, floori(cy), crack)
	_put(im, floori(cx) + k, floori(cy) + 2, crack)
	_put(im, floori(cx) + k - 1, floori(cy) + 3, crack)
	_outline(im, OUT_ROCK)
	_ground(im, cx, bottom, rx * 0.9, 2.4, 0.42)


# ---------------------------------------------------------------- buildings

## A tent cabin on a plank deck: canvas walls and roof, a dark door flap.
func _tent_cabin(im: Image, s: int) -> void:
	_boards(im, 4, 40, 24, 4, Color("9a7a50"), s, 3)
	_canvas(im, 7, 30, 18, 10, Color("e8e0cc"), s)
	_tent_roof(im, 16, 18, 30, 12.5, Color("e8e0cc"), s)
	# door flap, tied back
	K.rect(im, 14, 34, 4, 6, Color("2f2418"))
	K.hline(im, 14, 34, 4, Color("6a5036"))
	_put(im, 13, 36, Color("8a6c48"))
	# guy ropes
	_line_px(im, 6, 31, 2, 40, Color("7a6446"))
	_line_px(im, 25, 31, 29, 40, Color("7a6446"))
	_outline(im, OUT_BARK)
	_ground(im, 16.0, BASE + 1.0, 11.0, 2.4)


## A one-pixel line, for guy ropes and the like.
static func _line_px(im: Image, x0: int, y0: int, x1: int, y1: int, col: Color) -> void:
	var steps := maxi(absi(x1 - x0), absi(y1 - y0))
	for i in steps + 1:
		var t := float(i) / maxf(1.0, steps)
		_put(im, roundi(lerpf(x0, x1, t)), roundi(lerpf(y0, y1, t)), col)


## Canvas wall: vertical fold lines and a lit left side.
static func _canvas(im: Image, x0: int, y0: int, w: int, h: int, base: Color, s: int) -> void:
	var t := tones(base)
	var n := t.size()
	for y in range(y0, y0 + h):
		for x in range(x0, x0 + w):
			var f := float(x - x0) / w
			var v := 0.6 - (f - 0.5) * 0.2 - float(y - y0) / h * 0.1
			if (x - x0) % 6 == 0:
				v -= 0.1
			v += (K.hash2(x >> 2, y >> 2, s) - 0.5) * 0.08
			_put(im, x, y, t[_idx(n, v)])


## A canvas ridge roof: rows widen from the peak down to the eave.
static func _tent_roof(im: Image, cx: int, y0: int, y1: int, half_max: float, base: Color, s: int) -> void:
	var t := tones(base)
	var n := t.size()
	for y in range(y0, y1 + 1):
		var f := float(y - y0) / maxf(1.0, float(y1 - y0))
		var half := lerpf(1.0, half_max, f)
		for x in range(floori(cx - half), ceili(cx + half) + 1):
			var u := (x + 0.5 - cx) / maxf(half, 1.0)
			var v := 0.7 - u * 0.25 - f * 0.1
			if absf(u) < 0.06:
				v -= 0.2
			if y == y1:
				v -= 0.2
			if y == y0:
				v += 0.15
			_put(im, x, y, t[_idx(n, v)])


func _cabin(im: Image, s: int) -> void:
	_stones(im, 20, 9, 4, 12, Color("8c8478"), s + 3)
	_roof(im, 3, 17, 26, 13, Color("6a4a32"), s + 2)
	_boards(im, 7, 29, 18, 10, Color("7c5638"), s + 1, 4)
	_stones(im, 6, 39, 20, 5, Color("8e8678"), s)
	_win(im, 9, 32, 4, 4, Color("3a2a20"))
	_win(im, 19, 32, 4, 4, Color("3a2a20"))
	_planter(im, 8, 37, 6, s)
	_door(im, 14, 34, 4, 5, Color("5a3c26"), Color("2e2018"))
	_woodpile(im, 25, 41)
	_outline(im, OUT_BARK)
	_ground(im, 16.0, BASE + 1.0, 12.0, 2.4)


func _house(im: Image, s: int) -> void:
	_stones(im, 21, 8, 3, 10, Color("8a5a48"), s + 3)
	_roof(im, 2, 16, 28, 13, Color("4a6a48"), s + 2)
	_lap(im, 5, 29, 22, 10, Color("b8a888"), s + 1)
	_stones(im, 5, 39, 22, 5, Color("8a8478"), s)
	_win(im, 8, 31, 4, 4, Color("e8e0d0"), Color("d9c9a0"))
	_win(im, 19, 31, 4, 4, Color("e8e0d0"), Color("d9c9a0"))
	_planter(im, 7, 36, 6, s)
	_door(im, 14, 33, 4, 5, Color("5a3c26"), Color("3a2a20"))
	_outline(im, OUT_LEAF)
	_ground(im, 16.0, BASE + 1.0, 13.0, 2.4)


func _lodge(im: Image, s: int) -> void:
	_stones(im, 23, 3, 4, 13, Color("807a6e"), s + 4)
	_roof(im, 0, 9, 32, 18, Color("5a3e2a"), s + 2)
	_boards(im, 2, 26, 28, 10, Color("6a4630"), s + 1, 4)
	_stones(im, 1, 36, 30, 8, Color("8c8678"), s)
	for wx in [4, 9, 20, 25]:
		_win(im, wx, 29, 3, 4, Color("3a2a20"))
	_door(im, 14, 30, 4, 6, Color("4a3020"), Color("2e2018"))
	_outline(im, OUT_BARK)
	_ground(im, 16.0, BASE + 1.0, 15.0, 2.6)


func _white_house(im: Image, s: int) -> void:
	_stones(im, 21, 8, 3, 10, Color("a86a50"), s + 3)
	_roof(im, 2, 16, 24, 14, Color("3f5a44"), s + 2)
	_lap(im, 5, 30, 20, 9, Color("ece8dc"), s + 1)
	_stones(im, 5, 39, 20, 5, Color("9a948a"), s)
	_win(im, 7, 32, 4, 4, Color("f4f0e4"), Color(0, 0, 0, 0), Color("3f5a44"))
	_win(im, 19, 32, 4, 4, Color("f4f0e4"), Color(0, 0, 0, 0), Color("3f5a44"))
	_door(im, 13, 33, 4, 5, Color("3a5a48"), Color("f4f0e4"))
	_outline(im, OUT_LEAF)
	_ground(im, 16.0, BASE + 1.0, 12.0, 2.4)


## A camp tent: a bright orange ridge with fabric seams and a dark entrance.
func _camp_tent(im: Image, s: int) -> void:
	var t := ramp(ORANGE_LIT)
	var n := t.size()
	for y in range(14, 44):
		var half := minf((y - 14) * 0.5 + 1.0, 13.0)
		for x in range(floori(16.0 - half), ceili(16.0 + half) + 1):
			var u := (x + 0.5 - 16.0) / maxf(half, 1.0)
			var v := 0.72 - u * 0.4 - float(y - 14) / 30.0 * 0.2
			if int(absf(x - 16.0) / 3.0) % 2 == 0:
				v -= 0.1
			if y == 43:
				v -= 0.2
			_put(im, x, y, t[_idx(n, v)])
	K.rect(im, 14, 36, 4, 7, Color("26180e"))
	K.hline(im, 13, 36, 6, Color("6a4a2a"))
	_put(im, 16, 14, Color("3a2616"))
	# a little flag on the peak
	K.vline(im, 16, 6, 8, Color("5a4a3a"))
	K.rect(im, 17, 6, 3, 2, Color("c04a3a"))
	_outline(im, OUT_BARK)
	_ground(im, 16.0, BASE + 1.0, 9.0, 2.2)


# ---------------------------------------------------------------- signs

## A plank with a shaded face, a lit top edge and a dark bottom edge.
static func _plank(im: Image, x: int, y: int, w: int, h: int, s: int) -> void:
	var t := tones(Color("7c5a36"))
	var n := t.size()
	for yy in range(y, y + h):
		for xx in range(x, x + w):
			var v := 0.56 + (K.hash2(xx, yy >> 1, s) - 0.5) * 0.12
			if yy == y:
				v += 0.2
			if yy == y + h - 1:
				v -= 0.22
			if xx == x + w - 1:
				v -= 0.12
			_put(im, xx, yy, t[_idx(n, v)])


## A post with a lit left side and a shadowed right, with a little grain.
static func _post(im: Image, x: int, y0: int, y1: int, w: int, s: int) -> void:
	var r := ramp(POST)
	for y in range(y0, y1 + 1):
		for dx in w:
			var t := 0.82 - float(dx) / maxf(1.0, w - 1.0) * 0.7 + (K.hash2(x + dx, y / 2, s) - 0.5) * 0.25
			_put(im, x + dx, y, r[_idx(r.size(), t)])


func info_sign() -> Image:
	var im := K.make(16, 16)
	_post(im, 3, 9, 14, 2, 11)
	_post(im, 11, 9, 14, 2, 12)
	_plank(im, 1, 2, 14, 8, 13)
	# routed face with cream lettering and a green park badge
	K.rect(im, 2, 3, 12, 6, Color("2f2218"))
	K.hline(im, 2, 3, 12, Color("1a120c"))
	for y in [4, 6]:
		K.hline(im, 3, y, 7 if y == 4 else 5, Color("e4d8b8"))
	K.hline(im, 3, 7, 3, Color("b8ac90"))
	K.rect(im, 11, 4, 2, 3, Color("6c9a48"))
	_put(im, 11, 4, Color("9cc86c"))
	_ground(im, 8.0, 15.0, 6.0, 1.2, 0.3)
	_outline(im, OUT_BARK)
	return im


func trailhead() -> Image:
	var im := K.make(16, 24)
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
				_put(im, x + w + k, y + k, r[4])
		else:
			for k in 3:
				K.vline(im, x - 1 - k, y + k, 5 - k * 2, r[2])
		K.hline(im, x + 2, y + 2, w - 4, Color("e4d8b8"))
	_outline(im, OUT_BARK)
	_ground(im, 8.0, 23.0, 5.5, 1.2, 0.3)
	return im


func map_kiosk() -> Image:
	var im := K.make(16, 24)
	_post(im, 2, 12, 22, 2, 41)
	_post(im, 12, 12, 22, 2, 42)
	# the notice board: a frame around a little painted map
	var r := ramp(POST)
	K.rect(im, 1, 5, 14, 10, r[2])
	K.hline(im, 1, 5, 14, r[4])
	K.vline(im, 1, 5, 10, r[3])
	K.hline(im, 1, 14, 14, r[0])
	K.rect(im, 3, 6, 10, 8, Color("b8c88a"))
	for y in range(6, 14):
		for x in range(3, 13):
			if K.hash2(x, y, 43) > 0.82:
				_put(im, x, y, Color("9db070"))
	K.hline(im, 3, 10, 6, Color("5a96c8"))
	_put(im, 9, 9, Color("5a96c8"))
	_put(im, 10, 8, Color("5a96c8"))
	K.vline(im, 6, 6, 8, Color("d4b878"))
	_put(im, 10, 12, Color("d8323c"))
	_put(im, 10, 11, Color("f06a6a"))
	# a little shingled roof
	_roof(im, 0, 1, 16, 5, Color("5a3e2a"), 44)
	K.hline(im, 0, 5, 16, Color("2a1a10"))
	_ground(im, 8.0, 23.0, 7.0, 1.4, 0.3)
	_outline(im, OUT_BARK)
	return im
