extends "res://tools/hubs/ahwahnee_hotel_art.gd"
## Yosemite Village pixel art in the Ahwahnee's style: the village buildings
## and street props (Camp 4's props are in camp4_art.gd), drawn with the hotel's materials (cut granite
## foundations, stained-timber walls, mossy shingle roofs, painted signs), the
## same ramps, ordered dithering and light from the upper left, and a dark rim.
## Written to assets/sprites/buildings/ at the sizes the village scene expects,
## so footprints and signs stay where they are. Replace any PNG with
## hand-drawn art of the same size at any time.
##
## Every sprite is anchored at its bottom center. The buildings also get a
## "<name>_glow" picture of their lit windows for the builder to fade in at dusk.

const FloraArt = preload("res://tools/hubs/ahwahnee_flora_art.gd")
const OUT := "res://assets/sprites/buildings/"

## Building name -> size and look.
## How much bigger than first drawn the village buildings stand, so a shop is
## three or four people tall, as in Stardew Valley, with a door a person fits.
const VILLAGE_SCALE := 1.45

## The looks follow the real buildings: the Village Store a long, dark log
## store with two cross gables over a deep porch; the Welcome Center brown
## board-and-batten under a broad entry gable; the Museum (1926) a granite
## ground story under dark timber; Best's Studio and the Wilderness Center
## small brown frame buildings with porches; Degnan's a steep chalet roof;
## the Post Office granite with a green roof.
const BUILDINGS := {
	"village_store": {"goods": true, "size": Vector2i(110, 58), "wall": "timber", "label": "VILLAGE STORE", "seed": 11, "roof": ["2a2a22", "3a3c2c", "4d5238", "62684a", "7b815b", "989d76"], "windows": [12, 30, 80, 98], "gables": [22, 88], "chimney": 60, "porch": true, "scale": VILLAGE_SCALE},
	"welcome_center": {"flag": true, "size": Vector2i(66, 46), "wall": "board", "tone": 2, "label": "WELCOME CENTER", "seed": 23, "roof": ["24262a", "34383e", "484e56", "5e666e", "7a828a", "9aa2a8"], "windows": [10, 20, 46, 56], "gable": 33, "chimney": 52, "scale": VILLAGE_SCALE},
	"museum": {"portico": true, "size": Vector2i(58, 46), "wall": "stone_timber", "label": "YOSEMITE MUSEUM", "seed": 37, "roof": ["2c2822", "443c32", "5e5242", "786a54", "948468", "b0a07e"], "windows": [9, 19, 39, 49], "chimney": 8, "low": true, "scale": VILLAGE_SCALE},
	"bests_studio": {"size": Vector2i(46, 40), "wall": "board", "label": "BEST'S STUDIO", "seed": 41, "roof": ["2e2218", "4a3422", "644630", "7e5c3e", "9a7650", "b89468"], "windows": [8, 38], "gable": 23, "tone": 3, "porch": true, "scale": VILLAGE_SCALE},
	"degnans": {"size": Vector2i(52, 46), "wall": "stucco", "label": "DEGNAN'S", "seed": 53, "roof": ["34201a", "55301f", "74402a", "92583a", "ae7248", "c98c5c"], "windows": [8, 44], "chalet": true, "chimney": 40, "awning": true, "awning_a": "9a3a2a", "awning_b": "e8d8b0", "scale": VILLAGE_SCALE},
	"wilderness_center": {"size": Vector2i(42, 36), "wall": "board", "label": "WILDERNESS", "seed": 67, "roof": ["1c2a22", "2a4030", "3a5640", "4d6e50", "658a64", "84a67c"], "windows": [8, 34], "tone": 2, "green": true, "porch": true, "scale": VILLAGE_SCALE},
	"post_office": {"size": Vector2i(56, 40), "wall": "stone", "label": "POST OFFICE", "seed": 89, "roof": ["1c2a22", "2a4030", "3a5640", "4d6e50", "658a64", "84a67c"], "windows": [10, 46], "gable": 28, "scale": VILLAGE_SCALE},
	"valley_lodge": {"size": Vector2i(80, 44), "wall": "timber", "label": "YOSEMITE LODGE", "seed": 79, "windows": [10, 22, 58, 70], "gable": 40, "chimney": 64, "pitch": 12, "porch": true, "scale": VILLAGE_SCALE},
}

const PROPS := ["umacha", "chuckah", "bear_box", "shuttle_stop"]
const FILES := ["village_store", "welcome_center", "museum", "bests_studio", "degnans", "wilderness_center", "post_office", "valley_lodge",
	"chapel", "umacha", "chuckah", "bear_box", "shuttle_stop", "headstone_0", "headstone_1", "headstone_2", "headstone_clark", "tree_sequoia",
	"village_store_glow", "welcome_center_glow", "museum_glow", "bests_studio_glow", "degnans_glow", "wilderness_center_glow", "post_office_glow", "valley_lodge_glow", "chapel_glow"]


func save_all() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	for sprite_name: String in BUILDINGS:
		var built := building(sprite_name)
		_write(built[0], sprite_name)
		_write(built[1], sprite_name + "_glow")
	var church := chapel()
	_write(church[0], "chapel")
	_write(church[1], "chapel_glow")
	for v in 3:
		_write(headstone(v), "headstone_%d" % v)
	_write(headstone(3), "headstone_clark")
	_write(sequoia(), "tree_sequoia")
	_write(umacha(), "umacha")
	_write(chuckah(), "chuckah")
	_write(bear_box(), "bear_box")
	_write(shuttle_stop(), "shuttle_stop")


func _write(im: Image, sprite_name: String) -> void:
	im.save_png(ProjectSettings.globalize_path(OUT + sprite_name + ".png"))


# ---------------------------------------------------------------- walls

## Vertical board-and-batten siding in stained wood: lit left edge, shaded
## right edge on every board, battens, grain and a few knots.
func board_wall(im: Image, x: int, y: int, w: int, h: int, sd: int, tone := 3, tint := Color(0, 0, 0, 0)) -> void:
	for xx in w:
		var board := xx / 5
		var inb := xx % 5
		var base_t := 0.46 + (K.hash2(board, sd, 3) - 0.5) * 0.3
		for yy in h:
			var t := base_t + (K.hash2(x + xx, (y + yy) / 3, sd) - 0.5) * 0.12
			t += (0.5 - float(yy) / h) * 0.07
			var idx := clampi(roundi(t * 5.0) + tone - 3, 0, 5)
			if inb == 0:
				idx = clampi(idx + 1, 0, 5)
			elif inb >= 4:
				idx = clampi(idx - 2, 0, 5)
			var col := timber[idx]
			if tint.a > 0.0:
				col = col.lerp(tint, tint.a)
			K.px(im, x + xx, y + yy, col)
	for kn in maxi(1, w * h / 140):
		var kx := x + 1 + int(K.hash2(kn, sd, 5) * (w - 3))
		var ky := y + 1 + int(K.hash2(kn, sd, 6) * (h - 3))
		K.px(im, kx, ky, timber[0])
		K.px(im, kx + 1, ky, timber[1])
	# battens over the joints
	for bx in range(5, w - 1, 5):
		K.vline(im, x + bx, y, h, timber[2].lerp(timber[4], 0.35))


