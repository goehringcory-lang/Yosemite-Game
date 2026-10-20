extends "res://tools/hubs/valley_art.gd"
## Glacier Point pixel art in the Ahwahnee's style (the same ramps, light from
## the upper left and dark rim as valley_art.gd): the snack stand and the
## restrooms, the 1924 Geology Hut, the granite parapet and pipe railing
## round the overlook, Overhanging Rock, the coin viewers, the stone
## amphitheater, the foundations of the Glacier Point Hotel, the rim forest
## (red fir, Jeffrey pine, lodgepole, silver snags), the fallen Jeffrey pine on
## Sentinel Dome, and the drop past the edge (the painting of the view seen
## through it is glacier_vista_art.gd's). Written to assets/sprites/glacier/
## at 16px scale;
## tools/hubs/rebuild_glacier_point.sh moves them onto the 32px grid.

const GP_OUT := "res://assets/sprites/glacier/"

## Trunk footprints (width, depth) of the rim trees, for collision.
const GP_TRUNKS := {
	"gp_red_fir_a": Vector2(6, 4), "gp_red_fir_b": Vector2(6, 4),
	"gp_jeffrey_a": Vector2(6, 4), "gp_jeffrey_b": Vector2(6, 4),
	"gp_lodgepole": Vector2(4, 3), "gp_snag": Vector2(4, 3),
}
const GP_TREES := ["gp_red_fir_a", "gp_red_fir_b", "gp_jeffrey_a", "gp_jeffrey_b", "gp_lodgepole", "gp_snag"]

var fir_leaf: Array[Color] = []
var pine_leaf: Array[Color] = []
var bark_red: Array[Color] = []
var bark_cinnamon: Array[Color] = []
var silver: Array[Color] = []
var haze: Array[Color] = []


func _init() -> void:
	super._init()
	fir_leaf = _ramp(["14302e", "1c3e3a", "264f44", "33624e", "45765a", "5e8c68", "7ca47a"])
	pine_leaf = _ramp(["1c3424", "28452c", "365a34", "4a7040", "62884c", "7ea25c", "a0bc72"])
	bark_red = _ramp(["2c1418", "47202a", "632c34", "7e3c3c", "9a5246", "b46a52"])
	bark_cinnamon = _ramp(["3a1a10", "5c2c18", "83401f", "a8582a", "c8743a", "e2964e"])
	silver = _ramp(["3a3634", "57514c", "7a736a", "9e968a", "c2baac", "e0d8c8"])
	haze = _ramp(["4a5c78", "5c708c", "7088a2", "8aa0b6", "a6b8c8", "c4d2dc"])


func save_all() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(GP_OUT))
	var stand := building("", {"size": Vector2i(88, 46), "wall": "stone_timber", "label": "GIFTS - SNACKS", "seed": 7214,
		"roof": ["1f2620", "2c3a2c", "3c4e38", "506448", "687c5a", "86986e"], "windows": [12, 24, 64, 76], "gable": 44,
		"chimney": 70, "porch": true, "low": true, "scale": VILLAGE_SCALE})
	_gp_write(stand[0], "snack_stand")
	_gp_write(stand[1], "snack_stand_glow")
	var loo := building("", {"size": Vector2i(40, 32), "wall": "stone", "label": "RESTROOMS", "seed": 3200,
		"roof": ["1f2620", "2c3a2c", "3c4e38", "506448", "687c5a", "86986e"], "windows": [8, 32], "scale": VILLAGE_SCALE})
	_gp_write(loo[0], "restrooms")
	_gp_write(loo[1], "restrooms_glow")
	_gp_write(geology_hut(), "geology_hut")
	_gp_write(rim_wall(true), "rim_wall_h")
	_gp_write(rim_wall(false), "rim_wall_v")
	_gp_write(overhanging_rock(), "overhanging_rock")
	_gp_write(viewer(), "viewer")
	_gp_write(hotel_ruin(), "hotel_ruin")
	_gp_write(amphi_bench(), "amphi_bench")
	_gp_write(amphi_stage(), "amphi_stage")
	_gp_write(fallen_jeffrey(), "sentinel_jeffrey")
	_gp_write(conifer_fir(0), "gp_red_fir_a")
	_gp_write(conifer_fir(1), "gp_red_fir_b")
	_gp_write(jeffrey(0), "gp_jeffrey_a")
	_gp_write(jeffrey(1), "gp_jeffrey_b")
	_gp_write(lodgepole(), "gp_lodgepole")
	_gp_write(snag(), "gp_snag")
	_gp_write(trail_post(), "trail_post")


