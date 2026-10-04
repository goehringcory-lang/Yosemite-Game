extends RefCounted
## Draws the placeholder pixel art for the generated maps and adds it to the
## shared TileSet. Everything is drawn in code so the style matches the
## starter art; replace the PNGs with hand-drawn versions (same layout) at
## any time.

const Terrain = preload("res://tools/mapgen/terrain.gd")

const T := 16
const TILESET_PATH := "res://assets/tiles/world_tileset.tres"
const TERRAIN_PNG := "res://assets/sprites/terrain.png"
const FLORA_PNG := "res://assets/sprites/flora.png"
const BLOCKER_PNG := "res://assets/sprites/blocker.png"
## TileSet source ids. Source 0 is the starter atlas and stays as is.
const SOURCE_TERRAIN := 1
const SOURCE_FLORA := 2
const SOURCE_BLOCKER := 3
const VARIANTS := 4
const OUTLINE := Color("2a1f1a")

var rng := RandomNumberGenerator.new()


# ---------------------------------------------------------------- helpers

static func c(hex: String) -> Color:
	return Color(hex)


func rect(im: Image, x: int, y: int, w: int, h: int, col: Color) -> void:
	im.fill_rect(Rect2i(x, y, w, h).intersection(Rect2i(Vector2i.ZERO, im.get_size())), col)


func px(im: Image, x: int, y: int, col: Color) -> void:
	if x >= 0 and y >= 0 and x < im.get_width() and y < im.get_height():
		if col.a < 1.0:
			im.set_pixel(x, y, im.get_pixel(x, y).blend(col))
		else:
			im.set_pixel(x, y, col)


func speckle(im: Image, ox: int, oy: int, col: Color, count: int, w := T, h := T) -> void:
	for i in count:
		px(im, ox + rng.randi_range(0, w - 1), oy + rng.randi_range(0, h - 1), col)


func ellipse(im: Image, cx: float, cy: float, rx: float, ry: float, col: Color) -> void:
	for y in range(floori(cy - ry), ceili(cy + ry) + 1):
		for x in range(floori(cx - rx), ceili(cx + rx) + 1):
			var dx := (x + 0.5 - cx) / rx
			var dy := (y + 0.5 - cy) / ry
			if dx * dx + dy * dy <= 1.0:
				px(im, x, y, col)


## A lit blob: light on the upper left, dark on the lower right.
func blob(im: Image, cx: float, cy: float, rx: float, ry: float, dark: Color, mid: Color, light: Color) -> void:
	for y in range(floori(cy - ry), ceili(cy + ry) + 1):
		for x in range(floori(cx - rx), ceili(cx + rx) + 1):
			var dx := (x + 0.5 - cx) / rx
			var dy := (y + 0.5 - cy) / ry
			var d := dx * dx + dy * dy
			if d > 1.0:
				continue
			var lit := -dx * 0.6 - dy * 0.8 + rng.randf_range(-0.25, 0.25)
			px(im, x, y, light if lit > 0.45 else (mid if lit > -0.35 else dark))


## Adds a 1px outline around opaque pixels inside a region.
func outline(im: Image, region: Rect2i, col: Color) -> void:
	var edge: Array[Vector2i] = []
	for y in range(region.position.y, region.end.y):
		for x in range(region.position.x, region.end.x):
			if im.get_pixel(x, y).a > 0.5:
				continue
			for d: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
				var n := Vector2i(x, y) + d
				if region.has_point(n) and im.get_pixel(n.x, n.y).a > 0.5 and im.get_pixel(n.x, n.y) != col:
					edge.append(Vector2i(x, y))
					break
	for p in edge:
		im.set_pixelv(p, col)


func shadow(im: Image, cx: float, cy: float, rx: float, ry: float) -> void:
	ellipse(im, cx, cy, rx, ry, Color(0, 0, 0, 0.22))


# ---------------------------------------------------------------- terrain

## One row per terrain type, one column per variant.
func paint_terrain() -> Image:
	var im := Image.create_empty(T * VARIANTS, T * Terrain.COUNT, false, Image.FORMAT_RGBA8)
	for type in Terrain.COUNT:
		for v in VARIANTS:
			rng.seed = 1890 + type * 97 + v * 13
			_terrain_tile(im, type, v, v * T, type * T)
	return im


func _base(im: Image, ox: int, oy: int, base: String, dark: String, light: String, n_dark := 24, n_light := 14) -> void:
	rect(im, ox, oy, T, T, c(base))
	speckle(im, ox, oy, c(dark), n_dark)
	speckle(im, ox, oy, c(light), n_light)


