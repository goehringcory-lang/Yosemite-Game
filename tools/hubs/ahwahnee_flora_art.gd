extends RefCounted
## Pixel art for the Ahwahnee grounds and the Stoneman Meadow trail: mature
## Yosemite Valley trees, meadow plants, granite boulders, fallen logs, and the
## hotel's formal garden furniture. Drawn in code with PixelKit's helpers plus
## ramp-shaded, ordered-dithered foliage and stone, light from the upper left,
## warm highlights over cool shadows, and a selective dark rim around every
## sprite. Written to assets/sprites/ahwahnee/. Replace any PNG with
## hand-drawn art of the same size at any time.
##
## ## Contract
## Every sprite is RGBA on a transparent background and is anchored at the
## bottom center, where the object meets the ground (set Sprite2D.offset to
## Vector2(0, -height / 2)). A soft ground shadow is baked in.
## TRUNKS: collision footprint (width, height in px, centered on the anchor
## and sitting on it: shape position = Vector2(0, -height / 2)) for every piece
## that should block the player. Plants, flowers, grass, ferns, and the flat
## garden beds and steps are walk-through and are not listed.
## FILES: every sprite this module writes, without the .png extension.
## Tile-repeatable pieces (hedge_h/v, wall_h/v, steps) meet edge to edge:
## garden_hedge_h and garden_wall_h are 32 wide and repeat along x,
## garden_hedge_v and garden_wall_v are 16 wide and stack along y, and
## garden_steps is 48 wide. Their width and the left and right edges are seamless.

const K = preload("res://tools/hubs/pixel_kit.gd")
const DIR := "res://assets/sprites/ahwahnee/"

const TRUNKS := {
	"tree_ponderosa_a": Vector2(6, 5),
	"tree_ponderosa_b": Vector2(6, 5),
	"tree_ponderosa_c": Vector2(6, 5),
	"tree_incense_cedar_a": Vector2(7, 5),
	"tree_incense_cedar_b": Vector2(7, 5),
	"tree_white_fir": Vector2(6, 5),
	"tree_black_oak_a": Vector2(9, 5),
	"tree_black_oak_b": Vector2(9, 5),
	"tree_black_oak_c": Vector2(9, 5),
	"tree_dogwood_bloom_a": Vector2(6, 4),
	"tree_dogwood_bloom_b": Vector2(6, 4),
	"tree_willow_a": Vector2(8, 5),
	"tree_willow_b": Vector2(8, 5),
	"tree_snag": Vector2(5, 4),
	"tree_apple_old": Vector2(8, 5),
	"rock_granite_a": Vector2(46, 12),
	"rock_granite_b": Vector2(36, 10),
	"rock_granite_c": Vector2(25, 9),
	"rock_granite_d": Vector2(19, 8),
	"rock_mossy_a": Vector2(31, 10),
	"rock_mossy_b": Vector2(21, 8),
	"rock_river_a": Vector2(19, 7),
	"rock_river_b": Vector2(14, 6),
	"rock_river_c": Vector2(10, 5),
	"log_fallen_a": Vector2(56, 7),
	"log_fallen_b": Vector2(44, 7),
	"log_stump": Vector2(14, 6),
	"garden_fountain": Vector2(56, 20),
	"garden_urn_a": Vector2(10, 6),
	"garden_urn_b": Vector2(10, 6),
	"garden_topiary": Vector2(10, 6),
	"garden_hedge_h": Vector2(32, 8),
	"garden_hedge_v": Vector2(10, 32),
	"garden_hedge_corner": Vector2(12, 10),
	"garden_bench": Vector2(34, 8),
	"garden_flowerbed_a": Vector2(46, 10),
	"garden_flowerbed_b": Vector2(46, 10),
	"garden_flowerbed_c": Vector2(46, 10),
	"garden_wall_h": Vector2(32, 8),
	"garden_wall_v": Vector2(10, 32),
	"garden_wall_pillar": Vector2(12, 8),
	"garden_sundial": Vector2(10, 6),
	"garden_table_umbrella": Vector2(24, 8),
	"garden_birdbath": Vector2(10, 6),
}

## Extra footprints for pieces you can walk through: garden_arbor blocks only
## its two posts. Rect2 is (x from the sprite's center, y from the ground
## line, width, height); y is negative because it sits above the anchor.
const EXTRA_FOOTPRINTS := {
	"garden_arbor": [Rect2(-17, -5, 6, 5), Rect2(11, -5, 6, 5)],
}

## Every tree and rock sits on a ground line this many pixels above the bottom
## edge of its image (the baked shadow hangs below it). Place a sprite with its
## bottom edge BASE_INSET px below the spot where it should touch the ground.
const BASE_INSET := 3
const FILES: Array[String] = [
	"garden_arbor",
	"garden_bench",
	"garden_birdbath",
	"garden_flowerbed_a",
	"garden_flowerbed_b",
	"garden_flowerbed_c",
	"garden_fountain",
	"garden_hedge_corner",
	"garden_hedge_h",
	"garden_hedge_v",
	"garden_steps",
	"garden_sundial",
	"garden_table_umbrella",
	"garden_topiary",
	"garden_urn_a",
	"garden_urn_b",
	"garden_wall_h",
	"garden_wall_pillar",
	"garden_wall_v",
	"log_fallen_a",
	"log_fallen_b",
	"log_stump",
	"plant_bracken",
	"plant_cattails",
	"plant_cornlily",
	"plant_fern_a",
	"plant_fern_b",
	"plant_lupine",
	"plant_manzanita",
	"plant_mushrooms",
	"plant_paintbrush",
	"plant_shrub_a",
	"plant_shrub_b",
	"plant_tall_grass_a",
	"plant_tall_grass_b",
	"plant_wildflowers_a",
	"plant_wildflowers_b",
	"plant_wildflowers_c",
	"rock_granite_a",
	"rock_granite_b",
	"rock_granite_c",
	"rock_granite_d",
	"rock_mossy_a",
	"rock_mossy_b",
	"rock_river_a",
	"rock_river_b",
	"rock_river_c",
	"tree_apple_old",
	"tree_black_oak_a",
	"tree_black_oak_b",
	"tree_black_oak_c",
	"tree_dogwood_bloom_a",
	"tree_dogwood_bloom_b",
	"tree_incense_cedar_a",
	"tree_incense_cedar_b",
	"tree_ponderosa_a",
	"tree_ponderosa_b",
	"tree_ponderosa_c",
	"tree_snag",
	"tree_white_fir",
	"tree_willow_a",
	"tree_willow_b",
]

const LIGHT := Vector3(-0.52, -0.62, 0.59)
const BAYER := [0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5]

# Tone ramps, dark to light. Shadows lean blue-green, lights lean yellow.
const PINE_NEEDLE := ["1f3a2c", "2b4d33", "3a6438", "4e7d3c", "679644", "84b04c", "a6c95c", "c9e07e"]
const CEDAR_LEAF := ["1a3524", "24472c", "305c34", "3f7440", "528e4a", "6ca85a", "8cc272"]
const FIR_LEAF := ["16323a", "1e453f", "2a5c4b", "3a7659", "4f9068", "6aac7c", "8cc796"]
const OAK_LEAF := ["1c3a2e", "26482f", "345f34", "487a3a", "639441", "84ae4b", "a9c95f", "cfe486"]
const WILLOW_LEAF := ["2f5238", "417146", "5b8f4f", "7aab5a", "9cc56d", "bfdc8b", "dcef b0"]
const BARK_PINE := ["2a1a14", "44291d", "5f3a26", "7c5232", "98693c", "b4844e", "cfa06a"]
const BARK_CEDAR := ["331912", "4f281c", "6e3a27", "8c4f34", "a86845", "c58559"]
const BARK_OAK := ["221c1c", "372f2d", "504640", "6b5f55", "877a6c", "a3968a"]
const BARK_FIR := ["2a2726", "403b39", "5a534f", "766d66", "928779"]
const BARK_DEAD := ["2e2a29", "4a4340", "685f58", "8a7e71", "b0a290", "d0c4b0"]
const GRANITE := ["30343f", "484d5a", "626773", "7d818b", "9a9da2", "b8b7b1", "d5d0c2", "ece6d6"]


static func c(hex: String) -> Color:
	return Color(hex)


static func ramp(hexes: Array) -> Array[Color]:
	var out: Array[Color] = []
	for h in hexes:
		out.append(Color(String(h).replace(" ", "")))
	return out


static func bayer(x: int, y: int) -> float:
	return (float(BAYER[(y & 3) * 4 + (x & 3)]) + 0.5) / 16.0


## Picks a tone from a dark-to-light ramp. Only the middle band between two
## steps is dithered, so surfaces stay clean with a hint of texture.
static func shade(r: Array[Color], t: float, x: int, y: int) -> Color:
	var f := clampf(t, 0.0, 0.9999) * (r.size() - 1)
	var i := int(f)
	var frac := f - i
	if frac < 0.3:
		return r[i]
	if frac > 0.7:
		return r[i + 1]
	return r[i + 1] if (frac - 0.3) / 0.4 > bayer(x, y) else r[i]


## A lit, jagged-edged leaf mass: a sphere lit from the upper left with leafy
## texture noise. [param bias] lightens or darkens the whole clump.
static func blob(im: Image, cx: float, cy: float, rx: float, ry: float, r: Array[Color], seed_value: int, bias := 0.0, tex := 0.16, jag := 0.16) -> void:
	for y in range(floori(cy - ry - 1.0), ceili(cy + ry + 1.0) + 1):
		for x in range(floori(cx - rx - 1.0), ceili(cx + rx + 1.0) + 1):
			var dx := (x + 0.5 - cx) / rx
			var dy := (y + 0.5 - cy) / ry
			var d2 := dx * dx + dy * dy
			var edge := 1.0 + (K.hash2(x, y, seed_value) - 0.5) * jag * 2.0
			if d2 > edge * edge:
				continue
			var nz := sqrt(maxf(0.0, 1.0 - d2))
			var lam := dx * LIGHT.x + dy * LIGHT.y + nz * LIGHT.z
			var t := 0.5 + lam * 0.62 + (K.hash2(x, y, seed_value + 5) - 0.5) * tex * 2.0 + bias
			K.px(im, x, y, shade(r, t, x, y))


## Light and dark specks that read as individual leaves on a clump.
static func leaf_specks(im: Image, cx: float, cy: float, rx: float, ry: float, r: Array[Color], seed_value: int, count: int) -> void:
	for i in count:
		var a := K.hash2(i, 1, seed_value) * TAU
		var d := sqrt(K.hash2(i, 2, seed_value)) * 0.92
		var x := int(cx + cos(a) * d * rx)
		var y := int(cy + sin(a) * d * ry)
		var lit := (cos(a) * LIGHT.x + sin(a) * LIGHT.y) * -1.0
		if im.get_pixel(clampi(x, 0, im.get_width() - 1), clampi(y, 0, im.get_height() - 1)).a < 0.5:
			continue
		if lit > 0.05:
			K.px(im, x, y, r[r.size() - 1 - int(K.hash2(i, 3, seed_value) * 2.0)])
			K.px(im, x + 1, y, r[r.size() - 3])
		else:
			K.px(im, x, y, r[1 + int(K.hash2(i, 4, seed_value) * 2.0)])


## A 1 px rim around everything opaque, colored from the neighboring pixel
## (darkened and cooled) so foliage keeps dark green edges and stone dark gray.
static func rim(im: Image, amount := 0.55) -> void:
	var w := im.get_width()
	var h := im.get_height()
	var edge := {}
	for y in h:
		for x in w:
			if im.get_pixel(x, y).a > 0.5:
				continue
			var best := Color(0, 0, 0, 0)
			var found := false
			for d: Vector2i in [Vector2i.DOWN, Vector2i.RIGHT, Vector2i.LEFT, Vector2i.UP]:
				var n := Vector2i(x, y) + d
				if n.x >= 0 and n.y >= 0 and n.x < w and n.y < h and im.get_pixel(n.x, n.y).a > 0.5:
					best = im.get_pixel(n.x, n.y)
					found = true
					break
			if found:
				edge[Vector2i(x, y)] = best.darkened(amount).lerp(Color("1a1826"), 0.25)
	for p: Vector2i in edge:
		im.set_pixelv(p, edge[p])


## The x of a swaying trunk's center at row y.
static func trunk_x(cx: float, y: int, base_y: int, top_y: int, seed_value: int, sway: float, lean: float) -> float:
	var t := float(base_y - y) / maxf(1.0, float(base_y - top_y))
	return cx + sin(y * 0.07 + seed_value) * sway + lean * t


## A tapered bark column with a root flare, cylinder shading, and plated
## bark: dark cracks between plates that are offset column by column.
static func trunk(im: Image, cx: float, base_y: int, top_y: int, w_base: float, w_top: float, r: Array[Color], seed_value: int, sway := 1.0, lean := 0.0, plate := 6, flare := 3.0, fluted := false) -> void:
	for y in range(top_y, base_y + 1):
		var t := float(base_y - y) / maxf(1.0, float(base_y - top_y))
		var w := lerpf(w_base, w_top, pow(t, 0.8)) + flare * pow(1.0 - t, 7.0)
		var mx := trunk_x(cx, y, base_y, top_y, seed_value, sway, lean)
		var left := mx - w / 2.0
		for x in range(floori(left), ceili(left + w)):
			var u := (x + 0.5 - left) / w
			if u < 0.0 or u > 1.0:
				continue
			var lam := clampf(1.0 - absf(u - 0.3) * 1.5, 0.0, 1.0)
			var plate_row := int((y + K.hash2(x / 2, 3, seed_value) * plate) / plate)
			var pn := K.hash2(x / 2, plate_row, seed_value)
			var tone := lam * 0.72 + (pn - 0.5) * 0.4 + 0.06
			if fluted:
				var flute := (x + seed_value) % 3
				tone += 0.1 if flute == 0 else (-0.16 if flute == 2 else 0.0)
			var col := shade(r, tone, x, y)
			var ry := (y + int(K.hash2(x / 2, 0, seed_value) * plate)) % plate
			if not fluted:
				if ry == 0:
					col = r[0].lerp(r[1], 0.4)
				elif ry == 1 and u < 0.7:
					col = shade(r, tone + 0.18, x, y)
			if u > 0.86:
				col = col.darkened(0.16)
			K.px(im, x, y, col)