func _gp_write(im: Image, sprite_name: String) -> void:
	im.save_png(ProjectSettings.globalize_path(GP_OUT + sprite_name + ".png"))


# ---------------------------------------------------------------- buildings

## The Geology Hut (1924): an open-fronted shelter of rough granite with a
## shingle roof, on the knob east of the walkway, built so visitors could
## read the canyon below. Seen from the south: stone piers, an open front
## into the shade, and the exhibit rail inside.
func geology_hut() -> Image:
	var w := 58
	var h := 46
	var sd := 1924
	var im := K.make(w, h)
	K.shadow(im, w / 2.0, h - 2.5, w / 2.0 - 2.0, 2.6, 0.3)
	var wall_top := 22
	# the dark open interior, with the exhibit rail and a lit panel
	K.rect(im, 4, wall_top, w - 8, h - wall_top - 4, Color("1c1820"))
	shade(im, 4, wall_top, w - 8, h - wall_top - 4, Color("2e2a36"), 0.0, 0.6, 0.6)
	K.rect(im, 10, wall_top + 8, w - 20, 2, timber[3])
	K.hline(im, 10, wall_top + 8, w - 20, timber[5])
	for i in 3:
		var px_ := 14 + i * 12
		K.rect(im, px_, wall_top + 4, 8, 4, Color("b8ab88"))
		K.hline(im, px_ + 1, wall_top + 5, 6, Color("6a6a58"))
		K.hline(im, px_ + 1, wall_top + 6, 4, Color("6a6a58"))
	# rough granite piers at the corners and a low wall each side of the opening
	for pier_x in [1, w - 9]:
		stone_wall(im, pier_x, wall_top - 1, 8, h - wall_top - 2, sd + pier_x, 0.6, 3, 2, true)
	stone_wall(im, 9, h - 12, 12, 9, sd + 5, 0.55, 3, 2, true)
	stone_wall(im, w - 21, h - 12, 12, 9, sd + 6, 0.55, 3, 2, true)
	# a split-shake roof that overhangs the piers
	_vb_roof(im, 0, 3, w, wall_top - 3, sd + 200, 0.18)
	_vb_eave(im, 0, wall_top - 2, w)
	sign_board(im, w / 2, wall_top - 9, "GEOLOGY HUT")
	K.outline(im, Color("231a16"))
	return im


## A low parapet of mortared granite with a steel pipe railing on posts, the
## barrier round the Glacier Point overlook. [param horizontal] draws one
## tile of a run along the edge; otherwise the narrow end-on piece for the
## sides.
func rim_wall(horizontal: bool) -> Image:
	var w := 16 if horizontal else 6
	var h := 14 if horizontal else 22
	var im := K.make(w, h)
	var sd := 4 if horizontal else 9
	if horizontal:
		stone_wall(im, 0, h - 7, w, 7, sd, 0.62, 3, 2, false)
		K.hline(im, 0, h - 8, w, granite[6])
		# the pipe rail: posts at each end, two rails between
		for post_x in [1, 9]:
			K.vline(im, post_x, 1, h - 8, iron[2])
			K.vline(im, post_x + 1, 1, h - 8, iron[1])
		K.hline(im, 0, 1, w, iron[3])
		K.hline(im, 0, 2, w, iron[1])
		K.hline(im, 0, 4, w, iron[2])
	else:
		stone_wall(im, 0, 4, w, h - 4, sd, 0.62, 3, 2, false)
		K.vline(im, 0, 4, h - 4, granite[6])
		K.vline(im, 2, 0, 5, iron[2])
		K.vline(im, 3, 0, 5, iron[1])
		K.px(im, 2, 0, iron[3])
	return im