func _terrain_tile(im: Image, type: int, v: int, ox: int, oy: int) -> void:
	match type:
		Terrain.FOREST:
			_base(im, ox, oy, "6d8547", "5b7239", "7f9855", 26, 14)
			for i in 6:
				var x := ox + rng.randi_range(1, 13)
				var y := oy + rng.randi_range(1, 14)
				px(im, x, y, c("8a7446"))
				px(im, x + 1, y + (1 if i % 2 else -1), c("8a7446"))
			speckle(im, ox, oy, c("6b5634"), 4)
			if v == 2:
				ellipse(im, ox + 9.5, oy + 10.5, 1.5, 1.0, c("5a4630"))
		Terrain.MEADOW:
			_base(im, ox, oy, "73aa52", "62984a", "86bd62", 24, 16)
			for i in 6:
				var x := ox + rng.randi_range(1, 14)
				var y := oy + rng.randi_range(2, 14)
				px(im, x, y, c("578c3f"))
				px(im, x, y - 1, c("578c3f"))
			var flowers := ["f2d25c", "8b6cc9", "f4f1e6", "f2d25c"]
			for i in (3 if v < 3 else 1):
				var x := ox + rng.randi_range(1, 14)
				var y := oy + rng.randi_range(1, 13)
				px(im, x, y, c(flowers[(i + v) % flowers.size()]))
				px(im, x, y + 1, c("4f7f38"))
		Terrain.WET_MEADOW:
			_base(im, ox, oy, "5d9a5a", "4d8750", "72ad6a", 24, 12)
			for i in 6:
				var x := ox + rng.randi_range(1, 14)
				var y := oy + rng.randi_range(3, 14)
				px(im, x, y, c("3f7040"))
				px(im, x, y - 1, c("3f7040"))
				px(im, x - 1, y - 2, c("3f7040"))
			if v % 2 == 0:
				rect(im, ox + rng.randi_range(2, 10), oy + rng.randi_range(3, 12), 3, 1, c("8fbfd0"))
		Terrain.FOOTHILL:
			_base(im, ox, oy, "b8a864", "a39352", "cdbf7c", 26, 14)
			speckle(im, ox, oy, c("9c7a50"), 6)
			for i in 5:
				var x := ox + rng.randi_range(1, 14)
				var y := oy + rng.randi_range(2, 14)
				px(im, x, y, c("8a8a4a"))
				px(im, x + 1, y - 1, c("8a8a4a"))
		Terrain.FIR:
			_base(im, ox, oy, "556e42", "46603a", "667f4e", 26, 14)
			for i in 6:
				var x := ox + rng.randi_range(1, 13)
				var y := oy + rng.randi_range(1, 14)
				px(im, x, y, c("6e5a38"))
				px(im, x + 1, y, c("6e5a38"))
			speckle(im, ox, oy, c("7c6a44"), 3)
		Terrain.SUBALPINE:
			_base(im, ox, oy, "8e9a66", "7a8858", "a0aa74", 20, 10)
			ellipse(im, ox + rng.randi_range(3, 12) + 0.5, oy + rng.randi_range(3, 12) + 0.5, 2.5, 1.5, c("b9b19a"))
			speckle(im, ox, oy, c("a8a498"), 8)
			for i in 4:
				var x := ox + rng.randi_range(1, 14)
				var y := oy + rng.randi_range(2, 14)
				px(im, x, y, c("6f8050"))
				px(im, x, y - 1, c("6f8050"))
		Terrain.SCRUB:
			_base(im, ox, oy, "6b7446", "5b643a", "7a8452", 16, 8)
			for i in 3:
				blob(im, ox + rng.randi_range(3, 12) + 0.5, oy + rng.randi_range(3, 12) + 0.5, 3.0, 2.5,
					c("46542f"), c("566a38"), c("6c8446"))
			speckle(im, ox, oy, c("8a3b2a"), 4)
		Terrain.GRANITE:
			_base(im, ox, oy, "b3afa3", "a09c90", "c6c2b7", 22, 16)
			for i in 2:
				var x := ox + rng.randi_range(1, 11)
				var y := oy + rng.randi_range(1, 14)
				for k in rng.randi_range(3, 5):
					px(im, x + k, y + (k / 2 if i == 0 else 0), c("8c887d"))
			if v == 3:
				speckle(im, ox, oy, c("8a9a6a"), 5)
		Terrain.CLIFF:
			rect(im, ox, oy, T, T, c("a09c91"))
			# Streaks run the full height at the same columns in every
			# variant, so cliff faces read as continuous vertical walls.
			for col_x: int in [1, 5, 9, 13]:
				for y in T:
					px(im, ox + col_x, oy + y, c("868278"))
					px(im, ox + col_x + 1, oy + y, c("b6b2a7") if (y + col_x) % 5 else c("868278"))
			for y in T:
				px(im, ox + 11, oy + y, c("6d6a63") if v % 2 == 0 else c("868278"))
			speckle(im, ox, oy, c("6d6a63"), 8)
			speckle(im, ox, oy, c("c4c0b5"), 6)
			if v == 1:
				rect(im, ox, oy + 9, T, 1, c("6d6a63"))
				rect(im, ox, oy + 8, T, 1, c("c4c0b5"))
			if v == 3:
				for y in range(4, 16):
					px(im, ox + 7, oy + y, c("54524d"))
		Terrain.TALUS:
			rect(im, ox, oy, T, T, c("7a756b"))
			speckle(im, ox, oy, c("68645b"), 20)
			for i in 5:
				var bx := ox + rng.randi_range(2, 13) + 0.5
				var by := oy + rng.randi_range(2, 13) + 0.5
				var r := rng.randf_range(1.8, 3.2)
				ellipse(im, bx + 0.7, by + 0.7, r, r * 0.85, c("5e5a52"))
				ellipse(im, bx, by, r, r * 0.85, c("a8a498"))
				px(im, floori(bx - r * 0.4), floori(by - r * 0.4), c("c6c2b6"))
		Terrain.SCREE:
			_base(im, ox, oy, "a29d8f", "8a8579", "bcb8ac", 26, 18)
			for i in 4:
				var x := ox + rng.randi_range(1, 13)
				var y := oy + rng.randi_range(1, 13)
				rect(im, x, y, 2, 2, c("7e796e"))
				px(im, x, y, c("c8c4b8"))
		Terrain.RIVER:
			_base(im, ox, oy, "3a74b0", "326aa3", "4480bb", 18, 8)
			for i in 4:
				rect(im, ox + rng.randi_range(0, 12), oy + rng.randi_range(1, 14), rng.randi_range(2, 4), 1, c("6aa0d4"))
			px(im, ox + rng.randi_range(1, 14), oy + rng.randi_range(1, 14), c("a8d0f0"))
		Terrain.LAKE:
			_base(im, ox, oy, "2f64a0", "295a91", "3670ac", 20, 8)
			for i in 3:
				rect(im, ox + rng.randi_range(0, 12), oy + rng.randi_range(1, 14), 3, 1, c("4f86c0"))
		Terrain.CREEK:
			_base(im, ox, oy, "5b8fbf", "4f82b2", "6a9cc8", 16, 10)
			for i in 3:
				var sx := ox + rng.randi_range(2, 13) + 0.5
				var sy := oy + rng.randi_range(2, 13) + 0.5
				ellipse(im, sx, sy, 1.6, 1.2, c("8f8a7e"))
				px(im, floori(sx) - 1, floori(sy) - 1, c("b8b3a6"))
			for i in 3:
				rect(im, ox + rng.randi_range(0, 13), oy + rng.randi_range(1, 14), 2, 1, c("a8cce8"))
			speckle(im, ox, oy, c("d8ecf8"), 2)
		Terrain.FALLS:
			rect(im, ox, oy, T, T, c("c9dae8"))
			for x in T:
				var shade := c("eef6fb") if (x + v) % 3 == 0 else (c("b0c6d8") if (x + v) % 4 == 1 else c("dce9f3"))
				for y in T:
					px(im, ox + x, oy + y, shade)
			for i in 3:
				var x := ox + rng.randi_range(0, 15)
				for y in range(rng.randi_range(0, 8), T):
					px(im, x, oy + y, c("ffffff"))
			speckle(im, ox, oy, c("8f8b82"), 3)
		Terrain.SAND:
			_base(im, ox, oy, "d4c49c", "c0b088", "e2d6b4", 22, 14)
			speckle(im, ox, oy, c("a39c8c"), 4)
		Terrain.ROAD:
			_base(im, ox, oy, "56575b", "4c4d51", "616266", 30, 18)
		Terrain.PARKING:
			_base(im, ox, oy, "5e5f63", "54555a", "68696d", 26, 14)
			if v < 2:
				rect(im, ox + 7, oy + 2, 1, 12, c("d0d0c8"))
		Terrain.BRIDGE:
			rect(im, ox, oy, T, T, c("8a6a44"))
			for y in [0, 4, 8, 12]:
				rect(im, ox, oy + y, T, 1, c("6e5234"))
				rect(im, ox, oy + y + 1, T, 1, c("a0804f"))
			speckle(im, ox, oy, c("7a5c3a"), 10)
			for y in [2, 6, 10, 14]:
				px(im, ox + 2, oy + y, c("4a3a28"))
				px(im, ox + 13, oy + y, c("4a3a28"))
		Terrain.TRAIL:
			_base(im, ox, oy, "c4a26a", "b08e58", "d6b884", 24, 12)
			speckle(im, ox, oy, c("9c9790"), 4)
		Terrain.PAVED:
			_base(im, ox, oy, "a9a59b", "999589", "b9b5ab", 20, 12)
			if v == 1:
				for k in 5:
					px(im, ox + 4 + k, oy + 9 + (k % 2), c("8a867c"))
		Terrain.CAMP:
			_base(im, ox, oy, "b39a6c", "9f865a", "c4ad80", 22, 12)
			for i in 4:
				var x := ox + rng.randi_range(1, 13)
				var y := oy + rng.randi_range(1, 14)
				px(im, x, y, c("8a7446"))
				px(im, x + 1, y + 1, c("8a7446"))
		Terrain.SNOW:
			_base(im, ox, oy, "e8eef4", "d4dee8", "ffffff", 20, 14)
			speckle(im, ox, oy, c("c0cedc"), 4)
		Terrain.ALPINE:
			_base(im, ox, oy, "9a968b", "86827a", "b0aca2", 18, 12)
			ellipse(im, ox + rng.randi_range(3, 12) + 0.5, oy + rng.randi_range(3, 12) + 0.5, 2.5, 1.5, c("7c8a5a"))
			speckle(im, ox, oy, c("c8b060"), 2)
		Terrain.LAWN:
			rect(im, ox, oy, T, T, c("6cab52"))
			for x in T:
				if (x / 4 + v) % 2 == 0:
					rect(im, ox + x, oy, 1, T, c("64a24b"))
			speckle(im, ox, oy, c("78b85c"), 10)
		Terrain.BUILT:
			_base(im, ox, oy, "a8a090", "968e7e", "bab2a2", 20, 10)


