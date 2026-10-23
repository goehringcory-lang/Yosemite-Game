extends "res://tools/hubs/curry_ahwahnee_art.gd"
## The small things that make a town look lived in, for the plazas, lawns and
## lots of Curry Village and Yosemite Village: crates, barrels, milk cans,
## park trash cans, picnic tables, a newspaper rack, a mailbox, a sandwich
## board, flower beds, a wheelbarrow, a parked bicycle, bundles of firewood,
## an ice chest, suitcases, edging stones and worn patches of lawn. Drawn at
## the 16px scale in the Curry Village props' style (ramp-shaded, lit from the
## upper left, dark outline) and written to assets/sprites/clutter/; run
## through tools/art32/upgrade.py --fresh like the other hub art.
##
##   tools/hubs/rebuild_clutter.sh

const CLUTTER_DIR := "res://assets/sprites/clutter/"


func save_all() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(CLUTTER_DIR))
	var sheets := {
		"crate": crate(), "crate_stack": crate_stack(), "barrel": barrel(), "milk_cans": milk_cans(),
		"trash_can": trash_can(), "picnic_table": picnic_table(), "newspaper_rack": newspaper_rack(),
		"mailbox": mailbox(), "sandwich_board": sandwich_board(), "wheelbarrow": wheelbarrow(),
		"bicycle": bicycle(), "firewood": firewood(), "ice_chest": ice_chest(), "suitcases": suitcases(),
		"edging": edging(), "worn_patch_a": worn_patch(40, 12, 11), "worn_patch_b": worn_patch(30, 10, 12),
	}
	for i in 3:
		sheets["flower_bed_%d" % i] = flower_bed(i)
	for sprite_name: String in sheets:
		(sheets[sprite_name] as Image).save_png(ProjectSettings.globalize_path(CLUTTER_DIR + sprite_name + ".png"))


## A wood ramp, dark to light, darkening and lightening without the hue shift
## the buildings use: shifted, a wood's shadows land on the palette's greens.
func _wood(base: Color) -> Array[Color]:
	return [base.darkened(0.42), base.darkened(0.22), base, base.lightened(0.14), base.lightened(0.28)]


## A box of slats seen from above and in front: a lit lid, a front face of
## boards with a diagonal brace.
func _box(im: Image, x: int, y: int, w: int, h: int, top: int, base: Color, sd: int) -> void:
	var ramp := _wood(base)
	K.rect(im, x, y, w, top, ramp[3])
	K.hline(im, x, y, w, ramp[4])
	for i in range(1, w / 4):
		K.vline(im, x + i * 4, y, top, ramp[2])
	K.rect(im, x, y + top, w, h - top, ramp[2])
	for i in range(1, w / 4 + 1):
		K.vline(im, x + i * 4 - 1, y + top, h - top, ramp[1])
	K.vline(im, x, y + top, h - top, ramp[3])
	K.hline(im, x, y + top, w, ramp[0])
	# the brace, corner to corner
	var fh := h - top
	for t in fh:
		K.px(im, x + int(float(t) / fh * (w - 1)), y + top + t, ramp[1])
	K.vline(im, x + w - 1, y + top, fh, ramp[0])


func crate() -> Image:
	var im := K.make(14, 14)
	K.shadow(im, 7.0, 12.5, 6.5, 1.5, 0.3)
	_box(im, 1, 2, 12, 11, 3, Color("a07a4e"), 301)
	K.outline(im)
	return im


func crate_stack() -> Image:
	var im := K.make(22, 22)
	K.shadow(im, 11.0, 20.5, 10.0, 1.8, 0.3)
	_box(im, 1, 10, 12, 11, 3, Color("a07a4e"), 302)
	_box(im, 12, 13, 9, 8, 2, Color("8e6a44"), 303)
	_box(im, 2, 1, 10, 9, 3, Color("b08656"), 304)
	K.outline(im)
	return im


func barrel() -> Image:
	var im := K.make(14, 16)
	K.shadow(im, 7.0, 14.5, 6.0, 1.4, 0.3)
	var ramp := _wood(Color("8e6440"))
	for yy in 11:
		var bulge := 1 if yy > 1 and yy < 9 else 0
		for xx in range(1 - bulge, 11 + bulge):
			var idx := 2
			if xx <= 2:
				idx = 4 if xx <= 1 else 3
			elif xx >= 9:
				idx = 0
			elif xx % 3 == 0:
				idx = 1
			K.px(im, xx + 1, 3 + yy, ramp[idx])
	for hoop in [5, 11]:
		K.hline(im, 1, hoop, 12, Color("4a4a52"))
		K.px(im, 2, hoop, Color("8a8a92"))
	# the lid, seen from above
	K.ellipse(im, 7.0, 3.0, 5.0, 1.8, ramp[3])
	K.hline(im, 4, 2, 5, ramp[4])
	K.hline(im, 3, 4, 8, ramp[1])
	K.outline(im)
	return im