## Warm stained plaster between timber posts, for the bakery.
func stucco_wall(im: Image, x: int, y: int, w: int, h: int, sd: int) -> void:
	for yy in h:
		for xx in w:
			var n := K.hash2(x + xx, y + yy, sd)
			var blotch := vnoise((x + xx) * 0.09, (y + yy) * 0.07, sd + 4)
			var t := 0.52 + (n - 0.5) * 0.2 + (blotch - 0.5) * 0.34 + (0.5 - float(yy) / h) * 0.08
			K.px(im, x + xx, y + yy, stucco[clampi(roundi(t * 4.0), 0, 4)])
	for px_ in range(0, w - 2, 15):
		post(im, x + px_, y, h, sd + px_, 2)
	beam(im, x, y, w, sd + 1, 2)


func _wall(im: Image, style: String, x: int, y: int, w: int, h: int, sd: int, o: Dictionary) -> void:
	match style:
		"stone":
			stone_wall(im, x, y, w, h, sd, 0.56, 5, 3, false)
			beam(im, x, y, w, sd + 5, 2)
		"board":
			board_wall(im, x, y, w, h, sd, int(o.get("tone", 3)), Color(0.18, 0.34, 0.2, 0.42) if o.get("green", false) else Color(0, 0, 0, 0))
		"stucco":
			stucco_wall(im, x, y, w, h, sd)
		"timber":
			_vb_logs(im, x, y, w, h, sd)
		"stone_timber":
			# a granite ground story under stained timber, like the Museum
			var split := h * 9 / 20
			board_wall(im, x, y, w, split + 1, sd, 2)
			stone_wall(im, x, y + split, w, h - split, sd + 7, 0.6, 4, 3, false)
			beam(im, x, y + split - 1, w, sd + 5, 2)
		_:
			timber_wall(im, x, y, w, h, sd, int(o.get("pitch", 16)), 40)


## Shifts a tone toward cool violet-blue as it goes into shade and toward warm
## gold as it goes into sun, so no ramp is a plain multiply toward black.
## [param t] runs from -1 (deep shade) to 1 (full sun).
func _vb_tone(c: Color, t: float) -> Color:
	if t < 0.0:
		return c.lerp(Color(0.16, 0.16, 0.34), -t * 0.3).darkened(-t * 0.14)
	return c.lerp(Color(1.0, 0.84, 0.42), t * 0.2).lightened(t * 0.1)


## Hue-shifted shingle courses on a hipped roof seen from above: staggered
## shingles, a shaded lower lip on every course, moss creeping into the upper
## courses, and a mossy ridge cap. [param taper] narrows the roof toward the top.
func _vb_roof(im: Image, x: int, y: int, w: int, h: int, sd: int, taper := 0.28) -> void:
	var course := 3
	for row in h:
		var inset := int((h - 1 - row) * taper)
		var ci := row / course
		var inrow := row % course
		var off := (ci % 2) * 3
		var lit := 0.22 - float(row) / h * 0.3
		for sx in range(x + inset, x + w - inset):
			var gx := sx - x
			var shi := (gx + off) / 6
			var n := K.hash2(shi, ci, sd)
			var lev := clampi(roundi((0.3 + n * 0.5 + lit + (0.5 - float(gx) / w) * 0.2) * 5.0), 0, 5)
			var col := _vb_tone(roof[lev], (float(lev) / 5.0 - 0.5) * 1.1)
			if n < 0.2:
				col = col.darkened(0.1)
			if inrow == course - 1:
				col = _vb_tone(col, -0.55)
			elif inrow == 0 and ci > 0:
				col = col.lightened(0.08)
			if (gx + off) % 6 == 5 and inrow < course - 1:
				col = col.darkened(0.14)
			var mo := vnoise(gx * 0.13, row * 0.2, sd + 7)
			if mo > 0.7 and row < h * 0.6 and n > 0.25:
				col = moss[clampi(roundi((mo - 0.7) * 9.0), 0, 2)]
			if sx == x + inset:
				col = col.lightened(0.22)
			elif sx == x + w - inset - 1:
				col = col.darkened(0.32)
			K.px(im, sx, y + row, col)
	var ridge_inset := int((h - 1) * taper)
	K.hline(im, x + ridge_inset, y, w - ridge_inset * 2, roof[5].lightened(0.3))
	K.hline(im, x + ridge_inset, y + 1, w - ridge_inset * 2, roof[4].lightened(0.05))
	for mx in range(x + ridge_inset + 3, x + w - ridge_inset - 3, 7):
		if K.hash2(mx, y, sd + 9) < 0.7:
			K.px(im, mx, y, moss[2])
			K.px(im, mx + 1, y, moss[1])
	K.hline(im, x, y + h - 1, w, timber[0])
	K.hline(im, x, y + h - 2, w, _vb_tone(roof[0], -0.6))


## The eave: a dark fascia, rafter tails, and a deep cool shadow falling across
## the top of the wall.
func _vb_eave(im: Image, x: int, y: int, w: int) -> void:
	K.hline(im, x, y, w, timber[0])
	K.hline(im, x, y + 1, w, timber[1])
	for tx in range(x + 2, x + w - 2, 6):
		K.rect(im, tx, y + 2, 2, 2, timber[3])
		K.px(im, tx + 1, y + 4, timber[0])
	shade(im, x, y + 3, w, 7, Color("1e1834"), 1.0, 0.0, 0.5)


## Stacked hewn logs: a lit top edge, a shaded underside, grain streaks along
## each log, and round end-cuts with rings at both corners.
func _vb_logs(im: Image, x: int, y: int, w: int, h: int, sd: int) -> void:
	var course := 4
	for row in h:
		var ci := row / course
		var inrow := row % course
		var base_t := 0.5 + (K.hash2(ci, sd, 3) - 0.5) * 0.24
		for xx in w:
			var t := base_t + (0.5 - float(xx) / w) * 0.1
			var idx := clampi(roundi(t * 5.0), 0, 5)
			if inrow == 0:
				idx += 1
			elif inrow == course - 1:
				idx -= 1
			var col := timber[clampi(idx, 0, 5)]
			if inrow == 1 and K.hash2(xx / 5, ci, sd + 5) < 0.3:
				col = col.darkened(0.12)
			if inrow == course - 1:
				col = _vb_tone(col, -0.5)
			K.px(im, x + xx, y + row, col)
		# end-cuts: a pale face with a darker heart, lit on the left
		var end_l := timber[4] if inrow != course - 1 else timber[1]
		var end_r := timber[2] if inrow != course - 1 else timber[0]
		if inrow == 1:
			end_l = end_l.lightened(0.12)
			end_r = end_r.lightened(0.04)
		K.px(im, x, y + row, end_l)
		K.px(im, x + w - 1, y + row, end_r)
		if inrow == 1 or inrow == 2:
			K.px(im, x + w - 2, y + row, timber[1])


## A plank run with one plank per [param plank] rows: a lit top row, a dark
## seam, and grain streaks along the length.
func _vb_plank_rows(im: Image, x: int, y: int, w: int, h: int, sd: int, plank := 2) -> void:
	for row in h:
		var pi := row / plank
		var inrow := row % plank
		var base_t := 0.5 + (K.hash2(pi, sd, 41) - 0.5) * 0.3
		for xx in w:
			var idx := clampi(roundi(base_t * 5.0), 0, 5)
			if inrow == 0:
				idx += 1
			elif inrow == plank - 1:
				idx -= 1
			var col := timber[clampi(idx, 0, 5)]
			if inrow == 0 and K.hash2(xx / 6, pi, sd + 7) < 0.3:
				col = col.darkened(0.08)
			if xx == 0 or xx == w - 1:
				col = col.darkened(0.1)
			K.px(im, x + xx, y + row, col)