## Overhanging Rock: a granite slab that juts out past the rim over the
## Valley, lit along its top and dark underneath where it hangs free.
func overhanging_rock() -> Image:
	var w := 50
	var h := 30
	var sd := 3214
	var im := K.make(w, h)
	# its shadow far below would be lost in the haze: only the slab is drawn
	for yy in h:
		for xx in w:
			# a wedge: thick at the root (right), thin at the tip (left)
			var u := float(xx) / (w - 1)
			var top := 6.0 + (1.0 - u) * 9.0 + (vnoise(xx * 0.3, 0.0, sd) - 0.5) * 3.0
			var bottom := 16.0 + u * 11.0 + (vnoise(xx * 0.25, 4.0, sd) - 0.5) * 2.0
			if xx < 2 or yy < top or yy > bottom:
				continue
			var depth := (yy - top) / maxf(1.0, bottom - top)
			var t := 0.82 - depth * 0.75 + (K.hash2(xx, yy, sd) - 0.5) * 0.12
			if yy < top + 2.0:
				t = 0.95
			if depth > 0.55:
				t -= 0.18
			K.px(im, xx, yy, granite[clampi(roundi(t * 6.0), 0, 6)])
	# joints in the slab and lichen on its top
	for i in 7:
		K.px(im, 20 + i, int(10 + i * 0.6), granite[2])
	for i in 6:
		K.px(im, 30 + i * 2, 8 + (i % 2), Color("a8a862"))
	K.outline(im, Color("1e1a1e"))
	return im


## A coin-operated viewer on a post, its binoculars toward Half Dome.
func viewer() -> Image:
	var w := 12
	var h := 22
	var im := K.make(w, h)
	K.shadow(im, w / 2.0, h - 2.0, 4.0, 1.6, 0.3)
	K.rect(im, 5, 9, 2, h - 11, iron[2])
	K.vline(im, 5, 9, h - 11, iron[3])
	K.rect(im, 3, h - 3, 6, 2, iron[1])
	# the head: a rounded box with two eyepieces and a coin box
	K.rect(im, 2, 3, 8, 6, Color("4d6a56"))
	K.hline(im, 2, 3, 8, Color("6f8e74"))
	K.rect(im, 2, 8, 8, 1, Color("2e4034"))
	K.rect(im, 3, 1, 2, 2, iron[1])
	K.rect(im, 7, 1, 2, 2, iron[1])
	K.px(im, 6, 5, Color("d9b65a"))
	K.outline(im, Color("1e1a1a"))
	return im


## The foundations of the Glacier Point Hotel (1917) and McCauley's Mountain
## House (1878), which burned together in 1969: low granite footings and a
## few steps, in the duff.
func hotel_ruin() -> Image:
	var w := 124
	var h := 46
	var sd := 1969
	var im := K.make(w, h)
	# the old floor: packed earth and ash, grassed over in places
	for yy in range(6, h - 6):
		for xx in range(4, w - 4):
			var g := vnoise(xx * 0.2, yy * 0.2, sd)
			var col := Color("6b5a44") if g < 0.55 else Color("5a6a3a")
			if K.hash2(xx, yy, sd) < 0.12:
				col = Color("4a3e30")
			K.px(im, xx, yy, col)
	# outer footing and two inner walls, seen from above at a slant
	var walls := [Rect2i(2, 3, w - 4, 5), Rect2i(2, h - 9, w - 4, 5), Rect2i(2, 3, 5, h - 7), Rect2i(w - 7, 3, 5, h - 7),
		Rect2i(44, 3, 4, h - 8), Rect2i(84, 8, 4, 18), Rect2i(48, 22, 36, 4)]
	for r: Rect2i in walls:
		stone_wall(im, r.position.x, r.position.y, r.size.x, r.size.y, sd + r.position.x * 7 + r.position.y, 0.55, 2, 2, false)
		K.hline(im, r.position.x, r.position.y, r.size.x, granite[5])
	# gaps where doorways were, and a broken corner
	K.rect(im, 18, h - 9, 7, 5, Color("6b5a44"))
	K.rect(im, w - 7, 20, 5, 6, Color("6b5a44"))
	K.rect(im, 60, 22, 8, 4, Color("6b5a44"))
	# the hotel's big fireplace, its hearth stones still standing
	stone_wall(im, 96, 12, 12, 10, sd + 900, 0.5, 3, 2, false)
	K.rect(im, 99, 16, 6, 6, Color("2a2420"))
	K.rect(im, w - 14, 3, 8, 2, Color(0, 0, 0, 0))
	# the front steps
	for i in 3:
		K.rect(im, 62 - i * 2, h - 4 + i, 14 + i * 4, 1, granite[5 - i])
	K.outline(im, Color("2a2420"))
	return im


