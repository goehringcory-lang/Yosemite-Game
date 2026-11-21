extends Node
## Suggests spots for hidden finds (Finds, data/park/finds.json): open ground
## the player can walk to from the region's arrival, well away from roads,
## trails and paths, tagged by what's near it (a cliff's foot, water, woods).
##
##   godot --headless --path . res://tools/discovery/find_spots.tscn
##   FIND_REGIONS=el_capitan_meadow,leidig_meadow godot --headless ...
##   FIND_PLACE=1 godot --headless ...   # places finds in finds.json without a pos
##
## With FIND_PLACE, each find with no "pos" gets the best spot matching its
## "spot" ("near": rock, water, woods or meadow; "place": a Place it lies in),
## farthest off the path, clear of the map's edges, other finds and anything
## else you can interact with; then finds.json is written back.
##
## Prints a handful of spread-out candidates per region; pick one, write its
## position into finds.json, and tests/finds_test.tscn checks it still holds.

const Terrain := preload("res://scripts/world/terrain.gd")
const WalkCheck := preload("res://scripts/story/find_walk.gd")
const PATHS := [Terrain.ROAD, Terrain.PARKING, Terrain.BRIDGE, Terrain.TRAIL, Terrain.PAVED, Terrain.CAMP, Terrain.BUILT]
const ROCK := [Terrain.CLIFF, Terrain.TALUS, Terrain.SCREE, Terrain.GRANITE]
const WATER := [Terrain.RIVER, Terrain.LAKE, Terrain.CREEK, Terrain.FALLS]
const WOODS := [Terrain.FOREST, Terrain.FIR, Terrain.SUBALPINE]
## Cells from the nearest path for a spot to count as off the path.
const MIN_OFF := 4
const PICKS := 8
## Keep this far (px) inside the map, away from the seams to the next area.
const EDGE := 256.0
## And this far from anything else you can interact with, or another find.
const CLEAR := 112.0
## Two finds in one area lie at least this far apart.
const FIND_GAP := 320.0


func _ready() -> void:
	var wanted := OS.get_environment("FIND_REGIONS").split(",", false)
	var placing := OS.get_environment("FIND_PLACE") != ""
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(Finds.DATA))
	if placing:
		wanted = PackedStringArray()
		for find: Dictionary in data.finds:
			if not find.has("pos") and not find.region in wanted:
				wanted.append(find.region)
	var ids := PackedStringArray()
	for file in DirAccess.get_files_at("res://scenes/regions/"):
		if file.ends_with(".tscn") and (wanted.is_empty() or file.get_basename() in wanted):
			ids.append(file.get_basename())
	ids.sort()
	for id in ids:
		var region: Region = (load("res://scenes/regions/%s.tscn" % id) as PackedScene).instantiate()
		if region.indoors:
			region.free()
			continue
		add_child(region)
		StoryContent.attach(region)
		await get_tree().physics_frame
		await get_tree().physics_frame
		if placing:
			_place(region, data.finds)
		else:
			_survey(region)
		remove_child(region)
		region.free()
	if placing:
		var file := FileAccess.open(Finds.DATA, FileAccess.WRITE)
		file.store_string(JSON.stringify(data, "\t", false) + "\n")
		file.close()
	get_tree().quit()


## Gives each find in [param region] without a pos the best spot for it.
func _place(region: Region, finds: Array) -> void:
	var walk := WalkCheck.new()
	var start := WalkCheck.start_of(region)
	var walked := walk.walk(region, start.global_position)
	var ground := region.get_ground()
	var off := WalkCheck.path_distance(ground)
	var bounds := region.get_bounds().grow(-EDGE)
	var busy: Array[Vector2] = []
	for node in region.find_children("*", "", true, false):
		if node is Node2D and node.has_method("interact"):
			busy.append(node.global_position)
	var covers := _covers(region)
	# finds in one area lie well apart
	var placed: Array[Vector2] = []
	for find: Dictionary in finds:
		if find.region == region.region_id and find.has("pos"):
			placed.append(Vector2(find.pos[0], find.pos[1]))
	for find: Dictionary in finds:
		if find.region == region.region_id and find.has("pos"):
			busy.append(Vector2(find.pos[0], find.pos[1]))
	for find: Dictionary in finds:
		if find.region != region.region_id or find.has("pos"):
			continue
		var spot: Dictionary = find.get("spot", {})
		var place: Place = null
		for p in region.get_places():
			if p.display_name == spot.get("place", ""):
				place = p
		var best := Vector2.INF
		var best_score := -INF
		for at: Vector2i in walked:
			var pos := Vector2(at) * WalkCheck.STEP
			if not bounds.has_point(pos):
				continue
			if place and pos.distance_to(place.global_position) > place.radius * 1.2:
				continue
			# the whole neighbourhood walkable, so it's not wedged in a bush
			if not (walked.has(at + Vector2i(2, 0)) and walked.has(at - Vector2i(2, 0)) and walked.has(at + Vector2i(0, 2)) and walked.has(at - Vector2i(0, 2))):
				continue
			var cell := ground.local_to_map(ground.to_local(pos))
			var d: int = off.get(cell, 99)
			if d < int(spot.get("off", MIN_OFF)):
				continue
			# (a map painted by hand has no terrain tiles to tell by)
			var tags := _tags(ground, cell)
			if spot.has("near") and not tags.is_empty() and not spot.near in tags:
				continue
			if busy.any(func(b: Vector2) -> bool: return b.distance_to(pos) < CLEAR):
				continue
			if placed.any(func(b: Vector2) -> bool: return b.distance_to(pos) < FIND_GAP):
				continue
			if pos.distance_to(start.global_position) < 320.0:
				continue
			# off the path (up to a point), then clear of the map's edges, and
			# away from where you arrive
			var edge := minf(minf(pos.x - bounds.position.x, bounds.end.x - pos.x), minf(pos.y - bounds.position.y, bounds.end.y - pos.y))
			var score := minf(d, 6.0) * 100.0 + minf(edge, 600.0) * 0.1 + pos.distance_to(start.global_position) * 0.02
			if score <= best_score:
				continue
			# not under a tree or a bush drawn in front of it
			if _covered(covers, pos):
				continue
			if score > best_score:
				best_score = score
				best = pos
		if best == Vector2.INF:
			print("%s: %s found no spot" % [region.region_id, find.id])
			continue
		find["pos"] = [int(best.x), int(best.y)]
		busy.append(best)
		placed.append(best)
		print("%s: %s at %s" % [region.region_id, find.id, best])