# ---------------------------------------------------------------- openings

## A sash window in a timber frame lit on its top and left edges: sky glass with
## a diagonal glint (or warm glass with red curtains when lit), a mullion and
## transom, and a granite sill. Flower boxes come from [method _dress].
func _vb_window(im: Image, x: int, y: int, w: int, h: int, lit: bool, sd: int) -> void:
	K.rect(im, x - 1, y - 1, w + 2, h + 2, timber[0])
	K.hline(im, x - 1, y - 1, w + 2, timber[3])
	K.vline(im, x - 1, y - 1, h + 2, timber[2])
	for gy in h:
		for gx in w:
			var v := float(gy) / maxi(1, h - 1)
			var col: Color
			if lit:
				col = warm[clampi(roundi((0.9 - v * 0.6) * 7.0 + (K.hash2(gx, gy, sd) - 0.5) * 1.0), 1, 7)]
			else:
				col = sky[clampi(roundi((0.95 - v * 0.8) * 4.0 + (K.hash2(gx, gy, sd) - 0.5) * 0.8), 0, 4)]
				col = _vb_tone(col, -0.1 - v * 0.2)
			K.px(im, x + gx, y + gy, col)
	if lit:
		if w >= 6:
			var cur_h := maxi(2, h * 2 / 3)
			K.vline(im, x, y, cur_h, Color("9a3a2e"))
			K.vline(im, x + w - 1, y, cur_h, Color("7e2e26"))
			K.vline(im, x + 1, y, 1, Color("c4604c"))
	else:
		# a diagonal sky glint across the upper pane
		for k in range(0, mini(3, h - 2)):
			K.px(im, x + 2 + k, y + 1 + k, sky[4].lightened(0.2))
	if w >= 5:
		K.vline(im, x + w / 2, y, h, timber[1])
	if h >= 6:
		K.hline(im, x, y + h / 2, w, timber[1])
	K.hline(im, x, y, w, timber[0].lerp(warm[3] if lit else sky[1], 0.3))
	# granite sill, its top lit, and a shaded lip
	K.rect(im, x - 2, y + h + 1, w + 4, 1, granite[5])
	K.hline(im, x - 2, y + h + 1, w + 4, granite[6])
	K.hline(im, x - 2, y + h + 2, w + 4, granite[2])
	shade(im, x - 1, y + h + 3, w + 2, 3, timber[0], 1.0, 0.0, 0.4)
	_register(im, Rect2i(x, y, w, h), 1.0 if lit else 0.55 + K.hash2(x, y, sd) * 0.45)


## A plank door under a granite arched lintel with a keystone, two raised panels,
## and iron strap hinges, on a two-step granite stoop. The wall lantern by the
## door comes from [method _dress].
func plank_door(im: Image, cx: int, bottom: int, h: int, sd: int, w := 8) -> void:
	var x := cx - w / 2
	var top := bottom - h
	K.rect(im, x - 2, top - 2, w + 4, 2, granite[4])
	K.hline(im, x - 2, top - 2, w + 4, granite[6])
	K.hline(im, x - 2, top - 1, w + 4, granite[2])
	K.px(im, cx - 1, top - 2, granite[6].lightened(0.1))
	K.px(im, cx, top - 2, granite[6].lightened(0.1))
	K.rect(im, x - 1, top, w + 2, h, timber[0])
	K.vline(im, x - 1, top, h, timber[3])
	for yy in h:
		for xx in w:
			if yy < 2 and (xx < 2 - yy or xx >= w - (2 - yy)):
				continue
			var plank := xx / 2
			var idx := 2 + int(K.hash2(plank, sd, 7) * 2.0)
			if xx % 2 == 0:
				idx += 1
			var col := timber[clampi(idx, 0, 5)]
			if K.hash2(plank, yy / 4, sd + 3) < 0.15:
				col = col.darkened(0.08)
			K.px(im, x + xx, top + yy, col)
	# two raised panels, lit on their top-left edges
	for seg: Array in [[3, h / 2 - 1], [h / 2 + 1, h - 3]]:
		var p0: int = seg[0]
		var p1: int = seg[1]
		if p1 - p0 < 2:
			continue
		K.rect(im, x + 2, top + p0, w - 4, p1 - p0 + 1, timber[1])
		K.rect(im, x + 3, top + p0 + 1, w - 6, p1 - p0 - 1, timber[3])
		K.vline(im, x + 3, top + p0 + 1, p1 - p0 - 1, timber[4])
		K.hline(im, x + 3, top + p1, w - 6, timber[2])
	K.px(im, x, top + 2, iron[1])
	K.px(im, x, top + h - 4, iron[1])
	K.px(im, cx + 1, top + h / 2, warm[5])
	K.px(im, cx + 1, top + h / 2 - 1, warm[4])
	# two-step granite stoop
	K.rect(im, x - 2, bottom, w + 4, 1, granite[5])
	K.hline(im, x - 2, bottom, w + 4, granite[6])
	K.rect(im, x - 3, bottom + 1, w + 6, 1, granite[3])
	shade(im, x - 1, top, w + 2, 3, timber[0], 0.9, 0.0, 0.4)


## A painted sign board: dark stained wood, routed edge, nail heads, and
## hand-lettered words in ochre.
func sign_board(im: Image, cx: int, y: int, text: String, ink: Color = Color("f0e2bc")) -> void:
	var tw := K.text_width(text)
	var w := tw + 6
	var x := cx - w / 2
	K.rect(im, x, y, w, 9, timber[0])
	for yy in 7:
		for xx in w - 2:
			var n := K.hash2(xx, yy, 91)
			K.px(im, x + 1 + xx, y + 1 + yy, timber[1 if n > 0.12 else 2])
	K.hline(im, x + 1, y + 1, w - 2, timber[3])
	K.hline(im, x, y, w, timber[2])
	K.text(im, x + 3, y + 2, text, ink, timber[0])
	K.px(im, x + 1, y + 1, granite[5])
	K.px(im, x + w - 2, y + 1, granite[5])
	# iron bracket and two hangers running up to the wall
	K.hline(im, x + 3, y - 2, w - 6, iron[2])
	K.hline(im, x + 3, y - 3, w - 6, iron[3])
	K.px(im, x + 2, y - 1, iron[1])
	K.px(im, x + w - 3, y - 1, iron[1])
	shade(im, x, y + 9, w, 3, timber[0], 1.0, 0.0, 0.4)


## A striped canvas awning over the front, in two colors, with a shaded fringe.
func awning(im: Image, x: int, y: int, w: int, depth: int, a: Color, b: Color) -> void:
	for yy in depth:
		var inset := int((depth - 1 - yy) * 0.5)
		for xx in range(inset, w - inset):
			var stripe := (xx / 4) % 2 == 0
			var col := a if stripe else b
			col = col.lightened(0.1 - float(yy) / depth * 0.24)
			if xx == inset:
				col = col.lightened(0.18)
			elif xx == w - inset - 1:
				col = col.darkened(0.3)
			K.px(im, x + xx, y + yy, col)
	for xx in range(0, w, 2):
		K.px(im, x + xx, y + depth, (a if (xx / 4) % 2 == 0 else b).darkened(0.25))
	shade(im, x, y + depth + 1, w, 3, timber[0], 0.8, 0.0, 0.4)


# ---------------------------------------------------------------- buildings

