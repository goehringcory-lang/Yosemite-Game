class_name ClimbScenes
extends RefCounted
## The two ends of a route, painted into the wall picture: the ground at the
## foot of the first pitch (Camp Curry's cabins, Camp 4's tents, El Capitan
## Meadow, the Ahwahnee's lawn, the moraine under Lyell...) and the summit
## above the last pitch (the Glacier Point rim, the Spire's pinnacle, the top
## of El Capitan...).

const P := preload("res://scripts/climb/art/climb_paint.gd")
const L := preload("res://scripts/climb/art/climb_layout.gd")

const EARTH := {
	"curry": ["2a2c20", "3e4a2c", "56683a", "7a8c4c"],
	"camp4": ["2c2a20", "4a4430", "6a6240", "8a8458"],
	"valley_forest": ["26301e", "3a4a2a", "52683a", "74904c"],
	"bridalveil_talus": ["34322e", "4e4c46", "6e6a62", "908a7c"],
	"mist_wall": ["34322e", "4e4c46", "6e6a62", "908a7c"],
	"el_cap_meadow": ["3a4a22", "586e30", "7a9a40", "a0c058"],
	"ahwahnee": ["2a4020", "40622c", "5a8a3a", "7eb04e"],
	"half_dome_forest": ["26301e", "3a4a2a", "52683a", "74904c"],
	"tuolumne": ["3a4630", "586a3a", "7a8c4c", "a0b060"],
	"moraine": ["5a5a64", "7a7a86", "9a9aa8", "c0c0cc"],
}


static func _lit(col: Color, pal: Dictionary) -> Color:
	var tint: Color = pal.get("tint", Color.WHITE)
	var lum: float = pal.get("lum", 1.0)
	var t := col.lerp(Color(col.r * tint.r, col.g * tint.g, col.b * tint.b), 0.7)
	return Color(clampf(t.r * lum, 0, 1), clampf(t.g * lum, 0, 1), clampf(t.b * lum, 0, 1), col.a)