func _survey(region: Region) -> void:
	var walk := WalkCheck.new()
	var start := WalkCheck.start_of(region)
	if start == null:
		print("%s: no start" % region.region_id)
		return
	var walked := walk.walk(region, start.global_position)
	var ground := region.get_ground()
	var off := WalkCheck.path_distance(ground)
	var candidates: Array = []
	for at: Vector2i in walked:
		var pos := Vector2(at) * WalkCheck.STEP
		var cell := ground.local_to_map(ground.to_local(pos))
		var d: int = off.get(cell, 99)
		if d < MIN_OFF:
			continue
		candidates.append([pos, d, _tags(ground, cell)])
	print("%s (%s): %d walkable points, %d off the path" % [region.region_id, region.display_name, walked.size(), candidates.size()])
	if candidates.is_empty():
		return
	# Spread out: farthest-point picks, starting from the farthest off the path.
	candidates.sort_custom(func(a, b) -> bool: return a[1] > b[1])
	var picks: Array = [candidates[0]]
	while picks.size() < PICKS and picks.size() < candidates.size():
		var best: Array = []
		var best_gap := -1.0
		for c: Array in candidates:
			var gap := INF
			for p: Array in picks:
				gap = minf(gap, (c[0] as Vector2).distance_to(p[0]))
			if gap > best_gap:
				best_gap = gap
				best = c
		picks.append(best)
	for p: Array in picks:
		var place := region.place_at(p[0])
		print("   (%d, %d) off %d %s%s" % [p[0].x, p[0].y, p[1], ",".join(p[2]), (" in " + place.display_name) if place else ""])


func _tags(ground: TileMapLayer, cell: Vector2i) -> PackedStringArray:
	var tags := PackedStringArray()
	var near := {}
	for dy in range(-3, 4):
		for dx in range(-3, 4):
			var c := cell + Vector2i(dx, dy)
			if ground.get_cell_source_id(c) != 1:
				continue
			var t := ground.get_cell_atlas_coords(c).y
			if t in ROCK:
				near["rock"] = true
			elif t in WATER:
				near["water"] = true
			elif t in WOODS:
				near["woods"] = true
			elif t == Terrain.MEADOW or t == Terrain.WET_MEADOW:
				near["meadow"] = true
	for k in near:
		tags.append(k)
	return tags


## What's drawn over the ground: every sprite (trees, bushes, rocks) as
## [rect, image, y it sorts at], and the flora tiles' cells.
func _covers(region: Region) -> Array:
	var list: Array = []
	var images := {}
	for node in region.find_children("*", "Sprite2D", true, false):
		var sprite := node as Sprite2D
		if sprite.texture == null or not sprite.is_visible_in_tree() or sprite.texture.get_width() < 24:
			continue
		var rect := sprite.get_global_transform() * sprite.get_rect()
		var key := sprite.texture.resource_path
		if not images.has(key):
			var image := sprite.texture.get_image()
			if image and image.is_compressed():
				image.decompress()
			images[key] = image
		# y-sorted by the child of Entities it belongs to
		var sorter: Node2D = sprite
		while sorter.get_parent() is Node2D and sorter.get_parent() != region.entities and sorter.get_parent() != region:
			sorter = sorter.get_parent()
		list.append([rect, images[key], sorter.global_position.y, sprite])
	return list


## True if something drawn in front would hide much of a find at [param pos]
## (its icon is about 16 px, standing on pos).
func _covered(covers: Array, pos: Vector2) -> bool:
	var find := Rect2(pos + Vector2(-8, -18), Vector2(16, 16))
	for c: Array in covers:
		var rect: Rect2 = c[0]
		if not rect.intersects(find) or float(c[2]) < pos.y - 4.0:
			continue
		var image: Image = c[1]
		if image == null:
			return true
		var sprite: Sprite2D = c[3]
		var inv := sprite.get_global_transform().affine_inverse()
		var hidden := 0
		for y in range(int(find.position.y), int(find.end.y), 2):
			for x in range(int(find.position.x), int(find.end.x), 2):
				var local := inv * Vector2(x, y) - sprite.get_rect().position
				var px := Vector2i(local * Vector2(image.get_size()) / sprite.get_rect().size)
				if px.x >= 0 and px.y >= 0 and px.x < image.get_width() and px.y < image.get_height() and image.get_pixelv(px).a > 0.5:
					hidden += 1
		if hidden > 6: # of 64 samples
			return true
	return false
