extends RefCounted
## Places the buildings of a generated hub map. The map generator marks every
## OpenStreetMap footprint cell as a building, and a hub cell is 35 to 45 m
## wide, so stamping a cabin on each cell gave dense, overlapping grids. Here
## the cells become one building per footprint instead:
##   - a run of lodge cells (big OSM buildings) becomes one wide lodge sprite
##     (tools/mapgen/hub_building_art.gd), split every few cells if it is long;
##   - the white cells beside the hub's hotel marker become the Wawona Hotel;
##   - every other cell is a cabin, house, tent cabin or cottage from the flora
##     atlas, but only one to a 3 x 2 block, so none overlap and a block of
##     cabins reads as a few, with open ground between.
## Each building is a Sprite2D under Map/Buildings (y-sorted with the player,
## so you walk behind a roof and in front of a door) with its lit windows as a
## NightGlow child, and a StaticBody2D, Footprints, holds their collision.
##
## Used by region_builder.gd when it writes a map, and by rebuild_buildings.gd
## to redo the maps already in the project.

const Terrain = preload("res://tools/mapgen/terrain.gd")
const Art = preload("res://tools/mapgen/hub_building_art.gd")

const T := 16
const FLORA_PNG := "res://assets/sprites/flora.png"
const FLORA_GLOW_PNG := "res://assets/sprites/flora_glow.png"
const DIR := "res://assets/sprites/hub_buildings/"
const NIGHT_GLOW := "res://scripts/world/night_glow.gd"
## Cabins and the like keep this many cells apart (x, y).
const SPACING := Vector2i(3, 2)
## The most cells a lodge sprite spans before a long footprint gets a second.
const LODGE_SPAN := 6
## How far from the hotel marker the white cells still belong to the hotel.
const HOTEL_REACH := 10

## Flora types that are buildings.
static func is_building(flora_type: int) -> bool:
	return flora_type >= Terrain.Flora.TENT_CABIN and flora_type <= Terrain.Flora.WHITE_HOUSE


## Cell centre in map pixels.
static func center(c: Vector2i) -> Vector2:
	return Vector2(c) * T + Vector2(T / 2.0, T / 2.0)