# ---------------------------------------------------------------- flora

func paint_flora() -> Image:
	var rows := ceili(float(Terrain.Flora.COUNT) / Terrain.FLORA_COLUMNS)
	var fw := Terrain.FLORA_FRAME.x
	var fh := Terrain.FLORA_FRAME.y
	var im := Image.create_empty(fw * Terrain.FLORA_COLUMNS, fh * rows, false, Image.FORMAT_RGBA8)
	for flora in Terrain.Flora.COUNT:
		rng.seed = 1864 + flora * 31
		var frame := Terrain.frame_coords(flora)
		var ox := frame.x * fw
		var oy := frame.y * fh
		_flora(im, flora, ox, oy)
		if flora != Terrain.Flora.BLACK_OAK_CANOPY:
			outline(im, Rect2i(ox, oy, fw, fh), OUTLINE)
	return im


## A conifer silhouette built from tiers. Coordinates are frame-relative;
## the trunk base sits at (16, 44).
func _conifer(im: Image, ox: int, oy: int, top: int, bottom: int, half_w: float, tiers: float,
		dark: Color, mid: Color, light: Color, droop := 0.35) -> void:
	for y in range(top, bottom + 1):
		var t := float(y - top) / float(bottom - top)
		var phase := fmod(t * tiers, 1.0)
		var hw := half_w * (0.12 + 0.88 * t) * (1.0 - droop + droop * phase)
		hw = maxf(hw + rng.randf_range(-0.6, 0.6), 0.5)
		for x in range(floori(16 - hw), ceili(16 + hw)):
			var rel := (x + 0.5 - 16.0) / hw
			var col := light if rel < -0.3 else (mid if rel < 0.35 else dark)
			if phase > 0.82 and absf(rel) < 0.9:
				col = dark
			px(im, ox + x, oy + y, col)