## A bench of split granite on two blocks, one row of the amphitheater.
func amphi_bench() -> Image:
	var w := 30
	var h := 10
	var im := K.make(w, h)
	K.shadow(im, w / 2.0, h - 1.5, w / 2.0 - 1.0, 1.6, 0.26)
	for bx in [3, w - 7]:
		K.rect(im, bx, 5, 4, 4, granite[2])
		K.vline(im, bx, 5, 4, granite[3])
	for xx in range(1, w - 1):
		for yy in range(1, 5):
			var t := 0.75 - yy * 0.12 + (K.hash2(xx, yy, 77) - 0.5) * 0.15
			K.px(im, xx, yy, granite[clampi(roundi(t * 6.0), 0, 6)])
	K.hline(im, 1, 1, w - 2, granite[6])
	K.outline(im, Color("2a2420"))
	return im


## The amphitheater's stage: a flagstone platform with a granite back wall
## and a ranger's lectern, facing the benches.
func amphi_stage() -> Image:
	var w := 44
	var h := 30
	var im := K.make(w, h)
	K.shadow(im, w / 2.0, h - 2.0, w / 2.0 - 2.0, 2.4, 0.28)
	stone_wall(im, 2, 2, w - 4, 12, 1968, 0.6, 4, 2, false)
	K.hline(im, 2, 2, w - 4, granite[6])
	for yy in range(14, h - 2):
		for xx in range(2, w - 2):
			var t := 0.6 + (K.hash2(xx / 5, yy / 3, 11) - 0.5) * 0.2 + (0.5 - float(yy - 14) / 14.0) * 0.1
			K.px(im, xx, yy, granite[clampi(roundi(t * 6.0), 0, 6)])
			if xx % 5 == 0 or yy % 3 == 0:
				K.px(im, xx, yy, granite[2])
	# the lectern
	K.rect(im, w / 2 - 3, 12, 6, 9, timber[3])
	K.vline(im, w / 2 - 3, 12, 9, timber[5])
	K.rect(im, w / 2 - 4, 11, 8, 2, timber[4])
	K.outline(im, Color("2a2420"))
	return im


## A trail junction post with its routed brown sign arms.
func trail_post() -> Image:
	var w := 18
	var h := 26
	var im := K.make(w, h)
	K.shadow(im, w / 2.0, h - 1.5, 4.0, 1.4, 0.3)
	post(im, 8, 2, h - 3, 31)
	for arm: Array in [[2, 4, true], [8, 10, false], [3, 15, true]]:
		var ax: int = arm[0]
		var ay: int = arm[1]
		K.rect(im, ax, ay, 10, 4, timber[2])
		K.hline(im, ax, ay, 10, timber[4])
		K.hline(im, ax + 2, ay + 2, 6, Color("e8dcb8"))
		if arm[2]:
			K.px(im, ax - 1, ay + 1, timber[2])
			K.px(im, ax - 1, ay + 2, timber[2])
		else:
			K.px(im, ax + 10, ay + 1, timber[2])
			K.px(im, ax + 10, ay + 2, timber[2])
	K.outline(im, Color("231a16"))
	return im


# ---------------------------------------------------------------- trees

