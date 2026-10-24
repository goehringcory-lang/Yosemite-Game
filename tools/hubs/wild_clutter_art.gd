extends "res://tools/hubs/town_clutter_art.gd"
## The small things on the ground of the hubs outside the towns, so a forest
## floor reads as a forest floor and a campsite as somebody's camp: drifts of
## needles, cones, fallen twigs, pebbles, flat glacier-polished slabs, oak
## leaf litter, sedge and dry-grass tufts, seedlings, and the campers' gear
## (coolers, folding chairs, lanterns, water jugs, a clothesline with a towel,
## a camp stove, a pair of boots drying). Drawn at the 16px scale in the town
## clutter's style and written to assets/sprites/clutter/ with a wild_ or
## camp_ prefix; tools/hubs/rebuild_wild_dressing.sh upgrades them to the 32px
## art and lays them out (tools/hubs/dress_wilds.gd).
##
## The flat ones (FLAT) have no outline and lie under everyone; the rest
## stand up and sort with the people.

const FLAT := ["wild_needles_a", "wild_needles_b", "wild_cones", "wild_twigs", "wild_pebbles",
	"wild_slab_a", "wild_slab_b", "wild_leaves", "wild_lichen"]


func save_all() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(CLUTTER_DIR))
	var sheets := {
		"wild_needles_a": needles(18, 8, 401), "wild_needles_b": needles(13, 6, 402),
		"wild_cones": cones(), "wild_twigs": twigs(), "wild_pebbles": pebbles(),
		"wild_slab_a": slab(26, 11, 403), "wild_slab_b": slab(18, 8, 404),
		"wild_leaves": leaves(), "wild_lichen": lichen(),
		"wild_sedge": tuft(Color("5e8a3a"), 405), "wild_dry_grass": tuft(Color("c8a050"), 406),
		"wild_seedling": seedling(),
		"camp_cooler": cooler(), "camp_chair": camp_chair(), "camp_lantern": lantern_stand(),
		"camp_jug": water_jug(), "camp_clothesline": clothesline(), "camp_stove": camp_stove(),
		"camp_boots": boots(), "camp_crashpad": crash_pad(), "camp_rope": rope_coil(),
		"camp_haulbag": haul_bag(),
	}
	for sprite_name: String in sheets:
		(sheets[sprite_name] as Image).save_png(ProjectSettings.globalize_path(CLUTTER_DIR + sprite_name + ".png"))


## A soft-edged drift of fallen needles: a few strokes of rust and tan lying
## every which way over a faint shadow, no outline.
func needles(w: int, h: int, sd: int) -> Image:
	var im := K.make(w, h)
	var tones := [Color("7a4a2a"), Color("9a6438"), Color("b07a46"), Color("6a4a30")]
	for i in w * h / 5:
		var x := int(K.hash2(i, 1, sd) * w)
		var y := int(K.hash2(i, 2, sd) * h)
		var dx := (x + 0.5 - w / 2.0) / (w / 2.0)
		var dy := (y + 0.5 - h / 2.0) / (h / 2.0)
		if dx * dx + dy * dy > 0.9:
			continue
		var col: Color = tones[int(K.hash2(i, 3, sd) * tones.size()) % tones.size()]
		# each needle is a short stroke, flat or a little slanted
		var slant := 1 if K.hash2(i, 4, sd) > 0.5 else -1
		var flat := K.hash2(i, 5, sd) > 0.4
		for s in 3:
			var px_x := x + s
			var px_y := y if flat else y + (s * slant) / 2
			if px_x < w and px_y >= 0 and px_y < h:
				K.px(im, px_x, px_y, col)
	return im


## Three or four lodgepole cones, small and egg-shaped, scales lit on top.
func cones() -> Image:
	var im := K.make(12, 7)
	K.shadow(im, 6.0, 5.0, 5.5, 1.4, 0.18)
	for spot: Array in [[2, 3], [6, 2], [8, 4], [4, 5]]:
		var x: int = spot[0]
		var y: int = spot[1]
		K.rect(im, x, y, 3, 2, Color("6a4428"))
		K.px(im, x, y, Color("a8784a"))
		K.px(im, x + 1, y, Color("8a5a34"))
		K.px(im, x + 2, y + 1, Color("4a2e1a"))
	return im


