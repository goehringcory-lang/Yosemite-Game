extends "res://tools/hubs/ahwahnee_hotel_art.gd"
## Camp 4 pixel art in the Ahwahnee's style: Columbia Boulder with the chalk
## lightning bolt and chalked holds of Midnight Lightning, the campsites'
## tents (a 1950s canvas wall tent, modern domes, a dirtbag's tarp), steel
## fire rings with animated flames, picnic tables set for cooking or racking
## gear, the bulletin-board kiosk, the routed Park Service sign, a slackline,
## the traders' gear tarps, a 1970s van in the lot, and pine-needle litter.
## Same ramps, ordered dithering, light from the upper left and dark rim as
## the rest of the Valley. Written to assets/sprites/buildings/ as camp4_*.
## Replace any PNG with hand-drawn art of the same size at any time.
##
## Every sprite is anchored at its bottom center. The fire ring sheets have
## FIRE_FRAMES frames side by side and sit on a ground line FIRE_INSET px above
## their bottom edge. Tents and the cook table get a "<name>_glow" picture of
## lantern light for the builder to fade in at dusk.
##
## Preview: godot --headless --path . -s res://tools/hubs/preview_camp4_art.gd

const FloraArt = preload("res://tools/hubs/ahwahnee_flora_art.gd")
const OUT := "res://assets/sprites/buildings/"
const RIM := Color("231a16")
const CHALK := Color("f3f0e8")

const FIRE_W := 28
const FIRE_H := 30
const FIRE_FRAMES := 4
const FIRE_INSET := 4

## Columbia Boulder's size and where the chalk bolt sits on it, in px from
## the sprite's bottom center (the builder puts the Midnight Lightning sign there).
const COLUMBIA_SIZE := Vector2i(132, 100)
const BOLT_AT := Vector2(-4, -36)

## Dome tent colors: [shadow, light].
const DOMES := [["c0601f", "f0a050"], ["3d7a44", "7cb36a"], ["2f6a9c", "6aa2cc"], ["c9962c", "f0cd72"]]

const FILES := [
	"camp4_columbia_boulder", "camp4_boulder", "camp4_crash_pad",
	"camp4_tent_canvas", "camp4_tent_canvas_glow", "camp4_tent_tarp",
	"camp4_tent_dome_0", "camp4_tent_dome_1", "camp4_tent_dome_2", "camp4_tent_dome_3",
	"camp4_tent_dome_0_glow", "camp4_tent_dome_1_glow", "camp4_tent_dome_2_glow", "camp4_tent_dome_3_glow",
	"camp4_fire_ring", "camp4_fire_ring_cold",
	"camp4_table", "camp4_table_cook", "camp4_table_cook_glow", "camp4_table_rack",
	"camp4_board", "camp4_sign", "camp4_slackline", "camp4_tarp_rack", "camp4_tarp_bigwall",
	"camp4_van", "camp4_duff_0", "camp4_duff_1", "camp4_duff_2",
]

var canvas: Array[Color] = []
var gr: Array[Color] = []


func _init() -> void:
	super()
	canvas = _ramp(["4e4632", "6c6244", "8a7f58", "a69a6c", "c2b584", "dccf9f"])
	gr = FloraArt.ramp(FloraArt.GRANITE)


func save_all() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	_write(columbia_boulder(), "camp4_columbia_boulder")
	_write(small_boulder(), "camp4_boulder")
	_write(crash_pad(), "camp4_crash_pad")
	var tent := canvas_tent()
	_write(tent, "camp4_tent_canvas")
	_write(fabric_glow(tent, Rect2i(8, 12, 32, 22)), "camp4_tent_canvas_glow")
	_write(tarp_shelter(), "camp4_tent_tarp")
	for i in DOMES.size():
		var dome := dome_tent(Color(DOMES[i][0]), Color(DOMES[i][1]), i)
		_write(dome, "camp4_tent_dome_%d" % i)
		_write(fabric_glow(dome, Rect2i(3, 4, 30, 20)), "camp4_tent_dome_%d_glow" % i)
	_write(fire_ring(true), "camp4_fire_ring")
	_write(fire_ring(false), "camp4_fire_ring_cold")
	_write(picnic_table(""), "camp4_table")
	_write(picnic_table("cook"), "camp4_table_cook")
	_write(lantern_glow(), "camp4_table_cook_glow")
	_write(picnic_table("rack"), "camp4_table_rack")
	_write(bulletin_board(), "camp4_board")
	_write(park_sign(), "camp4_sign")
	_write(slackline(), "camp4_slackline")
	_write(gear_tarp(false), "camp4_tarp_rack")
	_write(gear_tarp(true), "camp4_tarp_bigwall")
	_write(van(), "camp4_van")
	for i in 3:
		_write(duff(i), "camp4_duff_%d" % i)


func _write(im: Image, sprite_name: String) -> void:
	im.save_png(ProjectSettings.globalize_path(OUT + sprite_name + ".png"))


# ---------------------------------------------------------------- helpers

## Fills a polygon (pixel centers inside it).
func poly(im: Image, pts: PackedVector2Array, col: Color) -> void:
	var r := Rect2(pts[0], Vector2.ZERO)
	for p in pts:
		r = r.expand(p)
	for y in range(floori(r.position.y), ceili(r.end.y) + 1):
		for x in range(floori(r.position.x), ceili(r.end.x) + 1):
			if Geometry2D.is_point_in_polygon(Vector2(x + 0.5, y + 0.5), pts):
				K.px(im, x, y, col)


## A 1 px line.
func line(im: Image, a: Vector2, b: Vector2, col: Color) -> void:
	var n := maxi(1, int(maxf(absf(b.x - a.x), absf(b.y - a.y))))
	for i in n + 1:
		var p := a.lerp(b, float(i) / n)
		K.px(im, roundi(p.x), roundi(p.y), col)


## A rope or guy line that sags between two points.
func sag_line(im: Image, a: Vector2, b: Vector2, sag: float, col: Color) -> void:
	var n := maxi(2, int(a.distance_to(b)))
	for i in n + 1:
		var t := float(i) / n
		var p := a.lerp(b, t) + Vector2(0, sin(t * PI) * sag)
		K.px(im, roundi(p.x), roundi(p.y), col)


## Text drawn at twice the size of PixelKit's 3x5 letters.
func big_text(im: Image, x: int, y: int, text_value: String, col: Color, shadow_col: Color) -> void:
	var cx := x
	for ch in text_value:
		var g: Array = K.FONT.get(ch, K.FONT[" "])
		if g[0] == "":
			cx += 5
			continue
		for gy in 5:
			for gx in 3:
				if g[gy][gx] == "#":
					K.rect(im, cx + gx * 2, y + gy * 2 + 1, 2, 2, shadow_col)
					K.rect(im, cx + gx * 2, y + gy * 2, 2, 2, col)
		cx += 8