func _trunk(im: Image, ox: int, oy: int, top: int, width: int, col: Color, dark: Color) -> void:
	var x0 := 16 - width / 2
	rect(im, ox + x0, oy + top, width, 45 - top, col)
	rect(im, ox + x0 + width - 1, oy + top, 1, 45 - top, dark)


func _flora(im: Image, flora: int, ox: int, oy: int) -> void:
	var F := Terrain.Flora
	match flora:
		F.PONDEROSA:
			shadow(im, ox + 16, oy + 45, 8, 2)
			_trunk(im, ox, oy, 16, 4, c("a0582f"), c("7a4020"))
			for y in range(18, 44, 3):
				px(im, ox + 15, oy + y, c("c07040"))
			for clump in [[16, 8, 6, 5], [11, 14, 5, 4], [21, 13, 5, 4], [14, 19, 5, 3], [19, 20, 5, 3], [16, 3, 3, 3]]:
				blob(im, ox + clump[0], oy + clump[1], clump[2], clump[3], c("2d5a34"), c("3b7040"), c("4f8a4c"))
		F.INCENSE_CEDAR:
			shadow(im, ox + 16, oy + 45, 7, 2)
			_trunk(im, ox, oy, 34, 4, c("8a4a2a"), c("6a3420"))
			rect(im, ox + 13, oy + 42, 6, 3, c("8a4a2a"))
			_conifer(im, ox, oy, 5, 38, 7.5, 7.0, c("3a6030"), c("4f7a3a"), c("65904a"), 0.25)
		F.BLACK_OAK_TRUNK:
			shadow(im, ox + 16, oy + 45, 10, 2)
			_trunk(im, ox, oy, 24, 4, c("5a4030"), c("402c20"))
			for branch in [[15, 24, -1, -1, 7], [17, 24, 1, -1, 7], [16, 22, 0, -1, 6], [14, 28, -1, -1, 4], [18, 27, 1, -1, 4]]:
				for k in branch[4]:
					px(im, ox + branch[0] + branch[2] * k, oy + branch[1] + branch[3] * k, c("5a4030"))
		F.BLACK_OAK_CANOPY:
			# Light grays, tinted per season by the layer's modulate.
			for clump in [[16, 17, 9, 7], [9, 21, 6, 5], [23, 21, 6, 5], [12, 12, 6, 5], [20, 12, 6, 5], [16, 25, 7, 4]]:
				blob(im, ox + clump[0], oy + clump[1], clump[2], clump[3], c("9a9a9a"), c("c4c4c4"), c("eeeeee"))
			outline(im, Rect2i(ox, oy, Terrain.FLORA_FRAME.x, Terrain.FLORA_FRAME.y), c("3a3a3a"))
		F.WHITE_FIR:
			shadow(im, ox + 16, oy + 45, 8, 2)
			_trunk(im, ox, oy, 38, 3, c("6a5a4a"), c("4f4236"))
			_conifer(im, ox, oy, 3, 40, 10.5, 6.0, c("2f5444"), c("3f6a55"), c("52806a"))
		F.DOGWOOD:
			shadow(im, ox + 16, oy + 45, 6, 2)
			_trunk(im, ox, oy, 32, 2, c("5a4a3a"), c("45382c"))
			for clump in [[16, 28, 6, 4], [11, 31, 4, 3], [21, 31, 4, 3]]:
				blob(im, ox + clump[0], oy + clump[1], clump[2], clump[3], c("3a6a30"), c("4f8040"), c("68984f"))
			for i in 7:
				px(im, ox + rng.randi_range(10, 22), oy + rng.randi_range(25, 33), c("f4f1e6"))
		F.SNAG:
			shadow(im, ox + 16, oy + 45, 5, 2)
			_trunk(im, ox, oy, 12, 3, c("8a8478"), c("6a655c"))
			for branch in [[16, 20, -1, -1, 5], [17, 26, 1, -1, 4], [16, 32, -1, 0, 4]]:
				for k in branch[4]:
					px(im, ox + branch[0] + branch[2] * k, oy + branch[1] + branch[3] * k, c("8a8478"))
			rect(im, ox + 15, oy + 10, 2, 2, c("a8a296"))
		F.RED_FIR:
			shadow(im, ox + 16, oy + 45, 8, 2)
			_trunk(im, ox, oy, 38, 3, c("7a4a36"), c("5a3426"))
			_conifer(im, ox, oy, 1, 40, 9.5, 7.0, c("283f30"), c("35553e"), c("476e50"))
		F.JEFFREY_PINE:
			shadow(im, ox + 16, oy + 45, 8, 2)
			_trunk(im, ox, oy, 18, 4, c("8a5a3a"), c("6a4028"))
			for clump in [[16, 10, 6, 5], [10, 16, 5, 4], [22, 15, 5, 4], [16, 21, 6, 3], [13, 5, 3, 3]]:
				blob(im, ox + clump[0], oy + clump[1], clump[2], clump[3], c("2a4a38"), c("3a6048"), c("4c7a58"))
		F.LODGEPOLE:
			shadow(im, ox + 16, oy + 45, 5, 2)
			_trunk(im, ox, oy, 30, 2, c("7a6a55"), c("5c4f40"))
			_conifer(im, ox, oy, 4, 36, 6.0, 9.0, c("2d4f2c"), c("3e6a3a"), c("558250"), 0.4)
		F.WHITEBARK:
			shadow(im, ox + 16, oy + 45, 8, 2)
			for trunk_x in [13, 16, 19]:
				rect(im, ox + trunk_x, oy + 30, 2, 15, c("8a8478"))
			for clump in [[12, 27, 5, 4], [20, 26, 5, 4], [16, 23, 6, 4], [16, 30, 7, 3]]:
				blob(im, ox + clump[0], oy + clump[1], clump[2], clump[3], c("344f36"), c("4a6a45"), c("5f825a"))
		F.HEMLOCK:
			shadow(im, ox + 16, oy + 45, 7, 2)
			_trunk(im, ox, oy, 36, 3, c("6a4e3c"), c("4f392c"))
			_conifer(im, ox, oy, 6, 38, 8.5, 8.0, c("223a2e"), c("2f5040"), c("3f6650"), 0.5)
			px(im, ox + 17, oy + 5, c("2f5040"))
			px(im, ox + 18, oy + 6, c("2f5040"))
		F.GRAY_PINE:
			shadow(im, ox + 16, oy + 45, 7, 2)
			_trunk(im, ox, oy, 24, 3, c("6a5a48"), c("4f4236"))
			for k in 8:
				px(im, ox + 16 - k, oy + 24 - k, c("6a5a48"))
				px(im, ox + 17 + k / 2, oy + 24 - k, c("6a5a48"))
			for clump in [[10, 15, 4, 3], [20, 13, 4, 3], [15, 9, 4, 3], [22, 19, 3, 2]]:
				blob(im, ox + clump[0], oy + clump[1], clump[2], clump[3], c("5e6e50"), c("7a8a6a"), c("95a585"))
		F.LIVE_OAK:
			shadow(im, ox + 16, oy + 45, 10, 2)
			_trunk(im, ox, oy, 34, 3, c("5a4a3a"), c("45382c"))
			for clump in [[16, 29, 9, 6], [10, 33, 5, 4], [22, 33, 5, 4], [16, 24, 6, 4]]:
				blob(im, ox + clump[0], oy + clump[1], clump[2], clump[3], c("2a4220"), c("3a5a2a"), c("4d7038"))
		F.MANZANITA:
			shadow(im, ox + 16, oy + 45, 8, 2)
			for k in 5:
				px(im, ox + 13 - k / 2, oy + 44 - k, c("8a3b2a"))
				px(im, ox + 19 + k / 2, oy + 44 - k, c("8a3b2a"))
				px(im, ox + 16, oy + 44 - k, c("9a4a32"))
			for clump in [[12, 37, 4, 3], [20, 37, 4, 3], [16, 35, 5, 3]]:
				blob(im, ox + clump[0], oy + clump[1], clump[2], clump[3], c("5a7048"), c("6f8a5a"), c("8aa070"))
		F.SHRUB:
			shadow(im, ox + 16, oy + 45, 8, 2)
			for clump in [[12, 40, 4, 3], [20, 40, 4, 3], [16, 37, 5, 4]]:
				blob(im, ox + clump[0], oy + clump[1], clump[2], clump[3], c("365e2c"), c("4a7a3a"), c("5f9048"))
		F.SEQUOIA:
			shadow(im, ox + 16, oy + 45, 12, 3)
			for y in range(16, 45):
				var w := 8 + (4 if y > 40 else (2 if y > 36 else 0))
				rect(im, ox + 16 - w / 2, oy + y, w, 1, c("a0522d"))
				px(im, ox + 16 - w / 2, oy + y, c("b8683a"))
				px(im, ox + 16 + w / 2 - 1, oy + y, c("7a3a20"))
			for furrow_x in [14, 17, 19]:
				for y in range(17, 44, 2):
					px(im, ox + furrow_x, oy + y, c("7a3a20"))
			for clump in [[16, 8, 7, 6], [10, 13, 5, 4], [22, 12, 5, 4], [16, 2, 4, 3], [13, 18, 4, 3], [20, 18, 4, 3]]:
				blob(im, ox + clump[0], oy + clump[1], clump[2], clump[3], c("2a4220"), c("3a5a2a"), c("4c7038"))
		F.SUGAR_PINE:
			shadow(im, ox + 16, oy + 45, 8, 2)
			_trunk(im, ox, oy, 8, 4, c("8a5a3a"), c("6a4028"))
			for branch in [[8, 12, 5, 3], [24, 9, 5, 3], [11, 20, 4, 3], [22, 18, 4, 3], [16, 5, 4, 3]]:
				blob(im, ox + branch[0], oy + branch[1], branch[2], branch[3], c("2d5236"), c("3c6a44"), c("508456"))
			for cone in [[8, 16], [24, 13]]:
				rect(im, ox + cone[0], oy + cone[1], 1, 3, c("8a6a40"))
		F.BOULDER:
			shadow(im, ox + 16, oy + 45, 8, 2)
			ellipse(im, ox + 16, oy + 40, 7, 5, c("7a766c"))
			ellipse(im, ox + 15.5, oy + 39.5, 6.5, 4.5, c("a9a59a"))
			ellipse(im, ox + 13.5, oy + 38, 3, 2, c("c8c4b8"))
		F.ERRATIC:
			shadow(im, ox + 16, oy + 45, 10, 3)
			ellipse(im, ox + 16, oy + 37, 9, 8, c("7a766c"))
			ellipse(im, ox + 15.5, oy + 36.5, 8.5, 7.5, c("aeaa9e"))
			ellipse(im, ox + 13, oy + 33, 4, 3, c("cbc7bb"))
			for k in 4:
				px(im, ox + 18 + k, oy + 36 + k / 2, c("86827a"))
		F.TENT_CABIN:
			_building(im, ox, oy, 14, 7, 6, c("e8e2d4"), c("c8c0b0"), c("8a6a44"), c("5a4632"), true)
		F.CABIN:
			_building(im, ox, oy, 14, 7, 7, c("7a5236"), c("5e3d26"), c("8a6440"), c("3b2a1e"), false)
		F.HOUSE:
			_building(im, ox, oy, 16, 8, 7, c("4f6b4a"), c("3d5439"), c("7a5a3a"), c("3b2a1e"), false)
		F.LODGE:
			_building(im, ox, oy, 18, 9, 8, c("5a3e2a"), c("45301f"), c("8f8b82"), c("3b2a1e"), false)
		F.WHITE_HOUSE:
			_building(im, ox, oy, 18, 8, 8, c("3f5a44"), c("2f4634"), c("eeeae0"), c("5a4a3a"), false)
		F.CAMP_TENT:
			shadow(im, ox + 16, oy + 45, 7, 2)
			for y in range(36, 45):
				var half := int((y - 35) * 0.75)
				rect(im, ox + 16 - half, oy + y, half, 1, c("d98c3a"))
				rect(im, ox + 16, oy + y, half, 1, c("b86f28"))
			rect(im, ox + 15, oy + 40, 2, 5, c("3a2616"))
		F.WILLOW:
			shadow(im, ox + 16, oy + 45, 8, 2)
			for stem_x in [13, 16, 19]:
				rect(im, ox + stem_x, oy + 36, 1, 9, c("6a5a3a"))
			for clump in [[12, 34, 4, 4], [20, 34, 4, 4], [16, 31, 5, 4], [16, 38, 6, 3]]:
				blob(im, ox + clump[0], oy + clump[1], clump[2], clump[3], c("5a8040"), c("7aa050"), c("93b868"))