func milk_cans() -> Image:
	var im := K.make(16, 15)
	K.shadow(im, 8.0, 13.5, 7.0, 1.4, 0.3)
	for can_x in [2, 8]:
		var steel := _ramp5(Color("a8b0b4"))
		K.rect(im, can_x, 5, 6, 8, steel[2])
		K.vline(im, can_x, 5, 8, steel[4])
		K.vline(im, can_x + 1, 5, 8, steel[3])
		K.vline(im, can_x + 5, 5, 8, steel[0])
		K.hline(im, can_x, 9, 6, steel[1])
		K.rect(im, can_x + 1, 2, 4, 3, steel[2])
		K.hline(im, can_x + 1, 2, 4, steel[4])
		K.rect(im, can_x + 2, 1, 2, 1, steel[1])
	K.outline(im)
	return im


## A park trash can: a green steel drum with a domed lid and a pull flap.
func trash_can() -> Image:
	var im := K.make(12, 16)
	K.shadow(im, 6.0, 14.5, 5.5, 1.4, 0.3)
	var ramp := _ramp5(Color("3f6a4a"))
	for xx in 10:
		var idx := 2
		if xx <= 1:
			idx = 4
		elif xx == 2:
			idx = 3
		elif xx >= 8:
			idx = 0
		K.vline(im, 1 + xx, 5, 9, ramp[idx])
	for rib in [7, 10]:
		K.hline(im, 1, rib, 10, ramp[1])
	K.ellipse(im, 6.0, 4.0, 5.4, 2.2, ramp[3])
	K.hline(im, 3, 3, 6, ramp[4])
	K.rect(im, 4, 5, 4, 2, Color("2a2a2e"))
	K.outline(im)
	return im


## A plank picnic table in 3/4 view: the top, a bench either side, A-frame legs.
func picnic_table() -> Image:
	var im := K.make(30, 18)
	K.shadow(im, 15.0, 15.5, 14.0, 2.2, 0.3)
	var ramp := _wood(Color("9a7048"))
	_slat(im, 2, 1, 26, 2, ramp, 311)
	for leg in [5, 24]:
		K.rect(im, leg, 3, 2, 12, ramp[0])
	_slat(im, 3, 6, 24, 2, ramp, 312)
	_slat(im, 3, 8, 24, 2, ramp, 313)
	K.hline(im, 3, 10, 24, ramp[0])
	_slat(im, 1, 12, 28, 2, ramp, 314)
	K.hline(im, 1, 14, 28, ramp[0])
	for leg in [3, 26]:
		K.rect(im, leg, 15, 2, 2, ramp[0])
	K.outline(im)
	return im


func newspaper_rack() -> Image:
	var im := K.make(10, 16)
	K.shadow(im, 5.0, 14.5, 4.5, 1.2, 0.3)
	var red := _ramp5(Color("b8443a"))
	K.rect(im, 1, 2, 8, 9, red[2])
	K.vline(im, 1, 2, 9, red[4])
	K.vline(im, 8, 2, 9, red[0])
	K.hline(im, 1, 1, 8, red[3])
	K.rect(im, 2, 3, 6, 4, Color("d8e0e4"))
	K.hline(im, 3, 4, 4, Color("6a6a70"))
	K.hline(im, 3, 6, 3, Color("6a6a70"))
	K.hline(im, 2, 8, 6, red[1])
	K.vline(im, 2, 11, 3, Color("4a4a52"))
	K.vline(im, 7, 11, 3, Color("4a4a52"))
	K.outline(im)
	return im


## A blue mailbox on its legs with a rounded top and a pull handle.
func mailbox() -> Image:
	var im := K.make(12, 18)
	K.shadow(im, 6.0, 16.5, 5.0, 1.3, 0.3)
	var blue := _ramp5(Color("2f5a8e"))
	K.rect(im, 2, 3, 8, 9, blue[2])
	K.ellipse(im, 6.0, 3.5, 4.0, 2.0, blue[3])
	K.hline(im, 4, 2, 4, blue[4])
	K.vline(im, 2, 3, 9, blue[4])
	K.vline(im, 9, 3, 9, blue[0])
	K.rect(im, 4, 5, 4, 1, Color("1a2a40"))
	K.rect(im, 4, 8, 4, 2, blue[3])
	K.hline(im, 2, 12, 8, blue[0])
	for leg in [3, 8]:
		K.vline(im, leg, 13, 3, Color("2a2a30"))
	K.outline(im)
	return im