func big_text_width(text_value: String) -> int:
	var w := 0
	for ch in text_value:
		w += 5 if K.FONT.get(ch, K.FONT[" "])[0] == "" else 8
	return w - 2


## A small orange glow ramp, for flames.
func flame_col(t: float) -> Color:
	return warm[clampi(roundi(3.0 + t * 4.0), 3, 7)]


# ---------------------------------------------------------------- Columbia Boulder

## Columbia Boulder: a house-sized block fallen from the wall, its top lit and
## patched with lichen, its south face steep and overhanging into a dark
## undercut. Up the middle of that face runs Midnight Lightning: chalked
## holds, tick marks, a smeared lip where climbers mantel onto the top, and
## the lightning bolt drawn in chalk beside the start.
func columbia_boulder() -> Image:
	var w := COLUMBIA_SIZE.x
	var h := COLUMBIA_SIZE.y
	var base := h - 6
	var cx := w / 2.0 - 2.0
	var half := w / 2.0 - 5.0
	var sd := 1978
	var im := K.make(w, h)
	K.shadow(im, cx + 4.0, base + 1.0, half + 4.0, 5.0, 0.34)
	# Facet cells, as on the Ahwahnee boulders.
	var cells := []
	for gy in range(-1, 9):
		for gx in range(-1, 11):
			cells.append(Vector3((gx + K.hash2(gx, gy, sd)) * 14.0, (gy + K.hash2(gx, gy, sd + 1)) * 13.0, K.hash2(gx, gy, sd + 2) - 0.5))
	var streaks := {}
	for i in 7:
		streaks[int(14 + K.hash2(i, 3, sd) * (w - 28))] = 0.4 + K.hash2(i, 4, sd) * 0.6
	for x in w:
		var u := (x + 0.5 - cx) / half
		var au := absf(u)
		if au > 1.0:
			continue
		var top := 8.0 + 12.0 * pow(au, 2.4) + FloraArt.wobble(x * 0.09, sd) * 2.5
		# a lower shoulder on the east end, and rounded ends
		top += 7.0 * smoothstep(0.3, 0.5, u)
		if au > 0.8:
			top += pow((au - 0.8) / 0.2, 2.0) * 24.0
		var lip := 31.0 + 8.0 * au * au + 4.0 * smoothstep(0.3, 0.5, u) + FloraArt.wobble(x * 0.13, sd + 5) * 2.4
		var bottom := base - 2.0 * au * au
		# the ends tuck under: the block is wider at the top than where it sits
		if au > 0.68:
			bottom -= pow((au - 0.68) / 0.32, 1.6) * 22.0
		lip = minf(lip, bottom - 6.0)
		for y in range(int(top), int(bottom) + 1):
			# nearest and second-nearest cells give the facet tone and its cracks
			var d1 := 1e9
			var d2 := 1e9
			var facet := 0.0
			for c: Vector3 in cells:
				var dd := (c.x - x) * (c.x - x) + (c.y - y) * (c.y - y)
				if dd < d1:
					d2 = d1
					d1 = dd
					facet = c.z
				elif dd < d2:
					d2 = dd
			var edge := sqrt(d2) - sqrt(d1)
			var t: float
			var on_top := y < lip
			if on_top:
				var fy := (y - top) / maxf(1.0, lip - top)
				t = 0.8 - u * 0.22 - fy * 0.08 + facet * 0.18
			else:
				# the south face is out of the sun, lit only on the west end
				var fy := (y - lip) / maxf(1.0, bottom - lip)
				t = 0.36 - u * 0.16 - fy * 0.12 + facet * 0.2 + maxf(0.0, -u - 0.6) * 0.7
				if y < lip + 2.0:
					t += 0.12
				# the overhang: the face tucks back into shadow near the ground
				if y > bottom - 12.0 and au < 0.8:
					t -= 0.2 * (1.0 - (bottom - y) / 12.0) + 0.04
			t += (K.hash2(x, y, sd + 9) - 0.5) * 0.08
			var col := FloraArt.shade(gr, t, x, y)
			var sp := K.hash2(x, y, sd + 4)
			if sp > 0.955:
				col = gr[maxi(0, int(t * 6.0) - 2)]
			elif sp < 0.025:
				col = gr[mini(gr.size() - 1, int(t * 7.0) + 2)]
			if edge < 0.9 and K.hash2(x / 3, y / 3, sd + 6) > 0.4:
				col = gr[1].lerp(gr[2], 0.4 if on_top else 0.0)
			elif edge < 1.8 and K.hash2(x, y, sd + 12) > 0.6:
				col = FloraArt.shade(gr, t + 0.16, x, y)
			if on_top:
				# lichen and the odd tuft of moss on the sunny top
				var ln := FloraArt.wobble(x * 0.45 + y * 0.3, sd + 20) + FloraArt.wobble(y * 0.6, sd + 21) * 0.5
				if ln > 0.62 and K.hash2(x, y, sd + 30) > 0.3:
					col = Color("b4bf80") if K.hash2(x, y, sd + 31) > 0.35 else Color("cfb060")
				elif ln < -0.95 and K.hash2(x, y, sd + 32) > 0.4:
					col = Color("588a52") if K.hash2(x, y, sd + 33) > 0.5 else Color("436f45")
				if lip - y < 1.5:
					col = gr[7] if K.hash2(x, y, sd + 34) > 0.3 else gr[6]
			else:
				# black water streaks run down the face from the lip
				for sx: int in streaks:
					var dx := absf(x - sx - FloraArt.wobble(y * 0.2, sx) * 1.5)
					var len_f: float = streaks[sx]
					if dx < 1.6 and (y - lip) < (bottom - lip) * len_f:
						col = col.lerp(Color("2c2f36"), 0.32 * (1.0 - dx / 1.6))
				if y >= bottom - 1.0:
					col = col.darkened(0.3)
			K.px(im, x, y, col)
	_midnight_lightning(im, w, base)
	# Duff, needles and a few stones banked against the foot of the rock.
	for i in 26:
		var bx := 24 + int(K.hash2(i, 1, sd) * (w - 48))
		var by := base - 1 + int(K.hash2(i, 2, sd) * 4.0)
		K.px(im, bx, by, timber[1 + int(K.hash2(i, 3, sd) * 3.0)])
		K.px(im, bx + 1, by, timber[2])
	for sx in [26, 33, 96, 104]:
		boulder(im, sx, base + 1, 3.0, 2.0, 300 + sx)
	K.outline(im, RIM)
	return im


