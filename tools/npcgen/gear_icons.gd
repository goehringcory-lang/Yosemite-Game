extends SceneTree
## Draws the gear icons that aren't hand-painted: the climbing shoes and the
## cams (assets/sprites/gear/climbing_shoes.png; cam_075.png, cam.png, cam_2.png
## and cam_3.png, one per size on the rack, see CamSizes). Icons are 64×64 with
## a dark rim like the painted ones. The shoes are drawn on a 32×32 grid and
## doubled; the cam needs the finer grid, so it's drawn at 64×64.
## Run: godot --headless --path . -s res://tools/npcgen/gear_icons.gd

const OUT := "res://assets/sprites/gear/"
const OUTLINE := Color("2a1f1a")

var im: Image


func _init() -> void:
	climbing_shoes().save_png(ProjectSettings.globalize_path(OUT + "climbing_shoes.png"))
	print("drew climbing_shoes")
	for size: Array in CAM_SIZES:
		cam(size[1], size[2], size[3]).save_png(ProjectSettings.globalize_path(OUT + size[0]))
		print("drew ", size[0])
	quit()


func rect(x: int, y: int, w: int, h: int, hex: String) -> void:
	im.fill_rect(Rect2i(x, y, w, h), Color(hex))


func px(x: int, y: int, hex: String) -> void:
	im.set_pixel(x, y, Color(hex))


## A pair of slim, downturned slab shoes: suede uppers, a black rubber rand
## round the toe, and laces up the top. The back shoe sits up and to the left.
func climbing_shoes() -> Image:
	im = Image.create_empty(32, 32, false, Image.FORMAT_RGBA8)
	_shoe(2, 5)
	_shoe(12, 15)
	_outline()
	var big := im.duplicate()
	big.resize(64, 64, Image.INTERPOLATE_NEAREST)
	return big


func _shoe(x: int, y: int) -> void:
	# Sole and rand: one smooth strip of black rubber, turned up at the toe.
	rect(x + 1, y + 8, 15, 2, "222226")
	rect(x + 15, y + 6, 2, 3, "222226")
	px(x + 16, y + 5, "222226")
	rect(x + 2, y + 8, 12, 1, "3a3a42")
	# Suede upper, low at the toe and high at the heel.
	rect(x + 1, y + 3, 5, 5, "c8502e")
	rect(x + 6, y + 4, 6, 4, "c8502e")
	rect(x + 12, y + 5, 3, 3, "c8502e")
	rect(x + 15, y + 6, 1, 1, "c8502e")
	# Light from the upper left, shade underneath.
	rect(x + 1, y + 3, 5, 1, "e8784a")
	rect(x + 6, y + 4, 6, 1, "e0704a")
	rect(x + 1, y + 7, 13, 1, "9a3a22")
	# Heel tab and the collar.
	rect(x, y + 2, 2, 4, "4a6a8a")
	rect(x + 2, y + 2, 4, 1, "8a3020")
	# Laces.
	for i in 3:
		px(x + 6 + i * 2, y + 5, "f0e8d8")
		px(x + 7 + i * 2, y + 6, "f0e8d8")


func _outline() -> void:
	var edge: Array[Vector2i] = []
	for y in 32:
		for x in 32:
			if im.get_pixel(x, y).a > 0.0:
				continue
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var p: Vector2i = Vector2i(x, y) + d
				if p.x >= 0 and p.y >= 0 and p.x < 32 and p.y < 32 and im.get_pixel(p.x, p.y).a > 0.0 \
						and im.get_pixel(p.x, p.y) != OUTLINE:
					edge.append(Vector2i(x, y))
					break
	for p in edge:
		im.set_pixelv(p, OUTLINE)



# --- The cam -----------------------------------------------------------------
# Modeled on a Black Diamond Camalot C4 #1: four bare aluminum lobes on a
# double axle, a single flexible stem, a trigger bar with two finger ears and
# its wires up to the lobes, then the thumb loop and the sewn sling, both in
# the size color (red for #1). Drawn at 64×64; light from the upper left.
# The other sizes are the same cam in their own colors (CAM_SIZES).

