extends Node
## Applies a hub's land patches (tools/mapgen/land_patches.gd) to its map
## scene as it is now, without regenerating it: regenerating needs the OSM and
## elevation downloads, and would undo the hand edits made to the scene since.
##   godot --headless --path . res://tools/mapgen/patch_land.tscn -- <hub id> <picture.png> [dry]
## Removes the buildings in the "clear" areas, turns their ground (and, with
## "unpave", the roads that lead nowhere) to forest floor and plants it, lays slab and talus along the cliff foot,
## fixes the collision, saves the scene, and paints the whole ground picture
## (16px to a tile) to <picture.png>. It prints "PATCHED x0 y0 x1 y1", the
## tiles that changed; tools/mapgen/patch_land.sh upgrades the picture to 32px
## and copies just that part into the map's ground picture. With "dry" it
## changes nothing and only paints (to check the picture matches).

const Terrain = preload("res://tools/mapgen/terrain.gd")
const Art = preload("res://tools/mapgen/art.gd")
const HubContent = preload("res://tools/mapgen/hub_content.gd")
const LandPatches = preload("res://tools/mapgen/land_patches.gd")
const GroundUpgrade = preload("res://tools/mapgen/ground_upgrade.gd")
const TILE := 32.0
const STORY_DIR := "res://scenes/story/content/"


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() < 2:
		push_error("usage: -- <hub id> <picture.png> [dry]")
		get_tree().quit(1)
		return
	var ok := patch(args[0], args[1], "dry" in args)
	get_tree().quit(0 if ok else 1)


func patch(hub_id: String, picture: String, dry: bool) -> bool:
	var map_path := "res://scenes/regions/generated/%s_map.tscn" % hub_id
	var map: Node = (load(map_path) as PackedScene).instantiate(PackedScene.GEN_EDIT_STATE_MAIN)
	var content: Dictionary = HubContent.CONTENT.get(hub_id, {})
	var size: Vector2i = map.get("size_in_tiles")
	var w := size.x
	var h := size.y
	var to_cell := func(p: Vector2) -> Vector2: return map.call("lonlat_to_position", p) / TILE
	var clear := LandPatches.mask(content, "clear", w, h, to_cell)
	var slabs := LandPatches.mask(content, "slabs", w, h, to_cell)
	var talus := LandPatches.mask(content, "talus", w, h, to_cell)
	var ground := map.get_node("Ground") as TileMapLayer
	var blocker := map.get_node("Blocker") as TileMapLayer
	var flora := map.get_node("Flora") as TileMapLayer
	var canopy := map.get_node("OakCanopy") as TileMapLayer
	var kind := PackedInt32Array()
	kind.resize(w * h)
	for j in h:
		for i in w:
			var c := Vector2i(i, j)
			kind[j * w + i] = ground.get_cell_atlas_coords(c).y if ground.get_cell_source_id(c) >= 0 else -1
	var changed := {}
	if not dry:
		var keep := _keep_mask(map, hub_id, w, h)
		var removed := _remove_buildings(map, clear, w)
		var blocked_before := {}
		for c in blocker.get_used_cells():
			blocked_before[c] = true
		# Built ground in the cleared areas becomes forest floor.
		for k in w * h:
			if clear[k] != 0 and kind[k] == Terrain.BUILT:
				kind[k] = Terrain.FOREST
				changed[Vector2i(k % w, k / w)] = true
		if LandPatches.wants(content, "unpave"):
			for c in LandPatches.unpave(kind, w, h, clear, _spot_cells(map, hub_id, true)):
				changed[c] = true
		for c in LandPatches.reshape(kind, w, h, slabs, talus, keep):
			changed[c] = true
		for c: Vector2i in changed:
			ground.set_cell(c, Art.SOURCE_TERRAIN, Vector2i(ground.get_cell_atlas_coords(c).x, kind[c.y * w + c.x]), ground.get_cell_alternative_tile(c))
		_fix_collision(blocker, kind, w, h, changed, blocked_before)
		var planted := _plant(flora, canopy, kind, w, h, clear, keep, changed, hub_id)
		print("%s: %d buildings removed, %d tiles changed, %d trees planted" % [hub_id, removed, changed.size(), planted])
		var packed := PackedScene.new()
		packed.pack(map)
		if ResourceSaver.save(packed, map_path) != OK:
			push_error("couldn't save " + map_path)
			return false
	var im := GroundUpgrade.paint(map, hub_id)
	im.save_png(picture)
	var box := Rect2i()
	for c: Vector2i in changed:
		box = Rect2i(c, Vector2i.ONE) if box.size == Vector2i.ZERO else box.merge(Rect2i(c, Vector2i.ONE))
	print("PATCHED %d %d %d %d" % [box.position.x, box.position.y, box.end.x, box.end.y])
	map.free()
	return true


## The cells of the spawns, signs, doors and kiosks, and of the story objects
## placed over the map (like the Apron's climb start). With [param ways_in],
## only the spawns, doors, kiosks and shuttle stops: the spots a road leads to.
func _spot_cells(map: Node, hub_id: String, ways_in := false) -> Array[Vector2i]:
	var spots: Array[Vector2i] = []
	for group in ["Spawns", "Objects"]:
		var parent := map.get_node_or_null(group)
		if parent != null:
			for node in parent.get_children():
				if node is Node2D and not (ways_in and String(node.name).begins_with("Sign_")):
					spots.append(Vector2i(((node as Node2D).position / TILE).floor()))
	var story_path := STORY_DIR + hub_id + ".tscn"
	if ResourceLoader.exists(story_path):
		var story: Node = (load(story_path) as PackedScene).instantiate()
		for node in story.get_children():
			if node is Node2D and (not ways_in or node is RegionDoor):
				spots.append(Vector2i(((node as Node2D).position / TILE).floor()))
		story.free()
	return spots