## A limb from (x0, y0) to (x1, y1) that thins along its length. A small
## bow in the middle keeps it from looking ruled.
static func limb(im: Image, x0: float, y0: float, x1: float, y1: float, w0: float, w1: float, r: Array[Color], seed_value: int, bow := 2.0) -> void:
	var length := Vector2(x1 - x0, y1 - y0).length()
	var steps := maxi(2, int(length * 2.0))
	var normal := Vector2(-(y1 - y0), x1 - x0).normalized()
	for s in steps + 1:
		var t := float(s) / steps
		var p := Vector2(lerpf(x0, x1, t), lerpf(y0, y1, t)) + normal * sin(t * PI) * bow
		var rad := lerpf(w0, w1, t) / 2.0
		for y in range(floori(p.y - rad - 1.0), ceili(p.y + rad + 1.0) + 1):
			for x in range(floori(p.x - rad - 1.0), ceili(p.x + rad + 1.0) + 1):
				var dx := x + 0.5 - p.x
				var dy := y + 0.5 - p.y
				var d := sqrt(dx * dx + dy * dy)
				if d > rad:
					continue
				var lam := 0.5 + (dx * LIGHT.x + dy * LIGHT.y) / maxf(rad, 0.8) * 0.5
				var n := K.hash2(x, y / 2, seed_value)
				K.px(im, x, y, shade(r, lam * 0.85 + (n - 0.5) * 0.3, x, y))


## A burst of long needles, like a ponderosa's pom-pom of needle bundles.
static func tuft(im: Image, cx: float, cy: float, rad: float, r: Array[Color], seed_value: int, bias := 0.0) -> void:
	# dark core so the burst has body
	for y in range(floori(cy - rad * 0.45), ceili(cy + rad * 0.45) + 1):
		for x in range(floori(cx - rad * 0.5), ceili(cx + rad * 0.5) + 1):
			var dx := (x + 0.5 - cx) / (rad * 0.5)
			var dy := (y + 0.5 - cy) / (rad * 0.42)
			if dx * dx + dy * dy <= 1.0:
				K.px(im, x, y, r[1 + int(bias < -0.1)])
	var count := int(rad * 3.6) + 6
	for i in count:
		var a := (float(i) + K.hash2(i, 1, seed_value) * 0.9) / count * TAU
		var dir := Vector2(cos(a), sin(a) * 0.82)
		var length := rad * (0.8 + 0.55 * K.hash2(i, 2, seed_value))
		var facing := clampf((-dir.x * 0.55 - dir.y * 0.65) * 0.5 + 0.5, 0.0, 1.0)
		var steps := int(length)
		for k in range(1, steps + 1):
			var p := Vector2(cx, cy) + dir * k
			var t := 0.24 + facing * 0.46 + float(k) / maxf(1.0, length) * 0.32 + (K.hash2(i, k, seed_value) - 0.5) * 0.14 + bias
			K.px(im, roundi(p.x), roundi(p.y), shade(r, t, roundi(p.x), roundi(p.y)))


## A frilly droop of foliage for cedars and firs: a flat lit ellipse.
static func fan(im: Image, cx: float, cy: float, rx: float, ry: float, r: Array[Color], seed_value: int, bias := 0.0) -> void:
	blob(im, cx, cy, rx, ry, r, seed_value, bias, 0.13, 0.12)


static func line(im: Image, x0: float, y0: float, x1: float, y1: float, col: Color) -> void:
	var steps := maxi(1, int(maxf(absf(x1 - x0), absf(y1 - y0))))
	for s in steps + 1:
		var t := float(s) / steps
		K.px(im, roundi(lerpf(x0, x1, t)), roundi(lerpf(y0, y1, t)), col)


static func quad(p0: Vector2, p1: Vector2, p2: Vector2, t: float) -> Vector2:
	return p0.lerp(p1, t).lerp(p1.lerp(p2, t), t)


func save_all() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DIR))
	var sheets := _all()
	for sprite_name: String in sheets:
		(sheets[sprite_name] as Image).save_png(ProjectSettings.globalize_path(DIR + sprite_name + ".png"))


func _all() -> Dictionary:
	var out := {}
	for i in 3:
		out["tree_ponderosa_" + "abc"[i]] = tree_ponderosa(i)
	for i in 2:
		out["tree_incense_cedar_" + "ab"[i]] = tree_cedar(i)
	for i in 3:
		out["tree_black_oak_" + "abc"[i]] = tree_oak(i)
	for i in 2:
		out["tree_dogwood_bloom_" + "ab"[i]] = tree_dogwood(i)
	out["tree_white_fir"] = tree_fir()
	for i in 2:
		out["tree_willow_" + "ab"[i]] = tree_willow(i)
	out["tree_snag"] = tree_snag()
	out["tree_apple_old"] = tree_apple()
	for i in 2:
		out["plant_tall_grass_" + "ab"[i]] = plant_grass(i)
	for i in 2:
		out["plant_fern_" + "ab"[i]] = plant_fern(i)
		out["plant_shrub_" + "ab"[i]] = plant_shrub(i)
	for i in 3:
		out["plant_wildflowers_" + "abc"[i]] = plant_wildflowers(i)
	out["plant_bracken"] = plant_bracken()
	out["plant_lupine"] = plant_lupine()
	out["plant_paintbrush"] = plant_paintbrush()
	out["plant_cornlily"] = plant_cornlily()
	out["plant_cattails"] = plant_cattails()
	out["plant_mushrooms"] = plant_mushrooms()
	out["plant_manzanita"] = plant_manzanita()
	out["rock_granite_a"] = rock(56, 40, 5101, 0.0, 0.6)
	out["rock_granite_b"] = rock(44, 32, 5102, 0.0, 0.4)
	out["rock_granite_c"] = rock(32, 26, 5103, 0.0, 0.5)
	out["rock_granite_d"] = rock(26, 20, 5104, 0.0, 0.3)
	out["rock_mossy_a"] = rock(40, 30, 5201, 0.7, 0.2)
	out["rock_mossy_b"] = rock(28, 22, 5202, 0.6, 0.1)
	out["rock_river_a"] = rock(26, 18, 5301, 0.0, 0.0, true, 0.6)
	out["rock_river_b"] = rock(20, 15, 5302, 0.0, 0.0, true, 0.5)
	out["rock_river_c"] = rock(15, 12, 5303, 0.0, 0.0, true, 0.4)
	out["log_fallen_a"] = log_fallen(64, 20, 5401)
	out["log_fallen_b"] = log_fallen(52, 18, 5402)
	out["log_stump"] = log_stump()
	out["garden_fountain"] = garden_fountain()
	out["garden_urn_a"] = garden_urn(0)
	out["garden_urn_b"] = garden_urn(1)
	out["garden_topiary"] = garden_topiary()
	out["garden_hedge_h"] = garden_hedge_h()
	out["garden_hedge_v"] = garden_hedge_v()
	out["garden_hedge_corner"] = garden_hedge_corner()
	out["garden_bench"] = garden_bench()
	for i in 3:
		out["garden_flowerbed_" + "abc"[i]] = garden_flowerbed(i)
	out["garden_wall_h"] = garden_wall_h()
	out["garden_wall_v"] = garden_wall_v()
	out["garden_wall_pillar"] = garden_wall_pillar()
	out["garden_arbor"] = garden_arbor()
	out["garden_sundial"] = garden_sundial()
	out["garden_table_umbrella"] = garden_table_umbrella()
	out["garden_steps"] = garden_steps()
	out["garden_birdbath"] = garden_birdbath()
	return out


# ------------------------------------------------------------------ trees

func tree_ponderosa(v: int) -> Image:
	var w := 64
	var h := 128
	var im := K.make(w, h)
	var seed_value := 100 + v * 17
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var cx := 32.0
	var base := h - 4
	var lean := [-1.6, 1.4, 0.2][v] as float
	var crown_top := 3 + v * 2
	var crown_bottom := 78 - v * 5
	var bark := ramp(BARK_PINE)
	var needles := ramp(PINE_NEEDLE)
	K.shadow(im, cx + 3.0, base + 0.5, 14.0, 3.2, 0.27)
	trunk(im, cx, base, crown_top + 6, 7.0, 2.6, bark, seed_value, 1.0, lean, 7, 3.6)
	# dead lower branches: short broken stubs
	for i in 4:
		var y := crown_bottom + 8 + i * 9 + int(rng.randf() * 4.0)
		var side := 1 if i % 2 == 0 else -1
		var sx := trunk_x(cx, y, base, crown_top + 6, seed_value, 1.0, lean)
		limb(im, sx, y, sx + side * (3.0 + rng.randf() * 2.0), y - 2.0, 2.0, 1.2, bark, seed_value + i, 0.0)
	# branches with needle tufts, painted low to high so upper ones sit behind
	var count := 9 + v
	var tufts: Array[Vector3] = []
	for i in count:
		var t := float(i) / float(count - 1)
		var y0 := lerpf(float(crown_bottom), float(crown_top + 10), t)
		var side := 1 if i % 2 == 0 else -1
		var length := 5.0 + (y0 - crown_top) * 0.16 + rng.randf() * 3.0
		var sx := trunk_x(cx, int(y0), base, crown_top + 6, seed_value, 1.0, lean)
		var tip := Vector2(sx + side * length, y0 - length * (0.25 + rng.randf() * 0.2))
		var mid := Vector2((sx + tip.x) / 2.0, (y0 + tip.y) / 2.0 + 2.5)
		for s in 12:
			var p := quad(Vector2(sx, y0), mid, tip, float(s) / 11.0)
			K.px(im, roundi(p.x), roundi(p.y), bark[2] if s < 8 else bark[1])
			if s < 5:
				K.px(im, roundi(p.x), roundi(p.y) + 1, bark[1])
		var rad := 5.0 + (y0 - crown_top) * 0.05 + rng.randf() * 1.6
		tufts.append(Vector3(tip.x, tip.y, rad))
		if length > 9.0:
			var q := quad(Vector2(sx, y0), mid, tip, 0.62)
			tufts.append(Vector3(q.x, q.y - 1.0, rad * 0.8))
	tufts.sort_custom(func(a: Vector3, b: Vector3) -> bool: return a.y < b.y)
	for i in tufts.size():
		var tf := tufts[i]
		var depth := -0.16 * (tf.y - crown_top) / float(crown_bottom - crown_top)
		tuft(im, tf.x, tf.y, tf.z, needles, seed_value + i * 3, depth)
	tuft(im, trunk_x(cx, crown_top + 6, base, crown_top + 6, seed_value, 1.0, lean), float(crown_top) + 3.0, 5.0, needles, seed_value + 99, 0.05)
	rim(im, 0.5)
	return im


func tree_cedar(v: int) -> Image:
	var w := 40
	var h := 112
	var im := K.make(w, h)
	var seed_value := 300 + v * 11
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var cx := 20.0 + (0.6 if v == 1 else -0.4)
	var base := h - 4
	var top := 4
	var bottom := 96 - v * 3
	var leaf := ramp(CEDAR_LEAF)
	K.shadow(im, cx + 3.0, base + 0.5, 13.0, 3.0, 0.27)
	trunk(im, cx, base, bottom - 30, 7.0, 4.4, ramp(BARK_CEDAR), seed_value, 0.5, 0.0, 9, 3.0, true)
	var y := float(top) + 2.0
	var tier := 0
	while y < bottom:
		var t := (y - top) / float(bottom - top)
		var hw := 2.0 + 14.5 * (1.0 - pow(1.0 - t, 1.55))
		hw *= 1.0 - 0.14 * smoothstep(0.86, 1.0, t)
		var n := maxi(1, int(hw / 3.6))
		for k in n:
			var bx := cx - hw + (float(k) + 0.5) / n * hw * 2.0 + (rng.randf() - 0.5) * 1.6
			var edge := absf(bx - cx) / maxf(hw, 1.0)
			var by := y + rng.randf() * 1.6 + edge * edge * 3.4
			var bias := -(bx - cx) / 15.0 * 0.16 - t * 0.08 - 0.07
			fan(im, bx, by, hw / n * 1.05 + 2.4, 3.4 - t * 0.2, leaf, seed_value + tier * 7 + k, bias)
		y += 4.4 + t * 0.9
		tier += 1
	# spire
	fan(im, cx, float(top) + 3.0, 2.2, 3.6, leaf, seed_value + 401, 0.1)
	leaf_specks(im, cx - 2.0, 48.0, 12.0, 36.0, leaf, seed_value + 21, 26)
	rim(im, 0.52)
	return im


func tree_fir() -> Image:
	var w := 36
	var h := 110
	var im := K.make(w, h)
	var seed_value := 512
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var cx := 18.0
	var base := h - 4
	var top := 3
	var bottom := 92
	var leaf := ramp(FIR_LEAF)
	K.shadow(im, cx + 3.0, base + 0.5, 12.0, 3.0, 0.27)
	trunk(im, cx, base, bottom - 22, 6.0, 4.0, ramp(BARK_FIR), seed_value, 0.4, 0.0, 7, 2.6)
	var y := float(top) + 3.0
	var tier := 0
	while y < bottom:
		var t := (y - top) / float(bottom - top)
		var hw := 1.5 + 14.6 * pow(t, 0.9)
		var n := maxi(1, int(hw / 3.2))
		for k in n:
			var f := (float(k) + 0.5) / n
			var bx := cx - hw + f * hw * 2.0 + (rng.randf() - 0.5) * 1.4
			var edge := absf(bx - cx) / maxf(hw, 1.0)
			var by := y + edge * edge * 2.6 + rng.randf() * 1.2
			var bias := -(bx - cx) / 15.0 * 0.15 - t * 0.06 - 0.06
			fan(im, bx, by, hw / n * 1.0 + 2.0, 2.8, leaf, seed_value + tier * 9 + k, bias)
		y += 3.8 + t * 0.8
		tier += 1
	# leader with a tapering spire
	for i in 7:
		fan(im, cx, float(top) + i * 1.0, 1.3 + i * 0.28, 2.0, leaf, seed_value + 601 + i, 0.08)
	leaf_specks(im, cx - 2.0, 50.0, 10.0, 38.0, leaf, seed_value + 31, 22)
	rim(im, 0.52)
	return im