## The problem's chalk: holds up the face, the smeared lip, and the bolt.
func _midnight_lightning(im: Image, w: int, base: int) -> void:
	var cx := w / 2 - 2
	var holds := [[2, 74], [8, 68], [-1, 62], [6, 55], [12, 48], [3, 44], [10, 39]]
	for i in holds.size():
		var hx: int = cx + holds[i][0]
		var hy: int = holds[i][1]
		var size := 3 + (1 if i % 3 == 0 else 0)
		for yy in 2:
			for xx in size:
				if K.hash2(hx + xx, hy + yy, 7) > 0.15:
					K.px(im, hx + xx, hy + yy, CHALK if yy == 0 else CHALK.darkened(0.18))
		# a hold's shadow and a tick mark beside it
		K.hline(im, hx, hy + 2, size, gr[0])
		if i % 2 == 1:
			K.px(im, hx - 2, hy + 1, CHALK.darkened(0.08))
	# the lip: a broad smear of chalk where hands slap and the mantel begins
	for xx in range(cx - 2, cx + 18):
		for yy in range(30, 35):
			if K.hash2(xx, yy, 8) > 0.45 + absf(xx - cx - 8) * 0.04:
				K.px(im, xx, yy + int(absf(xx - cx - 8) * 0.12), CHALK.lerp(gr[5], K.hash2(xx, yy, 9) * 0.5))
	# the lightning bolt, drawn in chalk left of the start holds
	var o := Vector2(cx + BOLT_AT.x - 22, base + BOLT_AT.y - 20)
	var bolt := PackedVector2Array([Vector2(9, 0), Vector2(19, 0), Vector2(13, 12), Vector2(20, 12), Vector2(4, 36), Vector2(8, 18), Vector2(1, 18)])
	for i in bolt.size():
		bolt[i] += o
	poly(im, bolt, CHALK)
	# worn, uneven chalk: a few grey pixels inside and a darker drawn edge
	var r := Rect2i(int(o.x), int(o.y), 22, 38)
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			if not Geometry2D.is_point_in_polygon(Vector2(x + 0.5, y + 0.5), bolt):
				continue
			if K.hash2(x, y, 11) > 0.86:
				K.px(im, x, y, CHALK.lerp(gr[4], 0.45))
			for d: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
				if not Geometry2D.is_point_in_polygon(Vector2(x + d.x + 0.5, y + d.y + 0.5), bolt):
					K.px(im, x + d.x, y + d.y, gr[5].lerp(CHALK, 0.3))
					break
	# drips of chalk dust below the bolt and the start holds
	for i in 7:
		K.px(im, int(o.x) + 2 + int(K.hash2(i, 1, 13) * 30.0), base - 3 - int(K.hash2(i, 2, 13) * 5.0), CHALK.lerp(gr[3], 0.4))


## A smaller warm-up boulder with chalk on its lit side.
func small_boulder() -> Image:
	var im := FloraArt.new().rock(64, 48, 1957, 0.08, 0.6, false, 1.1)
	for i in 9:
		var x := 18 + int(K.hash2(i, 1, 41) * 22.0)
		var y := 14 + int(K.hash2(i, 2, 41) * 20.0)
		if im.get_pixel(x, y).a > 0.5 and im.get_pixel(x + 1, y).a > 0.5:
			K.px(im, x, y, CHALK)
			K.px(im, x + 1, y, CHALK.darkened(0.15))
	return im


## A folded bouldering pad, red top and grey sides, with its straps.
func crash_pad() -> Image:
	var im := K.make(34, 16)
	K.shadow(im, 17, 13, 16.0, 2.4, 0.26)
	var top := _ramp(["7a1f1a", "9c2c22", "bf4030", "d8604a"])
	for y in range(2, 10):
		for x in range(2, 32):
			var t := 0.62 - float(x) / 30.0 * 0.3 - float(y - 2) / 8.0 * 0.15 + (K.hash2(x, y, 5) - 0.5) * 0.12
			K.px(im, x, y, at(top, t))
	K.hline(im, 2, 2, 30, top[3].lightened(0.15))
	# the fold seam and the side wall
	K.hline(im, 2, 6, 30, top[1])
	K.rect(im, 2, 10, 30, 3, iron[2])
	K.hline(im, 2, 10, 30, iron[3])
	K.hline(im, 2, 12, 30, iron[1])
	for sx in [9, 23]:
		K.vline(im, sx, 2, 11, iron[0])
		K.px(im, sx, 8, granite[6])
	# a spill of chalk where someone set the bag down
	for i in 5:
		K.px(im, 26 + i % 3, 4 + i / 3, CHALK)
	K.outline(im, RIM)
	return im


# ---------------------------------------------------------------- tents

## A canvas wall tent like the ones climbers lived in for whole seasons in the
## 1950s and 60s: short walls, a ridge roof going back, door flaps tied open,
## a patched and weathered skin, a pole poking through, and guy lines.
func canvas_tent() -> Image:
	var w := 48
	var h := 38
	var im := K.make(w, h)
	K.shadow(im, 24, h - 4.0, 22.0, 3.6, 0.3)
	var apex := Vector2(24, 9)
	var back := Vector2(0, -7)
	var eave_l := Vector2(7, 21)
	var eave_r := Vector2(41, 21)
	var floor_y := 33
	# roof planes, lit on the left
	_canvas_fill(im, PackedVector2Array([apex + back, apex, eave_l, eave_l + back]), 0.78, 11)
	_canvas_fill(im, PackedVector2Array([apex + back, apex, eave_r, eave_r + back]), 0.34, 12)
	line(im, apex + back, apex, canvas[5])
	# the front: gable and walls
	_canvas_fill(im, PackedVector2Array([apex, eave_r, Vector2(eave_r.x, floor_y), Vector2(eave_l.x, floor_y), eave_l]), 0.56, 13)
	# seams, a patch, and dirt splashed up the walls
	for sx in [15, 33]:
		for y in range(13, floor_y):
			if Geometry2D.is_point_in_polygon(Vector2(sx + 0.5, y + 0.5), PackedVector2Array([apex, eave_r, Vector2(eave_r.x, floor_y), Vector2(eave_l.x, floor_y), eave_l])):
				tint_px(im, sx, y, canvas[1], 0.5)
	K.rect(im, 33, 24, 5, 4, canvas[4].lerp(Color("8f7a52"), 0.4))
	K.hline(im, 33, 24, 5, canvas[5])
	for x in range(eave_l.x, eave_r.x + 1):
		for y in range(floor_y - 3, floor_y + 1):
			if K.hash2(x, y, 14) > 0.35 + (floor_y - y) * 0.15:
				tint_px(im, x, y, Color("6a4a2c"), 0.4)
	# eave line where the roof meets the wall
	line(im, apex, eave_l, canvas[5])
	line(im, apex, eave_r, canvas[2])
	K.hline(im, eave_l.x, eave_l.y, 1, canvas[1])
	# the open door: dark inside, flaps tied back on either side
	poly(im, PackedVector2Array([Vector2(24, 12), Vector2(30, floor_y + 1), Vector2(18, floor_y + 1)]), Color("1c140e"))
	poly(im, PackedVector2Array([Vector2(24, 13), Vector2(24, floor_y), Vector2(20, floor_y + 1), Vector2(19, 27)]), Color("140e0a"))
	K.rect(im, 21, floor_y - 2, 6, 2, Color("8a2a20"))
	K.hline(im, 21, floor_y - 2, 6, Color("b24a32"))
	poly(im, PackedVector2Array([Vector2(24, 12), Vector2(18, floor_y + 1), Vector2(15, floor_y + 1), Vector2(17, 24)]), canvas[3])
	poly(im, PackedVector2Array([Vector2(24, 12), Vector2(30, floor_y + 1), Vector2(33, floor_y + 1), Vector2(31, 24)]), canvas[1])
	K.px(im, 17, 24, Color("7a5a36"))
	K.px(im, 31, 24, Color("5a4026"))
	# ridge pole poking out above the gable, and the front upright
	K.vline(im, 24, 6, 4, timber[3])
	K.px(im, 24, 5, timber[4])
	K.vline(im, 24, 12, 3, timber[1])
	# guy lines out to the stakes
	for g in [[eave_l, Vector2(1, floor_y + 1)], [eave_r, Vector2(46, floor_y + 1)], [apex + back, Vector2(24, 1)]]:
		line(im, g[0], g[1], Color("d8cfb4").darkened(0.15))
		K.px(im, int(g[1].x), int(g[1].y), timber[4])
	K.outline(im, RIM)
	return im