## Returns [sprite, glow]: a village building seen from the front and above
## with the style set in [constant BUILDINGS], or in [param options] (same
## keys) for a building that isn't in the table. Options with no "label" get
## no sign, and "dark" leaves the wall lantern off.
func building(sprite_name: String, options := {}) -> Array:
	var o: Dictionary = (options if not options.is_empty() else BUILDINGS[sprite_name]).duplicate()
	# "scale" grows a building and its openings together (see VILLAGE_SCALE)
	var k: float = o.get("scale", 1.0)
	if k != 1.0:
		var base: Vector2i = o["size"]
		o["size"] = Vector2i(roundi(base.x * k / 2.0) * 2, roundi(base.y * k / 2.0) * 2)
		o["windows"] = (o["windows"] as Array).map(func(x: int) -> int: return roundi(x * k))
		for key in ["gable", "chimney"]:
			if o.has(key):
				o[key] = roundi(int(o[key]) * k)
		if o.has("gables"):
			o["gables"] = (o["gables"] as Array).map(func(x: int) -> int: return roundi(x * k))
	var size: Vector2i = o["size"]
	var w := size.x
	var h := size.y
	var sd: int = o["seed"]
	windows.clear()
	glass_snap = null
	var im := K.make(w, h)
	var base_roof := roof
	if o.has("roof"):
		roof = _ramp(o["roof"])
	var wall_h := int(round(h * (0.36 if o.get("low", false) else 0.42)))
	var wall_top := h - wall_h
	var found_h := 5
	var body_h := wall_h - found_h
	K.shadow(im, w / 2.0, h - 2.5, w / 2.0 - 1.0, 2.6, 0.3)

	_wall(im, o["wall"], 1, wall_top, w - 2, body_h + 1, sd, o)
	# Granite foundation course with moss at the footing.
	stone_wall(im, 1, h - found_h - 1, w - 2, found_h, sd + 100, 0.5, 3, 2, true)
	K.hline(im, 1, h - found_h - 1, w - 2, granite[5])

	# Roof, then a cross gable and chimney rising from it.
	var taper := 0.22 if o.get("low", false) else 0.28
	_vb_roof(im, 0, 2, w, wall_top - 3, sd + 200, taper)
	var gables: Array = o.get("gables", [])
	if o.has("gable"):
		gables = [o["gable"]]
	for gx: int in gables:
		var apex := mini(wall_top - 8, 15)
		gable(im, gx, wall_top - 1, mini(15, w / 4 + 2), apex, 3, sd + 300 + gx, true, 6)
	if o.get("chalet", false):
		# one steep gable over most of the front, its peak near the ridge
		gable(im, w / 2, wall_top - 1, w * 3 / 8, wall_top - 7, 3, sd + 300, true, 8)
	if o.has("chimney"):
		var cx: int = o["chimney"]
		chimney(im, cx, 8, maxi(6, wall_top - 14), sd + 400)
	_vb_eave(im, 0, wall_top - 2, w)

	# Windows, door, sign.
	var win_w := roundi(6 * k / 2.0) * 2
	var win_h := clampi(body_h - 7, 4, roundi(8 * k))
	for wx: int in o["windows"]:
		_vb_window(im, wx - win_w / 2, wall_top + 3, win_w, win_h, K.hash2(wx, sd, 5) < 0.55, sd + wx)
	var door_cx := w / 2
	if o.has("gable") and not o.get("low", false):
		door_cx = w / 2
	var door_h := mini(wall_h - 3, roundi(13 * k))
	plank_door(im, door_cx, h - 2, door_h, sd + 500, roundi(8 * k / 2.0) * 2)
	if o.get("awning", false):
		var aw := mini(w - 18, roundi(38 * k))
		awning(im, door_cx - aw / 2, wall_top + 1, aw, 5, Color(o.get("awning_a", "3f6b4a")), Color(o.get("awning_b", "e6d8b0")))
	if o.get("porch", false):
		_porch(im, wall_top, found_h, door_cx, sd)
	if o.has("label"):
		sign_board(im, door_cx, wall_top - 8 if not o.get("awning", false) else wall_top - 9, o["label"])

	o["_win_w"] = win_w
	_dress(im, o, sd, wall_top, win_h, door_cx, o.get("awning", false))
	# Ambient occlusion on the sunless side, and a lit lip on the near side.
	shade(im, w - 8, wall_top, 7, body_h + 1, timber[0], 0.0, 0.85, 0.34, false)
	shade(im, 1, wall_top + 2, 4, body_h, granite[6], 0.5, 0.0, 0.12, false)
	K.outline(im, Color("231a16"))
	var glow := _glow_image(im, w, h)
	roof = base_roof
	return [im, glow]


## Small touches that make a building lived in: flower boxes under some
## windows, a wall lantern by the door, and a downspout down the near corner.
func _dress(im: Image, o: Dictionary, sd: int, wall_top: int, win_h: int, door_cx: int, awning: bool) -> void:
	var wins: Array = o["windows"]
	var blooms: Array = [
		[Color("e86a8a"), Color("f6b0c2")], [Color("f0c84a"), Color("fbe9a0")],
		[Color("d8503a"), Color("f08a6a")], [Color("9a7ad8"), Color("c8b4f0")]]
	var pick: Array = blooms[sd % blooms.size()]
	for i in wins.size():
		if wins.size() >= 4 and i % 2 == 1:
			continue
		var wx: int = wins[i]
		var half: int = o.get("_win_w", 6) / 2 + 1
		var by := wall_top + 3 + win_h + 1
		K.rect(im, wx - half, by, half * 2, 2, timber[1])
		K.hline(im, wx - half, by, half * 2, timber[3])
		for fx in range(wx - half + 1, wx + half):
			var tall := K.hash2(fx, sd, 7) > 0.45
			K.px(im, fx, by - 1, leaf[3])
			if tall:
				K.px(im, fx, by - 2, pick[0] if (fx + sd) % 2 == 0 else pick[1])
			elif K.hash2(fx, sd, 8) > 0.5:
				K.px(im, fx, by - 1, pick[0])
	if o.get("flag", false):
		_visitor_details(im, wall_top, door_cx, sd)
	if o.get("goods", false):
		_store_goods(im, door_cx, sd)
	if o.get("portico", false):
		_museum_details(im, wall_top, door_cx, sd)
	if o.get("dark", false):
		return
	# a wall lantern beside the door
	var lx := door_cx + 7
	var ly := wall_top + 4
	K.rect(im, lx - 1, ly - 1, 3, 1, iron[3])
	K.rect(im, lx - 1, ly, 3, 4, iron[1])
	K.rect(im, lx, ly + 1, 1, 2, warm[6])
	K.px(im, lx, ly + 1, warm[7])
	K.hline(im, lx - 1, ly + 4, 3, iron[3])
	_register(im, Rect2i(lx, ly + 1, 1, 1), 1.0)