## A red fir: the tall, narrow spire of the Glacier Point forest, with short
## dense tiers drooping at their tips, deep blue-green, and the dark
## purple-red bark showing at the foot.
func conifer_fir(variant: int) -> Image:
	var w := 30 if variant == 0 else 26
	var h := 70 if variant == 0 else 60
	var sd := 4100 + variant * 37
	var im := K.make(w, h)
	var cx := w / 2.0
	K.shadow(im, cx, h - 2.5, w / 2.0 - 3.0, 2.4, 0.3)
	for yy in range(h - 16, h - 2):
		var half := 1.8 + maxf(0.0, float(yy - (h - 6)) / 4.0) * 1.2
		for xx in range(floori(cx - half), ceili(cx + half)):
			var u := (xx - (cx - half)) / (half * 2.0)
			var t := 0.7 - u * 0.6 + (K.hash2(xx, yy / 2, sd) - 0.5) * 0.2
			K.px(im, xx, yy, bark_red[clampi(roundi(t * 5.0), 0, 5)])
	var tiers := 10 if variant == 0 else 8
	var crown_h := h - 14
	for yy in range(1, crown_h):
		var f := float(yy) / crown_h
		var tier_f := fmod(f * tiers, 1.0)
		# the outline: a narrow spire, each tier flaring and drooping at the tip
		var half := 1.0 + f * (w / 2.0 - 2.0) * (0.72 + tier_f * 0.28)
		for xx in w:
			var dx := xx + 0.5 - cx
			var v := vnoise(xx * 0.45, yy * 0.5, sd)
			if absf(dx) > half + (v - 0.5) * 2.0:
				continue
			var t := 0.5 + (v - 0.5) * 0.6 - dx / (half + 1.0) * 0.32 - tier_f * 0.3 + (1.0 - f) * 0.12
			K.px(im, xx, yy, fir_leaf[clampi(roundi(t * 6.0), 0, 6)])
	K.px(im, int(cx), 0, fir_leaf[4])
	K.outline(im, Color("101c1c"))
	return im


## A Jeffrey pine: an open, lopsided crown of tufted clumps on stout limbs,
## and a straight trunk of cinnamon-red plates.
func jeffrey(variant: int) -> Image:
	var w := 38 if variant == 0 else 34
	var h := 66 if variant == 0 else 58
	var sd := 5200 + variant * 53
	var im := K.make(w, h)
	var cx := w / 2.0
	K.shadow(im, cx, h - 2.5, w / 2.0 - 4.0, 2.6, 0.3)
	# trunk: plates lit on the left, dark seams between
	for yy in range(16, h - 2):
		var half := 2.4 + maxf(0.0, float(yy - (h - 7)) / 5.0) * 1.4
		for xx in range(floori(cx - half), ceili(cx + half)):
			var u := (xx - (cx - half)) / (half * 2.0)
			var t := 0.8 - u * 0.65 + (K.hash2(xx / 2, yy / 3, sd) - 0.5) * 0.25
			if (yy + xx / 2) % 4 == 0:
				t -= 0.3
			K.px(im, xx, yy, bark_cinnamon[clampi(roundi(t * 5.0), 0, 5)])
	# clumps of needles at the ends of limbs, more on one side
	var clumps := [[0.5, 6, 7.0], [0.3, 14, 8.0], [0.72, 15, 7.5], [0.2, 25, 7.0], [0.62, 26, 8.5],
		[0.4, 35, 7.0], [0.8, 36, 6.0], [0.25, 42, 5.5]]
	if variant == 1:
		clumps = [[0.5, 6, 6.5], [0.35, 14, 7.0], [0.7, 16, 7.0], [0.3, 26, 7.5], [0.66, 28, 6.5], [0.5, 36, 6.0]]
	for cl: Array in clumps:
		var ccx: float = cl[0] * w
		var ccy: float = cl[1]
		var r: float = cl[2]
		# the limb out to the clump
		var steps := int(absf(ccx - cx))
		for s in steps:
			var lx := int(cx + signf(ccx - cx) * s)
			K.px(im, lx, int(ccy + 3 + s * 0.1), bark_cinnamon[1])
		for yy in range(int(ccy - r), int(ccy + r * 0.8)):
			for xx in range(int(ccx - r - 1), int(ccx + r + 1)):
				var dx := (xx + 0.5 - ccx) / r
				var dy := (yy + 0.5 - ccy) / (r * 0.75)
				var v := vnoise(xx * 0.5, yy * 0.5, sd)
				if dx * dx + dy * dy > 1.0 + (v - 0.5) * 0.8:
					continue
				var t := 0.55 - dx * 0.25 - dy * 0.3 + (v - 0.5) * 0.7
				K.px(im, xx, yy, pine_leaf[clampi(roundi(t * 6.0), 0, 6)])
	K.outline(im, Color("16201a"))
	return im