## [param cells] is {cell: flora type} for every building cell. No building
## covers a point in [param keep_clear] (spawns, signs, kiosks): a cabin is
## left out there. A lodge or hotel instead moves back behind any of the
## [param spawns], so the player never appears behind a roof. Returns the buildings: {kind, frame, texture, glow, base (pixels, bottom centre),
## size (sprite), shapes (collision Rect2s in map pixels)}.
static func layout(cells: Dictionary, hotel_at := Vector2(-1, -1), keep_clear := PackedVector2Array(), spawns := PackedVector2Array()) -> Array[Dictionary]:
	var F := Terrain.Flora
	var left: Dictionary = cells.duplicate()
	var out: Array[Dictionary] = []
	var taken: Array[Rect2] = []

	# The hotel: the white cells around the hotel's marker, standing just
	# behind the marker so the spot in front of it stays open ground.
	if hotel_at.x >= 0:
		var hotel_cell := Vector2i((hotel_at / T).floor())
		var box := Rect2i()
		var found := false
		for c: Vector2i in left:
			if left[c] == F.WHITE_HOUSE and maxi(absi(c.x - hotel_cell.x), absi(c.y - hotel_cell.y)) <= HOTEL_REACH:
				box = Rect2i(c, Vector2i.ONE) if not found else box.expand(c)
				found = true
		if found:
			var span := (box.size.x + 1) * T
			var w := 128
			for option: int in Art.HOTEL_WIDTHS:
				if option >= span + 16:
					w = option
					break
			var base := Vector2((box.position.x + box.end.x) / 2.0 * T, center(Vector2i(box.position.x, box.end.y - 1)).y + 4)
			var b := _building("hotel", "hotel_%d" % w, base, Vector2(w, Art.HOTEL_HEIGHT))
			b.shapes = [Rect2(base.x - w / 2.0 + 4, base.y - 20, w - 8, 23)]
			_back_off(b, spawns)
			out.append(b)
			taken.append(_sprite_rect(b).grow(T / 2.0))
			for c: Vector2i in left.keys():
				if taken[-1].has_point(center(c)):
					left.erase(c)

	# Lodges: rectangles of lodge cells, one sprite to a few cells of width.
	var lodge_cells := {}
	for c: Vector2i in left:
		if left[c] == F.LODGE:
			lodge_cells[c] = true
	for rect: Rect2i in _rectangles(lodge_cells):
		if rect.size.x < 2:
			continue # a lone lodge cell is placed with the cabins below
		var pieces := ceili(float(rect.size.x) / LODGE_SPAN)
		for i in pieces:
			var x0 := rect.position.x + rect.size.x * i / pieces
			var x1 := rect.position.x + rect.size.x * (i + 1) / pieces
			var piece := Rect2i(x0, rect.position.y, x1 - x0, rect.size.y)
			var base := Vector2((piece.position.x + piece.end.x) / 2.0 * T, center(Vector2i(piece.position.x, piece.end.y - 1)).y + 4)
			var w := _lodge_width(piece.size.x * T + 8)
			var b := _building("lodge", "lodge_%d" % w, base, Vector2(w, Art.lodge_height(w)))
			var depth := 13.0 + (piece.size.y - 1) * T
			b.shapes = [Rect2(base.x - w / 2.0 + 3, base.y + 3 - depth, w - 6, depth)]
			_back_off(b, spawns)
			out.append(b)
			taken.append(_sprite_rect(b).grow(4.0))
			for x in range(piece.position.x, piece.end.x):
				for y in range(piece.position.y, piece.end.y):
					left.erase(Vector2i(x, y))

	# Everything else: one to a SPACING block, in reading order.
	var order: Array = left.keys()
	order.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.y < b.y or (a.y == b.y and a.x < b.x))
	var placed: Array[Vector2i] = []
	for c: Vector2i in order:
		var crowded := false
		for p in placed:
			if absi(p.x - c.x) < SPACING.x and absi(p.y - c.y) < SPACING.y:
				crowded = true
				break
		if crowded:
			continue
		var b := _small(left[c], Vector2(center(c).x, center(c).y + 4))
		var rect := _sprite_rect(b)
		for t in taken:
			if rect.intersects(t):
				crowded = true
				break
		for point in keep_clear:
			if rect.has_point(point):
				crowded = true
				break
		if crowded:
			continue
		placed.append(c)
		out.append(b)
	return out


## Adds the Buildings node (sprites, glow, collision) to [param map], right
## after its Flora layer, and returns how many buildings it holds.
static func add_to(map: Node2D, cells: Dictionary, hotel_at := Vector2(-1, -1)) -> int:
	var keep_clear := PackedVector2Array()
	var spawns := PackedVector2Array()
	for group in ["Spawns", "Objects"]:
		if map.has_node(group):
			for spot: Node2D in map.get_node(group).get_children():
				keep_clear.append(spot.position)
				if group == "Spawns":
					spawns.append(spot.position)
	var old := map.get_node_or_null("Buildings")
	if old != null:
		map.remove_child(old)
		old.free()
	var list := layout(cells, hotel_at, keep_clear, spawns)
	var group := Node2D.new()
	group.name = "Buildings"
	group.y_sort_enabled = true
	var flora := map.get_node_or_null("Flora")
	map.add_child(group)
	if flora != null:
		map.move_child(group, flora.get_index() + 1)
	group.owner = map

	var body := StaticBody2D.new()
	body.name = "Footprints"
	group.add_child(body)
	body.owner = map
	var shapes := {}
	var flora_tex: Texture2D = load(FLORA_PNG)
	var glow_tex: Texture2D = load(FLORA_GLOW_PNG)
	var glow_script: Script = load(NIGHT_GLOW)
	var n := 0
	for b: Dictionary in list:
		var sprite := Sprite2D.new()
		var cell := Vector2i((b.base / T).floor())
		sprite.name = "%s_%d_%d" % [b.kind.capitalize(), cell.x, cell.y]
		var glow := Sprite2D.new()
		glow.name = "Glow"
		if b.frame >= 0:
			var at := Terrain.frame_coords(b.frame)
			var region := Rect2(at.x * Terrain.FLORA_FRAME.x, at.y * Terrain.FLORA_FRAME.y, Terrain.FLORA_FRAME.x, Terrain.FLORA_FRAME.y)
			sprite.texture = flora_tex
			sprite.region_enabled = true
			sprite.region_rect = region
			glow.texture = glow_tex
			glow.region_enabled = true
			glow.region_rect = region
		else:
			sprite.texture = load(DIR + b.texture + ".png")
			glow.texture = load(DIR + b.texture + "_glow.png")
		# Bottom centre of the picture sits on the position, which is also
		# where the sprite sorts against the player.
		sprite.position = b.base
		sprite.offset = Vector2(0, -b.size.y / 2.0) if b.frame < 0 else Vector2(0, -20)
		if b.has("tint"):
			sprite.modulate = b.tint
		glow.offset = sprite.offset
		glow.set_script(glow_script)
		glow.set("strength", 1.0)
		group.add_child(sprite)
		sprite.owner = map
		sprite.add_child(glow)
		glow.owner = map
		for r: Rect2 in b.shapes:
			var key := r.size
			if not shapes.has(key):
				var rs := RectangleShape2D.new()
				rs.size = r.size
				shapes[key] = rs
			var cs := CollisionShape2D.new()
			cs.shape = shapes[key]
			cs.position = r.get_center()
			cs.name = "S_%d_%d" % [roundi(r.get_center().x), roundi(r.get_center().y)]
			body.add_child(cs)
			cs.owner = map
		n += 1
	return n