func _canvas_fill(im: Image, pts: PackedVector2Array, tone: float, sd: int) -> void:
	var r := Rect2(pts[0], Vector2.ZERO)
	for p in pts:
		r = r.expand(p)
	for y in range(floori(r.position.y), ceili(r.end.y) + 1):
		for x in range(floori(r.position.x), ceili(r.end.x) + 1):
			if not Geometry2D.is_point_in_polygon(Vector2(x + 0.5, y + 0.5), pts):
				continue
			var t := tone + (vnoise(x * 0.3, y * 0.3, sd) - 0.5) * 0.18 - (y - r.position.y) / maxf(1.0, r.size.y) * 0.12
			K.px(im, x, y, FloraArt.shade(canvas, t, x, y))


## A modern dome tent: a nylon fly shaded as a dome, the crossing poles,
## a vestibule zipped over the door, a mesh vent, and staked guy lines.
func dome_tent(color: Color, light: Color, v: int) -> Image:
	var w := 36
	var h := 28
	var im := K.make(w, h)
	K.shadow(im, 18, h - 4.0, 17.0, 3.0, 0.3)
	var cx := 18.0
	var cy := 20.0
	var rx := 15.5
	var ry := 16.0
	var dark := color.darkened(0.45)
	for y in range(3, 25):
		for x in range(2, 34):
			var dx := (x + 0.5 - cx) / rx
			var dy := (y + 0.5 - cy) / ry
			if dx * dx + dy * dy > 1.0 or y > 23:
				continue
			var nz := sqrt(maxf(0.0, 1.0 - dx * dx - dy * dy))
			var lam := -dx * 0.55 - dy * 0.45 + nz * 0.55
			var t := clampf(0.3 + lam * 0.7 + (K.hash2(x, y, 81 + v) - 0.5) * 0.08, 0.0, 1.0)
			var col := dark.lerp(color, clampf(t * 2.0, 0.0, 1.0)).lerp(light, clampf(t * 2.0 - 1.0, 0.0, 1.0))
			# the poles show as darker seams crossing over the top
			var s1 := absf(dx - dy * 0.55 - 0.05)
			var s2 := absf(dx + dy * 0.55 + 0.05)
			if (s1 < 0.06 or s2 < 0.06) and dy < 0.1:
				col = col.darkened(0.25)
			K.px(im, x, y, col)
	# the fly's hem, darker, staked out at the corners
	for x in range(3, 33):
		K.px(im, x, 23, dark)
	# vestibule over the door, zipped, with the pull and a mesh vent above
	poly(im, PackedVector2Array([Vector2(18, 10), Vector2(26, 24), Vector2(10, 24)]), color.darkened(0.12))
	poly(im, PackedVector2Array([Vector2(18, 10), Vector2(18, 24), Vector2(10, 24)]), color.lerp(light, 0.25))
	K.vline(im, 18, 11, 13, dark.darkened(0.2))
	K.px(im, 19, 17, Color("e8e2d0"))
	for x in range(15, 22):
		if x % 2 == 0:
			K.px(im, x, 7, dark)
	# guy lines and stakes
	for g in [[Vector2(4, 16), Vector2(0, 25)], [Vector2(32, 16), Vector2(35, 25)], [Vector2(18, 4), Vector2(18, 1)]]:
		line(im, g[0], g[1], Color("e2dccb").darkened(0.2))
		K.px(im, int(g[1].x), int(g[1].y), granite[5])
	K.outline(im, RIM)
	return im


## A blue plastic tarp strung over a rope between two sticks, a 1970s
## climber's home: open at the front, a sleeping bag and a stuff sack inside.
func tarp_shelter() -> Image:
	var w := 46
	var h := 32
	var im := K.make(w, h)
	K.shadow(im, 23, h - 4.0, 21.0, 3.2, 0.28)
	var blue := _ramp(["1e3a5c", "2a5582", "3a6ea6", "5a8cc4", "86b0de"])
	var apex := Vector2(23, 8)
	var back := Vector2(0, -6)
	var el := Vector2(4, 27)
	var er := Vector2(42, 27)
	# far end and the underside of the tarp, in shadow
	poly(im, PackedVector2Array([apex + back, el + back, er + back]), blue[0].darkened(0.2))
	poly(im, PackedVector2Array([apex, el + Vector2(2, 0), er - Vector2(2, 0)]), blue[1].darkened(0.35))
	# the ground inside: a foam pad and a red down bag, a stuff sack
	poly(im, PackedVector2Array([Vector2(16, 20), Vector2(30, 20), Vector2(33, 27), Vector2(13, 27)]), Color("6a7a4a"))
	for y in range(21, 27):
		for x in range(17, 30):
			var t := 0.6 - float(x - 17) / 13.0 * 0.4 + (0.5 - float(y - 21) / 6.0) * 0.2
			K.px(im, x, y, at(_ramp(["6a1c1a", "922a22", "b8402c", "d8664a"]), t))
	for x in range(17, 30, 3):
		K.vline(im, x, 21, 6, Color("6a1c1a"))
	K.ellipse(im, 34, 24, 2.5, 2.0, Color("e0a83a"))
	# the two tarp planes, lit on the left, with grommets at the corners
	poly(im, PackedVector2Array([apex + back, apex, el, el + back]), blue[3])
	poly(im, PackedVector2Array([apex + back, apex, er, er + back]), blue[1])
	for y in range(2, 28):
		for x in w:
			var p := im.get_pixel(x, y)
			if p == blue[3] or p == blue[1]:
				var n := vnoise(x * 0.4, y * 0.4, 31)
				if n > 0.68:
					K.px(im, x, y, p.lightened(0.12))
				elif n < 0.25:
					K.px(im, x, y, p.darkened(0.12))
	line(im, apex, el, blue[4])
	line(im, apex, er, blue[2])
	line(im, apex + back, apex, blue[4])
	for g in [el, er, el + back, er + back]:
		K.px(im, int(g.x), int(g.y), Color("d8d0c0"))
	# the ridge rope runs out to two sticks, and the sticks to stakes
	K.vline(im, 23, 6, 3, timber[3])
	line(im, apex + back + Vector2(0, -2), Vector2(23, 0), Color("c8b890"))
	K.outline(im, RIM)
	return im