const STEEL_HI := "d6f1ee"
const STEEL_LT := "bdb8ae"
const STEEL := "93918f"
const STEEL_DK := "6a6a70"
const STEEL_DEEP := "4e4e56"
## File, then the size color's light, base and dark: #0.75 green, #1 red,
## #2 yellow, #3 blue, as Black Diamond colors them (CamSizes.SIZES).
const CAM_SIZES := [
	["cam_075.png", "8fcf6a", "4f9a3a", "2f6526"],
	["cam.png", "ec6a5e", "c8382e", "8a2420"],
	["cam_2.png", "f6d873", "dcaa2c", "98701a"],
	["cam_3.png", "6fa8e6", "2f6cc0", "1d437f"],
]
const TRIGGER_LT := "6a6a74"
const TRIGGER := "3c3c44"
const TRIGGER_DK := "2e2e34"


func cam(size_lt: String, size: String, size_dk: String) -> Image:
	im = Image.create_empty(64, 64, false, Image.FORMAT_RGBA8)
	# Back lobes first, fanned further open, in shade behind the front pair.
	_part(_lobe(-1, -0.34), STEEL_DK, STEEL, STEEL_DEEP, -1)
	_part(_lobe(1, -0.34), STEEL_DK, STEEL, STEEL_DEEP, 1)
	# Front lobes, with grip teeth along the outer contact edge.
	_part(_lobe(-1, 0.0), STEEL_LT, STEEL_HI, STEEL, -1)
	_part(_lobe(1, 0.0), STEEL_LT, STEEL_HI, STEEL, 1)
	# The holes near each lobe's tip where the trigger wire hooks on.
	_axle(17, 24)
	_axle(47, 24)
	# Trigger wires run from the trigger's ears up to the lobe tips.
	_line(Vector2i(17, 34), Vector2i(15, 28), STEEL_LT)
	_line(Vector2i(46, 34), Vector2i(48, 28), STEEL_LT)
	# The stem: one cable in a grey sheath, from the axles to the thumb loop.
	_part(_poly([Vector2(29, 12), Vector2(35, 12), Vector2(35, 47), Vector2(29, 47)]), STEEL_DK, STEEL, STEEL_DEEP)
	# The double axle, seen end on, through both lobe pairs.
	_part(_poly([Vector2(23, 10), Vector2(41, 10), Vector2(41, 17), Vector2(23, 17)]), STEEL, STEEL_LT, STEEL_DK)
	_axle(26, 13)
	_axle(38, 13)
	# The sling: a short sewn loop of webbing, with a bar tack.
	_part(_poly([Vector2(28, 50), Vector2(36, 50), Vector2(37, 63), Vector2(27, 63)]), size, size_lt, size_dk)
	_hole(_poly([Vector2(31, 57), Vector2(33, 57), Vector2(33, 61), Vector2(31, 61)]))
	for x in range(26, 39):
		var c := im.get_pixel(x, 54)
		if c.a > 0.0 and c != OUTLINE:
			px(x, 54, "f4dccc" if x % 2 == 0 else size_dk)
	# Thumb loop in the size color, over the top of the sling.
	_part(_ellipse(Vector2(32, 48), 8.0, 5.0), size, size_lt, size_dk)
	_hole(_ellipse(Vector2(32, 48), 4.6, 1.8))
	# The trigger bar, with a finger ear curling down at each end.
	_part(_poly([
		Vector2(12, 34), Vector2(18, 33), Vector2(46, 33), Vector2(52, 34),
		Vector2(53, 37), Vector2(50, 41), Vector2(46, 40), Vector2(43, 37.5),
		Vector2(21, 37.5), Vector2(18, 40), Vector2(14, 41), Vector2(11, 37),
	]), TRIGGER, TRIGGER_LT, TRIGGER_DK)
	_outline64()
	return im