## The Village Store's goods out front: stacked crates of produce and a
## sack-and-barrel corner either side of the door, and a hanging trade sign.
func _store_goods(im: Image, door_cx: int, sd: int) -> void:
	var h := im.get_height()
	var fruit := [Color("d04a3a"), Color("e8b83a"), Color("7aa84a"), Color("c87a3a")]
	for side in [-1, 1]:
		var bx: int = door_cx + side * 14 - 4
		for row in 1:
			var cw := 9
			var cx := bx + row
			var cy := h - 11 - row * 4
			K.rect(im, cx, cy, cw, 4, timber[3])
			K.hline(im, cx, cy, cw, timber[4])
			K.hline(im, cx, cy + 3, cw, timber[0])
			K.vline(im, cx + cw - 1, cy, 4, timber[1])
			for k in cw - 2:
				K.px(im, cx + 1 + k, cy - 1, fruit[(k + row + (sd + side) % 4) % 4])
				if k % 2 == 0:
					K.px(im, cx + 1 + k, cy - 2, fruit[(k + sd) % 4].lightened(0.2))
	# a flour sack leaning by the left crates
	var sx: int = door_cx - 25
	K.rect(im, sx, h - 12, 4, 6, stucco[4])
	K.vline(im, sx + 3, h - 12, 6, stucco[2])
	K.hline(im, sx + 1, h - 13, 2, stucco[3])
	K.px(im, sx + 1, h - 9, Color("a8382a"))


## The Museum: a broad granite step with a low wall, two gate lamps, and an
## interpretive panel on a post by the door.
func _museum_details(im: Image, wall_top: int, door_cx: int, sd: int) -> void:
	var h := im.get_height()
	var w := im.get_width()
	K.rect(im, door_cx - 7, h - 5, 14, 3, granite[4])
	K.hline(im, door_cx - 7, h - 5, 14, granite[6])
	K.hline(im, door_cx - 7, h - 3, 14, granite[1])
	for side in [-1, 1]:
		var lx: int = door_cx + side * 11
		K.vline(im, lx, h - 10, 6, iron[2])
		K.rect(im, lx - 1, h - 13, 3, 3, iron[1])
		K.px(im, lx, h - 12, warm[6])
		K.px(im, lx, h - 11, warm[7])
		K.hline(im, lx - 1, h - 14, 3, iron[3])
	# interpretive panel
	var px0: int = w - 8
	K.vline(im, px0 + 2, h - 12, 8, timber[1])
	K.rect(im, px0, h - 16, 6, 5, timber[0])
	K.rect(im, px0 + 1, h - 15, 4, 3, Color("d8c898"))
	K.hline(im, px0 + 1, h - 14, 4, Color("8a7a58"))


## The Welcome Center's own touches: a cut-stone arch over the door and
## two planters by the entrance.
func _visitor_details(im: Image, wall_top: int, door_cx: int, sd: int) -> void:
	var h := im.get_height()
	# arch of voussoirs over the door
	for k in range(-5, 6):
		var ay := wall_top + 10 - int(sqrt(maxf(0.0, 30.0 - k * k)) * 0.8)
		K.px(im, door_cx + k, ay, granite[6] if k % 2 == 0 else granite[4])
		K.px(im, door_cx + k, ay + 1, granite[2])
	# planters flanking the step
	for side in [-1, 1]:
		var bx: int = door_cx + side * 9 - 2
		K.rect(im, bx, h - 9, 5, 4, timber[2])
		K.hline(im, bx, h - 9, 5, timber[4])
		for k in 5:
			K.px(im, bx + k, h - 10, leaf[3])
			if K.hash2(k, side + sd, 3) > 0.4:
				K.px(im, bx + k, h - 11, Color("e86a8a") if side < 0 else Color("f0c84a"))


## Lit windows and a soft halo, drawn over the finished building (for night).
func _glow_image(final: Image, w: int, h: int) -> Image:
	var im := K.make(w, h)
	for entry: Array in windows:
		var r: Rect2i = entry[0]
		var strength: float = entry[1]
		if strength < 1.0 and K.hash2(r.position.x, r.position.y, 77) < 0.3:
			continue
		var visible := 0
		for yy in range(r.position.y, r.end.y):
			for xx in range(r.position.x, r.end.x):
				if final.get_pixel(xx, yy) == glass_snap.get_pixel(xx, yy):
					visible += 1
		if float(visible) / (r.size.x * r.size.y) < 0.6:
			continue
		for ring in range(3, 0, -1):
			var a := (0.10 if ring == 3 else (0.16 if ring == 2 else 0.24)) * strength
			for yy in range(r.position.y - ring, r.end.y + ring):
				for xx in range(r.position.x - ring, r.end.x + ring):
					if not r.has_point(Vector2i(xx, yy)) and xx >= 0 and yy >= 0 and xx < w and yy < h and final.get_pixel(xx, yy).a > 0.5:
						K.px(im, xx, yy, Color(1.0, 0.72, 0.3, a))
		for yy in range(r.position.y, r.end.y):
			for xx in range(r.position.x, r.end.x):
				var t := float(yy - r.position.y) / maxi(1, r.size.y - 1)
				K.px(im, xx, yy, Color(1.0, 0.8 - t * 0.12, 0.38, (0.62 - t * 0.2) * strength))
	return im


## A deep porch along the front: log posts from the eave down to a plank
## deck on the foundation, with a rail and balusters between the posts and a
## gap at the door.
func _porch(im: Image, wall_top: int, found_h: int, door_cx: int, sd: int) -> void:
	var w := im.get_width()
	var h := im.get_height()
	var deck_y := h - found_h - 3
	# the deck: three rows of planks, lit on the front edge, seams every board
	for xx in range(2, w - 2):
		for yy in 3:
			var idx := 3 if yy == 0 else (4 if yy == 1 else 1)
			if (xx + yy * 3) % 7 == 0:
				idx -= 1
			K.px(im, xx, deck_y + yy, timber[clampi(idx, 0, 5)])
	K.hline(im, 2, deck_y + 3, w - 4, timber[0])
	var posts := [2, w - 5, door_cx - 12, door_cx + 9]
	for span: Array in [[2, door_cx - 12], [door_cx + 9, w - 5]]:
		var n := int((span[1] - span[0]) / 22)
		for k in range(1, n + 1):
			posts.append(span[0] + (span[1] - span[0]) * k / (n + 1))
	# the rail between posts, kept clear of the door
	var rail_y := deck_y - 6
	for xx in range(3, w - 3):
		if xx > door_cx - 11 and xx < door_cx + 9:
			continue
		K.px(im, xx, rail_y, timber[4])
		K.px(im, xx, rail_y + 1, timber[1])
		if xx % 3 == 0:
			K.vline(im, xx, rail_y + 2, deck_y - rail_y - 2, timber[2])
	for px_: int in posts:
		post(im, px_, wall_top - 1, deck_y - wall_top + 1, sd + px_, 3)
		K.px(im, px_, deck_y + 1, timber[0])
	# the porch roof's shade on the wall behind
	shade(im, 2, wall_top, w - 4, 5, Color("1e1834"), 0.6, 0.0, 0.35)