## Lantern light through a tent's fabric, for dusk: warm over the fabric,
## brightest low and in the middle where the lantern hangs.
func fabric_glow(src: Image, area: Rect2i) -> Image:
	var w := src.get_width()
	var h := src.get_height()
	var im := K.make(w, h)
	var center := Vector2(area.get_center()) + Vector2(0, area.size.y * 0.15)
	for y in range(area.position.y, area.end.y):
		for x in range(area.position.x, area.end.x):
			var p := src.get_pixel(x, y)
			if p.a < 0.5 or p == RIM:
				continue
			var d := (Vector2(x, y) - center) / (Vector2(area.size) * 0.55)
			var a := clampf(1.0 - d.length(), 0.0, 1.0)
			if a <= 0.02:
				continue
			# ordered steps so the light reads as pixel art, not a blur
			a = floorf(a * 4.0 + FloraArt.bayer(x, y)) / 4.0
			K.px(im, x, y, Color(1.0, 0.72, 0.32, a * 0.55))
	return im


# ---------------------------------------------------------------- fire rings

## The Park Service's steel campground fire ring, with a flip-up grate at the
## back. Lit: a sheet of FIRE_FRAMES frames of split logs burning. Cold:
## charred ends in grey ash.
func fire_ring(lit: bool) -> Image:
	var frames := FIRE_FRAMES if lit else 1
	var im := K.make(FIRE_W * frames, FIRE_H)
	for f in frames:
		_fire_frame(im, f * FIRE_W, f, lit)
	return im


func _fire_frame(im: Image, ox: int, f: int, lit: bool) -> void:
	var cx := ox + FIRE_W / 2.0
	var ground := FIRE_H - FIRE_INSET
	var ty := ground - 5.0
	var rx := 11.5
	var ry := 4.5
	var rust := _ramp(["221c1a", "362c26", "4c3c32", "665040", "806650"])
	K.shadow(im, cx + 1.0, ground - 1.0, rx + 2.0, 3.4, 0.32)
	# back rim and the grate standing on it
	for x in range(int(cx - rx), int(cx + rx) + 1):
		var dx := (x + 0.5 - cx) / rx
		if absf(dx) > 1.0:
			continue
		var yb := ty - ry * sqrt(1.0 - dx * dx)
		K.px(im, x, int(yb), rust[3])
		K.px(im, x, int(yb) + 1, rust[1])
	for gx in range(int(cx - 7), int(cx - 1), 2):
		K.vline(im, gx, int(ty - ry) - 3, 3, iron[2])
	K.hline(im, int(cx - 7), int(ty - ry) - 3, 7, iron[3])
	# ash bed
	K.ellipse(im, cx, ty, rx - 1.0, ry - 1.0, Color("57514c"))
	for i in 18:
		var ax := int(cx - rx + 2 + K.hash2(i, f, 5) * (rx * 2 - 4))
		var ay := int(ty - ry + 2 + K.hash2(i, f, 6) * (ry * 2 - 3))
		K.px(im, ax, ay, Color("9a948c") if K.hash2(i, 1, 7) > 0.4 else Color("6e6862"))
	# logs crossing in the ring, charred at the ends
	for lg in [[-7, 2, 7, -2, 0], [-6, -2, 6, 2, 1], [-2, 1, 3, -3, 2]]:
		var a := Vector2(cx + lg[0], ty + lg[1])
		var b := Vector2(cx + lg[2], ty + lg[3])
		line(im, a, b, timber[2])
		line(im, a + Vector2(0, -1), b + Vector2(0, -1), timber[4] if not lit else timber[3])
		K.px(im, int(a.x), int(a.y), Color("1a1412"))
		K.px(im, int(b.x), int(b.y) - 1, Color("2a2420") if not lit else warm[4])
	if lit:
		# glowing coals, then the flames
		for i in 10:
			var ex := int(cx - 6 + K.hash2(i, f, 8) * 12.0)
			var ey := int(ty - 1 + K.hash2(i, f, 9) * 3.0)
			K.px(im, ex, ey, warm[5] if K.hash2(i, f, 10) > 0.5 else warm[3])
		_flames(im, cx, ty + 1.0, f)
	# the front wall of the ring, lit on the left, over the bottom of the fire
	for x in range(int(cx - rx), int(cx + rx) + 1):
		var dx := (x + 0.5 - cx) / rx
		if absf(dx) > 1.0:
			continue
		var yf := ty + ry * sqrt(1.0 - dx * dx)
		var t := 0.75 - (dx + 1.0) * 0.32
		for yy in 4:
			var c := at(rust, t - yy * 0.05)
			if yy == 0:
				c = rust[4] if not lit else warm[3].lerp(rust[4], 0.5)
			K.px(im, x, int(yf) - 1 + yy, c)
		if K.hash2(x, 3, 12) > 0.85:
			K.px(im, x, int(yf) + 2, rust[0])
	_outline_rect(im, Rect2i(ox, 0, FIRE_W, FIRE_H))