## A lodgepole pine: thin and straight, with a short narrow crown.
func lodgepole() -> Image:
	var w := 18
	var h := 56
	var sd := 6100
	var im := K.make(w, h)
	var cx := w / 2.0
	K.shadow(im, cx, h - 2.0, 5.0, 1.8, 0.28)
	for yy in range(20, h - 2):
		K.px(im, int(cx) - 1, yy, BARK_LIGHT)
		K.px(im, int(cx), yy, Color("6e5a46") if (yy % 5) else Color("4a3a2e"))
	for yy in range(2, 40):
		var f := float(yy) / 40.0
		var half := 1.0 + sin(f * PI * 0.9) * 6.5
		for xx in w:
			var dx := xx + 0.5 - cx
			var v := vnoise(xx * 0.5, yy * 0.45, sd)
			if absf(dx) > half + (v - 0.5) * 2.5:
				continue
			var t := 0.5 + (v - 0.5) * 0.8 - dx / (half + 1.0) * 0.3
			K.px(im, xx, yy, pine_leaf[clampi(roundi(t * 6.0), 0, 6)])
	K.outline(im, Color("16201a"))
	return im

const BARK_LIGHT := Color("8a735a")


## A silver snag: a dead fir weathered gray, its broken limbs bare.
func snag() -> Image:
	var w := 22
	var h := 54
	var sd := 6600
	var im := K.make(w, h)
	var cx := w / 2.0
	K.shadow(im, cx, h - 2.0, 5.0, 1.8, 0.28)
	for yy in range(4, h - 2):
		var half := 1.2 + float(yy) / h * 1.6
		for xx in range(floori(cx - half), ceili(cx + half)):
			var u := (xx - (cx - half)) / (half * 2.0)
			var t := 0.85 - u * 0.6 + (K.hash2(xx, yy / 3, sd) - 0.5) * 0.2
			K.px(im, xx, yy, silver[clampi(roundi(t * 5.0), 0, 5)])
	for i in 7:
		var ly := 10 + i * 5
		var dir := -1 if i % 2 == 0 else 1
		var length := 3 + int(K.hash2(i, 3, sd) * 5.0)
		for s in length:
			K.px(im, int(cx + dir * (2 + s)), ly - s / 2, silver[3 if dir < 0 else 2])
	K.outline(im, Color("221e1c"))
	return im


## The Jeffrey pine of Sentinel Dome, lying where it fell in 2003: a
## twisted, wind-bleached trunk and its broken crown of bare limbs across the
## granite.
func fallen_jeffrey() -> Image:
	var w := 72
	var h := 24
	var sd := 2003
	var im := K.make(w, h)
	K.shadow(im, w / 2.0, h - 4.0, w / 2.0 - 6.0, 3.0, 0.3)
	# the trunk lies left to right, thick at the root, which is still
	# anchored in a crack at the right end
	for xx in range(6, w - 4):
		var u := float(xx - 6) / (w - 10)
		var half := 1.4 + u * 3.2
		var cy := 14.0 + sin(u * 5.0) * 1.2
		for yy in range(int(cy - half), int(cy + half) + 1):
			var t := 0.85 - (yy - (cy - half)) / (half * 2.0) * 0.6 + (K.hash2(xx / 3, yy, sd) - 0.5) * 0.18
			if (xx + yy * 3) % 9 == 0:
				t -= 0.25
			K.px(im, xx, yy, silver[clampi(roundi(t * 5.0), 0, 5)])
	# the root plate
	for yy in range(6, 20):
		for xx in range(w - 8, w - 1):
			if K.hash2(xx, yy, sd + 1) < 0.55 + (1.0 - absf(yy - 13) / 7.0) * 0.4:
				K.px(im, xx, yy, silver[1 + int(K.hash2(xx, yy, sd + 2) * 3.0)])
	# bare limbs, twisted
	for b: Array in [[10, -1], [16, 1], [22, -1], [30, 1], [38, -1]]:
		var bx: int = b[0]
		var dir: int = b[1]
		for s in 6:
			K.px(im, bx + s / 2, 13 + dir * (2 + s), silver[4 if dir < 0 else 2])
	K.outline(im, Color("221e1c"))
	return im