## Paints the ground under the belay ledge of pitch one.
static func paint_base(im: Image, kind: String, state: ClimbState, pal: Dictionary, edge: PackedInt32Array, seed_value: int) -> void:
	if kind == "":
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value + 5
	var w := im.get_width()
	var h := im.get_height()
	var y0 := int(L.wall_px(state.top_row, 0, 0).y) + 7
	var ramp: Array = EARTH.get(kind, EARTH.valley_forest)
	var cols: Array[Color] = []
	for hx: String in ramp:
		cols.append(_lit(Color(hx), pal))
	var x_end := w
	# The ground: a rolling surface with a lit top, needles and rocks.
	for x in w:
		var gy := y0 + int(sin(x * 0.045) * 1.5 + sin(x * 0.11) * 1.0)
		var e := edge[mini(gy, edge.size() - 1)] + 4 if gy < edge.size() else w
		if x > e:
			continue
		im.fill_rect(Rect2i(x, gy, 1, h - gy), cols[1])
		im.fill_rect(Rect2i(x, gy, 1, 2), cols[3])
		im.fill_rect(Rect2i(x, gy + 2, 1, 2), cols[2])
	for i in w * (h - y0) / 24:
		var x := rng.randi_range(0, w - 1)
		var y := rng.randi_range(y0 + 4, h - 1)
		var col := cols[rng.randi_range(0, 2)]
		P.px(im, x, y, col)
		if rng.randf() < 0.3:
			P.px(im, x + 1, y, col.darkened(0.2))
	var rock_like: bool = kind in ["bridalveil_talus", "mist_wall", "moraine"]
	var c := ClimbRock.colors("apron" if kind != "moraine" else "ice", pal)
	# Boulders at the foot of the wall.
	for i in 6 if rock_like else 3:
		var bx := rng.randi_range(8, 250)
		var by := y0 + rng.randi_range(8, 40)
		var br := rng.randi_range(5, 12 if rock_like else 8)
		P.ellipse(im, bx, by + 1, br + 1, br * 0.62 + 1, c.seam)
		P.shaded_ellipse(im, bx, by, br, br * 0.62, ClimbRock.tone(c, 2.4), ClimbRock.tone(c, 3.8), ClimbRock.tone(c, 1.3))
	match kind:
		"curry":
			_tent_cabin(im, 20, y0 + 6, pal, rng, true)
			_tent_cabin(im, 92, y0 + 14, pal, rng, false)
			_trees(im, y0, pal, rng, [6, 196, 250], true)
			_sign(im, 150, y0 + 3, pal, "CAMP CURRY")
		"camp4":
			_tent(im, 30, y0 + 8, pal, rng, Color("d8884a"))
			_tent(im, 100, y0 + 16, pal, rng, Color("4a78b8"))
			_trees(im, y0, pal, rng, [8, 190, 252], false)
			# A picnic table.
			P.rect(im, 160, y0 + 8, 18, 3, _lit(Color("8a5a2a"), pal))
			P.rect(im, 162, y0 + 11, 2, 5, _lit(Color("5a3a1a"), pal))
			P.rect(im, 174, y0 + 11, 2, 5, _lit(Color("5a3a1a"), pal))
		"valley_forest", "half_dome_forest":
			_trees(im, y0, pal, rng, [4, 40, 190, 238, 262], kind == "half_dome_forest")
		"ahwahnee":
			_hotel(im, 4, y0, pal, rng)
			_trees(im, y0, pal, rng, [180, 232, 262], false)
		"el_cap_meadow":
			_trees(im, y0, pal, rng, [10, 262], false)
			for i in 30:
				ClimbProps.tuft(im, rng.randi_range(0, 280), y0 + rng.randi_range(4, 60), rng, pal)
			# Visitors with binoculars, looking up at the wall.
			for i in 3:
				_visitor(im, 60 + i * 38, y0 + 10 + (i % 2) * 6, pal, i)
		"tuolumne":
			ClimbProps.ledge_plant(im, 20, y0 + 8, ["krummholz"], rng, pal)
			_trees(im, y0, pal, rng, [4, 210, 256], true)
			# Granite slabs and a trail sign.
			_sign(im, 120, y0 + 3, pal, "CATHEDRAL")
		"moraine":
			for i in 14:
				var rx := rng.randi_range(4, 280)
				var ry := y0 + rng.randi_range(6, 50)
				P.rect(im, rx, ry, rng.randi_range(2, 5), rng.randi_range(1, 3), _lit(Color("5a5a66"), pal))
			# Snow patches.
			for i in 4:
				P.ellipse(im, rng.randi_range(20, 270), y0 + rng.randi_range(10, 50), rng.randi_range(10, 24), 3, _lit(Color("eef4fa"), pal))
			_cairn(im, 40, y0 + 6, pal)
		"bridalveil_talus", "mist_wall":
			_trees(im, y0, pal, rng, [6, 250], false)
	# The belay ledge is just a spot on the ground at the start.
	var _unused := x_end


static func _trees(im: Image, y0: int, pal: Dictionary, rng: RandomNumberGenerator, xs: Array, conifers: bool) -> void:
	var c := ClimbRock.colors("apron", pal)
	for x: int in xs:
		var y := y0 + rng.randi_range(14, 36)
		var th := rng.randi_range(46, 84)
		if conifers or rng.randf() < 0.5:
			ClimbProps.pine(im, x, y, th, rng, c)
		else:
			ClimbProps.oak(im, x, y, th, rng, c)


static func _tent(im: Image, x: int, y: int, pal: Dictionary, rng: RandomNumberGenerator, color: Color) -> void:
	var col := _lit(color, pal)
	var dark := col.darkened(0.3)
	var lit := col.lightened(0.25)
	for k in 14:
		var half := 14 - k
		P.rect(im, x - half, y - 14 + k, half * 2 + 1, 1, col if k > 3 else lit)
		P.px(im, x - half, y - 14 + k, lit)
		P.px(im, x + half, y - 14 + k, dark)
	P.rect(im, x - 3, y - 6, 6, 6, _lit(Color("2a1f1a"), pal))
	P.rect(im, x - 15, y, 31, 1, dark)
	P.px(im, x, y - 15, _lit(Color("5a3a1a"), pal))


