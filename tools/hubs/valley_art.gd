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
const BUILDINGS := {
	"village_store": {"size": Vector2i(80, 56), "wall": "timber", "label": "VILLAGE STORE", "seed": 11, "roof": ["2a2a22", "3a3c2c", "4d5238", "62684a", "7b815b", "989d76"], "windows": [14, 66], "gable": 20, "chimney": 60, "awning": true},
	"welcome_center": {"flag": true, "size": Vector2i(64, 46), "wall": "stone", "label": "WELCOME", "seed": 23, "roof": ["24262a", "34383e", "484e56", "5e666e", "7a828a", "9aa2a8"], "windows": [11, 53], "gable": 32, "chimney": 46},
	"museum": {"size": Vector2i(56, 46), "wall": "stone", "label": "MUSEUM", "seed": 37, "roof": ["2c2822", "443c32", "5e5242", "786a54", "948468", "b0a07e"], "windows": [9, 19, 37, 47], "chimney": 8, "low": true},
	"bests_studio": {"size": Vector2i(44, 38), "wall": "board", "label": "BEST'S", "seed": 41, "roof": ["2e2218", "4a3422", "644630", "7e5c3e", "9a7650", "b89468"], "windows": [9, 35], "gable": 22, "tone": 3},
	"degnans": {"size": Vector2i(48, 40), "wall": "stucco", "label": "DEGNAN'S", "seed": 53, "roof": ["34201a", "55301f", "74402a", "92583a", "ae7248", "c98c5c"], "windows": [9, 39], "chimney": 36, "awning": true, "awning_a": "9a3a2a", "awning_b": "e8d8b0"},
	"wilderness_center": {"size": Vector2i(40, 36), "wall": "board", "label": "PERMITS", "seed": 67, "roof": ["1c2a22", "2a4030", "3a5640", "4d6e50", "658a64", "84a67c"], "windows": [8, 32], "tone": 2, "green": true},
	"valley_lodge": {"size": Vector2i(72, 44), "wall": "timber", "label": "LODGE", "seed": 79, "windows": [10, 22, 50, 62], "gable": 36, "chimney": 56, "pitch": 12},
}

const PROPS := ["umacha", "chuckah", "bear_box", "shuttle_stop"]
const FILES := ["village_store", "welcome_center", "museum", "bests_studio", "degnans", "wilderness_center", "valley_lodge",
	"umacha", "chuckah", "bear_box", "shuttle_stop",
	"village_store_glow", "welcome_center_glow", "museum_glow", "bests_studio_glow", "degnans_glow", "wilderness_center_glow", "valley_lodge_glow"]


func save_all() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	for sprite_name: String in BUILDINGS:
		var built := building(sprite_name)
		_write(built[0], sprite_name)
		_write(built[1], sprite_name + "_glow")
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
		_:
			timber_wall(im, x, y, w, h, sd, int(o.get("pitch", 16)), 40)


# ---------------------------------------------------------------- openings

## A plank door under a stone lintel with an arched top, on a granite step.
func plank_door(im: Image, cx: int, bottom: int, h: int, sd: int, w := 8) -> void:
	var x := cx - w / 2
	var top := bottom - h
	K.rect(im, x - 2, top - 2, w + 4, 2, granite[4])
	K.hline(im, x - 2, top - 2, w + 4, granite[6])
	K.hline(im, x - 2, top - 1, w + 4, granite[2])
	K.rect(im, x - 1, top, w + 2, h, timber[0])
	for yy in h:
		for xx in w:
			if yy < 2 and (xx < 2 - yy or xx >= w - (2 - yy)):
				continue
			var plank := xx / 2
			var idx := 2 + int(K.hash2(plank, sd, 7) * 2.0)
			if xx % 2 == 0:
				idx += 1
			var col := timber[clampi(idx, 0, 5)]
			if yy > h * 0.55 and yy < h * 0.6:
				col = timber[1]
			K.px(im, x + xx, top + yy, col)
	K.vline(im, cx, top + 2, h - 2, timber[1])
	K.px(im, cx - 2, top + h / 2, warm[5])
	K.px(im, cx + 1, top + h / 2, warm[4])
	# step
	K.rect(im, x - 2, bottom, w + 4, 1, granite[5])
	K.hline(im, x - 2, bottom, w + 4, granite[6])
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
## with the style set in [constant BUILDINGS].
func building(sprite_name: String) -> Array:
	var o: Dictionary = BUILDINGS[sprite_name]
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
	shingle_roof(im, 0, 2, w, wall_top - 3, sd + 200, taper)
	if o.has("gable"):
		var gx: int = o["gable"]
		var apex := mini(wall_top - 8, 15)
		gable(im, gx, wall_top - 1, mini(15, w / 4 + 2), apex, 3, sd + 300, true, 6)
	if o.has("chimney"):
		var cx: int = o["chimney"]
		chimney(im, cx, 8, maxi(6, wall_top - 14), sd + 400)
	eave(im, 0, wall_top - 2, w)

	# Windows, door, sign.
	var win_h := clampi(body_h - 7, 4, 8)
	for wx: int in o["windows"]:
		window(im, wx - 3, wall_top + 3, 6, win_h, K.hash2(wx, sd, 5) < 0.55, sd + wx)
	var door_cx := w / 2
	if o.has("gable") and not o.get("low", false):
		door_cx = w / 2
	var door_h := mini(wall_h - 3, 13)
	plank_door(im, door_cx, h - 2, door_h, sd + 500)
	if o.get("awning", false):
		var aw := mini(w - 18, 38)
		awning(im, door_cx - aw / 2, wall_top + 1, aw, 5, Color(o.get("awning_a", "3f6b4a")), Color(o.get("awning_b", "e6d8b0")))
	sign_board(im, door_cx, wall_top - 8 if not o.get("awning", false) else wall_top - 9, o["label"])

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
		var by := wall_top + 3 + win_h + 1
		K.rect(im, wx - 4, by, 8, 2, timber[1])
		K.hline(im, wx - 4, by, 8, timber[3])
		for fx in range(wx - 3, wx + 4):
			var tall := K.hash2(fx, sd, 7) > 0.45
			K.px(im, fx, by - 1, leaf[3])
			if tall:
				K.px(im, fx, by - 2, pick[0] if (fx + sd) % 2 == 0 else pick[1])
			elif K.hash2(fx, sd, 8) > 0.5:
				K.px(im, fx, by - 1, pick[0])
	if o.get("flag", false):
		_visitor_details(im, wall_top, door_cx, sd)
	# a wall lantern beside the door
	var lx := door_cx + 7
	var ly := wall_top + 4
	K.rect(im, lx - 1, ly - 1, 3, 1, iron[3])
	K.rect(im, lx - 1, ly, 3, 4, iron[1])
	K.rect(im, lx, ly + 1, 1, 2, warm[6])
	K.px(im, lx, ly + 1, warm[7])
	K.hline(im, lx - 1, ly + 4, 3, iron[3])


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