## A chalkboard A-frame: "OPEN" and a scrawl of today's special.
func sandwich_board() -> Image:
	var im := K.make(12, 16)
	K.shadow(im, 6.0, 14.5, 5.5, 1.3, 0.3)
	var wood := _wood(Color("8a6440"))
	K.rect(im, 1, 1, 10, 12, wood[2])
	K.vline(im, 1, 1, 12, wood[4])
	K.vline(im, 10, 1, 12, wood[0])
	K.rect(im, 2, 2, 8, 9, Color("2e3a34"))
	K.hline(im, 3, 4, 5, Color("e8e4d4"))
	K.hline(im, 3, 6, 6, Color("c8c4b4"))
	K.hline(im, 3, 8, 4, Color("e8a8a0"))
	K.px(im, 1, 13, wood[0])
	K.px(im, 1, 14, wood[0])
	K.px(im, 10, 13, wood[0])
	K.px(im, 10, 14, wood[0])
	K.outline(im)
	return im


## A long, low bed edged with granite, packed with flowers. Three plantings.
const BED_BLOOMS := [
	["e04a6a", "f2d25c", "f2ecd6", "b06ad0"],
	["f2d25c", "e8a030", "e8704a", "f8e888"],
	["a98ad8", "f2ecd6", "8a6ac8", "e04a6a"],
]


func flower_bed(variant: int) -> Image:
	var blooms: Array = BED_BLOOMS[variant % BED_BLOOMS.size()]
	var im := K.make(34, 12)
	K.shadow(im, 17.0, 10.5, 16.0, 1.4, 0.25)
	var stone := _ramp5(Color("9a948a"))
	K.rect(im, 1, 6, 32, 4, stone[2])
	for i in 8:
		var sx := 1 + i * 4
		K.hline(im, sx, 6, 3, stone[4])
		K.vline(im, sx + 3, 6, 4, stone[0])
	K.hline(im, 1, 9, 32, stone[0])
	K.rect(im, 2, 4, 30, 2, Color("3a2a1e"))
	for i in 15:
		var lx := 2 + i * 2
		K.ellipse(im, lx + 0.5, 4.0 - (i % 2), 1.6, 1.4, Color("3f7a3a"))
		K.px(im, lx, 2 - (i % 2), Color("7ab860"))
	for i in 11:
		var fx := 3 + i * 3 + (i % 2)
		var fy := 1 + (i * 7) % 3
		var col := Color(blooms[i % blooms.size()])
		K.rect(im, fx, fy, 2, 2, col)
		K.px(im, fx, fy, col.lightened(0.3))
		K.px(im, fx + 1, fy + 1, col.darkened(0.25))
	K.outline(im)
	return im


func wheelbarrow() -> Image:
	var im := K.make(20, 13)
	K.shadow(im, 10.0, 11.5, 9.0, 1.3, 0.3)
	var tray := _ramp5(Color("4f7650"))
	for yy in 5:
		K.hline(im, 4 + yy, 3 + yy, 11 - yy, tray[2 if yy > 0 else 4])
	K.hline(im, 4, 3, 11, tray[4])
	K.rect(im, 5, 4, 9, 1, Color("5a4a38"))
	K.hline(im, 13, 7, 6, Color("6e4a2e"))
	K.hline(im, 14, 5, 5, Color("6e4a2e"))
	K.ellipse(im, 5.0, 9.0, 2.4, 2.4, Color("2a2a2e"))
	K.px(im, 5, 9, Color("8a8a92"))
	K.vline(im, 12, 8, 3, Color("4a3424"))
	K.outline(im)
	return im


## A bicycle on its kickstand, side on.
func bicycle() -> Image:
	var im := K.make(20, 13)
	K.shadow(im, 10.0, 11.5, 9.0, 1.2, 0.25)
	for wx in [4.0, 15.0]:
		K.ring(im, wx, 8.0, 3.4, 3.4, Color("2a2a2e"))
		K.px(im, int(wx), 8, Color("8a8a92"))
	var frame := Color("c8402e")
	for t in 8:
		K.px(im, 5 + t, 8 - t / 2, frame)
		K.px(im, 7 + t, 4, frame)
	K.vline(im, 14, 4, 4, frame)
	K.hline(im, 6, 3, 3, Color("3a2a20"))
	K.hline(im, 13, 2, 3, Color("6a6a70"))
	K.outline(im)
	return im