## A Camp Curry tent cabin: white canvas on a wood frame, with a door.
static func _tent_cabin(im: Image, x: int, y: int, pal: Dictionary, rng: RandomNumberGenerator, lit_window: bool) -> void:
	var canvas := _lit(Color("e8e0c8"), pal)
	var shade := canvas.darkened(0.22)
	var wood := _lit(Color("7a4a24"), pal)
	# Walls with a short wood base, then the canvas roof.
	P.rect(im, x, y - 14, 44, 14, canvas)
	P.rect(im, x, y - 14, 3, 14, canvas.lightened(0.15))
	P.rect(im, x + 40, y - 14, 4, 14, shade)
	P.rect(im, x, y - 4, 44, 4, wood)
	P.rect(im, x, y - 4, 44, 1, wood.lightened(0.25))
	for k in 12:
		P.rect(im, x - k + 6, y - 26 + k, 44 - 12 + k * 2 - 6, 1, canvas if k > 2 else canvas.lightened(0.18))
	P.rect(im, x + 2, y - 28, 40, 2, canvas.lightened(0.2))
	P.rect(im, x + 19, y - 12, 8, 12, _lit(Color("3a2a1c"), pal))
	P.rect(im, x + 19, y - 12, 8, 1, wood)
	if lit_window:
		P.rect(im, x + 32, y - 11, 6, 6, _lit(Color("ffd070"), pal))
		P.rect(im, x + 34, y - 11, 1, 6, wood)


static func _sign(im: Image, x: int, y: int, pal: Dictionary, text: String) -> void:
	var wood := _lit(Color("7a4a24"), pal)
	P.rect(im, x, y - 14, 2, 14, wood.darkened(0.2))
	P.rect(im, x + 30, y - 14, 2, 14, wood.darkened(0.2))
	P.rect(im, x - 2, y - 24, 36, 11, wood)
	P.rect(im, x - 2, y - 24, 36, 1, wood.lightened(0.3))
	P.rect(im, x - 2, y - 14, 36, 1, wood.darkened(0.3))
	for i in text.length():
		var ch := text[i]
		if ch != " ":
			P.px(im, x + 1 + i * 3, y - 20, _lit(Color("f2dcaa"), pal))
			P.px(im, x + 1 + i * 3, y - 18, _lit(Color("f2dcaa"), pal))
			P.px(im, x + 2 + i * 3, y - 19, _lit(Color("f2dcaa"), pal))


static func _hotel(im: Image, x: int, y: int, pal: Dictionary, rng: RandomNumberGenerator) -> void:
	# The Ahwahnee: a long stone-and-timber hall with a green-brown roof and
	# lit windows, seen from the foot of the wall.
	var stone := _lit(Color("a89878"), pal)
	var roof := _lit(Color("5a4a34"), pal)
	var win := _lit(Color("ffd070"), pal)
	P.rect(im, x, y + 12, 120, 30, stone)
	P.rect(im, x, y + 12, 120, 2, stone.lightened(0.25))
	P.rect(im, x, y + 40, 120, 2, stone.darkened(0.3))
	for k in 10:
		P.rect(im, x - 2 + k, y + 2 + k, 124 - k * 2, 1, roof if k > 0 else roof.lightened(0.2))
	for i in 9:
		P.rect(im, x + 8 + i * 12, y + 22, 5, 9, win if i % 3 != 1 else win.darkened(0.2))
		P.rect(im, x + 8 + i * 12, y + 22, 5, 1, stone.darkened(0.3))
	P.rect(im, x + 54, y + 28, 12, 14, _lit(Color("2a1f1a"), pal))