# ---------------------------------------------------------------- helpers

static func _building(kind: String, texture: String, base: Vector2, size: Vector2) -> Dictionary:
	return {kind = kind, frame = -1, texture = texture, base = base, size = size, shapes = []}


## One flora-atlas building on a cell, with the old cell-sized collision.
static func _small(flora_type: int, base: Vector2) -> Dictionary:
	var b := _building("cabin", "", base, Vector2(Terrain.FLORA_FRAME))
	b.frame = flora_type
	b.shapes = [Rect2(base.x - 7, base.y - 8, 14, 11)]
	# A little variety so a row of cabins is not one cabin repeated.
	var h := fposmod(sin(base.x * 12.9898 + base.y * 78.233) * 43758.5453, 1.0)
	var v := 0.93 + h * 0.12
	b.tint = Color(v, v, v * (0.98 + h * 0.04))
	return b


## The picture's bounds in map pixels.
static func _sprite_rect(b: Dictionary) -> Rect2:
	if b.frame >= 0:
		# Only the building itself, not the frame's empty margin.
		return Rect2(b.base.x - 12, b.base.y - 30, 24, 33)
	return Rect2(b.base.x - b.size.x / 2.0, b.base.y - b.size.y, b.size.x, b.size.y + 3)


## Moves a building up until none of [param points] is hidden behind it.
static func _back_off(b: Dictionary, points: PackedVector2Array) -> void:
	for _pass in 8:
		var moved := false
		for point in points:
			if _sprite_rect(b).has_point(point):
				var dy: float = point.y - 12.0 - b.base.y
				b.base.y += dy
				for i in b.shapes.size():
					b.shapes[i].position.y += dy
				moved = true
		if not moved:
			return


static func _lodge_width(wanted: int) -> int:
	var best: int = Art.LODGE_WIDTHS[0]
	for w: int in Art.LODGE_WIDTHS:
		if absi(w - wanted) < absi(best - wanted):
			best = w
	return best


## Greedy cover of a set of cells by rectangles: take the first cell in
## reading order, run right, then grow down while the whole row is there.
static func _rectangles(cells: Dictionary) -> Array[Rect2i]:
	var left: Dictionary = cells.duplicate()
	var order: Array = left.keys()
	order.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.y < b.y or (a.y == b.y and a.x < b.x))
	var out: Array[Rect2i] = []
	for c: Vector2i in order:
		if not left.has(c):
			continue
		var x1 := c.x
		while left.has(Vector2i(x1 + 1, c.y)):
			x1 += 1
		var y1 := c.y
		var growing := true
		while growing:
			for x in range(c.x, x1 + 1):
				if not left.has(Vector2i(x, y1 + 1)):
					growing = false
					break
			if growing:
				y1 += 1
		var rect := Rect2i(c, Vector2i(x1 - c.x + 1, y1 - c.y + 1))
		for y in range(rect.position.y, rect.end.y):
			for x in range(rect.position.x, rect.end.x):
				left.erase(Vector2i(x, y))
		out.append(rect)
	return out
