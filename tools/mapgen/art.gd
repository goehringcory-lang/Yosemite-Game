extends RefCounted
## Draws the placeholder pixel art for the generated maps and adds it to the
## shared TileSet. Everything is drawn in code so the style matches the
## starter art; replace the PNGs with hand-drawn versions (same layout) at
## any time.

const Terrain = preload("res://tools/mapgen/terrain.gd")
const FloraHd = preload("res://tools/mapgen/flora_hd.gd")

const T := 16
const TILESET_PATH := "res://assets/tiles/world_tileset.tres"
const TERRAIN_PNG := "res://assets/sprites/terrain.png"
const FLORA_PNG := "res://assets/sprites/flora.png"
const FLORA_GLOW_PNG := "res://assets/sprites/flora_glow.png"
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

## The flora atlas: see flora_hd.gd.
func paint_flora() -> Image:
	return FloraHd.new().paint()


## The lit windows of the flora atlas's buildings, for the night glow.
func paint_flora_glow() -> Image:
	return FloraHd.new().paint_glow()


# ---------------------------------------------------------------- objects

func paint_info_sign() -> Image:
	return FloraHd.new().info_sign()


func paint_trailhead() -> Image:
	return FloraHd.new().trailhead()


func paint_map_kiosk() -> Image:
	return FloraHd.new().map_kiosk()


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
	_save_png(paint_flora_glow(), FLORA_GLOW_PNG)
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