## A fallen branch with two side twigs, grey-brown, lying flat.
func twigs() -> Image:
	var im := K.make(20, 8)
	var bark := Color("6e5a48")
	var lit := Color("9a8670")
	for x in range(1, 18):
		var y := 4 + int(roundf(sin(x * 0.4) * 0.8))
		K.px(im, x, y, bark)
		if x % 3 == 0:
			K.px(im, x, y - 1, lit)
	for t: Array in [[6, -1], [12, 1], [15, -1]]:
		var tx: int = t[0]
		for s in 3:
			K.px(im, tx + s, 4 + int(t[1]) * (s + 1), bark)
	K.px(im, 18, 4, Color("4a3a2e"))
	return im


## A few pebbles of granite and darker stone, each lit on its upper left.
func pebbles() -> Image:
	var im := K.make(13, 7)
	var stone := _ramp5(Color("9a948a"))
	var dark := _ramp5(Color("6e6a66"))
	for spot: Array in [[2, 3, stone], [6, 2, dark], [9, 4, stone], [5, 5, stone]]:
		var x: int = spot[0]
		var y: int = spot[1]
		var ramp: Array[Color] = spot[2]
		K.rect(im, x, y, 2, 2, ramp[2])
		K.px(im, x, y, ramp[4])
		K.px(im, x + 1, y + 1, ramp[0])
		K.px(im, x, y + 2, Color(0.05, 0.03, 0.02, 0.22))
		K.px(im, x + 1, y + 2, Color(0.05, 0.03, 0.02, 0.22))
	return im


## A flat slab of glacier-polished granite showing through the duff: pale,
## with a lit upper edge, a darker lower lip, a crack and a sheen of polish.
func slab(w: int, h: int, sd: int) -> Image:
	var im := K.make(w, h)
	var g := _ramp5(Color("b8b2a4"))
	for y in h:
		for x in w:
			var dx := (x + 0.5 - w / 2.0) / (w / 2.0)
			var dy := (y + 0.5 - h / 2.0) / (h / 2.0)
			var d := dx * dx + dy * dy + (K.hash2(x / 2, y / 2, sd) - 0.5) * 0.3
			if d > 0.95:
				continue
			var col := g[2]
			if dy < -0.55:
				col = g[3]
			elif dy > 0.6:
				col = g[1]
			if K.hash2(x, y, sd + 1) > 0.94:
				col = g[1]
			K.px(im, x, y, col)
			if d > 0.78 and dy > 0.0:
				K.px(im, x, y, g[0])
	# the polish: a short bright streak
	for x in range(w / 4, w / 4 + w / 5):
		K.px(im, x, h / 3, g[4])
	# a crack across it
	var cx := w * 2 / 3
	for y in range(1, h - 1):
		K.px(im, cx + (y % 3) / 2 - 1, y, g[0])
	return im


## Fallen oak leaves, brown and gold, in a loose drift.
func leaves() -> Image:
	var im := K.make(16, 8)
	var tones := [Color("a8682e"), Color("c8903a"), Color("8a5428"), Color("d8b050")]
	for i in 14:
		var x := 1 + int(K.hash2(i, 1, 411) * 13)
		var y := 1 + int(K.hash2(i, 2, 411) * 5)
		var col: Color = tones[i % tones.size()]
		K.px(im, x, y, col)
		K.px(im, x + 1, y, col.darkened(0.15))
		if i % 3 == 0:
			K.px(im, x, y + 1, col.darkened(0.25))
	return im


## A low rock with crusts of lichen: lime and rust spots on grey.
func lichen() -> Image:
	var im := slab(14, 7, 412)
	for i in 7:
		var x := 2 + int(K.hash2(i, 1, 413) * 10)
		var y := 1 + int(K.hash2(i, 2, 413) * 4)
		if im.get_pixel(x, y).a > 0.5:
			K.px(im, x, y, Color("b8c454") if i % 3 else Color("c87a3a"))
	return im


## A tuft of sedge or dry grass: blades fanning up from a dark base.
func tuft(base: Color, sd: int) -> Image:
	var im := K.make(10, 9)
	K.shadow(im, 5.0, 7.5, 4.0, 1.0, 0.2)
	var ramp := _ramp5(base)
	for b in 7:
		var bx := 1.5 + b * 1.2
		var lean := (bx - 5.0) * 0.35
		var tall := 4 + int(K.hash2(b, 1, sd) * 3)
		for s in tall:
			var x := int(roundf(bx + lean * s / tall))
			var col := ramp[1] if s < 2 else (ramp[3] if s == tall - 1 else ramp[2])
			K.px(im, x, 7 - s, col)
	K.hline(im, 3, 7, 4, ramp[0])
	return im