## Yosemite Chapel (1879): a brown board-and-batten nave under a steep
## shingled gable, a square bell tower over the door with louvered belfry
## openings and a tall spire, pointed lancet windows that glow at dusk, and
## granite steps. Returns [sprite, glow].
func chapel() -> Array:
	var w := 64
	var h := 114
	var sd := 1879
	windows.clear()
	glass_snap = null
	var im := K.make(w, h)
	var base_roof := roof
	roof = _ramp(["2a2420", "3e342c", "54463a", "6c5a48", "86725a", "a48c6e"])
	var cx := 32
	K.shadow(im, cx, h - 2.5, 30.0, 3.0, 0.3)
	# the nave: its long roof runs back from the gable, so both slopes show
	var hw := 28
	var base := 76
	var apex := 26
	var depth := 15
	for x in range(cx - hw, cx + hw + 1):
		var edge := base - apex + int(absf(x - cx) * apex / float(hw))
		var left := x < cx
		for y in range(edge - depth, edge):
			var col := shingle_col(x + 200, y - (edge - depth), sd, 0.14 if left else -0.18)
			if y == edge - depth:
				col = col.lightened(0.25) if left else col.darkened(0.2)
			if vnoise(x * 0.2, y * 0.25, sd + 2) > 0.74 and left:
				col = moss[1]
			K.px(im, x, y, col)
		# the gable face, board-and-batten
		for y in range(edge, base):
			var board := (x - cx + 100) % 4
			var t := 0.5 + (K.hash2(x / 4, y / 3, sd) - 0.5) * 0.14 - float(x - cx + hw) / (hw * 2) * 0.16
			var idx := clampi(roundi(t * 5.0), 0, 5)
			if board == 0:
				idx = clampi(idx + 1, 0, 5)
			elif board == 3:
				idx = clampi(idx - 1, 0, 5)
			K.px(im, x, y, timber[idx])
		# bargeboards in pale trim
		K.px(im, x, edge, stucco[4] if left else stucco[2])
		K.px(im, x, edge + 1, stucco[2] if left else stucco[1])
	# the nave wall under the gable, and the foundation
	board_wall(im, cx - hw, base, hw * 2 + 1, h - 6 - base, sd, 3)
	K.hline(im, cx - hw, base, hw * 2 + 1, stucco[3])
	stone_wall(im, cx - hw, h - 7, hw * 2 + 1, 5, sd + 100, 0.5, 3, 2, true)
	K.hline(im, cx - hw, h - 7, hw * 2 + 1, granite[5])
	# lancet windows either side of the tower
	for wx in [cx - 21, cx + 16]:
		_lancet(im, wx, base + 5, 5, 18, sd + wx)
	# the tower: lighter boards, a cornice, the belfry, and the spire
	var tw := 18
	var tx := cx - tw / 2
	var t_top := 34
	for yy in range(t_top, h - 7):
		for xx in tw:
			var t := 0.66 + (K.hash2(tx + xx, yy / 3, sd + 9) - 0.5) * 0.1 - float(xx) / tw * 0.3
			var idx := clampi(roundi(t * 5.0), 0, 5)
			if xx % 4 == 0:
				idx = clampi(idx + 1, 0, 5)
			K.px(im, tx + xx, yy, timber[idx])
	K.vline(im, tx, t_top, h - 7 - t_top, stucco[3])
	K.vline(im, tx + tw - 1, t_top, h - 7 - t_top, timber[0])
	# belfry: two louvered arched openings, and a cornice above and below
	for bx in [tx + 3, tx + 10]:
		K.rect(im, bx, t_top + 5, 5, 11, Color("140c08"))
		K.hline(im, bx + 1, t_top + 4, 3, Color("140c08"))
		for ly in range(t_top + 6, t_top + 16, 2):
			K.hline(im, bx, ly, 5, timber[2])
	K.rect(im, tx - 1, t_top + 17, tw + 2, 2, stucco[3])
	K.hline(im, tx - 1, t_top + 18, tw + 2, timber[1])
	K.rect(im, tx - 1, t_top - 1, tw + 2, 2, stucco[4])
	K.hline(im, tx - 1, t_top, tw + 2, timber[1])
	# a small round window over the door
	K.ellipse(im, cx, t_top + 28, 3.4, 3.4, timber[0])
	K.ellipse(im, cx, t_top + 28, 2.2, 2.2, warm[3])
	_register(im, Rect2i(cx - 1, t_top + 27, 2, 2), 0.8)
	# the spire, shingled, lit on the left, with an iron finial
	var s_top := 2
	for yy in range(s_top, t_top - 1):
		var half := int(float(yy - s_top) / (t_top - 1 - s_top) * (tw / 2 + 1))
		for xx in range(cx - half, cx + half + 1):
			var col := shingle_col(xx + 90, yy, sd + 3, 0.18 if xx < cx else -0.2)
			if xx == cx - half:
				col = col.lightened(0.2)
			K.px(im, xx, yy, col)
	K.vline(im, cx, 0, 3, iron[2])
	K.hline(im, cx - 1, 1, 3, iron[2])
	# the door: a pointed arch of pale trim over double plank doors
	var dw := 12
	var dtop := h - 27
	for yy in range(dtop, h - 7):
		for xx in dw:
			var arch := yy - dtop < 3 and absf(xx - (dw - 1) / 2.0) > (yy - dtop) + 1.0
			if arch:
				continue
			var col := timber[2 + int(K.hash2(xx / 2, 0, sd) * 2.0)]
			if xx == dw / 2:
				col = timber[0]
			K.px(im, cx - dw / 2 + xx, yy, col)
	for k in 6:
		K.px(im, cx - 7 + k, dtop + 3 - k / 2, stucco[4])
		K.px(im, cx + 6 - k, dtop + 3 - k / 2, stucco[2])
	K.px(im, cx - 2, h - 17, warm[5])
	K.px(im, cx + 1, h - 17, warm[5])
	# granite steps
	K.rect(im, cx - 9, h - 7, 18, 2, granite[5])
	K.hline(im, cx - 9, h - 7, 18, granite[6])
	K.rect(im, cx - 11, h - 5, 22, 2, granite[3])
	K.hline(im, cx - 11, h - 5, 22, granite[5])
	shade(im, cx + hw - 6, base, 6, h - 7 - base, timber[0], 0.0, 0.8, 0.3, false)
	K.outline(im, Color("231a16"))
	var glow := _glow_image(im, w, h)
	roof = base_roof
	return [im, glow]


## A pointed lancet window of small diamond panes: deep blue by day, warm
## when lit, under a pale pointed hood.
func _lancet(im: Image, x: int, y: int, w: int, h: int, sd: int) -> void:
	K.rect(im, x - 1, y - 1, w + 2, h + 2, timber[0])
	for gy in h:
		for gx in w:
			if gy < 2 and (gx < 1 - gy or gx > w - 2 + gy):
				continue
			var col := sky[1].lerp(Color("3a4a7a"), 0.5)
			if (gx + gy) % 3 == 0:
				col = col.lightened(0.18)
			if gx == w / 2 or gy == h / 2:
				col = timber[1]
			K.px(im, x + gx, y + gy, col)
	K.px(im, x + 1, y + 1, sky[4])
	K.hline(im, x - 1, y - 2, w + 2, stucco[3])
	K.px(im, x + w / 2 - 1, y - 3, stucco[4])
	K.px(im, x + w / 2, y - 3, stucco[3])
	K.rect(im, x - 2, y + h + 1, w + 4, 1, granite[5])
	_register(im, Rect2i(x, y + 2, w, h - 2), 0.9)