# ---------------------------------------------------------------- the view

## The drop's colors, from the game's palette (tools/art32/palette.py), so the
## 32px upgrade keeps them exactly: the vista shader finds the haze by color.
const V_HAZE := Color("235679")
const V_SHADOW := Color("2d3050")
const V_GRANITE := [Color("2b2a30"), Color("47464d"), Color("6a6a70"), Color("93918f"), Color("bdb8ae"), Color("e4ddcc")]


## True where an ordered dither of coverage [param t] is on at (x, y).
static func _on(t: float, x: int, y: int) -> bool:
	return t > (BAYER[(y & 3) * 4 + (x & 3)] + 0.5) / 16.0


## [param a], or [param b] wherever a dither of coverage [param t] is on.
static func _mix(a: Color, b: Color, t: float, x: int, y: int) -> Color:
	return b if _on(t, x, y) else a


## The drop past an overlook's rim, one picture the size of the map:
## transparent over the ground, and wherever [param drop] is set (a tile past
## the edge), the haze color, which the vista shader
## (assets/shaders/vista.gdshader) replaces with a painting of the view. Drawn
## in: the lip, a lit granite edge with a dark contact line under it, and the
## cliff's own shadow dithered over the view just below it.
func view_below(drop: PackedByteArray, tw: int, th: int) -> Image:
	var T16 := 16
	var pw := tw * T16
	var ph := th * T16
	var im := K.make(pw, ph)
	var sd := 3200
	# Distance (in tiles) from the land, per tile: -0.5 on land, then 0.5, 1.5...
	var dist := PackedFloat32Array()
	dist.resize(tw * th)
	var queue: Array[Vector2i] = []
	for ty in th:
		for tx in tw:
			var k := ty * tw + tx
			if drop[k]:
				dist[k] = 1e9
			else:
				dist[k] = -0.5
				queue.append(Vector2i(tx, ty))
	var head := 0
	while head < queue.size():
		var c := queue[head]
		head += 1
		var nd := 0.5 if dist[c.y * tw + c.x] < 0.0 else dist[c.y * tw + c.x] + 1.0
		for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n := c + d
			if n.x < 0 or n.y < 0 or n.x >= tw or n.y >= th:
				continue
			var nk := n.y * tw + n.x
			if dist[nk] > nd:
				dist[nk] = nd
				queue.append(n)
	for py in ph:
		for px_ in pw:
			# the rim, blended between tile centers and roughened with noise
			var fx := px_ / float(T16) - 0.5
			var fy := py / float(T16) - 0.5
			var x0 := clampi(floori(fx), 0, tw - 1)
			var y0 := clampi(floori(fy), 0, th - 1)
			var x1 := mini(x0 + 1, tw - 1)
			var y1 := mini(y0 + 1, th - 1)
			var ax := clampf(fx - x0, 0.0, 1.0)
			var ay := clampf(fy - y0, 0.0, 1.0)
			var d := lerpf(lerpf(minf(dist[y0 * tw + x0], 40.0), minf(dist[y0 * tw + x1], 40.0), ax),
				lerpf(minf(dist[y1 * tw + x0], 40.0), minf(dist[y1 * tw + x1], 40.0), ax), ay)
			var dpx := d * T16 + (vnoise(px_ * 0.18, py * 0.18, sd) - 0.5) * 6.0
			if dpx <= 0.0:
				continue
			var col := V_HAZE
			# the cliff's own shadow on the view just under the lip
			if dpx < 26.0:
				col = _mix(col, V_SHADOW, (1.0 - dpx / 26.0) * 0.8, px_, py)
			# the lip: a lit granite edge with a dark contact line under it
			if dpx < 2.5:
				col = V_GRANITE[4] if dpx < 1.3 else V_GRANITE[1]
			im.set_pixel(px_, py, col)
	return im


static func _dist_to_line(p: Vector2, pts: Array, scale: float) -> float:
	var best := 1e9
	for i in pts.size() - 1:
		var a: Vector2 = pts[i] * scale
		var b: Vector2 = pts[i + 1] * scale
		best = minf(best, p.distance_to(Geometry2D.get_closest_point_to_segment(p, a, b)))
	return best