func tree_oak(v: int) -> Image:
	var w := 92
	var h := 96
	var im := K.make(w, h)
	var seed_value := 700 + v * 23
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var cx := 46.0
	var base := h - 4
	var bark := ramp(BARK_OAK)
	var leaf := ramp(OAK_LEAF)
	var spread := [1.0, 0.86, 1.12][v] as float
	var lean := [-2.0, 2.4, 0.0][v] as float
	K.shadow(im, cx + 5.0, base + 0.5, 27.0 * spread, 5.0, 0.28)
	var fork_y := 62 + v * 3
	trunk(im, cx, base, fork_y, 10.0, 8.0, bark, seed_value, 1.4, lean, 5, 4.5)
	var fx := trunk_x(cx, fork_y, base, fork_y, seed_value, 1.4, lean)
	# main limbs: fork into a wide dome
	var limbs := [
		[-19.0 * spread, 38.0], [17.0 * spread, 36.0 + v * 3.0], [rng.randf_range(-5.0, 5.0), 28.0 + v * 4.0],
		[-28.0 * spread, 52.0], [28.0 * spread, 50.0 - v * 2.0],
	]
	for l: Array in limbs:
		limb(im, fx, float(fork_y) + 2.0, fx + float(l[0]), float(l[1]), 6.0, 2.2, bark, seed_value + int(l[1]), 3.0)
	# canopy clumps, sorted so lower ones overlap the ones behind them
	var clumps: Array[Vector3] = []
	var dome_cx := fx
	var dome_cy := 38.0 + v * 1.5
	var rx_dome := 33.0 * spread
	var ry_dome := 27.0 - v * 1.0
	for i in 40:
		var a := rng.randf() * TAU
		var d := 0.35 + 0.65 * sqrt(rng.randf())
		var bx := dome_cx + cos(a) * d * rx_dome
		var by := dome_cy + sin(a) * d * ry_dome * (0.9 if sin(a) > 0.0 else 1.0)
		clumps.append(Vector3(bx, by, 6.5 + rng.randf() * 5.5))
	clumps.sort_custom(func(a: Vector3, b: Vector3) -> bool: return a.y < b.y)
	# dark mass behind everything for depth
	blob(im, dome_cx, dome_cy + 3.0, rx_dome * 0.86, ry_dome * 0.78, leaf, seed_value + 1, -0.4, 0.1, 0.05)
	for i in clumps.size():
		var cl := clumps[i]
		var g := ((dome_cx - cl.x) * 0.5 + (dome_cy - cl.y) * 0.75) / 34.0
		var bias := clampf(g, -0.3, 0.16) - 0.38
		blob(im, cl.x, cl.y, cl.z, cl.z * 0.82, leaf, seed_value + 9 * i, bias, 0.17, 0.17)
		leaf_specks(im, cl.x, cl.y, cl.z, cl.z * 0.82, leaf, seed_value + i * 5, 7)
	# a low branch crossing in front of the trunk and a leaf drape under the crown
	limb(im, fx + 1.0, float(fork_y) + 4.0, fx + 12.0 * spread, float(fork_y) - 3.0, 4.0, 2.0, bark, seed_value + 77, 1.5)
	for i in 3:
		var lx := fx + (i - 1) * 15.0 * spread + rng.randf_range(-3.0, 3.0)
		blob(im, lx, dome_cy + ry_dome * 0.86, 7.0, 4.5, leaf, seed_value + 130 + i, -0.42, 0.15, 0.2)
	rim(im, 0.5)
	return im


static func dogwood_flower(im: Image, x: int, y: int, shadowed: bool) -> void:
	var lit := c("fdfdf6")
	var mid := c("e8ecea")
	var dark := c("bfc9d6")
	if shadowed:
		lit = mid
		mid = dark
		dark = c("9aa8bc")
	K.ellipse(im, x - 1.6, y, 1.7, 1.3, lit)
	K.ellipse(im, x, y - 1.6, 1.3, 1.7, lit)
	K.ellipse(im, x + 1.6, y, 1.7, 1.3, mid)
	K.ellipse(im, x, y + 1.6, 1.3, 1.7, dark)
	K.px(im, x, y, c("d8d88a"))
	K.px(im, x + 3, y, c("f0cfd4"))
	K.px(im, x, y + 3, c("e6c4cc"))


func tree_dogwood(v: int) -> Image:
	var w := 48
	var h := 56
	var im := K.make(w, h)
	var seed_value := 900 + v * 13
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var cx := 24.0
	var base := h - 3
	var leaf := ramp(["1c3a2e", "26482f", "345f34", "487a3a", "639441", "84ae4b"])
	K.shadow(im, cx + 3.0, base + 0.5, 16.0, 3.2, 0.26)
	trunk(im, cx, base, 30, 4.4, 2.6, ramp(BARK_OAK), seed_value, 1.0, [-1.5, 1.5][v] as float, 5, 2.6)
	limb(im, cx, 40.0, cx - 14.0, 30.0, 2.6, 1.4, ramp(BARK_OAK), seed_value + 1, 1.5)
	limb(im, cx, 36.0, cx + 14.0, 26.0, 2.6, 1.4, ramp(BARK_OAK), seed_value + 2, 1.5)
	# layered horizontal tiers, top first so lower tiers overlap
	var tiers := [[24.0, 15.0, 11.0, 4.6], [17.0, 21.0, 8.5, 4.4], [31.0, 23.0, 9.5, 4.4], [24.0, 32.0, 15.0, 5.4], [11.0, 36.0, 8.0, 4.0], [37.0, 37.0, 8.5, 4.0]]
	for i in tiers.size():
		var t: Array = tiers[i]
		var tcx: float = float(t[0]) + (v * 2.0 - 1.0) * (1.0 if i % 2 == 0 else -1.0)
		var tcy: float = float(t[1])
		blob(im, tcx, tcy + 1.0, float(t[2]), float(t[3]), leaf, seed_value + i * 11, -0.06, 0.16, 0.18)
		leaf_specks(im, tcx, tcy, float(t[2]), float(t[3]), leaf, seed_value + i * 3, 6)
		var n := int(float(t[2]) * 0.5)
		for k in n:
			var a := rng.randf() * TAU
			var d := sqrt(rng.randf()) * 0.9
			var fx := int(tcx + cos(a) * d * float(t[2]))
			var fy := int(tcy - 0.6 + sin(a) * d * float(t[3]) * 0.75)
			dogwood_flower(im, fx, fy, sin(a) > 0.55)
	rim(im, 0.5)
	return im


func tree_willow(v: int) -> Image:
	var w := 64
	var h := 64
	var im := K.make(w, h)
	var seed_value := 1100 + v * 31
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var cx := 32.0
	var base := h - 4
	var leaf := ramp(WILLOW_LEAF)
	var bark := ramp(BARK_OAK)
	K.shadow(im, cx + 3.0, base + 0.5, 24.0, 4.0, 0.26)
	trunk(im, cx - 2.0, base, 26, 8.0, 5.0, bark, seed_value, 1.4, [3.0, -3.0][v] as float, 5, 4.0)
	limb(im, cx, 32.0, cx - 16.0, 20.0, 4.0, 2.0, bark, seed_value + 1, 2.0)
	limb(im, cx, 30.0, cx + 15.0, 18.0, 4.0, 2.0, bark, seed_value + 2, 2.0)
	# crown mound
	blob(im, cx, 20.0, 27.0, 15.0, leaf, seed_value, -0.3, 0.14, 0.12)
	blob(im, cx - 12.0, 18.0, 13.0, 10.0, leaf, seed_value + 3, -0.1, 0.15, 0.14)
	blob(im, cx + 12.0, 19.0, 13.0, 10.0, leaf, seed_value + 4, -0.16, 0.15, 0.14)
	blob(im, cx, 12.0, 14.0, 9.0, leaf, seed_value + 5, -0.04, 0.15, 0.14)
	# hanging strands: inner ones dark, outer ones lit
	for layer in 3:
		for i in 46:
			var x0 := cx - 25.0 + rng.randf() * 50.0
			var dxn := (x0 - cx) / 27.0
			var y0 := 20.0 + 15.0 * sqrt(maxf(0.0, 1.0 - dxn * dxn)) - 3.0 + rng.randf() * 3.0
			var length := 8.0 + rng.randf() * (16.0 - layer * 2.0)
			var sway := rng.randf_range(-1.6, 1.6)
			var phase := rng.randf() * TAU
			for s in int(length):
				var t := float(s) / length
				var x := roundi(x0 + sin(t * 3.0 + phase) * 1.3 + sway * t)
				var y := roundi(y0 + s)
				var lam := (0.32 + layer * 0.16) + (1.0 - absf(dxn)) * 0.1 + t * 0.26 - dxn * 0.12 + (K.hash2(i, s, seed_value) - 0.5) * 0.12
				K.px(im, x, y, shade(leaf, lam, x, y))
	leaf_specks(im, cx, 20.0, 26.0, 14.0, leaf, seed_value + 55, 24)
	rim(im, 0.48)
	return im


func tree_snag() -> Image:
	var w := 24
	var h := 80
	var im := K.make(w, h)
	var seed_value := 1300
	var cx := 12.0
	var base := h - 3
	var bark := ramp(BARK_DEAD)
	K.shadow(im, cx + 2.0, base + 0.5, 9.0, 2.6, 0.26)
	trunk(im, cx, base, 12, 8.0, 4.0, bark, seed_value, 0.6, 1.0, 8, 3.0)
	# jagged broken top
	for i in 4:
		K.px(im, int(cx) - 1 + i, 11 - (i % 2) * 2, bark[3])
	K.px(im, int(cx), 8, bark[4])
	K.px(im, int(cx), 9, bark[3])
	limb(im, cx + 1.0, 38.0, cx + 9.0, 30.0, 2.2, 1.0, bark, seed_value + 1, 1.0)
	limb(im, cx - 1.0, 52.0, cx - 8.0, 47.0, 2.0, 0.9, bark, seed_value + 2, 1.0)
	limb(im, cx + 1.0, 24.0, cx + 6.0, 20.0, 1.8, 0.8, bark, seed_value + 3, 0.5)
	# woodpecker holes and lichen
	K.rect(im, int(cx) - 1, 30, 2, 3, bark[0])
	K.px(im, int(cx) - 1, 29, bark[1])
	K.rect(im, int(cx), 44, 2, 2, bark[0])
	for i in 6:
		K.px(im, int(cx) - 3 + int(K.hash2(i, 1, 5) * 5.0), 34 + i * 6, c("9db78a"))
		K.px(im, int(cx) - 3 + int(K.hash2(i, 2, 5) * 5.0), 36 + i * 6, c("d2b458"))
	rim(im, 0.5)
	return im


func tree_apple() -> Image:
	var w := 48
	var h := 56
	var im := K.make(w, h)
	var seed_value := 1500
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var cx := 24.0
	var base := h - 4
	var bark := ramp(BARK_OAK)
	var leaf := ramp(["1f4030", "2a5232", "3b6c38", "508640", "6ea24a", "8fbe58", "b3d874"])
	K.shadow(im, cx + 3.0, base + 0.5, 17.0, 3.4, 0.27)
	trunk(im, cx - 1.0, base, 34, 8.0, 5.0, bark, seed_value, 2.2, 2.0, 5, 3.6)
	limb(im, cx, 38.0, cx - 12.0, 24.0, 4.0, 2.2, bark, seed_value + 1, 2.5)
	limb(im, cx + 1.0, 36.0, cx + 13.0, 26.0, 4.0, 2.2, bark, seed_value + 2, -2.5)
	limb(im, cx, 34.0, cx + 1.0, 18.0, 3.4, 2.0, bark, seed_value + 3, 2.0)
	var clumps := [[24.0, 22.0, 13.0, 10.0], [12.0, 28.0, 9.0, 7.0], [36.0, 29.0, 9.0, 7.0], [16.0, 17.0, 8.5, 7.0], [32.0, 17.0, 8.5, 7.0], [24.0, 12.0, 8.0, 6.0]]
	for i in clumps.size():
		var cl: Array = clumps[i]
		var g := ((24.0 - float(cl[0])) * 0.5 + (22.0 - float(cl[1])) * 0.75) / 24.0
		blob(im, float(cl[0]), float(cl[1]), float(cl[2]), float(cl[3]), leaf, seed_value + i * 9, clampf(g, -0.25, 0.28) - 0.04, 0.16, 0.16)
		leaf_specks(im, float(cl[0]), float(cl[1]), float(cl[2]), float(cl[3]), leaf, seed_value + i, 6)
	for i in 16:
		var a := rng.randf() * TAU
		var d := sqrt(rng.randf()) * 0.85
		var ax := int(24.0 + cos(a) * d * 17.0)
		var ay := int(22.0 + sin(a) * d * 12.0)
		K.px(im, ax, ay, c("b3241e"))
		K.px(im, ax + 1, ay, c("e8503c"))
		K.px(im, ax, ay - 1, c("f58a6c") if i % 3 == 0 else c("d0382a"))
	rim(im, 0.5)
	return im


# ------------------------------------------------------------------ plants

const GRASS_GOLD := ["3f5a2c", "587632", "789238", "9cad44", "c2c25e", "e4d888"]
const FERN_LEAF := ["1b432b", "285a33", "37743a", "4f9040", "71ad4d", "98c962", "bde184"]
const BRACKEN_LEAF := ["2c5030", "3e6c36", "578a3c", "78a844", "9cc455", "c1de7a"]


## One grass blade from (x, y) up, bowing to one side.
static func blade(im: Image, x: float, y: float, height: float, bend: float, r: Array[Color], seed_value: int, head := false) -> void:
	var steps := int(height)
	var tip := Vector2.ZERO
	for s in steps:
		var t := float(s) / maxf(1.0, height - 1.0)
		var bx := x + bend * t * t
		var by := y - s
		var lam := 0.18 + t * 0.62 + (K.hash2(s, int(x), seed_value) - 0.5) * 0.12
		K.px(im, roundi(bx), roundi(by), shade(r, lam, roundi(bx), roundi(by)))
		tip = Vector2(bx, by)
	if head:
		for k in 3:
			K.px(im, roundi(tip.x), roundi(tip.y) - k, r[r.size() - 2 + (k % 2)])
		K.px(im, roundi(tip.x) - 1, roundi(tip.y) - 1, r[r.size() - 3])