## A small building seen from the front: roof above, wall with a door below.
func _building(im: Image, ox: int, oy: int, width: int, roof_h: int, wall_h: int,
		roof: Color, roof_dark: Color, wall: Color, door: Color, canvas: bool) -> void:
	var x0 := ox + 16 - width / 2
	var wall_top := oy + 45 - wall_h
	shadow(im, ox + 16, oy + 45, width / 2.0 + 2, 2)
	rect(im, x0, wall_top, width, wall_h, wall)
	rect(im, x0, wall_top, width, 1, wall.darkened(0.25))
	if canvas:
		rect(im, x0 + width / 2 - 2, wall_top + 2, 4, wall_h - 2, door)
		rect(im, x0, oy + 44, width, 1, c("8a6a44"))
	else:
		rect(im, x0 + width / 2 - 1, wall_top + 2, 3, wall_h - 2, door)
		rect(im, x0 + 2, wall_top + 2, 2, 2, c("f2d88a"))
		rect(im, x0 + width - 4, wall_top + 2, 2, 2, c("f2d88a"))
	for y in roof_h:
		var inset := roof_h - 1 - y
		var ry := wall_top - roof_h + y
		rect(im, x0 - 1 + inset / 2, ry, width + 2 - inset, 1, roof if y < roof_h - 2 else roof_dark)
	rect(im, x0 - 1 + roof_h / 2, wall_top - roof_h, width + 2 - roof_h, 1, roof.lightened(0.2))