## A grave marker: 0 a round-topped granite tablet, 1 a peaked slab with
## lichen, 2 a weathered wooden board, 3 Galen Clark's rough granite block.
func headstone(variant: int) -> Image:
	var w := 24 if variant == 3 else 10
	var h := 16 if variant == 3 else 14
	var im := K.make(w, h)
	var sd := 600 + variant * 7
	K.shadow(im, w / 2.0, h - 2.0, w / 2.0 - 1.0, 1.4, 0.28)
	if variant == 3:
		for yy in range(2, h - 2):
			for xx in range(1, w - 1):
				var e := pow((xx - w / 2.0 + 0.5) / (w / 2.0 - 1.0), 2.0) + pow((yy - h + 3.0) / (h - 4.0), 2.0) * 0.6
				if e > 1.0 + (K.hash2(xx, yy, sd) - 0.5) * 0.2:
					continue
				var t := 0.82 - float(xx) / w * 0.36 - float(yy) / h * 0.1 + (K.hash2(xx / 2, yy / 2, sd) - 0.5) * 0.14
				K.px(im, xx, yy, granite[clampi(roundi(t * 6.0), 0, 6)])
		K.text(im, 2, 6, "CLARK", granite[0])
		for xx in range(2, w - 2, 3):
			K.px(im, xx, h - 3, moss[1])
	elif variant == 2:
		K.rect(im, 3, 3, 4, 9, Color("8a7a66"))
		K.vline(im, 3, 3, 9, Color("a89a84"))
		K.vline(im, 6, 3, 9, Color("6a5c4c"))
		K.px(im, 4, 2, Color("9a8a74"))
		K.px(im, 5, 2, Color("7a6a58"))
		K.hline(im, 4, 6, 2, Color("5a4c3e"))
		K.px(im, 4, 9, Color("6a5c4c"))
	else:
		for yy in range(2, h - 2):
			for xx in range(2, w - 2):
				var top := 2 + (absi(xx - 4) if variant == 1 else (1 if xx == 2 or xx == w - 3 else 0))
				if yy < top:
					continue
				var t := 0.66 - float(xx - 2) / (w - 4) * 0.4 + (K.hash2(xx, yy, sd) - 0.5) * 0.12
				K.px(im, xx, yy, granite[clampi(roundi(t * 6.0), 0, 6)])
		K.hline(im, 3, 6, 4, granite[2])
		K.hline(im, 3, 8, 3, granite[2])
		if variant == 1:
			K.px(im, 6, 5, Color("b8b070"))
			K.px(im, 3, 10, Color("a8a060"))
	# grass at the foot
	for xx in range(1, w - 1):
		if K.hash2(xx, 0, sd + 1) > 0.45:
			K.px(im, xx, h - 3, leaf[3])
			if K.hash2(xx, 1, sd + 1) > 0.6:
				K.px(im, xx, h - 4, leaf[4])
	K.outline(im, Color("231a16"))
	return im


## A young giant sequoia, like the ones Galen Clark planted round his grave:
## a tall, dense blue-green cone of clumped foliage over a flared, furrowed
## cinnamon trunk.
func sequoia() -> Image:
	var w := 34
	var h := 78
	var sd := 1910
	var im := K.make(w, h)
	var cx := w / 2.0
	var green: Array[Color] = _ramp(["1a332c", "24463a", "325a44", "44704e", "5c865c", "7a9e6c"])
	var bark: Array[Color] = _ramp(["3c1c12", "5a2a18", "7a3a20", "984c2a", "b4643a", "cc8250"])
	K.shadow(im, cx, h - 2.5, 12.0, 2.4, 0.3)
	# the trunk, flared at the foot, lit on the left, with deep furrows
	for yy in range(40, h - 2):
		var half := 2.6 + pow(maxf(0.0, float(yy - (h - 12)) / 10.0), 2.0) * 3.2
		for xx in range(floori(cx - half), ceili(cx + half)):
			var u := (xx - (cx - half)) / (half * 2.0)
			var t := 0.75 - u * 0.6 + (K.hash2(xx, yy / 3, sd) - 0.5) * 0.14
			if (xx + yy / 6) % 3 == 0:
				t -= 0.18
			K.px(im, xx, yy, bark[clampi(roundi(t * 5.0), 0, 5)])
	# the crown: widening toward a rounded skirt, built from clumps
	for yy in range(2, 62):
		var f := float(yy - 2) / 60.0
		var half := 2.0 + f * 13.0
		if f > 0.85:
			half *= 1.0 - (f - 0.85) * 2.4
		for xx in range(0, w):
			var dx := xx + 0.5 - cx
			var v := vnoise(xx * 0.32, yy * 0.36, sd)
			if absf(dx) > half + (v - 0.5) * 4.0:
				continue
			if yy > 50 and v < 0.28:
				continue
			var t := 0.42 + (v - 0.5) * 0.9 - dx / (half + 1.0) * 0.28 + (0.5 - f) * 0.12
			var c := vnoise(xx * 0.32 + 0.6, yy * 0.36 + 0.5, sd)
			if c < v - 0.12:
				t += 0.16
			K.px(im, xx, yy, green[clampi(roundi(t * 5.0), 0, 5)])
	K.px(im, int(cx), 1, green[3])
	K.outline(im, Color("1e1a16"))
	return im


# ---------------------------------------------------------------- Indian Village

## A cone of incense-cedar bark slabs over a pole frame, with a doorway.
## Each course of slabs overlaps the one below it and throws a shadow, the
## apex is sooted by the fire inside, and the doorway has a lintel pole and a
## hanging woven mat. A worn patch of earth and a ring of stones sit at the base.
## TRIBAL REVIEW NEEDED: a placeholder shape until the tribes have reviewed it.
func umacha() -> Image:
	var w := 32
	var h := 44
	var im := K.make(w, h)
	K.shadow(im, 16, 42, 14.5, 2.4, 0.3)
	# packed earth worn round the door
	K.ellipse(im, 16, 42, 13.0, 2.2, Color("7a6044"))
	K.ellipse(im, 15, 41.6, 10.0, 1.4, Color("94784f"))
	var courses := [5, 12, 19, 26, 33, 42]
	for y in range(5, 42):
		var half := (y - 3) * 0.41
		var course := 0
		while course < courses.size() - 1 and y >= courses[course + 1]:
			course += 1
		var cy: int = y - courses[course]
		for x in range(floori(16 - half), ceili(16 + half)):
			var u := (x - (16 - half)) / maxf(1.0, half * 2.0)
			# slabs are tall strips, staggered between courses
			var slab := (x + course * 2) / 3
			var n := K.hash2(slab, course, 17)
			var t := 0.58 + (n - 0.5) * 0.3 - u * 0.62 + (0.5 - float(y) / h) * 0.1
			# each course is lit at its top edge and shadowed under the next
			if cy == 0:
				t += 0.2
			elif cy >= 6:
				t -= 0.24
			elif cy >= 5:
				t -= 0.1
			var idx := clampi(roundi(t * 4.0) + 1, 0, 5)
			var col := timber[idx]
			# bark furrows and the seams between slabs
			if (x + course * 2) % 3 == 0:
				col = col.darkened(0.2)
			elif K.hash2(x, y / 2, 18) > 0.92:
				col = col.lightened(0.14)
			K.px(im, x, y, col)
	# soot streaks down from the smoke hole
	for y in range(5, 17):
		var half := (y - 3) * 0.41
		for x in range(floori(16 - half), ceili(16 + half)):
			var k := K.hash2(x, y, 23)
			var fade := 1.0 - float(y - 5) / 12.0
			if k < 0.42 * fade:
				K.px(im, x, y, im.get_pixel(x, y).darkened(0.32 * fade + 0.1))
	# pole tips crossing at the apex, with a wisp of smoke
	for pole in [[14, 0, -1], [17, 1, 1], [19, 0, 1], [12, 1, -1]]:
		for k in 7:
			K.px(im, pole[0] + pole[2] * (k / 4), pole[1] + k, timber[1] if k % 2 == 0 else timber[0])
	K.px(im, 15, 0, timber[3])
	K.px(im, 18, 1, timber[3])
	K.px(im, 16, 2, Color(0.8, 0.8, 0.82, 0.55))
	K.px(im, 17, 1, Color(0.85, 0.85, 0.88, 0.4))
	K.px(im, 16, 0, Color(0.85, 0.85, 0.88, 0.3))
	# doorway: lintel pole, dark opening, a woven mat folded back at one side
	K.rect(im, 11, 31, 10, 11, timber[0])
	K.rect(im, 12, 30, 8, 1, timber[0])
	K.rect(im, 13, 32, 6, 9, Color("120a07"))
	K.hline(im, 11, 31, 10, timber[3])
	K.hline(im, 12, 30, 8, timber[2])
	for my in range(32, 41):
		K.px(im, 13, my, stucco[2] if my % 2 == 0 else stucco[3])
		K.px(im, 14, my, stucco[1] if my % 2 == 0 else stucco[2])
	shade(im, 11, 41, 10, 1, timber[0], 1.0, 1.0, 0.5)
	# granite stones holding the base down
	for sx in [4, 8, 24, 28]:
		boulder(im, sx + 1, 41, 2.8, 1.9, sd_for(sx))
	K.outline(im, Color("231a16"))
	return im