## A broad lanceolate leaf along a curve, with a midrib, pleats, and the side
## facing the light brighter.
static func broad_leaf(im: Image, base: Vector2, mid: Vector2, tip: Vector2, half_w: float, r: Array[Color], seed_value: int) -> void:
	var steps := 30
	for s in steps + 1:
		var t := float(s) / steps
		var p := quad(base, mid, tip, t)
		var q := quad(base, mid, tip, minf(1.0, t + 0.04))
		var tangent := (q - p).normalized()
		if tangent == Vector2.ZERO:
			tangent = Vector2.UP
		var normal := Vector2(-tangent.y, tangent.x)
		if normal.x + normal.y > 0.0:
			normal = -normal
		var hw := half_w * pow(sin(clampf(t * 0.92 + 0.08, 0.0, 1.0) * PI), 0.75)
		var span := int(ceil(hw))
		for k in range(-span, span + 1):
			var u := float(k) / maxf(hw, 0.5)
			if absf(u) > 1.0:
				continue
			var pp := p + normal * k
			var tone := 0.42 + t * 0.2 + u * 0.22 - 0.06 * absf(u) + (0.05 if int(absf(k)) % 2 == 0 else -0.05) + (K.hash2(s, k, seed_value) - 0.5) * 0.06
			if k == 0:
				tone += 0.16
			K.px(im, roundi(pp.x), roundi(pp.y), shade(r, tone, roundi(pp.x), roundi(pp.y)))


func plant_grass(v: int) -> Image:
	var w := 24
	var h := 22
	var im := K.make(w, h)
	var rng := RandomNumberGenerator.new()
	rng.seed = 2100 + v * 7
	var r := ramp(GRASS_GOLD)
	K.shadow(im, w / 2.0 + 1.0, h - 2.0, 9.0, 2.0, 0.2)
	var n := 12 + v * 3
	for i in n:
		var x := 3.0 + rng.randf() * 18.0
		var hgt := 9.0 + rng.randf() * (11.0 if v == 0 else 9.0)
		var bend := (x - 12.0) * 0.32 + rng.randf_range(-3.0, 3.0)
		blade(im, x, h - 3.0, hgt, bend, r, 2100 + i, rng.randf() < (0.35 if v == 0 else 0.6))
	rim(im, 0.42)
	return im


static func frond(im: Image, base: Vector2, mid: Vector2, tip: Vector2, r: Array[Color], seed_value: int, leaf_len: float, spacing := 2) -> void:
	var steps := 26
	for s in steps + 1:
		var t := float(s) / steps
		var p := quad(base, mid, tip, t)
		var q := quad(base, mid, tip, minf(1.0, t + 0.04))
		var tangent := (q - p).normalized()
		if tangent == Vector2.ZERO:
			tangent = Vector2.UP
		var normal := Vector2(-tangent.y, tangent.x)
		var lam := 0.28 + t * 0.4 + clampf((-p.x + base.x) * 0.01 + (base.y - p.y) * 0.006, -0.1, 0.16)
		K.px(im, roundi(p.x), roundi(p.y), shade(r, lam - 0.12, roundi(p.x), roundi(p.y)))
		if s % spacing == 0 and t > 0.12:
			var ll := leaf_len * pow(sin(clampf(t * 0.94 + 0.03, 0.0, 1.0) * PI), 0.6) + 0.7
			for side in [-1, 1]:
				for k in range(1, int(ll) + 1):
					var lp: Vector2 = p + normal * (side * k) + tangent * (k * 0.55)
					var tone := lam + (0.14 if side == 1 else 0.0) + (K.hash2(s, k * side, seed_value) - 0.5) * 0.12 - float(k) / ll * 0.1
					K.px(im, roundi(lp.x), roundi(lp.y), shade(r, tone, roundi(lp.x), roundi(lp.y)))


func plant_fern(v: int) -> Image:
	var w := 40
	var h := 32
	var im := K.make(w, h)
	var rng := RandomNumberGenerator.new()
	rng.seed = 2300 + v * 11
	var r := ramp(FERN_LEAF)
	K.shadow(im, w / 2.0 + 1.0, h - 2.0, 11.0, 2.4, 0.2)
	var base := Vector2(w / 2.0, h - 3.0)
	var n := 6 + v
	# back fronds first, so the ones leaning toward the viewer sit in front
	var fronds: Array[Vector3] = []
	for i in n:
		var a := lerpf(-1.25, 1.25, (float(i) + rng.randf() * 0.6) / float(n))
		fronds.append(Vector3(a, 14.0 + rng.randf() * 5.0, rng.randf()))
	fronds.sort_custom(func(p: Vector3, q: Vector3) -> bool: return absf(p.x) > absf(q.x))
	for i in fronds.size():
		var f := fronds[i]
		var a := f.x
		var reach := f.y
		var up := reach * 1.25 - absf(a) * 5.0
		var out := sin(a) * (reach * 0.8)
		var ctrl := base + Vector2(out * 0.45, -up * 1.75)
		var tip := base + Vector2(out * 1.35, -up * 0.3 + absf(a) * 5.0)
		frond(im, base, ctrl, tip, r, 2300 + i, 3.4 - v * 0.3, 2)
	rim(im, 0.42)
	return im


func plant_bracken() -> Image:
	var w := 34
	var h := 30
	var im := K.make(w, h)
	var rng := RandomNumberGenerator.new()
	rng.seed = 2500
	var r := ramp(BRACKEN_LEAF)
	K.shadow(im, w / 2.0 + 1.0, h - 2.0, 12.0, 2.6, 0.2)
	var stalks := [[7.0, 12.0], [26.0, 11.0], [14.0, 7.0], [21.0, 8.0], [17.0, 13.0]]
	# outer stalks first so the center ones overlap them
	for i in stalks.size():
		var sx: float = stalks[i][0]
		var top: float = stalks[i][1]
		var base := Vector2(17.0 + (sx - 17.0) * 0.55, h - 3.0)
		var head := Vector2(sx, top + 5.0)
		for s in 24:
			var p := base.lerp(head, float(s) / 23.0)
			K.px(im, roundi(p.x), roundi(p.y), r[2] if s % 2 == 0 else r[1])
		# a three-lobed, hand-shaped frond
		for lobe in [[-1.15, 8.0], [1.15, 8.0], [0.0, 9.5]]:
			var a: float = lobe[0]
			var length: float = lobe[1]
			var tip := head + Vector2(sin(a) * length, -cos(a) * length * 0.62 - 1.0)
			var mid := head + Vector2(sin(a) * length * 0.45, -cos(a) * length * 0.55 + 1.0)
			broad_leaf(im, head, mid, tip, 2.7, r, 2500 + i * 3)
	rim(im, 0.42)
	return im


func plant_shrub(v: int) -> Image:
	var w := 30
	var h := 22
	var im := K.make(w, h)
	var rng := RandomNumberGenerator.new()
	rng.seed = 2700 + v * 5
	var leaf := ramp(["1d3f2e", "28502f", "3a6b37", "508540", "6ba04a", "8dbb58", "b0d474"]) if v == 0 else ramp(["24443a", "30594a", "417458", "578e63", "72a874", "93c184"])
	K.shadow(im, w / 2.0 + 1.0, h - 2.0, 12.0, 2.6, 0.24)
	var clumps := [[15.0, 11.0, 9.5, 7.5], [8.0, 13.0, 6.5, 5.5], [22.0, 13.0, 6.5, 5.5], [14.0, 7.0, 6.0, 5.0], [19.0, 9.0, 5.5, 4.5]]
	for i in clumps.size():
		var cl: Array = clumps[i]
		var g := (15.0 - float(cl[0])) * 0.02 + (11.0 - float(cl[1])) * 0.03
		blob(im, float(cl[0]), float(cl[1]), float(cl[2]), float(cl[3]), leaf, 2700 + i * 6, clampf(g, -0.2, 0.22) - 0.04, 0.17, 0.2)
		leaf_specks(im, float(cl[0]), float(cl[1]), float(cl[2]), float(cl[3]), leaf, 2700 + i, 5)
	if v == 1:
		for i in 14:
			var a := rng.randf() * TAU
			var d := sqrt(rng.randf()) * 0.85
			var fx := int(15.0 + cos(a) * d * 11.0)
			var fy := int(10.0 + sin(a) * d * 7.0)
			K.px(im, fx, fy, c("f28fb0"))
			K.px(im, fx + 1, fy, c("ffc8d8"))
			K.px(im, fx, fy + 1, c("d8608a"))
	rim(im, 0.5)
	return im


func plant_lupine() -> Image:
	var w := 24
	var h := 30
	var im := K.make(w, h)
	var rng := RandomNumberGenerator.new()
	rng.seed = 2900
	var leaf := ramp(FERN_LEAF)
	K.shadow(im, w / 2.0, h - 2.0, 8.0, 2.0, 0.2)
	# palmate leaves at the base
	for i in 7:
		var a := lerpf(-1.3, 1.3, float(i) / 6.0)
		for k in range(1, 8):
			var x := 12.0 + sin(a) * k * 1.1
			var y := h - 3.0 - cos(a) * k * 0.55 - k * 0.15
			K.px(im, roundi(x), roundi(y), shade(leaf, 0.3 + float(k) / 8.0 * 0.4 + (0.1 if a < 0.0 else 0.0), roundi(x), roundi(y)))
	var florets := ramp(["4a3591", "5b45a8", "7059c2", "8d7ad8", "adaaee", "d8d4fa"])
	for s in 4:
		var sx := 6.0 + s * 4.0 + rng.randf_range(-1.0, 1.0)
		var top := 4.0 + rng.randf() * 6.0
		for y in range(int(top), h - 4):
			K.px(im, roundi(sx), y, leaf[2])
		for y in range(int(top), int(top) + 15, 2):
			var t := float(y - int(top)) / 14.0
			var fw := 1 + int((1.0 - t) * 0.0)
			for dx in [-1, 0, 1]:
				if (y / 2 + dx) % 2 == 0 or dx == 0:
					K.px(im, roundi(sx) + dx, y, shade(florets, 0.9 - t * 0.8 - dx * 0.06 + (K.hash2(s, y, 5) - 0.5) * 0.2, roundi(sx) + dx, y))
			K.px(im, roundi(sx) - 1, y + 1, florets[1])
			K.px(im, roundi(sx) + 1, y + 1, florets[2])
		K.px(im, roundi(sx), int(top) - 1, florets[5])
	rim(im, 0.42)
	return im


func plant_paintbrush() -> Image:
	var w := 24
	var h := 28
	var im := K.make(w, h)
	var rng := RandomNumberGenerator.new()
	rng.seed = 3100
	var leaf := ramp(FERN_LEAF)
	var bract := ramp(["8e1a1a", "b62a1e", "d84420", "ee6428", "f6903a", "fbc060"])
	K.shadow(im, w / 2.0, h - 2.0, 9.0, 2.0, 0.2)
	var xs := [5.0, 11.0, 17.0]
	for s in 3:
		var sx: float = xs[s] + rng.randf_range(-0.8, 0.8)
		var top := 6 + int(rng.randf() * 6.0) + (s % 2) * 3
		for y in range(top + 5, h - 3):
			K.px(im, roundi(sx) + int(sin(y * 0.5 + s) * 0.9), y, leaf[3])
			K.px(im, roundi(sx) + 1 + int(sin(y * 0.5 + s) * 0.9), y, leaf[1])
		for k in 3:
			var y := top + 9 + k * 4
			K.px(im, roundi(sx) - 1, y, leaf[4])
			K.px(im, roundi(sx) - 2, y - 1, leaf[5])
			K.px(im, roundi(sx) + 2, y + 1, leaf[2])
		# the flame-shaped bract head
		for k in 9:
			var y := top + k
			var half := 1 + int(sin(float(k) / 8.0 * PI * 0.85 + 0.35) * 1.9)
			for dx in range(-half, half + 1):
				var jag := K.hash2(s * 7 + dx, k, 5) > 0.7 and absi(dx) == half
				if jag:
					continue
				var t := 0.28 + float(8 - k) / 8.0 * 0.35 - dx * 0.12 + (K.hash2(s, k * 3 + dx, 9) - 0.5) * 0.28
				K.px(im, roundi(sx) + dx, y, shade(bract, t, roundi(sx) + dx, y))
		K.px(im, roundi(sx), top - 1, bract[4])
		K.px(im, roundi(sx) - 1, top, bract[5])
	rim(im, 0.4)
	return im


func plant_wildflowers(v: int) -> Image:
	var w := 32
	var h := 18
	var im := K.make(w, h)
	var rng := RandomNumberGenerator.new()
	rng.seed = 3300 + v * 19
	var grass := ramp(GRASS_GOLD)
	var leaf := ramp(FERN_LEAF)
	for i in 8:
		blade(im, 3.0 + rng.randf() * 26.0, h - 2.0, 4.0 + rng.randf() * 5.0, rng.randf_range(-2.0, 2.0), grass, 3300 + i, false)
	for i in 12:
		var x := 3 + int(rng.randf() * 26.0)
		var top := 3 + int(rng.randf() * 7.0)
		for y in range(top + 1, h - 2):
			K.px(im, x, y, leaf[2 + (y % 2)])
		match v:
			0: # lupine and yarrow
				if i % 3 == 0:
					K.px(im, x - 1, top, c("ffffff"))
					K.hline(im, x - 2, top + 1, 5, c("f2efe0"))
					K.px(im, x, top - 1, c("fbf8ea"))
					K.hline(im, x - 2, top + 2, 5, c("d8d2b8"))
				else:
					K.rect(im, x - 1, top, 3, 4, c("7a5fc9"))
					K.px(im, x, top - 1, c("b6a6ee"))
					K.px(im, x - 1, top + 1, c("a692e6"))
					K.px(im, x + 1, top + 3, c("4a3591"))
			1: # poppies
				K.rect(im, x - 1, top, 3, 2, c("f28a1c"))
				K.hline(im, x - 2, top + 1, 5, c("f6a428"))
				K.px(im, x, top, c("ffd24a"))
				K.px(im, x + 1, top + 1, c("d0660e"))
				if i % 4 == 0:
					K.px(im, x, top - 2, c("7fb2f0"))
					K.px(im, x - 1, top - 1, c("a4ccf8"))
					K.px(im, x + 1, top - 1, c("5a92d8"))
			2: # shooting stars and yarrow
				if i % 3 != 0:
					K.px(im, x, top, c("3a2a3a"))
					K.vline(im, x - 1, top - 3, 3, c("d84a9c"))
					K.vline(im, x + 1, top - 3, 3, c("b83a86"))
					K.px(im, x, top - 2, c("f8a0cc"))
					K.px(im, x, top - 3, c("ffd0e4"))
					K.px(im, x, top + 1, c("f0d048"))
				else:
					K.hline(im, x - 2, top, 5, c("fbf8ea"))
					K.hline(im, x - 1, top - 1, 3, c("ffffff"))
					K.hline(im, x - 2, top + 1, 5, c("d8d2b8"))
	return im