static func _visitor(im: Image, x: int, y: int, pal: Dictionary, i: int) -> void:
	var shirt := _lit([Color("c84a3a"), Color("4a78c8"), Color("e8c040")][i % 3], pal)
	P.rect(im, x - 2, y - 12, 5, 7, shirt)
	P.rect(im, x - 2, y - 5, 5, 6, _lit(Color("4a4a58"), pal))
	P.rect(im, x - 1, y - 16, 3, 4, _lit(Color("e0ac7e"), pal))
	P.rect(im, x - 2, y - 17, 5, 2, _lit(Color("5a3a22"), pal))
	P.px(im, x + 2, y - 14, _lit(Color("1a1a20"), pal))
	P.px(im, x + 3, y - 15, _lit(Color("1a1a20"), pal))


static func _cairn(im: Image, x: int, y: int, pal: Dictionary) -> void:
	var g := _lit(Color("7a7a86"), pal)
	P.ellipse(im, x, y - 2, 6, 3, g.darkened(0.2))
	P.ellipse(im, x, y - 6, 4, 2.5, g)
	P.ellipse(im, x, y - 9, 3, 2, g.lightened(0.15))
	P.px(im, x - 1, y - 11, g.lightened(0.3))


# ---------------------------------------------------------------- finishes

## Paints what's above the last ledge: cuts the wall away to a summit shape
## and dresses it.
static func paint_finish(im: Image, kind: String, state: ClimbState, pal: Dictionary, edge: PackedInt32Array, seed_value: int) -> void:
	if kind == "":
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value + 9
	var w := im.get_width()
	var y_top := int(L.wall_px(state.top_row, state.top_row, 0).y) + 7
	var cx := int(L.GRID_X + 2.5 * L.COL_W)
	var c := ClimbRock.colors("apron", pal)
	# How much rock stands above the ledge, by summit type.
	var shape := "lip"
	match kind:
		"spire_top", "peak_summit":
			shape = "spire"
		"dome_top":
			shape = "dome"
		"column_top", "chimney_top", "arches_top", "el_cap_top":
			shape = "lip_high"
		"glacier_ridge":
			shape = "ridge"
		"tree_ledge", "anchor":
			shape = "lip_high"
	for y in range(0, y_top):
		var above := y_top - y
		var lo := 0
		var hi := w
		match shape:
			"lip":
				if above > 12:
					hi = 0
			"lip_high":
				if above > 22:
					hi = 0
			"spire":
				var half := maxi(int(70.0 - above * 0.62), 0)
				lo = cx - half
				hi = cx + half + 6
				if above > 112:
					hi = 0
			"dome":
				var half := int(sqrt(maxf(1.0 - pow(above / 70.0, 2.0), 0.0)) * 240.0)
				hi = mini(cx + half, w)
				lo = 0
				if above > 70:
					hi = 0
			"ridge":
				var sl := int(above * 1.1)
				hi = maxi(w - sl * 2, 0)
				if above > 80:
					hi = 0
		if lo > 0:
			im.fill_rect(Rect2i(0, y, lo, 1), Color(0, 0, 0, 0))
		if hi < w:
			im.fill_rect(Rect2i(hi, y, w - hi, 1), Color(0, 0, 0, 0))
		# A lit rim down the right-hand slope of the summit shape.
		if hi > 0 and hi < w:
			im.set_pixel(maxi(hi - 1, 0), y, ClimbRock.tone(c, 3.9))
			im.set_pixel(maxi(hi - 2, 0), y, ClimbRock.tone(c, 3.4))
		if lo > 0:
			im.set_pixel(mini(lo, w - 1), y, c.seam)
	match kind:
		"rim":
			_rim(im, y_top, pal, rng, w, edge)
		"tree_ledge", "arches_top", "column_top", "chimney_top", "el_cap_top":
			for i in 5:
				ClimbProps.pine(im, rng.randi_range(8, int(edge[mini(y_top, edge.size() - 1)]) - 8), y_top - 4, rng.randi_range(26, 46), rng, c)
			if kind == "el_cap_top":
				# The summit of El Capitan: a long granite plateau, a few pines.
				ClimbProps.pine(im, cx + 20, y_top - 4, 52, rng, c)
		"spire_top", "peak_summit":
			# A tiny summit with a cairn and a fluttering sling or flag.
			_cairn(im, cx, y_top - 110, pal)
			if kind == "peak_summit":
				P.vline(im, cx + 4, y_top - 126, 14, _lit(Color("5a3a1a"), pal))
				P.rect(im, cx + 5, y_top - 126, 7, 4, _lit(Color("d8452e"), pal))
		"dome_top":
			for i in 7:
				var x := cx - 100 + i * 36
				var above := 70.0 * sqrt(maxf(1.0 - pow((x - cx) / 240.0, 2.0), 0.0))
				ClimbProps.pine(im, x, y_top - int(above) + 4, rng.randi_range(14, 24), rng, c)
		"anchor":
			# Swan Slab's top: chains and bolts, a tree to sit against.
			for i in 3:
				var bx := cx - 30 + i * 22
				P.rect(im, bx, y_top - 4, 4, 5, ClimbRock.tone(c, 0.4))
				P.rect(im, bx + 1, y_top - 3, 2, 2, Color("c8ccd4"))
			ClimbProps.pine(im, cx + 80, y_top - 4, 40, rng, c)
		"glacier_ridge":
			for i in 8:
				var x := w - 60 - i * 30
				P.ellipse(im, x, y_top - int(x * 0.0) - (w - x) / 3 + 8, 8, 3, _lit(Color("eef4fa"), pal))