## A lodgepole seedling, knee high: three tiers of needles on a thin stem.
func seedling() -> Image:
	var im := K.make(9, 13)
	K.shadow(im, 4.5, 11.5, 3.5, 1.0, 0.24)
	var green := _ramp5(Color("3e6a3a"))
	K.vline(im, 4, 3, 9, Color("6a4a30"))
	for tier: Array in [[7, 4], [4, 3], [1, 2]]:
		var y: int = tier[0]
		var half: int = tier[1]
		K.hline(im, 4 - half, y + 1, half * 2 + 1, green[1])
		K.hline(im, 4 - half + 1, y, half * 2 - 1, green[2])
		K.px(im, 4 - half + 1, y, green[4])
	K.px(im, 4, 0, green[3])
	K.outline(im)
	return im


## A camp cooler: a red box with a white lid and a handle.
func cooler() -> Image:
	var im := K.make(16, 12)
	K.shadow(im, 8.0, 10.5, 7.0, 1.3, 0.3)
	var red := _ramp5(Color("b8402e"))
	var white := _ramp5(Color("e8e4d8"))
	K.rect(im, 1, 2, 14, 3, white[3])
	K.hline(im, 1, 2, 14, white[4])
	K.hline(im, 1, 4, 14, white[1])
	K.rect(im, 1, 5, 14, 5, red[2])
	K.vline(im, 1, 5, 5, red[4])
	K.vline(im, 14, 5, 5, red[0])
	K.hline(im, 1, 9, 14, red[0])
	K.hline(im, 5, 1, 6, Color("3a3a3e"))
	K.rect(im, 6, 6, 4, 1, white[2])
	K.outline(im)
	return im


## A folding camp chair in green canvas on a steel frame.
func camp_chair() -> Image:
	var im := K.make(12, 14)
	K.shadow(im, 6.0, 12.5, 5.0, 1.2, 0.28)
	var canvas := _ramp5(Color("3a6a5a"))
	var steel := Color("8a8a8e")
	# the legs, crossed
	for i in 5:
		K.px(im, 2 + i, 8 + i, steel)
		K.px(im, 9 - i, 8 + i, steel)
	# the back and the seat
	K.rect(im, 2, 1, 8, 6, canvas[2])
	K.hline(im, 2, 1, 8, canvas[4])
	K.vline(im, 2, 1, 6, canvas[3])
	K.rect(im, 1, 7, 10, 2, canvas[1])
	K.hline(im, 1, 7, 10, canvas[3])
	K.vline(im, 1, 4, 4, steel)
	K.vline(im, 10, 4, 4, steel)
	K.outline(im)
	return im


## A camp lantern on a stake: a green hood over a glass globe.
func lantern_stand() -> Image:
	var im := K.make(8, 18)
	K.shadow(im, 4.0, 16.5, 3.0, 1.0, 0.26)
	K.vline(im, 3, 6, 11, Color("4a3a2e"))
	K.vline(im, 4, 6, 11, Color("6a5440"))
	K.hline(im, 1, 3, 6, Color("2e5a3a"))
	K.hline(im, 2, 2, 4, Color("3e7a4a"))
	K.rect(im, 2, 4, 4, 3, Color("f0d890"))
	K.px(im, 2, 4, Color("fff4c8"))
	K.hline(im, 2, 7, 4, Color("2e5a3a"))
	K.px(im, 3, 1, Color("8a8a8e"))
	K.outline(im)
	return im


## A blue water jug with a spigot.
func water_jug() -> Image:
	var im := K.make(10, 12)
	K.shadow(im, 5.0, 10.5, 4.0, 1.0, 0.28)
	var blue := _ramp5(Color("3a70a8"))
	K.rect(im, 1, 3, 8, 7, blue[2])
	K.vline(im, 1, 3, 7, blue[4])
	K.vline(im, 2, 3, 7, blue[3])
	K.vline(im, 8, 3, 7, blue[0])
	K.hline(im, 1, 3, 8, blue[3])
	K.rect(im, 3, 1, 4, 2, blue[1])
	K.hline(im, 3, 1, 4, blue[3])
	K.rect(im, 4, 7, 2, 1, Color("e8e4d8"))
	K.outline(im)
	return im