func plant_cornlily() -> Image:
	var w := 30
	var h := 38
	var im := K.make(w, h)
	var leaf := ramp(["1f4a2c", "2e6234", "417c3c", "5c9a45", "7db855", "a2d472", "c8ec96"])
	K.shadow(im, w / 2.0 + 1.0, h - 2.0, 11.0, 2.4, 0.22)
	var base := Vector2(15.0, h - 3.0)
	var specs := [[-1.3, 15.0], [1.25, 14.0], [-0.8, 18.0], [0.75, 17.0], [-0.3, 20.0], [0.3, 17.0]]
	# flower spike behind the leaves
	for y in range(3, 26):
		K.px(im, 15, y, leaf[3])
	var florets := ramp(["7a9a58", "a6c274", "cfe19c", "eef6c8"])
	for y in range(3, 17):
		var lim := 2 if y > 6 else 1
		for dx in range(-lim, lim + 1):
			if K.hash2(dx + 4, y, 12) > 0.22:
				K.px(im, 15 + dx, y, shade(florets, 0.9 - float(y - 3) / 14.0 * 0.5 - dx * 0.16 + (K.hash2(dx, y, 3) - 0.5) * 0.3, 15 + dx, y))
	for i in specs.size():
		var a: float = specs[i][0]
		var length: float = specs[i][1]
		var tip := base + Vector2(sin(a) * length * 1.1, -cos(a) * length * 0.7 + absf(a) * 4.0)
		var mid := base + Vector2(sin(a) * length * 0.35, -cos(a) * length * 0.95)
		broad_leaf(im, base, mid, tip, 2.9, leaf, 3500 + i)
	rim(im, 0.42)
	return im


func plant_cattails() -> Image:
	var w := 26
	var h := 36
	var im := K.make(w, h)
	var rng := RandomNumberGenerator.new()
	rng.seed = 3700
	var leaf := ramp(["2a4a2c", "3c6432", "56823a", "78a244", "9cc258"])
	K.shadow(im, w / 2.0, h - 2.0, 9.0, 2.0, 0.2)
	for i in 9:
		var x := 3.0 + i * 2.4 + rng.randf_range(-0.6, 0.6)
		var hgt := 20.0 + rng.randf() * 11.0
		blade(im, x, h - 3.0, hgt, (x - 13.0) * 0.35 + rng.randf_range(-2.0, 2.0), leaf, 3700 + i, false)
	for i in 4:
		var x := 6 + i * 4
		var top := 6 + int(rng.randf() * 7.0)
		for y in range(top, h - 4):
			K.px(im, x + (1 if y < top + 4 else 0) * 0, y, leaf[2])
		K.rect(im, x - 1, top, 3, 7, c("6a3e22"))
		K.vline(im, x - 1, top, 7, c("9a6234"))
		K.vline(im, x + 1, top, 7, c("452614"))
		K.px(im, x, top - 1, c("a89050"))
		K.px(im, x, top - 2, c("c8b070"))
		K.px(im, x, top + 7, c("8a7a48"))
	rim(im, 0.42)
	return im


func plant_mushrooms() -> Image:
	var w := 18
	var h := 14
	var im := K.make(w, h)
	K.shadow(im, w / 2.0, h - 2.0, 7.0, 1.8, 0.22)
	var caps := [[5, 7, 4, 3], [11, 6, 5, 3], [9, 10, 3, 2]]
	for cap: Array in caps:
		var cx: int = cap[0]
		var top: int = cap[1]
		K.rect(im, cx - 1, top + 2, 2, 5, c("e8dcc4"))
		K.vline(im, cx + 1, top + 2, 5, c("b8a88a"))
		K.ellipse(im, cx, top + 1.0, float(cap[2]), float(cap[3]), c("a8542c"))
		K.ellipse(im, cx - 1.0, top + 0.4, float(cap[2]) * 0.6, float(cap[3]) * 0.55, c("d07c44"))
		K.px(im, cx - 2, top, c("f0b070"))
		K.px(im, cx + 1, top + 2, c("7a3a1e"))
		K.px(im, cx + 1, top, c("f4e6cc"))
	rim(im, 0.5)
	return im


func plant_manzanita() -> Image:
	var w := 36
	var h := 30
	var im := K.make(w, h)
	var rng := RandomNumberGenerator.new()
	rng.seed = 3900
	var bark := ramp(["3a1a14", "5c2a1e", "7f3d2a", "a05638", "c2734a", "dc9466"])
	var leaf := ramp(["25402e", "31573a", "436f45", "588a52", "72a566", "96c17e"])
	K.shadow(im, w / 2.0 + 1.0, h - 2.0, 14.0, 2.6, 0.24)
	# twisting red stems fan out of the ground
	for i in 4:
		var x1 := 18.0 + (i - 1.5) * 7.0 + rng.randf_range(-2.0, 2.0)
		limb(im, 18.0 + (i - 1.5) * 2.0, h - 3.0, x1, 9.0 + rng.randf() * 6.0, 1.9, 1.0, bark, 3900 + i, rng.randf_range(-3.5, 3.5))
	# glossy leaf clusters on the outer stems
	var clumps: Array[Vector3] = []
	for i in 14:
		var a := rng.randf() * TAU
		var d := 0.2 + sqrt(rng.randf()) * 0.8
		clumps.append(Vector3(18.0 + cos(a) * d * 15.0, 14.0 + sin(a) * d * 8.5, 3.4 + rng.randf() * 2.4))
	clumps.sort_custom(func(p: Vector3, q: Vector3) -> bool: return p.y < q.y)
	for i in clumps.size():
		var cl := clumps[i]
		var g := (18.0 - cl.x) * 0.02 + (12.0 - cl.y) * 0.03
		blob(im, cl.x, cl.y, cl.z, cl.z * 0.78, leaf, 3900 + i * 3, clampf(g, -0.2, 0.25), 0.18, 0.22)
		leaf_specks(im, cl.x, cl.y, cl.z, cl.z * 0.78, leaf, 3900 + i, 3)
	for i in 16:
		var a := rng.randf() * TAU
		var d := sqrt(rng.randf()) * 0.9
		var fx := int(18.0 + cos(a) * d * 15.0)
		var fy := int(14.0 + sin(a) * d * 8.5)
		if i % 2 == 0:
			K.px(im, fx, fy, c("b02a22"))
			K.px(im, fx + 1, fy, c("e05a3c"))
		else:
			K.px(im, fx, fy, c("f8dce0"))
			K.px(im, fx, fy + 1, c("dca0b0"))
	rim(im, 0.5)
	return im



# ------------------------------------------------------------------ rocks and logs

## Smooth 1-D noise from a few sines, period-free.
static func wobble(t: float, seed_value: int) -> float:
	var p1 := K.hash2(seed_value, 1, 3) * TAU
	var p2 := K.hash2(seed_value, 2, 3) * TAU
	var p3 := K.hash2(seed_value, 3, 3) * TAU
	return (sin(t * 1.7 + p1) * 0.5 + sin(t * 3.1 + p2) * 0.3 + sin(t * 5.3 + p3) * 0.2)


## A granite boulder: a lumpy dome broken into facets by cracks, salt-and-
## pepper speckle, lichen on the lit top, and optional moss. [param flat]
## squashes it; [param wet] adds a water-worn sheen and foam at the base.
func rock(w: int, h: int, seed_value: int, moss := 0.0, lichen := 0.5, wet := false, cracks := 1.0) -> Image:
	var im := K.make(w, h)
	var gr := ramp(GRANITE)
	var base_y := h - 4
	var rx := (w - 4) / 2.0
	var ry := float(h - 6)
	var cx := w / 2.0
	K.shadow(im, cx + 2.0, base_y + 1.0, rx * 0.98, 2.6 + h * 0.03, 0.28)
	# jittered cell centers for the facets
	var cell := 9.0 + w * 0.06
	var lumps := []
	for y in range(-1, int(ry / cell) + 3):
		for x in range(-1, int(w / cell) + 2):
			lumps.append(Vector3((x + K.hash2(x, y, seed_value)) * cell, (y + K.hash2(x, y, seed_value + 1)) * cell, K.hash2(x, y, seed_value + 2) - 0.5))
	for y in range(0, base_y + 1):
		for x in range(0, w):
			var dx := (x + 0.5 - cx) / rx
			var top_y := base_y - ry * pow(maxf(0.0, 1.0 - pow(absf(dx), 2.2)), 1.0 / 2.2) * (1.0 + wobble(x * 0.12, seed_value) * 0.14)
			if y < top_y or absf(dx) > 1.0:
				continue
			# dome normal
			var hy := (y - base_y + ry * 0.78) / (ry * 0.9)
			var d2 := dx * dx + hy * hy
			var nz := sqrt(maxf(0.0, 1.0 - minf(d2, 1.0)))
			var lam := dx * LIGHT.x + hy * LIGHT.y + nz * LIGHT.z
			# facet: nearest and second-nearest cell centers
			var d1 := 1e9
			var d1t := 0.0
			var d2c := 1e9
			for lp: Vector3 in lumps:
				var dd := (lp.x - x) * (lp.x - x) + (lp.y - (y - (base_y - ry))) * (lp.y - (y - (base_y - ry)))
				if dd < d1:
					d2c = d1
					d1 = dd
					d1t = lp.z
				elif dd < d2c:
					d2c = dd
			var edge := sqrt(d2c) - sqrt(d1)
			var t := 0.46 + lam * 0.36 + d1t * 0.3
			var col := shade(gr, t + (K.hash2(x, y, seed_value + 9) - 0.5) * 0.1, x, y)
			var sp := K.hash2(x, y, seed_value + 4)
			if sp > 0.955:
				col = gr[maxi(0, int(t * 5.0) - 2)]
			elif sp < 0.03:
				col = gr[mini(gr.size() - 1, int(t * 6.0) + 2)]
			if edge < 0.9 * cracks and K.hash2(x / 3, y / 3, seed_value + 6) > 0.35:
				col = gr[0].lerp(gr[1], 0.5)
			elif edge < 1.7 * cracks and t > 0.4 and K.hash2(x, y, seed_value + 12) > 0.55:
				col = shade(gr, t + 0.2, x, y)
			# lichen on the lit side, moss in the lee
			var ln := wobble(x * 0.5 + y * 0.31, seed_value + 20) + wobble(y * 0.7, seed_value + 21) * 0.5
			if lichen > 0.0 and lam > 0.25 and ln > 0.85 - lichen * 0.5 and K.hash2(x, y, seed_value + 30) > 0.35:
				col = c("b4bf80") if K.hash2(x, y, seed_value + 31) > 0.3 else c("cfb060")
			if moss > 0.0 and (lam > 0.45 or y > base_y - 4) and wobble(x * 0.42 + y * 0.2, seed_value + 40) > 0.4 - moss * 0.9:
				col = shade(ramp(["25402e", "31573a", "436f45", "588a52", "72a566", "96c17e"]), 0.35 + lam * 0.4 + (K.hash2(x, y, 2) - 0.5) * 0.25, x, y)
			if y >= base_y - 1:
				col = col.darkened(0.3)
			if wet:
				col = col.lerp(c("4a6878"), 0.22)
			K.px(im, x, y, col)
	if wet:
		# sheen and foam
		for i in 4:
			var hx := int(cx - rx * 0.4) + i * 2
			var hy := int(base_y - ry * 0.7) + int(K.hash2(i, 1, seed_value) * 3.0) + (i % 2)
			K.px(im, hx, hy, c("f4fbff"))
			K.px(im, hx + 1, hy + 1, c("c8e4f0"))
		for x in range(1, w - 1):
			if K.hash2(x, 5, seed_value) > 0.3:
				K.px(im, x, base_y + 1, Color(0.92, 0.97, 1.0, 0.75))
			if K.hash2(x, 6, seed_value) > 0.6:
				K.px(im, x, base_y + 2, Color(0.85, 0.93, 0.98, 0.5))
	rim(im, 0.55)
	return im