## Bundles of split firewood tied with twine, stacked for sale.
func firewood() -> Image:
	var im := K.make(18, 15)
	K.shadow(im, 9.0, 13.5, 8.0, 1.4, 0.3)
	# log ends: bark round a pale cut face, in three courses
	for row in 3:
		for i in 4 - row:
			var lx := 2 + i * 4 + row * 2
			var ly := 10 - row * 3
			K.ellipse(im, lx + 1.5, ly + 1.5, 2.0, 1.8, Color("5a3a22"))
			K.ellipse(im, lx + 1.5, ly + 1.5, 1.2, 1.1, Color("d8b880") if (i + row) % 2 else Color("c8a46a"))
			K.px(im, lx + 1, ly + 1, Color("f0d8a8"))
	# twine round the bundle, and a price card
	K.vline(im, 9, 4, 9, Color("d8c8a0"))
	K.rect(im, 13, 1, 4, 3, Color("f0ece0"))
	K.px(im, 14, 2, Color("a8402e"))
	K.outline(im)
	return im


## A white ice freezer with ICE on its front, the kind outside every camp store.
func ice_chest() -> Image:
	var im := K.make(20, 16)
	K.shadow(im, 10.0, 14.5, 9.0, 1.4, 0.3)
	var white := _ramp5(Color("e4e4dc"))
	K.rect(im, 1, 3, 18, 3, white[3])
	K.hline(im, 1, 3, 18, white[4])
	K.rect(im, 1, 6, 18, 8, white[2])
	K.vline(im, 1, 6, 8, white[4])
	K.vline(im, 18, 6, 8, white[0])
	K.hline(im, 1, 6, 18, white[0])
	# a blue panel with a snowflake
	K.rect(im, 5, 7, 10, 6, Color("3a78c0"))
	K.hline(im, 8, 10, 5, Color("f4f4ee"))
	K.vline(im, 10, 8, 5, Color("f4f4ee"))
	for d in [[-1, -1], [1, -1], [-1, 1], [1, 1]]:
		K.px(im, 10 + d[0], 10 + d[1], Color("cfe6f8"))
	K.hline(im, 1, 13, 18, white[0])
	K.outline(im)
	return im


## Two suitcases and a hatbox waiting by the door.
func suitcases() -> Image:
	var im := K.make(16, 13)
	K.shadow(im, 8.0, 11.5, 7.5, 1.3, 0.3)
	var brown := _wood(Color("8a5a3a"))
	K.rect(im, 1, 5, 9, 6, brown[2])
	K.hline(im, 1, 5, 9, brown[4])
	K.vline(im, 9, 5, 6, brown[0])
	K.hline(im, 4, 4, 3, brown[0])
	K.vline(im, 3, 5, 6, Color("d8b060"))
	var green := _ramp5(Color("4a6a5a"))
	K.rect(im, 2, 1, 7, 4, green[2])
	K.hline(im, 2, 1, 7, green[4])
	K.vline(im, 8, 1, 4, green[0])
	K.ellipse(im, 12.5, 7.5, 3.0, 3.2, Color("d8c8a8"))
	K.hline(im, 10, 6, 5, Color("a8402e"))
	K.outline(im)
	return im


## A short row of rounded granite edging stones, for the edge of a lawn.
func edging() -> Image:
	var im := K.make(34, 6)
	var stone := _ramp5(Color("9a948a"))
	for i in 6:
		var sx := 1 + i * 5 + (i % 2)
		K.ellipse(im, sx + 2.0, 3.0, 2.4, 1.8, stone[2])
		K.px(im, sx + 1, 2, stone[4])
		K.hline(im, sx + 1, 4, 3, stone[0])
	K.outline(im)
	return im


## A patch of lawn worn to bare earth where people cut across: soft-edged,
## no outline, lying flat under everything.
func worn_patch(w: int, h: int, sd: int) -> Image:
	var im := K.make(w, h)
	for y in h:
		for x in w:
			var dx := (x + 0.5 - w / 2.0) / (w / 2.0)
			var dy := (y + 0.5 - h / 2.0) / (h / 2.0)
			var d := dx * dx + dy * dy + (K.hash2(x, y, sd) - 0.5) * 0.5
			if d < 0.55:
				K.px(im, x, y, Color("9a7a52") if K.hash2(x, y, sd + 1) > 0.25 else Color("86683f"))
			elif d < 0.95 and K.hash2(x, y, sd + 2) > 0.45:
				K.px(im, x, y, Color("8a8a4a"))
	return im