## Three tongues of flame whose heights shift frame to frame.
func _flames(im: Image, cx: float, base: float, f: int) -> void:
	var tongues := [[-4.0, 10.0, 0.0], [0.5, 15.0, 1.7], [4.5, 11.0, 3.1], [-1.5, 7.0, 4.4]]
	for tg: Array in tongues:
		var phase: float = f * 1.57 + tg[2]
		var fh: float = tg[1] * (0.8 + 0.25 * sin(phase))
		var fx: float = cx + tg[0] + sin(phase * 1.3) * 0.8
		var fw := 2.8
		for yy in int(fh):
			var k := float(yy) / fh
			var half_w := fw * (1.0 - k) * (1.0 - k * 0.3) + 0.4
			var lean := sin(phase + k * 2.0) * k * 1.6
			for xx in range(floori(fx - half_w + lean), ceili(fx + half_w + lean)):
				var edge := absf(xx + 0.5 - fx - lean) / maxf(0.5, half_w)
				var t := 1.0 - k * 0.8 - edge * 0.6
				K.px(im, xx, int(base - yy), flame_col(t))
	# a spark or two above
	K.px(im, int(cx + 2 - f), int(base - 15 + (f % 2)), warm[6])
	if f % 2 == 0:
		K.px(im, int(cx - 3), int(base - 17), warm[5])


## PixelKit's outline, limited to one frame of a sheet so frames don't bleed.
func _outline_rect(im: Image, r: Rect2i) -> void:
	var sub := im.get_region(r)
	K.outline(sub, RIM)
	im.blit_rect(sub, Rect2i(Vector2i.ZERO, r.size), r.position)


# ---------------------------------------------------------------- tables

## A heavy Park Service picnic table with its benches, seen from the front
## and above. "cook" sets out a camp stove, a pot and a white-gas lantern;
## "rack" a coiled rope, a rack of gear and climbing shoes.
func picnic_table(variant: String) -> Image:
	var w := 36
	var h := 26
	var im := K.make(w, h)
	K.shadow(im, 18, h - 3.5, 17.0, 3.0, 0.3)
	# back bench, then the top, the A-frame legs, and the front bench
	_planks(im, 4, 3, 28, 2, 3)
	for lx in [7, 28]:
		line(im, Vector2(lx - 2, 22), Vector2(lx + 1, 11), timber[1])
		line(im, Vector2(lx + 3, 22), Vector2(lx, 11), timber[2])
	_planks(im, 2, 6, 32, 7, 4)
	K.hline(im, 2, 13, 32, timber[1])
	K.hline(im, 2, 14, 32, timber[0])
	_planks(im, 3, 17, 30, 3, 3)
	K.hline(im, 3, 20, 30, timber[1])
	for lx in [6, 29]:
		K.rect(im, lx, 21, 2, 2, timber[1])
	shade(im, 20, 6, 14, 8, timber[0], 0.0, 0.8, 0.28, false)
	match variant:
		"cook":
			# a green two-burner stove with its lid up, a pot, the lantern
			K.rect(im, 6, 4, 11, 3, Color("2e5a34"))
			K.hline(im, 6, 4, 11, Color("4a7e4c"))
			K.rect(im, 6, 7, 11, 4, Color("3a6a3e"))
			K.hline(im, 6, 7, 11, Color("6a9a5e"))
			K.rect(im, 8, 8, 3, 1, iron[0])
			K.rect(im, 12, 8, 3, 1, iron[0])
			K.rect(im, 12, 5, 4, 3, iron[2])
			K.hline(im, 12, 5, 4, iron[3].lightened(0.2))
			K.px(im, 14, 4, Color("e8e8f0"))
			# lantern: red fount, glowing globe, bail
			K.rect(im, 25, 9, 3, 2, Color("a8302a"))
			K.rect(im, 25, 6, 3, 3, Color("fff0b8"))
			K.px(im, 25, 6, Color("ffffff"))
			K.hline(im, 25, 5, 3, iron[1])
			K.px(im, 26, 4, iron[2])
			# tin mugs
			K.rect(im, 20, 9, 2, 2, granite[5])
			K.px(im, 20, 9, granite[6])
		"rack":
			# a coiled rope, cams on a sling, a pair of shoes
			K.ellipse(im, 10, 9, 4.5, 2.6, Color("2f7a8a"))
			K.ellipse(im, 10, 9, 3.0, 1.6, Color("4aa0b0"))
			K.ellipse(im, 10, 9, 1.3, 0.7, timber[3])
			K.hline(im, 7, 7, 5, Color("7ad0d8"))
			var lobes := [Color("8a4ac0"), Color("4ab04a"), Color("d03a2a"), Color("e8c03a"), Color("3a7ad0")]
			K.hline(im, 16, 7, 12, Color("2a2a2a"))
			for i in lobes.size():
				K.vline(im, 17 + i * 2, 8, 2, granite[5])
				K.px(im, 17 + i * 2, 10, lobes[i])
			K.rect(im, 28, 9, 3, 2, Color("b84a2a"))
			K.rect(im, 31, 9, 2, 2, Color("b84a2a").darkened(0.2))
	K.outline(im, RIM)
	return im


func _planks(im: Image, x: int, y: int, w: int, h: int, tone: int) -> void:
	for yy in h:
		for xx in w:
			var idx := tone + (1 if yy == 0 else 0) - (1 if (yy == 3 and h > 4) else 0)
			var n := K.hash2(x + xx, (y + yy) / 2, 41)
			if n > 0.93:
				idx += 1
			elif n < 0.06:
				idx -= 1
			K.px(im, x + xx, y + yy, timber[clampi(idx, 0, 5)])
	# board joints along the top
	if h > 4:
		K.hline(im, x, y + 3, w, timber[tone - 1])


## The cook table's lantern lit at dusk.
func lantern_glow() -> Image:
	var im := K.make(36, 26)
	for ring in range(5, 0, -1):
		var a := 0.06 + (5 - ring) * 0.06
		K.ellipse(im, 26.5, 7.5, ring + 1.5, ring + 1.0, Color(1.0, 0.78, 0.36, a))
	K.rect(im, 25, 6, 3, 3, Color(1.0, 0.9, 0.6, 0.8))
	return im


# ---------------------------------------------------------------- camp furniture