## A fallen log lying left-right, with a cut end at the left, a rough break
## at the right, bark fissures, branch stubs, and moss on top.
func log_fallen(w: int, h: int, seed_value: int) -> Image:
	var im := K.make(w, h)
	var bark := ramp(["3a2a20", "54402f", "6f563e", "8c7050", "a88c68", "c4a882"])
	var rad := (h - 6) / 2.0
	var yc := h - 4 - rad
	K.shadow(im, w / 2.0 + 2.0, h - 3.0, w / 2.0 - 2.0, 2.6, 0.26)
	var x0 := 6
	var x1 := w - 3
	for x in range(x0, x1):
		var wob := wobble(x * 0.18, seed_value) * 0.9
		var r_here := rad + wob * 0.6
		if x > x1 - 5:
			r_here -= float(x - (x1 - 5)) * 0.45 * K.hash2(x, 3, seed_value)
		for y in range(floori(yc - r_here), ceili(yc + r_here) + 1):
			var v := (y + 0.5 - yc) / r_here
			if absf(v) > 1.0:
				continue
			var lam := 1.0 - (v + 1.0) / 2.0
			var t := 0.2 + lam * 0.6
			var fissure := K.hash2(x / 5, y, seed_value) > 0.9 and K.hash2(x, y / 2, seed_value + 3) > 0.5
			var col := shade(bark, t + (K.hash2(x, y / 2, seed_value + 1) - 0.5) * 0.24, x, y)
			if fissure:
				col = bark[0]
			elif K.hash2(x / 3, y, seed_value + 6) > 0.86:
				col = shade(bark, t + 0.22, x, y)
			K.px(im, x, y, col)
	# moss on top
	var moss_r := ramp(["25402e", "31573a", "436f45", "588a52", "72a566", "96c17e"])
	for x in range(x0 + 4, x1 - 2):
		var m := wobble(x * 0.31, seed_value + 50)
		if m > 0.05:
			var depth := 1 + int((m - 0.05) * 5.0)
			for k in depth:
				var y := int(yc - rad) + k + int(wobble(x * 0.7, seed_value + 51) * 0.6)
				K.px(im, x, y, shade(moss_r, 0.78 - float(k) * 0.16 + (K.hash2(x, k, 4) - 0.5) * 0.25, x, y))
	# branch stubs on the top
	for i in 2:
		var bx := x0 + 10 + int(K.hash2(i, 7, seed_value) * float(w - 30)) + i * 14
		var by := int(yc - rad)
		K.rect(im, bx, by - 3, 3, 4, bark[2])
		K.vline(im, bx, by - 3, 4, bark[4])
		K.hline(im, bx, by - 4, 3, c("d8b880"))
	# cut end: rings
	var e_rx := 3.4
	K.ellipse(im, x0, yc, e_rx, rad, c("8a5c34"))
	K.ellipse(im, x0 - 0.3, yc, e_rx - 0.9, rad - 1.1, c("c89a5c"))
	K.ellipse(im, x0 - 0.4, yc, e_rx - 1.8, rad - 2.6, c("dcb87a"))
	K.ellipse(im, x0 - 0.4, yc, e_rx - 2.6, rad - 4.0, c("b08048"))
	K.px(im, x0 - 1, int(yc), c("6a4224"))
	K.px(im, x0, int(yc) - 2, c("f0d8a0"))
	rim(im, 0.5)
	return im


func log_stump() -> Image:
	var w := 26
	var h := 22
	var im := K.make(w, h)
	var bark := ramp(BARK_OAK)
	var cx := w / 2.0
	K.shadow(im, cx + 2.0, h - 2.5, 11.0, 2.6, 0.26)
	# roots flaring
	for i in 5:
		var side := -1 if i % 2 == 0 else 1
		var ang := (0.3 + i * 0.2) * side
		limb(im, cx + side * 3.0, h - 6.0, cx + side * (9.0 + i * 0.6), h - 3.0, 4.0, 1.5, bark, 4000 + i, 0.5)
	for y in range(6, h - 3):
		var w_here := 8.5 + pow(float(y - 6) / float(h - 9), 4.0) * 2.5
		for x in range(int(cx - w_here), int(cx + w_here) + 1):
			var u := (x + 0.5 - cx) / w_here
			if absf(u) > 1.0:
				continue
			var lam := 0.5 - u * 0.6
			var t := 0.22 + lam * 0.6 + (K.hash2(x / 2, y, 41) - 0.5) * 0.28
			var col := shade(bark, t, x, y)
			if K.hash2(x / 2, y / 3, 44) > 0.8:
				col = bark[0]
			K.px(im, x, y, col)
	K.ellipse(im, cx, 6.0, 8.8, 4.0, c("8a5c34"))
	K.ellipse(im, cx - 0.2, 5.6, 7.8, 3.3, c("c89a5c"))
	K.ellipse(im, cx - 0.4, 5.6, 5.8, 2.5, c("dcb87a"))
	K.ellipse(im, cx - 0.4, 5.6, 3.8, 1.6, c("b08048"))
	K.ellipse(im, cx - 0.4, 5.6, 1.6, 0.8, c("dcb87a"))
	K.px(im, int(cx) - 4, 4, c("f0d8a0"))
	K.px(im, int(cx) - 3, 4, c("f0d8a0"))
	for i in 5:
		K.px(im, int(cx) - 7 + i * 3, 8, c("5a8a4a"))
		K.px(im, int(cx) - 7 + i * 3, 9, c("7aa85a"))
	rim(im, 0.5)
	return im


# ------------------------------------------------------------------ garden

const WOOD_WARM := ["2c1e16", "4a3424", "6a4c34", "8a6844", "a88458", "c8a678"]
const WATER := ["245a78", "2f7896", "4494ac", "62b0c0", "8acad4", "bfe6ec", "f2fbfc"]
const HEDGE_LEAF := ["15301f", "1e3f27", "2a5230", "386a38", "4b8340", "649c48", "82b658"]


## Coursed granite blocks filling a rectangle. Joints wrap around
## [param wrap_w], so a piece [param wrap_w] wide tiles left to right.
static func blocks(im: Image, x: int, y: int, w: int, h: int, gr: Array[Color], seed_value: int, course := 5, tone_base := 0.5, wrap_w := -1) -> void:
	var ww := w if wrap_w < 0 else wrap_w
	var rows := int(ceil(float(h) / course))
	for row in rows:
		var ry := y + row * course
		var rh := mini(course, y + h - ry)
		var off := int(K.hash2(row, 1, seed_value) * ww)
		var cuts: Array[int] = [0]
		var pos := 0
		while pos < ww:
			pos += 7 + int(K.hash2(row, pos, seed_value + 2) * 8.0)
			if pos > ww - 5:
				pos = ww
			cuts.append(pos)
		for i in cuts.size() - 1:
			var tone := tone_base + (K.hash2(row, i, seed_value + 3) - 0.5) * 0.4
			for bx in range(cuts[i], cuts[i + 1]):
				var xx := x + (bx + off) % ww
				for by in rh:
					var t := tone + (1.0 - float(by) / float(maxi(1, rh - 1))) * 0.12
					var col := shade(gr, t + (K.hash2(xx, ry + by, seed_value + 5) - 0.5) * 0.12, xx, ry + by)
					var sp := K.hash2(xx, ry + by, seed_value + 6)
					if sp > 0.965:
						col = gr[maxi(0, int(t * 6.0) - 2)]
					elif sp < 0.03:
						col = gr[mini(gr.size() - 1, int(t * 6.0) + 2)]
					if bx == cuts[i]:
						col = gr[1].lerp(gr[2], 0.3)
					elif by == rh - 1:
						col = col.darkened(0.3)
					elif by == 0:
						col = shade(gr, t + 0.24, xx, ry + by)
					K.px(im, xx, ry + by, col)


static func clipped_leaf(x: int, y: int, cell: int, seed_value: int) -> float:
	# Tone offset from a staggered grid of little leaf tufts: light on the
	# upper left of each tuft, dark on the lower right.
	var row := y / cell
	var cx := (x + (row % 2) * (cell / 2)) / cell
	var lx := (x + (row % 2) * (cell / 2)) % cell
	var ly := y % cell
	var n := (K.hash2(cx, row, seed_value) - 0.5) * 0.28
	if lx == 0 or ly == 0:
		n += 0.14
	elif lx == cell - 1 or ly == cell - 1:
		n -= 0.14
	return n


func garden_hedge_h() -> Image:
	var w := 32
	var h := 18
	var im := K.make(w, h)
	var leaf := ramp(HEDGE_LEAF)
	K.hline(im, 0, h - 2, w, Color(0, 0, 0, 0.22))
	K.hline(im, 0, h - 3, w, Color(0, 0, 0, 0.12))
	var top := 2
	for x in w:
		var jag := int(wobble(sin(x * TAU / w) * 3.0 + cos(x * TAU / w * 2.0) * 2.0, 71) * 1.2 + 0.5)
		for y in range(top + jag, h - 4):
			var face_top := y < 9
			var t := (0.62 if face_top else 0.36) + clipped_leaf(x, y, 3, 77) * 0.9
			if face_top:
				t += 0.08 - float(y - top) * 0.012
			else:
				t -= float(y - 9) * 0.02
			K.px(im, x, y, shade(leaf, t, x, y))
	# the edge between the lit top and the shadowed front
	for x in w:
		K.px(im, x, 9, shade(leaf, 0.3, x, 9))
	rim(im, 0.5)
	return im


func garden_hedge_v() -> Image:
	var w := 16
	var h := 32
	var im := K.make(w, h)
	var leaf := ramp(HEDGE_LEAF)
	for y in h:
		K.px(im, 13, y, Color(0, 0, 0, 0.2))
		K.px(im, 14, y, Color(0, 0, 0, 0.12))
		var jl := int(wobble(sin(y * TAU / h) * 3.0 + cos(y * TAU / h * 2.0) * 2.0, 73) * 0.8 + 0.5)
		for x in range(3 + jl, 13):
			var lit := 0.62 if x < 9 else 0.5
			var t := lit + clipped_leaf(x, y, 3, 79) * 0.9 - (0.12 if x >= 11 else 0.0)
			K.px(im, x, y, shade(leaf, t, x, y))
	# outline the two long edges only, so pieces stack without seams
	for y in h:
		K.px(im, 2, y, shade(leaf, 0.15, 2, y))
		K.px(im, 13, y, shade(leaf, 0.08, 13, y))
	return im


func garden_hedge_corner() -> Image:
	var w := 16
	var h := 20
	var im := K.make(w, h)
	var leaf := ramp(HEDGE_LEAF)
	K.shadow(im, 9.0, h - 2.5, 7.0, 2.0, 0.24)
	for y in range(2, h - 3):
		for x in range(2, 14):
			var face_top := y < 10
			var t := (0.62 if face_top else 0.36) + clipped_leaf(x, y, 3, 83) * 0.9
			if face_top:
				t += 0.06 - float(y) * 0.01 - float(x - 2) * 0.008
			else:
				t -= float(y - 10) * 0.018
			K.px(im, x, y, shade(leaf, t, x, y))
	for x in range(2, 14):
		K.px(im, x, 10, shade(leaf, 0.28, x, 10))
	rim(im, 0.5)
	return im


func garden_wall_h() -> Image:
	var w := 32
	var h := 20
	var im := K.make(w, h)
	var gr := ramp(GRANITE)
	K.hline(im, 0, h - 2, w, Color(0, 0, 0, 0.24))
	K.hline(im, 0, h - 3, w, Color(0, 0, 0, 0.12))
	# capstone top, with a couple of slab joints
	for x in w:
		for y in range(1, 5):
			var t := 0.86 - (y - 1) * 0.03 + (K.hash2(x, y, 91) - 0.5) * 0.1
			K.px(im, x, y, shade(gr, t, x, y))
	for jx in [5, 17, 27]:
		K.vline(im, jx, 1, 4, gr[3])
	# capstone front edge and shadow
	for x in w:
		K.px(im, x, 5, shade(gr, 0.62, x, 5))
		K.px(im, x, 6, shade(gr, 0.5, x, 6))
		K.px(im, x, 7, gr[1].lerp(gr[2], 0.3))
	blocks(im, 0, 8, w, h - 10, gr, 93, 5, 0.46, w)
	rim(im, 0.55)
	return im


func garden_wall_v() -> Image:
	var w := 16
	var h := 32
	var im := K.make(w, h)
	var gr := ramp(GRANITE)
	for y in h:
		K.px(im, 14, y, Color(0, 0, 0, 0.2))
		K.px(im, 15, y, Color(0, 0, 0, 0.1))
		for x in range(3, 12):
			var t := 0.58 - float(x - 3) * 0.012 + (K.hash2(x, y, 95) - 0.5) * 0.16
			K.px(im, x, y, shade(gr, t, x, y))
		K.px(im, 1, y, shade(gr, 0.6, 1, y))
		K.px(im, 2, y, shade(gr, 0.66, 2, y))
		K.px(im, 12, y, shade(gr, 0.36, 12, y))
		K.px(im, 13, y, shade(gr, 0.28, 13, y))
	for jy in [7, 19]:
		K.hline(im, 3, jy, 9, gr[3])
	# the long edges get a dark line but the ends stay open to stack
	for y in h:
		K.px(im, 0, y, gr[1])
		K.px(im, 14, y, gr[1].darkened(0.2))
	return im


func garden_wall_pillar() -> Image:
	var w := 18
	var h := 30
	var im := K.make(w, h)
	var gr := ramp(GRANITE)
	K.shadow(im, 10.0, h - 2.5, 8.0, 2.0, 0.26)
	# plinth
	blocks(im, 2, 23, 14, 5, gr, 101, 5, 0.42)
	# shaft
	blocks(im, 3, 9, 12, 14, gr, 103, 5, 0.46)
	for y in range(9, 23):
		K.px(im, 14, y, gr[1].lerp(gr[2], 0.4))
		K.px(im, 13, y, gr[2])
	# cap slab
	for x in range(1, 17):
		for y in range(6, 9):
			var t := 0.85 - (y - 6) * 0.1 - float(x - 1) * 0.006
			K.px(im, x, y, shade(gr, t, x, y))
	K.hline(im, 1, 8, 16, gr[2])
	# pyramid top: four facets
	for y in range(1, 6):
		var half := 1 + (y - 1) * 2
		for x in range(9 - half, 9 + half):
			var left := x < 9
			var t := (0.9 if left else 0.4) - float(y) * 0.02
			K.px(im, x, y, shade(gr, t, x, y))
	K.vline(im, 8, 1, 5, gr[3])
	rim(im, 0.55)
	return im


func garden_steps() -> Image:
	var w := 48
	var h := 16
	var im := K.make(w, h)
	var gr := ramp(GRANITE)
	# upper tread, upper riser, lower tread, lower riser
	for x in w:
		for y in 4:
			K.px(im, x, y, shade(gr, 0.62 - y * 0.03 + (K.hash2(x, y, 111) - 0.5) * 0.1, x, y))
		K.px(im, x, 3, shade(gr, 0.86, x, 3))
	blocks(im, 0, 4, w, 4, gr, 113, 4, 0.3, w)
	for x in w:
		for y in range(8, 12):
			K.px(im, x, y, shade(gr, 0.74 - (y - 8) * 0.03 + (K.hash2(x, y, 115) - 0.5) * 0.1, x, y))
		K.px(im, x, 11, shade(gr, 0.86, x, 11))
	blocks(im, 0, 12, w, 3, gr, 117, 3, 0.26, w)
	for x in w:
		K.px(im, x, 15, Color(0, 0, 0, 0.3))
	return im