# ---------------------------------------------------------------- objects

func paint_info_sign() -> Image:
	var im := Image.create_empty(16, 16, false, Image.FORMAT_RGBA8)
	shadow(im, 8, 15, 6, 1)
	rect(im, 3, 9, 2, 6, c("5a3e28"))
	rect(im, 11, 9, 2, 6, c("5a3e28"))
	rect(im, 1, 3, 14, 7, c("6b4a2f"))
	rect(im, 2, 4, 12, 5, c("3a2a1c"))
	for y in [5, 7]:
		rect(im, 3, y, 7, 1, c("d8ccb0"))
	rect(im, 11, 5, 2, 3, c("7fa05a"))
	outline(im, Rect2i(0, 0, 16, 16), OUTLINE)
	return im


func paint_trailhead() -> Image:
	var im := Image.create_empty(16, 24, false, Image.FORMAT_RGBA8)
	shadow(im, 8, 23, 5, 1)
	rect(im, 7, 4, 2, 19, c("6b4a2f"))
	rect(im, 2, 5, 11, 4, c("8a6a44"))
	rect(im, 12, 6, 2, 2, c("8a6a44"))
	rect(im, 4, 11, 11, 4, c("8a6a44"))
	rect(im, 3, 12, 1, 2, c("8a6a44"))
	for y in [6, 12]:
		rect(im, 4, y + 1, 7, 1, c("e8dcb8"))
	outline(im, Rect2i(0, 0, 16, 24), OUTLINE)
	return im