## The camp's bulletin board: a shingle-roofed kiosk on two posts, its board
## pinned three deep with notes (partners wanted, rides, gear for trade).
func bulletin_board() -> Image:
	var w := 46
	var h := 50
	var im := K.make(w, h)
	K.shadow(im, 23, h - 3.0, 20.0, 2.6, 0.3)
	for px_ in [6, 37]:
		post(im, px_, 10, h - 13, 500 + px_, 3)
	# the board, framed
	K.rect(im, 4, 14, 38, 24, timber[0])
	for yy in 22:
		for xx in 36:
			K.px(im, 5 + xx, 15 + yy, Color("8a6a46").lerp(Color("6e5236"), K.hash2(xx / 3, yy, 5) * 0.6))
	K.hline(im, 4, 14, 38, timber[4])
	K.hline(im, 4, 37, 38, timber[1])
	# notes, overlapping, in a few papers and inks
	var papers := [Color("f2ecd8"), Color("f4e48a"), Color("f2c2c8"), Color("cfe4f2"), Color("e8e8e0")]
	for i in 15:
		var nx := 6 + int(K.hash2(i, 1, 61) * 29.0)
		var ny := 16 + int(K.hash2(i, 2, 61) * 15.0)
		var nw := 5 + int(K.hash2(i, 3, 61) * 4.0)
		var nh := 5 + int(K.hash2(i, 4, 61) * 3.0)
		var paper: Color = papers[i % papers.size()]
		K.rect(im, nx + 1, ny + 1, nw, nh, Color(0, 0, 0, 0.25))
		K.rect(im, nx, ny, nw, nh, paper)
		K.hline(im, nx, ny, nw, paper.lightened(0.3))
		for ly in range(ny + 2, ny + nh - 1, 2):
			K.hline(im, nx + 1, ly, nw - 2 - int(K.hash2(i, ly, 62) * 2.0), Color("4a4a5a") if i % 3 else Color("2a3a7a"))
		K.px(im, nx + nw / 2, ny, Color("c83a2a"))
	# header board and a little shingle roof
	K.rect(im, 9, 5, 28, 9, timber[0])
	K.rect(im, 10, 6, 26, 7, timber[2])
	K.hline(im, 10, 6, 26, timber[4])
	K.text_centered(im, 10, 26, 7, "CAMP 4", Color("f0e2bc"), timber[0])
	K.shingles(im, 1, 0, 44, 6, roof[3], 71, 0.3, 2)
	K.hline(im, 1, 5, 44, roof[0])
	K.outline(im, RIM)
	return im


## The Park Service sign at the camp: a brown routed board with cream
## letters, on two posts in a bed of stones.
func park_sign() -> Image:
	var w := 50
	var h := 34
	var im := K.make(w, h)
	K.shadow(im, 25, h - 3.0, 22.0, 2.4, 0.3)
	for px_ in [9, 39]:
		post(im, px_, 18, 13, 600 + px_, 3)
	var brown := _ramp(["2e1c12", "42291a", "573522", "6a4330", "7e543e"])
	K.rect(im, 2, 2, 46, 20, brown[0])
	for yy in 18:
		for xx in 44:
			var n := K.hash2(xx, yy / 2, 91)
			K.px(im, 3 + xx, 3 + yy, brown[2] if n > 0.15 else brown[1])
	K.hline(im, 3, 3, 44, brown[4])
	K.vline(im, 3, 3, 18, brown[3])
	K.hline(im, 3, 20, 44, brown[1])
	var cream := Color("eadcb2")
	big_text(im, 3 + (44 - big_text_width("CAMP 4")) / 2, 5, "CAMP 4", cream, brown[0])
	K.text_centered(im, 3, 44, 16, "WALK-IN", cream.darkened(0.06), brown[0])
	for sx in [5, 44]:
		K.px(im, sx, 5, granite[5])
		K.px(im, sx, 18, granite[5])
	for sx in [6, 13, 36, 43]:
		boulder(im, sx, h - 4, 3.2, 2.2, 700 + sx)
	K.outline(im, RIM)
	return im


## A slackline of flat webbing between two trees, with tree pads and a
## ratchet at one end. The trees themselves are separate props, standing
## SLACK_SPAN px apart at this sprite's two ends.
const SLACK_SPAN := 92

func slackline() -> Image:
	var w := SLACK_SPAN + 8
	var h := 26
	var im := K.make(w, h)
	var y0 := 7.0
	var x0 := 4.0
	var x1 := x0 + SLACK_SPAN
	# the line's shadow on the ground
	for x in range(int(x0) + 4, int(x1) - 3):
		if x % 2 == 0:
			var t := (x - x0) / SLACK_SPAN
			K.px(im, x, int(h - 3 - sin(t * PI) * 2.0), Color(0.05, 0.03, 0.02, 0.22))
	# webbing: two pixel rows, lit on top
	for x in range(int(x0), int(x1) + 1):
		var t := (x - x0) / SLACK_SPAN
		var y := int(y0 + sin(t * PI) * 4.5)
		K.px(im, x, y, Color("e8a83a"))
		K.px(im, x, y + 1, Color("a86a1c"))
	# tree pads and the ratchet
	for ex in [x0, x1]:
		K.rect(im, int(ex) - 3, int(y0) - 2, 6, 5, Color("3a6a8a"))
		K.hline(im, int(ex) - 3, int(y0) - 2, 6, Color("5a8aaa"))
	K.rect(im, int(x0) + 8, int(y0) - 1, 4, 3, iron[2])
	K.hline(im, int(x0) + 8, int(y0) - 1, 4, granite[6])
	K.px(im, int(x0) + 12, int(y0) + 1, Color("c83a2a"))
	return im


## A tarp spread with a trader's gear. The rack trader lays out ropes, a row
## of cams, hexes and carabiners; the big-wall trader a haul bag, aiders,
## ascenders and a folded portaledge.
func gear_tarp(bigwall: bool) -> Image:
	var w := 40
	var h := 24
	var im := K.make(w, h)
	K.shadow(im, 20, h - 4.0, 19.0, 2.6, 0.22)
	var tarp := _ramp(["4a5040", "5e6650", "727c62", "889276"]) if bigwall else _ramp(["3a4a5c", "4c5e72", "607488", "7a8ea0"])
	for yy in 16:
		for xx in 36:
			var t := 0.5 + (vnoise(xx * 0.25, yy * 0.3, 61) - 0.5) * 0.5 + (0.5 - float(yy) / 16.0) * 0.2
			K.px(im, 2 + xx, 3 + yy, at(tarp, t))
	K.hline(im, 2, 3, 36, tarp[3])
	for g in [[2, 3], [37, 3], [2, 18], [37, 18]]:
		K.px(im, g[0], g[1], granite[6])
	if bigwall:
		# the haul bag, standing, with its straps
		for yy in range(0, 16):
			for xx in range(4, 14):
				var dx := (xx + 0.5 - 9.0) / 5.0
				var t := 0.7 - dx * 0.4 - float(yy) / 16.0 * 0.15
				K.px(im, xx, yy + 2, at(_ramp(["5a1a1a", "8a2a24", "b03a2e", "d0583e"]), t))
		K.hline(im, 4, 2, 10, Color("e8d8b0"))
		for sx in [6, 11]:
			K.vline(im, sx, 3, 14, Color("2a2a2a"))
		# aiders: webbing ladders laid out flat
		for ax in [18, 23]:
			K.vline(im, ax, 6, 11, Color("3a7ad0"))
			K.vline(im, ax + 3, 6, 11, Color("3a7ad0").darkened(0.2))
			for sy in range(8, 17, 3):
				K.hline(im, ax, sy, 4, Color("6aa0e0"))
		# ascenders and a folded portaledge
		K.rect(im, 29, 6, 2, 4, Color("d8c040"))
		K.rect(im, 32, 6, 2, 4, Color("d84040"))
		K.rect(im, 28, 12, 9, 6, Color("2a2a2a"))
		K.hline(im, 28, 12, 9, granite[5])
		K.hline(im, 28, 15, 9, Color("4a6aa0"))
	else:
		# two rope coils
		for rc in [[9, 10, Color("a8372a")], [19, 13, Color("3a8a5a")]]:
			var col: Color = rc[2]
			K.ellipse(im, rc[0], rc[1], 5.0, 3.6, col.darkened(0.15))
			K.ellipse(im, rc[0], rc[1], 3.6, 2.4, col)
			K.ellipse(im, rc[0], rc[1], 1.6, 1.0, tarp[1])
			K.hline(im, rc[0] - 3, rc[1] - 3, 4, col.lightened(0.3))
		# cams in a row by size, slings in rack colors
		var slings := [Color("8a4ac0"), Color("4ab04a"), Color("d03a2a"), Color("e8c03a"), Color("3a7ad0"), Color("a0a0a0")]
		for i in slings.size():
			var cx := 25 + i * 2
			K.vline(im, cx, 5, 3, slings[i])
			K.vline(im, cx, 8, 3, granite[5])
			K.px(im, cx, 11, granite[6])
		# hexes and a string of carabiners
		for hx in [26, 30, 34]:
			K.rect(im, hx, 14, 3, 3, granite[4])
			K.hline(im, hx, 14, 3, granite[6])
		for i in 6:
			K.px(im, 6 + i * 2, 17, granite[6] if i % 2 == 0 else Color("d8b040"))
	K.outline(im, RIM)
	return im