func garden_bench() -> Image:
	var w := 38
	var h := 22
	var im := K.make(w, h)
	var gr := ramp(GRANITE)
	var wood := ramp(WOOD_WARM)
	K.shadow(im, w / 2.0 + 1.0, h - 2.5, 16.0, 2.4, 0.26)
	# back rest: top rail and slats, behind the seat
	K.rect(im, 4, 1, 30, 2, wood[4])
	K.hline(im, 4, 1, 30, wood[5])
	K.hline(im, 4, 3, 30, wood[1])
	for x in range(5, 33, 3):
		K.rect(im, x, 4, 2, 5, wood[3])
		K.vline(im, x, 4, 5, wood[4])
		K.vline(im, x + 1, 4, 5, wood[2])
	K.rect(im, 4, 9, 30, 1, wood[2])
	# seat: lit top slats and a shadowed front edge
	K.rect(im, 2, 10, 34, 3, wood[4])
	K.hline(im, 2, 10, 34, wood[5])
	K.hline(im, 2, 11, 34, wood[4])
	K.hline(im, 2, 12, 34, wood[3])
	for x in range(6, 36, 9):
		K.vline(im, x, 10, 3, wood[2])
	K.rect(im, 2, 13, 34, 2, wood[2])
	K.hline(im, 2, 13, 34, wood[3])
	K.hline(im, 2, 14, 34, wood[1])
	# stone ends
	for sx in [3, 29]:
		blocks(im, sx, 12, 7, 8, gr, 121 + sx, 4, 0.5)
		for x in range(7):
			K.px(im, sx + x, 12, shade(gr, 0.92, sx + x, 12))
	rim(im, 0.52)
	return im


func garden_flowerbed(v: int) -> Image:
	var w := 52
	var h := 24
	var im := K.make(w, h)
	var gr := ramp(GRANITE)
	var leaf := ramp(["1c3a2e", "26482f", "345f34", "487a3a", "639441", "84ae4b", "a9c95f"])
	K.shadow(im, w / 2.0 + 1.0, h - 3.0, 25.0, 3.0, 0.24)
	var cx := w / 2.0
	var cy := 13.0
	# edging stones around an oval of soil: back first, front stones with faces
	var soil := ramp(["2a1c14", "3c281c", "523628", "6a4834"])
	K.ellipse(im, cx, cy + 1.0, 22.0, 8.5, soil[1])
	K.ellipse(im, cx, cy, 21.0, 7.5, soil[2])
	for i in 60:
		K.px(im, int(cx - 20.0 + K.hash2(i, 1, 130 + v) * 40.0), int(cy - 6.0 + K.hash2(i, 2, 130 + v) * 12.0), soil[3] if i % 2 == 0 else soil[0])
	var stones := 26
	for i in stones:
		var a := float(i) / stones * TAU
		var sx := cx + cos(a) * 22.5
		var sy := cy + 1.0 + sin(a) * 9.0
		var front := sin(a) > 0.0
		var sw := 3.0 + K.hash2(i, 5, 131) * 1.4
		var sh := 2.3 + K.hash2(i, 6, 131) * 1.0 + (1.0 if front else 0.0)
		var tone := 0.4 + (K.hash2(i, 7, 131) - 0.5) * 0.3 + (0.22 if cos(a) < 0.0 and sin(a) < 0.3 else 0.0)
		blob(im, sx, sy, sw, sh, gr, 133 + i, tone - 0.5, 0.08, 0.06)
	# plants, back to front
	var spots: Array[Vector2] = []
	var rows := 3
	var per := [7, 8, 7]
	for r in rows:
		for k in per[r]:
			var fx: float = cx - 18.0 + (float(k) + 0.5) / float(per[r]) * 36.0 + (r % 2) * 2.0 + (K.hash2(k, r, 135) - 0.5) * 3.0
			var fy: float = cy - 4.0 + r * 3.6 + (K.hash2(k, r, 136) - 0.5) * 1.6
			var e := (fx - cx) / 21.0
			if absf(e) < 0.94 and absf((fy - cy) / 7.5) < 0.92 - e * e * 0.1:
				spots.append(Vector2(fx, fy))
	for i in spots.size():
		var sp := spots[i]
		match v:
			0: # roses
				blob(im, sp.x, sp.y - 1.0, 4.2, 3.6, leaf, 140 + i, clampf((cx - sp.x) * 0.01, -0.1, 0.12) - 0.05, 0.16, 0.2)
				var cols := ["e0304a", "f2607a", "fbe6ec", "c02040", "ff9aac"]
				for k in 3:
					var fx := int(sp.x - 2.0 + K.hash2(i, k, 141) * 4.0)
					var fy := int(sp.y - 3.0 + K.hash2(i, k + 5, 141) * 3.0)
					K.px(im, fx, fy, c(cols[(i + k) % 5]))
					K.px(im, fx + 1, fy, c(cols[(i + k + 2) % 5]))
					K.px(im, fx, fy + 1, c("8a1a2a") if (i + k) % 3 else c("f8c8d0"))
			1: # marigolds
				blob(im, sp.x, sp.y, 3.4, 2.6, leaf, 150 + i, -0.08, 0.16, 0.2)
				for k in 4:
					var fx := int(sp.x - 2.0 + K.hash2(i, k, 151) * 4.0)
					var fy := int(sp.y - 2.0 + K.hash2(i, k + 5, 151) * 2.0)
					var orange := (i + k) % 2 == 0
					K.px(im, fx, fy, c("f28a1c") if orange else c("ffc832"))
					K.px(im, fx + 1, fy, c("ffb830") if orange else c("ffe470"))
					K.px(im, fx, fy + 1, c("c85a10") if orange else c("e8a018"))
			2: # lavender
				for k in 5:
					var sx2 := int(sp.x - 3.0 + k * 1.5)
					var top := int(sp.y - 6.0 + K.hash2(i, k, 161) * 3.0)
					K.vline(im, sx2, top + 3, 4, leaf[2])
					for y in range(top, top + 4):
						K.px(im, sx2, y, c("8a6ad0") if y % 2 == 0 else c("6a48b0"))
						K.px(im, sx2 + 1, y, c("b0a0ee") if y % 2 else c("9080d8"))
				blob(im, sp.x, sp.y + 1.0, 3.6, 2.0, ramp(["3a4a46", "50645a", "6a8070", "88a088", "a8c0a0"]), 165 + i, 0.0, 0.14, 0.2)
	rim(im, 0.52)
	return im


func garden_arbor() -> Image:
	var w := 44
	var h := 52
	var im := K.make(w, h)
	var wood := ramp(WOOD_WARM)
	var gr := ramp(GRANITE)
	var leaf := ramp(["1c3a2e", "26482f", "345f34", "487a3a", "639441", "84ae4b", "a9c95f"])
	var rng := RandomNumberGenerator.new()
	rng.seed = 6100
	K.shadow(im, w / 2.0 + 1.0, h - 3.0, 20.0, 3.0, 0.26)
	# stone footings and timber posts
	for px_ in [5, 34]:
		blocks(im, px_ - 1, h - 9, 7, 6, gr, 171 + px_, 3, 0.46)
		for y in range(12, h - 9):
			K.rect(im, px_, y, 5, 1, wood[3])
			K.px(im, px_, y, wood[5])
			K.px(im, px_ + 1, y, wood[4])
			K.px(im, px_ + 3, y, wood[2])
			K.px(im, px_ + 4, y, wood[1])
	# the arch: a timber ring, thick and lit on the upper left
	var acx := w / 2.0
	for x in range(5, 39):
		var u := (x + 0.5 - acx) / 17.5
		if absf(u) > 1.0:
			continue
		var top := 14.0 - sqrt(1.0 - u * u) * 10.0
		for y in range(int(top), int(top) + 4):
			var t := 0.7 - float(y - int(top)) * 0.12 - u * 0.1 + (K.hash2(x, y, 5) - 0.5) * 0.12
			K.px(im, x, y, shade(wood, t, x, y))
	# top slats across the arch
	for x in range(9, 36, 5):
		K.rect(im, x, 1, 2, 3, wood[3])
		K.px(im, x, 1, wood[5])
	K.rect(im, 8, 3, 28, 1, wood[2])
	# climbing roses: leafy clumps up the posts and over the arch
	var spots: Array[Vector2] = []
	for i in 9:
		spots.append(Vector2(7.0 + (i % 2) * 1.5 + rng.randf_range(-1.0, 1.0), 18.0 + i * 3.6))
		spots.append(Vector2(36.0 + (i % 2) * -1.5 + rng.randf_range(-1.0, 1.0), 18.0 + i * 3.6))
	for i in 12:
		var a := PI + float(i) / 11.0 * PI
		spots.append(Vector2(acx + cos(a) * 17.5 + rng.randf_range(-1.0, 1.0), 14.0 + sin(a) * 10.0 + 1.0))
	for i in 16:
		spots.append(Vector2(9.0 + rng.randf() * 26.0, 2.0 + rng.randf() * 3.0))
	spots.sort_custom(func(p: Vector2, q: Vector2) -> bool: return p.y < q.y)
	for i in spots.size():
		var sp := spots[i]
		blob(im, sp.x, sp.y, 3.6, 3.2, leaf, 180 + i * 3, clampf((acx - sp.x) * 0.012, -0.1, 0.12) - 0.02, 0.18, 0.24)
	var cols := ["e8506a", "f7809a", "fbe0e6", "d02e4e", "ffb0c0"]
	for i in 34:
		var sp := spots[(i * 5) % spots.size()]
		var fx := int(sp.x - 2.0 + K.hash2(i, 1, 190) * 4.0)
		var fy := int(sp.y - 2.0 + K.hash2(i, 2, 190) * 4.0)
		K.px(im, fx, fy, c(cols[i % 5]))
		K.px(im, fx + 1, fy, c(cols[(i + 2) % 5]))
		K.px(im, fx, fy + 1, c("a01a38") if i % 3 else c("fbd0d8"))
	rim(im, 0.52)
	return im


func garden_sundial() -> Image:
	var w := 18
	var h := 30
	var im := K.make(w, h)
	var gr := ramp(GRANITE)
	K.shadow(im, 10.0, h - 2.5, 7.0, 2.0, 0.26)
	blocks(im, 2, 24, 14, 4, gr, 201, 4, 0.44)
	# fluted pedestal
	for y in range(11, 24):
		var half := 3.0 + float(y - 11) * 0.12
		for x in range(int(9.0 - half), int(9.0 + half) + 1):
			var u := (x + 0.5 - 9.0) / half
			var t := 0.7 - u * 0.32 + (0.08 if (x % 2 == 0) else -0.04)
			K.px(im, x, y, shade(gr, t, x, y))
	K.rect(im, 4, 21, 10, 3, gr[3])
	K.hline(im, 4, 21, 10, gr[5])
	# bronze plate with patina and a gnomon
	var br := ramp(["4a3a1e", "6a5a2a", "8a7a3e", "b09a54", "d4c078", "ecdca0"])
	K.ellipse(im, 9.0, 11.0, 8.0, 3.4, gr[2])
	K.ellipse(im, 9.0, 10.0, 7.4, 3.0, br[2])
	K.ellipse(im, 8.6, 9.8, 6.0, 2.3, br[3])
	K.ellipse(im, 8.4, 9.6, 3.6, 1.2, br[4])
	for i in 8:
		var a := float(i) / 8.0 * TAU
		K.px(im, roundi(9.0 + cos(a) * 6.2), roundi(10.0 + sin(a) * 2.4), br[0])
	for i in 4:
		K.px(im, 9 + i, 9 - i / 2 - (0 if i < 3 else 0), br[1])
	K.vline(im, 9, 6, 4, br[1])
	K.px(im, 9, 6, br[5])
	K.px(im, 10, 7, br[0])
	K.px(im, 10, 8, br[0])
	K.px(im, 6, 10, c("6a9a7a"))
	rim(im, 0.52)
	return im


func garden_table_umbrella() -> Image:
	var w := 52
	var h := 48
	var im := K.make(w, h)
	var cream := ramp(["b4a888", "d0c4a0", "e4d9b8", "f2ead0", "fcf8e8"])
	var green := ramp(["1e4a30", "2a6040", "3a7a50", "4e9662", "6ab07a"])
	var wire := ramp(["1e2622", "34403a", "52625a", "7a8c80"])
	K.shadow(im, 26.0, h - 3.0, 22.0, 3.4, 0.24)
	# chairs on either side
	for cx in [9, 43]:
		K.ellipse(im, cx, 40.0, 4.6, 2.2, wire[0])
		K.ellipse(im, cx, 39.0, 4.2, 1.9, cream[3])
		K.ellipse(im, cx - 0.6, 38.8, 3.0, 1.2, cream[4])
		K.vline(im, cx - 4, 30, 9, wire[1])
		K.vline(im, cx + 4, 30, 9, wire[0])
		K.hline(im, cx - 4, 30, 9, wire[2])
		K.hline(im, cx - 3, 32, 7, wire[1])
		for lx in [cx - 3, cx + 3]:
			K.vline(im, lx, 41, 4, wire[1])
	# table: cloth top with a drape
	K.rect(im, 25, 34, 2, 10, wire[1])
	K.vline(im, 25, 34, 10, wire[3])
	K.ellipse(im, 26.0, 42.5, 6.0, 2.0, wire[1])
	K.ellipse(im, 26.0, 35.0, 12.5, 4.2, cream[2])
	K.ellipse(im, 25.5, 34.4, 11.0, 3.4, cream[3])
	K.ellipse(im, 25.0, 34.0, 8.0, 2.2, cream[4])
	for i in 9:
		var x := 15 + i * 3
		K.px(im, x, 38, cream[1])
		K.px(im, x + 1, 39 if i % 2 else 38, cream[0])
	# a teapot and cups
	K.ellipse(im, 27.0, 33.0, 2.2, 1.5, c("6a8ab0"))
	K.px(im, 26, 32, c("b0c8e4"))
	K.px(im, 22, 34, c("f8f4ea"))
	K.px(im, 31, 35, c("f8f4ea"))
	# pole and umbrella: green and cream gores with a scalloped edge
	K.rect(im, 25, 8, 2, 28, wire[2])
	K.vline(im, 25, 8, 28, wire[3])
	var ucx := 26.0
	var ucy := 12.0
	for y in range(0, 19):
		var t := float(y) / 18.0
		var half := 2.0 + 23.0 * pow(sin(minf(1.0, float(y) / 14.0) * PI / 2.0), 0.85)
		var yy := 3 + y
		for x in range(int(ucx - half), int(ucx + half) + 1):
			var u := (x + 0.5 - ucx) / 25.0
			var ang := int(floor((u + 1.0) * 5.5))
			var col := green if ang % 2 == 0 else cream
			var tone := 0.8 - t * 0.42 - u * 0.24 - (0.1 if y > 14 else 0.0)
			if y > 16 and ((x + int(ucx)) % 5 == 0):
				continue
			K.px(im, x, yy, shade(col, tone, x, yy))
	# underside shadow and the finial
	for x in range(6, 47):
		var u := (x + 0.5 - ucx) / 21.0
		var yb := 3 + 19 + int(2.0 * sqrt(maxf(0.0, 1.0 - u * u)))
		K.px(im, x, yb, Color(0, 0, 0, 0.22))
	K.px(im, 26, 1, c("d4b060"))
	K.px(im, 26, 2, c("b08a3c"))
	rim(im, 0.5)
	return im