func sd_for(v: int) -> int:
	return 200 + v


## An acorn granary: a tall woven store on poles under a thatched cap, with
## flat stones under the cap to keep out mice, a basket-weave body and cord
## bands, and thatch in layered rings. The poles stand on stones.
## TRIBAL REVIEW NEEDED: a placeholder shape until the tribes have reviewed it.
func chuckah() -> Image:
	var w := 20
	var h := 40
	var im := K.make(w, h)
	K.shadow(im, 10, 38.5, 8.5, 1.8, 0.3)
	for px_ in [4, 9, 15]:
		post(im, px_, 26, 12, 300 + px_, 2)
	# footing stones
	for px_ in [5, 10, 16]:
		boulder(im, px_, 38, 2.2, 1.4, 310 + px_)
	K.hline(im, 3, 26, 15, timber[1])
	# woven body: a diagonal basket weave, lit on the left, bellied at the middle
	for y in range(12, 27):
		var half := 6.4 + sin((y - 12) / 14.0 * PI) * 1.2
		for x in range(floori(10 - half), ceili(10 + half)):
			var u := (x - (10 - half)) / (half * 2.0)
			var weave := ((x + y) % 4 < 2) != ((x - y + 40) % 6 < 3)
			var t := 0.62 + (K.hash2(x, y, 31) - 0.5) * 0.14 - u * 0.55
			var col := stucco[clampi(roundi(t * 4.0), 0, 4)]
			if weave:
				col = col.darkened(0.16)
			elif (x + y) % 4 == 0:
				col = col.lightened(0.08)
			K.px(im, x, y, col)
	# willow cord bands
	for y in [14, 19, 24]:
		for x in range(4, 17):
			if im.get_pixel(x, y).a > 0.5:
				var u := float(x - 4) / 12.0
				K.px(im, x, y, timber[clampi(3 - int(u * 3.0), 0, 3)])
		for x in range(4, 17):
			if im.get_pixel(x, y + 1).a > 0.5:
				K.px(im, x, y + 1, timber[0])
	# the cap: layered rings of thatch, each lit on top, and a ridge knot
	for y in range(3, 13):
		var half := (y - 1) * 0.8
		var ring := (y - 3) / 3
		for x in range(floori(10 - half), ceili(10 + half)):
			var u := (x - (10 - half)) / maxf(1.0, half * 2.0)
			var t := 0.72 - u * 0.45 + (K.hash2(x, y, 32) - 0.5) * 0.26
			if (y - 3) % 3 == 0:
				t += 0.16
			elif (y - 3) % 3 == 2:
				t -= 0.14
			var col := warm[clampi(roundi(t * 3.0) + 2, 2, 5)].lerp(stucco[3], 0.5)
			if (x + y * 2 + ring) % 4 == 0:
				col = col.darkened(0.18)
			K.px(im, x, y, col)
	# the overhang's shadow on the body
	for x in range(5, 16):
		K.px(im, x, 13, Color(0, 0, 0, 0.3))
		K.px(im, x, 14, Color(0, 0, 0, 0.14))
	K.hline(im, 3, 12, 14, timber[0])
	K.px(im, 10, 2, stucco[3])
	K.px(im, 10, 1, stucco[2])
	K.px(im, 10, 0, timber[1])
	K.outline(im, Color("231a16"))
	return im


# ---------------------------------------------------------------- street props

## A steel bear-proof food box: olive paint over riveted panels, a heavy lid
## with a latch and hasp, a worn edge, a dent, and a lit top.
func bear_box() -> Image:
	var im := K.make(16, 12)
	K.shadow(im, 8, 10.5, 7.5, 1.4, 0.28)
	for yy in 9:
		for xx in 14:
			var t := 0.6 + (K.hash2(xx, yy, 51) - 0.5) * 0.1 - float(xx) / 14.0 * 0.32 + (0.5 - float(yy) / 9.0) * 0.1
			K.px(im, 1 + xx, 1 + yy, moss[clampi(roundi(t * 2.0), 0, 2)].darkened(0.08))
	# the lid: a steel band with a lit top edge, and a shadow under it
	K.rect(im, 1, 1, 14, 3, iron[3])
	K.hline(im, 1, 1, 14, iron[3].lightened(0.35))
	K.hline(im, 1, 3, 14, iron[1])
	K.hline(im, 1, 4, 14, iron[0])
	# paint worn through to steel along the lid edge
	for xx in [3, 4, 9, 12]:
		K.px(im, 1 + xx, 5, iron[2])
	# hasp and latch
	K.rect(im, 6, 5, 4, 4, granite[5])
	K.hline(im, 6, 5, 4, granite[6])
	K.rect(im, 7, 7, 2, 2, iron[0])
	K.px(im, 7, 6, iron[1])
	K.vline(im, 8, 6, 2, iron[1])
	# rivets and a dent
	for rv in [[2, 6], [13, 6], [2, 8], [13, 8]]:
		K.px(im, rv[0], rv[1], granite[6])
	K.px(im, 11, 7, moss[0])
	K.px(im, 12, 7, moss[0].darkened(0.2))
	K.hline(im, 1, 9, 14, iron[0])
	# a bear-warning decal
	K.px(im, 3, 7, Color("e8d08a"))
	K.px(im, 4, 7, Color("e8d08a"))
	K.outline(im, Color("231a16"))
	return im


## The shuttle stop: a green stained-wood sign on an iron post, with a bus
## roundel and a stone footing.
func shuttle_stop() -> Image:
	var im := K.make(16, 30)
	K.shadow(im, 8, 28.5, 5.5, 1.3, 0.3)
	for yy in range(10, 28):
		K.px(im, 7, yy, iron[3])
		K.px(im, 8, yy, iron[1])
	K.rect(im, 5, 26, 6, 3, granite[4])
	K.hline(im, 5, 26, 6, granite[6])
	K.hline(im, 5, 28, 6, granite[1])
	K.rect(im, 1, 1, 14, 10, timber[0])
	for yy in 8:
		for xx in 12:
			K.px(im, 2 + xx, 2 + yy, leaf[1 + int(K.hash2(xx, yy, 71) * 1.4)])
	K.hline(im, 2, 2, 12, leaf[3])
	K.rect(im, 4, 4, 8, 4, Color("eadfbe"))
	K.hline(im, 4, 4, 8, Color("fff3d2"))
	K.rect(im, 5, 5, 6, 2, leaf[2])
	K.px(im, 5, 7, iron[0])
	K.px(im, 10, 7, iron[0])
	K.outline(im, Color("231a16"))
	return im