func paint_map_kiosk() -> Image:
	var im := Image.create_empty(16, 24, false, Image.FORMAT_RGBA8)
	shadow(im, 8, 23, 7, 1)
	rect(im, 2, 12, 2, 11, c("5a3e28"))
	rect(im, 12, 12, 2, 11, c("5a3e28"))
	rect(im, 1, 2, 14, 3, c("45301f"))
	rect(im, 0, 4, 16, 1, c("5a3e2a"))
	rect(im, 2, 5, 12, 9, c("6b4a2f"))
	rect(im, 3, 6, 10, 7, c("7fa05a"))
	rect(im, 3, 9, 10, 1, c("4f86c0"))
	rect(im, 6, 6, 1, 7, c("c8a060"))
	px(im, 9, 8, c("d8323c"))
	outline(im, Rect2i(0, 0, 16, 24), OUTLINE)
	return im


func paint_blocker() -> Image:
	var im := Image.create_empty(T, T, false, Image.FORMAT_RGBA8)
	im.fill(Color(0.9, 0.1, 0.1, 0.35))
	for i in T:
		px(im, i, i, Color(1, 0.2, 0.2, 0.8))
		px(im, T - 1 - i, i, Color(1, 0.2, 0.2, 0.8))
	return im


# ---------------------------------------------------------------- tileset