func garden_birdbath() -> Image:
	var w := 22
	var h := 30
	var im := K.make(w, h)
	var gr := ramp(GRANITE)
	var wt := ramp(WATER)
	K.shadow(im, 12.0, h - 2.5, 8.0, 2.0, 0.26)
	blocks(im, 5, 25, 12, 3, gr, 211, 3, 0.44)
	for y in range(15, 25):
		var half := 2.0 + pow(float(y - 15) / 10.0, 2.0) * 3.0
		for x in range(int(11.0 - half), int(11.0 + half) + 1):
			var u := (x + 0.5 - 11.0) / half
			K.px(im, x, y, shade(gr, 0.72 - u * 0.32, x, y))
	K.ellipse(im, 11.0, 15.0, 9.0, 3.6, gr[2])
	K.ellipse(im, 11.0, 14.0, 9.0, 3.4, gr[5])
	K.ellipse(im, 11.0, 14.3, 7.4, 2.6, gr[3])
	K.ellipse(im, 11.0, 14.6, 6.8, 2.2, wt[2])
	K.ellipse(im, 10.4, 14.4, 4.6, 1.4, wt[4])
	K.px(im, 8, 13, wt[6])
	K.px(im, 9, 13, wt[6])
	K.px(im, 14, 15, wt[5])
	# a Steller's jay drinking
	var jay := ramp(["101828", "1c2c58", "2c4890", "4a6cc0", "88a8e8"])
	K.rect(im, 13, 9, 4, 4, jay[2])
	K.rect(im, 13, 7, 3, 3, jay[0])
	K.px(im, 12, 6, jay[0])
	K.px(im, 13, 6, jay[0])
	K.px(im, 12, 8, jay[1])
	K.px(im, 14, 8, c("f4f4f4"))
	K.px(im, 12, 10, c("f0c040"))
	K.px(im, 16, 11, jay[3])
	K.px(im, 17, 12, jay[1])
	K.px(im, 15, 12, jay[4])
	K.px(im, 14, 13, jay[0])
	rim(im, 0.52)
	return im


func garden_urn(v: int) -> Image:
	var w := 18
	var h := 28
	var im := K.make(w, h)
	var gr := ramp(GRANITE)
	var leaf := ramp(["1c3a2e", "26482f", "345f34", "487a3a", "639441", "84ae4b", "a9c95f"])
	K.shadow(im, 10.0, h - 2.5, 7.0, 2.0, 0.26)
	# square plinth
	blocks(im, 4, 22, 11, 4, gr, 221 + v, 4, 0.44)
	# the vase body, round and lit from the left
	for y in range(9, 23):
		var t := float(y - 9) / 13.0
		var half := 3.2 + sin(t * PI * 0.95) * 2.9 - t * 0.6
		for x in range(int(9.5 - half), int(9.5 + half) + 1):
			var u := (x + 0.5 - 9.5) / half
			var tone := 0.72 - u * 0.4 + (K.hash2(x, y, 5) - 0.5) * 0.06
			K.px(im, x, y, shade(gr, tone, x, y))
		if y == 13 or y == 20:
			K.hline(im, int(9.5 - half), y, int(half * 2.0) + 1, gr[2])
	K.rect(im, 7, 20, 5, 3, gr[3])
	K.ellipse(im, 9.5, 9.0, 6.0, 2.0, gr[5])
	K.ellipse(im, 9.5, 9.2, 4.8, 1.4, gr[1])
	if v == 0:
		# red geraniums
		blob(im, 9.5, 6.0, 6.0, 4.0, leaf, 231, -0.02, 0.16, 0.22)
		for i in 9:
			var fx := int(5.0 + K.hash2(i, 1, 232) * 9.0)
			var fy := int(2.0 + K.hash2(i, 2, 232) * 6.0)
			K.px(im, fx, fy, c("d8283a"))
			K.px(im, fx + 1, fy, c("f0586a"))
			K.px(im, fx, fy - 1, c("f88a98") if i % 3 == 0 else c("b01e30"))
	else:
		# white petunias and trailing ivy
		blob(im, 9.5, 5.5, 5.5, 3.6, leaf, 241, -0.04, 0.16, 0.22)
		for i in 8:
			var fx := int(5.0 + K.hash2(i, 1, 242) * 9.0)
			var fy := int(2.0 + K.hash2(i, 2, 242) * 5.0)
			K.px(im, fx, fy, c("fbf8ee"))
			K.px(im, fx + 1, fy, c("e0d8f4"))
			K.px(im, fx, fy + 1, c("b8a0e0"))
		for s in 3:
			var sx := 5 + s * 4
			for k in 9:
				K.px(im, sx + int(sin(k * 0.8 + s) * 0.9), 9 + k, leaf[2 + (k + s) % 3])
				if k % 3 == 0:
					K.px(im, sx + int(sin(k * 0.8 + s) * 0.9) + 1, 9 + k, leaf[5])
	rim(im, 0.52)
	return im


func garden_topiary() -> Image:
	var w := 20
	var h := 36
	var im := K.make(w, h)
	var leaf := ramp(CEDAR_LEAF)
	var clay := ramp(["5a2a1a", "80402a", "a85a3a", "c8794e", "e09a6c"])
	K.shadow(im, 11.0, h - 2.5, 8.0, 2.2, 0.26)
	# terracotta pot
	for y in range(27, 34):
		var half := 5.6 - float(y - 27) * 0.28 + (0.6 if y < 29 else 0.0)
		for x in range(int(10.0 - half), int(10.0 + half) + 1):
			var u := (x + 0.5 - 10.0) / half
			K.px(im, x, y, shade(clay, 0.66 - u * 0.36 + (0.1 if y < 29 else 0.0), x, y))
	K.hline(im, 4, 27, 12, clay[4])
	K.hline(im, 5, 30, 10, clay[1])
	K.vline(im, 10, 22, 6, c("4a3020"))
	K.vline(im, 9, 22, 6, c("6a4a30"))
	# three clipped tiers and a point
	var tiers := [[10.0, 22.0, 7.4, 4.6], [10.0, 15.5, 5.6, 3.8], [10.0, 9.5, 4.0, 3.0]]
	for i in tiers.size():
		var t: Array = tiers[i]
		blob(im, float(t[0]), float(t[1]), float(t[2]), float(t[3]), leaf, 251 + i * 5, 0.0, 0.1, 0.02)
	for i in 4:
		blob(im, 10.0, 5.0 - i * 0.6, 1.9 - i * 0.4, 2.2, leaf, 262 + i, 0.06, 0.08, 0.02)
	leaf_specks(im, 10.0, 15.0, 6.0, 10.0, leaf, 271, 10)
	rim(im, 0.52)
	return im


func garden_fountain() -> Image:
	var w := 68
	var h := 60
	var im := K.make(w, h)
	var gr := ramp(GRANITE)
	var wt := ramp(WATER)
	var cx := 34.0
	K.shadow(im, cx + 3.0, 55.0, 31.0, 4.2, 0.25)
	# basin: dark front face, then the lit rim on top
	for y in range(30, 56):
		for x in range(2, 66):
			var dx := (x + 0.5 - cx) / 31.0
			var dy := (y + 0.5 - 48.0) / 12.0
			if dx * dx + dy * dy <= 1.0 and y > 40:
				var t := 0.4 - dx * 0.22 + (K.hash2(x / 3, y / 4, 301) - 0.5) * 0.24
				var col := shade(gr, t, x, y)
				if (y + (x / 5) * 2) % 5 == 0:
					col = gr[1]
				K.px(im, x, y, col)
	for y in range(28, 54):
		for x in range(2, 66):
			var dx := (x + 0.5 - cx) / 31.0
			var dy := (y + 0.5 - 43.0) / 12.5
			var d2 := dx * dx + dy * dy
			if d2 <= 1.0:
				var lam := -dx * 0.55 - dy * 0.6
				K.px(im, x, y, shade(gr, 0.62 + lam * 0.3 + (K.hash2(x, y, 303) - 0.5) * 0.1, x, y))
	# water inside the rim
	for y in range(31, 51):
		for x in range(6, 62):
			var dx := (x + 0.5 - cx) / 26.5
			var dy := (y + 0.5 - 42.0) / 9.6
			if dx * dx + dy * dy > 1.0:
				continue
			var far := (1.0 - (dy + 1.0) / 2.0)
			var ripple := 0.5 + 0.5 * sin(sqrt(dx * dx * 4.0 + dy * dy * 9.0) * 22.0)
			var t := 0.34 + (1.0 - far) * 0.2 + ripple * 0.14 + (K.hash2(x, y, 305) - 0.5) * 0.06 - dx * 0.06
			if dy < -0.62:
				t -= 0.16 # shadow under the far rim
			K.px(im, x, y, shade(wt, t, x, y))
	# glints
	for i in 26:
		var gx := int(cx + (K.hash2(i, 1, 306) - 0.5) * 44.0)
		var gy := int(42.0 + (K.hash2(i, 2, 306) - 0.5) * 15.0)
		var dx := (gx - cx) / 26.0
		var dy := (gy - 42.0) / 9.5
		if dx * dx + dy * dy < 0.85:
			K.hline(im, gx, gy, 2 + (i % 2), wt[6])
	# central pedestal
	for y in range(20, 42):
		var half := 3.2 + float(y - 20) * 0.05
		for x in range(int(cx - half), int(cx + half) + 1):
			var u := (x + 0.5 - cx) / half
			K.px(im, x, y, shade(gr, 0.62 - u * 0.36 + (0.06 if y % 4 == 0 else 0.0), x, y))
	K.ellipse(im, cx, 41.5, 8.0, 3.0, gr[3])
	K.ellipse(im, cx - 0.4, 41.0, 7.0, 2.4, gr[5])
	K.ellipse(im, cx, 41.3, 6.0, 1.8, wt[3])
	for i in 6:
		K.px(im, int(cx - 6.0 + i * 2.2), 43, Color(0.92, 0.97, 1.0, 0.8))
	# middle bowl
	K.ellipse(im, cx, 27.0, 14.0, 5.6, gr[2])
	K.ellipse(im, cx, 25.6, 14.0, 5.4, gr[5])
	K.ellipse(im, cx - 0.4, 25.8, 12.2, 4.4, gr[3])
	K.ellipse(im, cx, 26.0, 11.2, 3.8, wt[2])
	K.ellipse(im, cx - 1.0, 25.8, 8.0, 2.4, wt[4])
	K.hline(im, int(cx) - 6, 24, 4, wt[6])
	# streams over the lip of the middle bowl
	for i in 9:
		var sx := int(cx - 11.0 + i * 2.75)
		var lip := 29 + int(2.6 * sqrt(maxf(0.0, 1.0 - pow((sx - cx) / 13.0, 2.0))))
		for y in range(lip, 41 + int(absf(sx - cx) * 0.06)):
			K.px(im, sx, y, wt[5] if (y + i) % 3 else wt[3])
			if (y + i) % 4 == 0:
				K.px(im, sx + 1, y, wt[2])
		K.px(im, sx, 41, wt[6])
	# small top bowl and the jet
	for y in range(11, 21):
		K.rect(im, int(cx) - 1, y, 3, 1, shade(gr, 0.6 + (0.12 if y % 3 == 0 else 0.0), int(cx), y))
	K.vline(im, int(cx) - 1, 11, 10, gr[5])
	K.vline(im, int(cx) + 1, 11, 10, gr[2])
	K.ellipse(im, cx, 12.0, 7.4, 3.0, gr[2])
	K.ellipse(im, cx, 11.0, 7.4, 2.9, gr[5])
	K.ellipse(im, cx, 11.3, 6.0, 2.1, wt[3])
	K.ellipse(im, cx - 0.6, 11.1, 3.6, 1.1, wt[5])
	for i in 7:
		var sx := int(cx - 6.0 + i * 2.0)
		for y in range(14, 25):
			K.px(im, sx, y, wt[5] if (y + i) % 2 else wt[4])
	# a stone finial and the spray
	K.ellipse(im, cx, 6.0, 2.6, 2.6, gr[4])
	K.px(im, int(cx) - 1, 5, gr[7])
	K.px(im, int(cx) + 1, 7, gr[2])
	for i in 12:
		var a := (float(i) / 11.0 - 0.5) * 2.4
		for k in 8:
			var t := float(k) / 7.0
			var sx := cx + sin(a) * t * 9.0
			var sy := 4.0 - (1.0 - pow(2.0 * t - 1.0, 2.0)) * 5.0 + t * t * 8.0
			K.px(im, roundi(sx), roundi(sy), wt[6] if k % 2 == 0 else wt[4])
	rim(im, 0.5)
	return im