## The Glacier Point rim: a low stone wall with a railing, tourists, and the
## far edge of the world.
static func _rim(im: Image, y_top: int, pal: Dictionary, rng: RandomNumberGenerator, w: int, edge: PackedInt32Array) -> void:
	var e := int(edge[mini(y_top, edge.size() - 1)])
	var stone := _lit(Color("a89878"), pal)
	var rail := _lit(Color("5a3a24"), pal)
	# The low wall along the lip.
	P.rect(im, 20, y_top - 14, e - 24, 14, stone)
	P.rect(im, 20, y_top - 14, e - 24, 2, stone.lightened(0.3))
	for x in range(20, e - 8, 11):
		P.rect(im, x, y_top - 14, 1, 14, stone.darkened(0.25))
	for x in range(26, e - 10, 14):
		P.rect(im, x, y_top - 30, 2, 16, rail)
	P.rect(im, 20, y_top - 30, e - 24, 2, rail.lightened(0.15))
	P.rect(im, 20, y_top - 22, e - 24, 1, rail)
	# Tourists, small and bright, leaning on the rail.
	var shirts := [Color("c84a3a"), Color("4a78c8"), Color("e8c040"), Color("7ac24a"), Color("f4f0e6")]
	for i in 6:
		var x := 40 + i * 38 + rng.randi_range(-6, 6)
		var shirt := _lit(shirts[i % shirts.size()], pal)
		P.rect(im, x - 2, y_top - 36, 5, 6, shirt)
		P.rect(im, x - 2, y_top - 30, 5, 5, _lit(Color("4a4a58"), pal))
		P.rect(im, x - 1, y_top - 40, 3, 4, _lit(Color("e0ac7e"), pal))
		P.rect(im, x - 2, y_top - 41, 5, 2, _lit([Color("3a2a1a"), Color("c8a050"), Color("8a5a2a")][i % 3], pal))
		if i % 2 == 0:
			P.px(im, x + 3, y_top - 37, _lit(Color("e8e0c8"), pal))
	# A few pines behind.
	var c := ClimbRock.colors("apron", pal)
	for i in 3:
		ClimbProps.pine(im, 30 + i * 90 + rng.randi_range(-10, 10), y_top - 14, rng.randi_range(40, 62), rng, c)