func save_images() -> void:
	_save_png(paint_terrain(), TERRAIN_PNG)
	_save_png(paint_flora(), FLORA_PNG)
	_save_png(paint_blocker(), BLOCKER_PNG)
	_save_png(paint_info_sign(), "res://assets/sprites/info_sign.png")
	_save_png(paint_trailhead(), "res://assets/sprites/trailhead.png")
	_save_png(paint_map_kiosk(), "res://assets/sprites/map_kiosk.png")


## Rebuilds the generated sources of the shared TileSet (run after the
## images are imported). Source 0, the starter atlas, is left untouched.
func build_tileset() -> void:
	var tileset: TileSet = load(TILESET_PATH)
	for id in [SOURCE_TERRAIN, SOURCE_FLORA, SOURCE_BLOCKER]:
		if tileset.has_source(id):
			tileset.remove_source(id)

	# Each source joins the TileSet before its tiles are made, so the tiles
	# know about the TileSet's physics layer.
	var terrain := TileSetAtlasSource.new()
	terrain.texture = _texture(TERRAIN_PNG)
	terrain.texture_region_size = Vector2i(T, T)
	tileset.add_source(terrain, SOURCE_TERRAIN)
	for type in Terrain.COUNT:
		for v in VARIANTS:
			var coords := Vector2i(v, type)
			terrain.create_tile(coords)
			if type in Terrain.SHADED:
				for alt in range(1, Terrain.SHADE_MODULATE.size()):
					terrain.create_alternative_tile(coords, alt)
					terrain.get_tile_data(coords, alt).modulate = Terrain.SHADE_MODULATE[alt]

	var flora := TileSetAtlasSource.new()
	flora.texture = _texture(FLORA_PNG)
	flora.texture_region_size = Terrain.FLORA_FRAME
	tileset.add_source(flora, SOURCE_FLORA)
	for kind in Terrain.Flora.COUNT:
		var coords := Terrain.frame_coords(kind)
		flora.create_tile(coords)
		var data := flora.get_tile_data(coords, 0)
		# Frames are 32x48 with the trunk base at (16, 44): shift them up so
		# the base lands just below the cell center.
		data.texture_origin = Vector2i(0, 16)
		data.y_sort_origin = 4
		var box: Rect2 = Terrain.FLORA_COLLISION.get(kind, Rect2())
		if box.has_area():
			data.add_collision_polygon(0)
			data.set_collision_polygon_points(0, 0, PackedVector2Array([
				box.position, Vector2(box.end.x, box.position.y), box.end, Vector2(box.position.x, box.end.y)]))

	var blocker := TileSetAtlasSource.new()
	blocker.texture = _texture(BLOCKER_PNG)
	blocker.texture_region_size = Vector2i(T, T)
	tileset.add_source(blocker, SOURCE_BLOCKER)
	blocker.create_tile(Vector2i.ZERO)
	var block_data := blocker.get_tile_data(Vector2i.ZERO, 0)
	block_data.add_collision_polygon(0)
	block_data.set_collision_polygon_points(0, 0, PackedVector2Array([
		Vector2(-8, -8), Vector2(8, -8), Vector2(8, 8), Vector2(-8, 8)]))

	var err := ResourceSaver.save(tileset, TILESET_PATH)
	assert(err == OK, "Could not save the TileSet")


func _save_png(image: Image, path: String) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	image.save_png(path)


func _texture(path: String) -> Texture2D:
	var texture: Texture2D = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_REPLACE)
	assert(texture != null, "%s isn't imported yet" % path)
	return texture