## The points of one lobe: side -1 is the left lobe, 1 the right. The lobe
## is a solid fan that pivots on the axle: its outer edge is the toothed
## contact curve, sweeping from the top round to the tip where the trigger
## wire hooks on. open rotates it (radians) round the axle; the back pair is
## turned a little, so it peeks out from behind the front pair.
func _lobe(side: int, open: float) -> PackedVector2Array:
	var pts := [
		Vector2(28, 9), Vector2(22, 6), Vector2(15, 6), Vector2(9, 9),
		Vector2(5, 14), Vector2(4, 20), Vector2(6, 25), Vector2(11, 28.5),
		Vector2(16, 28.5), Vector2(21, 24), Vector2(27, 17),
	]
	var pivot := Vector2(26, 13)
	var out := PackedVector2Array()
	for p in pts:
		var q: Vector2 = pivot + (p - pivot).rotated(open)
		out.append(Vector2(q.x if side < 0 else 64.0 - q.x, q.y))
	return out


func _poly(pts: Array) -> PackedVector2Array:
	return PackedVector2Array(pts)


func _ellipse(c: Vector2, rx: float, ry: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in 48:
		var a := TAU * i / 48.0
		out.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	return out


func _inside(poly: PackedVector2Array, x: int, y: int) -> bool:
	return Geometry2D.is_point_in_polygon(Vector2(x + 0.5, y + 0.5), poly)


## Fills a shape with its own dark rim, lit on the upper left and shaded on
## the lower right, so overlapping parts stay readable.
## teeth -1 or 1 notches the rim that faces left or right: a lobe's grip.
func _part(poly: PackedVector2Array, base: String, lit: String, dark: String, teeth := 0) -> void:
	var cells := {}
	for y in 64:
		for x in 64:
			if _inside(poly, x, y):
				cells[Vector2i(x, y)] = true
	for c in cells:
		var rim := false
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			if not cells.has(c + d):
				rim = true
		if rim:
			im.set_pixelv(c, OUTLINE)
		elif not cells.has(c + Vector2i(-1, -1) * 2) or not cells.has(c + Vector2i(0, -2)) or not cells.has(c + Vector2i(-2, 0)):
			im.set_pixelv(c, Color(lit))
		elif not cells.has(c + Vector2i(1, 1) * 2) or not cells.has(c + Vector2i(0, 2)) or not cells.has(c + Vector2i(2, 0)):
			im.set_pixelv(c, Color(dark))
		else:
			im.set_pixelv(c, Color(base))
	if teeth != 0:
		var out := Vector2i(teeth, 0)
		for c in cells:
			if not cells.has(c + out) and c.y % 3 == 0 and cells.has(c - out * 2):
				im.set_pixelv(c, Color(0, 0, 0, 0))
				im.set_pixelv(c - out, OUTLINE)


## Cuts a see-through hole with a dark rim around it.
func _hole(poly: PackedVector2Array) -> void:
	for y in 64:
		for x in 64:
			if _inside(poly, x, y):
				im.set_pixel(x, y, Color(0, 0, 0, 0))
	for y in 64:
		for x in 64:
			if im.get_pixel(x, y).a == 0.0 or _inside(poly, x, y):
				continue
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				if _inside(poly, x + d.x, y + d.y):
					px(x, y, "2a1f1a")
					break


func _axle(x: int, y: int) -> void:
	rect(x - 2, y - 1, 5, 3, "2a1f1a")
	rect(x - 1, y - 2, 3, 5, "2a1f1a")
	rect(x - 1, y - 1, 3, 3, STEEL)
	px(x - 1, y - 1, STEEL_HI)
	px(x + 1, y + 1, STEEL_DK)
	px(x, y, STEEL_DEEP)


func _line(a: Vector2i, b: Vector2i, hex: String) -> void:
	var n := maxi(absi(b.x - a.x), absi(b.y - a.y))
	for i in n + 1:
		var p := Vector2(a).lerp(Vector2(b), float(i) / n).round()
		px(int(p.x), int(p.y), hex)


## The outside rim for the 64×64 cam: any clear pixel touching a colored one.
func _outline64() -> void:
	var edge: Array[Vector2i] = []
	for y in 64:
		for x in 64:
			if im.get_pixel(x, y).a > 0.0:
				continue
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var p: Vector2i = Vector2i(x, y) + d
				if p.x >= 0 and p.y >= 0 and p.x < 64 and p.y < 64 and im.get_pixel(p.x, p.y).a > 0.0 \
						and im.get_pixel(p.x, p.y) != OUTLINE:
					edge.append(Vector2i(x, y))
					break
	for p in edge:
		im.set_pixelv(p, OUTLINE)