## A 1970s van in the lot: two-tone paint, the split front, a row of windows,
## and a haul bag lashed to the roof rack.
func van() -> Image:
	var w := 60
	var h := 38
	var im := K.make(w, h)
	K.shadow(im, 30, h - 4.0, 28.0, 3.4, 0.32)
	var paint := _ramp(["7a3014", "a4441c", "c85e28", "e07c3c"])
	var cream := _ramp(["9a907a", "c0b69a", "ddd3b6", "f0e8d0"])
	var body := Rect2i(3, 9, 54, 22)
	for y in range(body.position.y, body.end.y):
		for x in range(body.position.x, body.end.x):
			# round the corners
			var dx := mini(x - body.position.x, body.end.x - 1 - x)
			var dy := mini(y - body.position.y, body.end.y - 1 - y)
			if dx < 3 and dy < 3 and (3 - dx) * (3 - dy) > 3:
				continue
			var t := 0.7 - float(y - body.position.y) / body.size.y * 0.35 + (0.06 if x < 20 else 0.0)
			var col := at(paint, t) if y >= 20 else at(cream, t + 0.1)
			K.px(im, x, y, col)
	# the V where the two colors meet at the front
	for i in 7:
		K.hline(im, 3, 20 - i, 6 - i, at(paint, 0.8))
	K.hline(im, 3, 20, 54, paint[3])
	K.hline(im, 3, 9, 54, cream[3])
	# windows
	K.rect(im, 4, 11, 7, 6, Color("2a3a4a"))
	K.px(im, 5, 12, Color("a8c8d8"))
	for wx in [14, 25, 36, 47]:
		K.rect(im, wx, 11, 8, 6, Color("24323e"))
		K.hline(im, wx, 11, 8, Color("4a6070"))
		K.px(im, wx + 1, 12, Color("c8e0e8"))
		K.px(im, wx + 2, 12, Color("88a8b8"))
	# door seams, headlight, bumper
	K.vline(im, 12, 11, 19, paint[0])
	K.vline(im, 23, 11, 19, paint[0])
	K.rect(im, 3, 22, 2, 3, Color("f0e8c8"))
	K.hline(im, 2, 29, 56, granite[4])
	K.hline(im, 2, 30, 56, granite[2])
	# wheels
	for wx in [13, 47]:
		K.ellipse(im, wx, 31, 4.5, 4.5, Color("1a1818"))
		K.ellipse(im, wx, 31, 2.0, 2.0, granite[5])
		K.px(im, wx - 1, 30, granite[6])
	# roof rack and a haul bag
	K.hline(im, 10, 7, 40, iron[2])
	for rx in [10, 30, 49]:
		K.vline(im, rx, 7, 2, iron[1])
	K.rect(im, 18, 2, 16, 5, Color("2f5a8a"))
	K.hline(im, 18, 2, 16, Color("5a86b4"))
	K.vline(im, 22, 2, 5, Color("1a1a1a"))
	K.vline(im, 29, 2, 5, Color("1a1a1a"))
	shade(im, 40, 9, 17, 21, iron[0], 0.0, 0.7, 0.25, false)
	K.outline(im, RIM)
	return im


## Pine needles, cones and an oak leaf or two on the camp's dirt.
func duff(v: int) -> Image:
	var w := 40
	var h := 28
	var im := K.make(w, h)
	var needle := [Color("8a5a2e"), Color("a4723c"), Color("6e4a2a"), Color("b8884a")]
	var sd := 900 + v * 17
	for i in 46:
		var x := 2 + int(K.hash2(i, 1, sd) * (w - 6))
		var y := 2 + int(K.hash2(i, 2, sd) * (h - 5))
		var cx := w / 2.0
		var cy := h / 2.0
		# denser toward the middle, thin at the edges
		if pow((x - cx) / cx, 2.0) + pow((y - cy) / cy, 2.0) > 0.7 + K.hash2(i, 3, sd) * 0.3:
			continue
		var col: Color = needle[int(K.hash2(i, 4, sd) * 4.0) % 4]
		var dir := 1 if K.hash2(i, 5, sd) > 0.5 else -1
		col.a = 0.6
		K.px(im, x, y, col)
		if K.hash2(i, 6, sd) > 0.3:
			K.px(im, x + dir, y + 1, col.darkened(0.1))
	for i in v % 2 + 1:
		var x := 8 + int(K.hash2(i, 7, sd) * (w - 16))
		var y := 6 + int(K.hash2(i, 8, sd) * (h - 12))
		K.rect(im, x, y, 2, 3, Color("6a4428"))
		K.px(im, x, y, Color("9a6a3a"))
		K.px(im, x + 1, y + 2, Color("8a5a32"))
		K.hline(im, x, y + 3, 2, Color(0.05, 0.03, 0.02, 0.3))
	if v == 1:
		K.rect(im, 26, 16, 4, 2, Color("a8782a"))
		K.px(im, 25, 17, Color("8a5a1a"))
	return im