## A clothesline between two poles, with a striped towel and a shirt on it.
func clothesline() -> Image:
	var im := K.make(32, 18)
	K.shadow(im, 3.0, 16.5, 2.0, 0.8, 0.24)
	K.shadow(im, 29.0, 16.5, 2.0, 0.8, 0.24)
	for pole in [2, 29]:
		K.vline(im, pole, 2, 15, Color("6a4a30"))
		K.vline(im, pole + 1, 2, 15, Color("8a6440"))
	for x in range(4, 29):
		var sag := int(roundf(sin(PI * (x - 4) / 25.0) * 2.0))
		K.px(im, x, 3 + sag, Color("d8d0bc"))
	# a striped towel
	for y in 6:
		var col := Color("e8c050") if y % 3 == 0 else Color("c84a3a")
		K.hline(im, 8, 5 + y, 6, col)
	K.vline(im, 13, 5, 6, Color("8a3028"))
	# a shirt
	K.rect(im, 18, 5, 6, 5, Color("6a8ab0"))
	K.hline(im, 17, 5, 8, Color("8aa8c8"))
	K.vline(im, 23, 5, 5, Color("4a6a8a"))
	K.outline(im)
	return im


## A two-burner camp stove, green, its lid propped open.
func camp_stove() -> Image:
	var im := K.make(14, 11)
	K.shadow(im, 7.0, 9.5, 6.0, 1.2, 0.28)
	var green := _ramp5(Color("3e7a4a"))
	K.rect(im, 1, 1, 12, 3, green[3])
	K.hline(im, 1, 1, 12, green[4])
	K.rect(im, 1, 4, 12, 5, green[2])
	K.hline(im, 1, 8, 12, green[0])
	K.vline(im, 12, 4, 5, green[0])
	for bx in [3, 8]:
		K.rect(im, bx, 5, 3, 2, Color("2a2a2e"))
		K.px(im, bx + 1, 5, Color("5a5a60"))
	K.outline(im)
	return im


## A pair of hiking boots set out to dry.
func boots() -> Image:
	var im := K.make(11, 8)
	K.shadow(im, 5.5, 6.5, 5.0, 1.0, 0.26)
	var leather := _wood(Color("7a5034"))
	for bx in [1, 6]:
		K.rect(im, bx, 1, 3, 4, leather[2])
		K.px(im, bx, 1, leather[4])
		K.rect(im, bx, 5, 4, 1, leather[1])
		K.hline(im, bx, 6, 4, Color("3a2a22"))
		K.px(im, bx + 1, 2, Color("c84a3a"))
	K.outline(im)
	return im


## A folded bouldering crash pad, blue with a red flap, leaning on its side.
func crash_pad() -> Image:
	var im := K.make(20, 12)
	K.shadow(im, 10.0, 10.5, 9.0, 1.3, 0.3)
	var blue := _ramp5(Color("3a5a8a"))
	K.rect(im, 1, 2, 18, 8, blue[2])
	K.hline(im, 1, 2, 18, blue[4])
	K.hline(im, 1, 6, 18, blue[0])
	K.vline(im, 18, 2, 8, blue[0])
	K.rect(im, 3, 3, 5, 3, Color("b8402e"))
	K.hline(im, 10, 4, 6, Color("2a2a2e"))
	K.outline(im)
	return im


## A climbing rope coiled on the ground, with its tail.
func rope_coil() -> Image:
	var im := K.make(14, 8)
	K.shadow(im, 7.0, 6.0, 6.0, 1.2, 0.26)
	var rope := Color(0.702, 0.212, 0.169)
	K.ellipse(im, 6.5, 4.0, 5.5, 2.8, rope.darkened(0.25))
	K.ellipse(im, 6.5, 3.6, 3.4, 1.6, rope)
	K.ellipse(im, 6.5, 3.6, 1.6, 0.7, rope.darkened(0.4))
	K.hline(im, 4, 2, 5, rope.lightened(0.3))
	K.hline(im, 11, 6, 3, rope)
	K.outline(im)
	return im


## A big-wall haul bag, scuffed red, with its shoulder straps.
func haul_bag() -> Image:
	var im := K.make(10, 16)
	K.shadow(im, 5.0, 14.5, 4.5, 1.2, 0.3)
	var red := _ramp5(Color("a83a2e"))
	K.rect(im, 1, 3, 8, 11, red[2])
	K.vline(im, 1, 3, 11, red[4])
	K.vline(im, 8, 3, 11, red[0])
	K.ellipse(im, 4.5, 3.0, 4.0, 1.5, red[3])
	K.vline(im, 3, 4, 9, Color("2a2a2e"))
	K.vline(im, 6, 4, 9, Color("2a2a2e"))
	K.hline(im, 2, 9, 6, red[1])
	K.px(im, 4, 1, Color("8a8a8e"))
	K.outline(im)
	return im