## Cells to leave as they are: around each of _spot_cells().
func _keep_mask(map: Node, hub_id: String, w: int, h: int) -> PackedByteArray:
	var keep := PackedByteArray()
	keep.resize(w * h)
	for c in _spot_cells(map, hub_id):
		for dy in range(-2, 3):
			for dx in range(-2, 3):
				var n := c + Vector2i(dx, dy)
				if n.x >= 0 and n.y >= 0 and n.x < w and n.y < h:
					keep[n.y * w + n.x] = 1
	return keep


## Frees the building sprites and footprints standing in a "clear" area.
func _remove_buildings(map: Node, clear: PackedByteArray, w: int) -> int:
	var buildings := map.get_node_or_null("Buildings")
	if buildings == null:
		return 0
	var removed := 0
	var parents: Array[Node] = [buildings]
	if buildings.has_node("Footprints"):
		parents.append(buildings.get_node("Footprints"))
	for parent in parents:
		for node in parent.get_children():
			if not node is Node2D or node.name == "Footprints":
				continue
			var c := Vector2i(((node as Node2D).position / TILE).floor())
			var k := c.y * w + c.x
			if k >= 0 and k < clear.size() and clear[k] != 0:
				if parent == buildings:
					removed += 1
				parent.remove_child(node)
				node.free()
	return removed


## Blocker tiles go on unwalkable cells that touch walkable ones (as
## region_builder.gd lays them). Cells that became forest floor or slab are
## open; talus is not.
func _fix_collision(blocker: TileMapLayer, kind: PackedInt32Array, w: int, h: int, changed: Dictionary, blocked_before: Dictionary) -> void:
	var open := func(c: Vector2i) -> bool:
		if c.x < 0 or c.y < 0 or c.x >= w or c.y >= h:
			return false
		var t := kind[c.y * w + c.x]
		if t < 0 or Terrain.is_solid(t) or t == Terrain.BUILT:
			return false
		return changed.has(c) or not blocked_before.has(c)
	var near := {}
	for c: Vector2i in changed:
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				near[c + Vector2i(dx, dy)] = true
	for c: Vector2i in near:
		if open.call(c):
			if changed.has(c):
				blocker.erase_cell(c)
			continue
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				if open.call(c + Vector2i(dx, dy)):
					blocker.set_cell(c, Art.SOURCE_BLOCKER, Vector2i.ZERO)


## Plants the cleared forest floor as thickly as region_builder.gd plants OSM
## woods (ponderosa, incense cedar, black oak, a little white fir and
## dogwood), and a few trees on the new talus. Returns how many it planted.
func _plant(flora: TileMapLayer, canopy: TileMapLayer, kind: PackedInt32Array, w: int, h: int, clear: PackedByteArray, keep: PackedByteArray, changed: Dictionary, hub_id: String) -> int:
	var F := Terrain.Flora
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(hub_id + ":land_patches")
	var noise := FastNoiseLite.new()
	noise.seed = hash(hub_id)
	noise.frequency = 0.09
	noise.fractal_octaves = 2
	var planted := 0
	for j in h:
		for i in w:
			var c := Vector2i(i, j)
			var k := j * w + i
			# New slab is mostly bare: the trees that stood there go.
			if changed.has(c) and kind[k] == Terrain.GRANITE and flora.get_cell_source_id(c) >= 0:
				flora.erase_cell(c)
				canopy.erase_cell(c)
			if keep[k] != 0 or flora.get_cell_source_id(c) >= 0:
				continue
			var options: Array = []
			var density := 0.0
			if changed.has(c) and kind[k] == Terrain.GRANITE:
				density = 0.05
				options = [[F.ERRATIC, 2], [F.JEFFREY_PINE, 2]]
			elif clear[k] != 0 and kind[k] == Terrain.FOREST:
				density = LandPatches.FOREST_DENSITY
				options = [[F.PONDEROSA, 4], [F.INCENSE_CEDAR, 3], [F.BLACK_OAK_TRUNK, 3], [F.WHITE_FIR, 1], [F.DOGWOOD, 1], [F.SNAG, 0.4]]
			elif changed.has(c) and kind[k] == Terrain.TALUS:
				density = 0.08
				options = [[F.INCENSE_CEDAR, 1], [F.LIVE_OAK, 1]]
			if density <= 0.0 or rng.randf() > density * (0.55 + noise.get_noise_2d(i, j) * 0.9):
				continue
			var tree: int = _weighted(rng, options)
			flora.set_cell(c, Art.SOURCE_FLORA, Terrain.frame_coords(tree))
			if tree == F.BLACK_OAK_TRUNK:
				canopy.set_cell(c, Art.SOURCE_FLORA, Terrain.frame_coords(F.BLACK_OAK_CANOPY))
			planted += 1
	return planted


func _weighted(rng: RandomNumberGenerator, options: Array) -> int:
	var total := 0.0
	for o: Array in options:
		total += o[1]
	var roll := rng.randf() * total
	for o: Array in options:
		roll -= o[1]
		if roll <= 0.0:
			return o[0]
	return options[-1][0]
