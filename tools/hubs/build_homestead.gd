extends AhwahneeStyle
## Gives the Lamon Homestead the Ahwahnee's look: its flat tiles are painted
## over with the Ahwahnee ground (meadow, packed-dirt path, the stream), and
## the ring of bush and rock tiles around it is dressed with the Ahwahnee's
## trees, shrubs and boulders. The tile layer stays underneath, hidden, so
## walking, collisions and foraging don't change, and the tent, the signs, the
## gates and the shuttle stop are left exactly as they are. The five black
## oaks keep their acorns and their seasons; scenes/objects/black_oak.tscn now
## shows the Ahwahnee oak in all four seasons (tree_oak_seasons.png, drawn by
## ahwahnee_flora_art.gd).
## Run from the project folder:
##
##   godot --headless --path . res://tools/hubs/build_homestead.tscn
##
## It rewrites scenes/regions/lamon_homestead.tscn and paints
## assets/sprites/ahwahnee/ground_homestead.png. It is safe to run again: it
## removes what it added last time (GroundArt and the "Dec_" props) first.

const SCENE := "res://scenes/regions/lamon_homestead.tscn"
const GW := 40
const GH := 30
## The tile art's types in this scene (atlas x on source 0).
const GRASS := 0
const GRASS_TUFT := 1
const DIRT := 2
const WATER := 3
const BUSH := 6
const ROCK := 7


func _ready() -> void:
	print("== Lamon Homestead")
	load_flora()
	import_assets()
	_root = (load(SCENE) as PackedScene).instantiate(PackedScene.GEN_EDIT_STATE_MAIN)
	_ground = _root.get_node("Ground")
	_entities = _root.get_node("Entities")
	_clear_previous()
	_read_grid()
	_paint()
	_dress()
	for child in _root.get_children():
		_own(child, _root)
	var packed := PackedScene.new()
	assert(packed.pack(_root) == OK)
	save_resource(packed, SCENE)
	_root.free()
	print("Done")
	get_tree().quit()


func _clear_previous() -> void:
	var old := _root.get_node_or_null("GroundArt")
	if old != null:
		_root.remove_child(old)
		old.free()
	for child in _entities.get_children():
		if str(child.name).begins_with("Dec_"):
			_entities.remove_child(child)
			child.free()


## The terrain grid, read from the tile art.
func _read_grid() -> void:
	w = GW
	h = GH
	kind.resize(w * h)
	no_trees.resize(w * h)
	no_trees.fill(0)
	for y in h:
		for x in w:
			var t := _ground.get_cell_atlas_coords(Vector2i(x, y)).x
			var k: int = Terrain.MEADOW
			match t:
				DIRT:
					k = Terrain.TRAIL
				WATER:
					k = Terrain.RIVER
				BUSH, ROCK:
					k = Terrain.FOREST
			kind[y * w + x] = k
			if t != GRASS and t != GRASS_TUFT:
				no_trees[y * w + x] = 1
	rng.seed = 1861
	noise.seed = 1861
	noise.frequency = 0.12


func _paint() -> void:
	_save_ground_art("ground_homestead", 1861)


func _atlas(x: int, y: int) -> int:
	return _ground.get_cell_atlas_coords(Vector2i(x, y)).x


func _dress() -> void:
	_reserve_entities(1, 1)
	# Keep the spawn points and the gates clear.
	for spot: Marker2D in _root.get_node("Spawns").get_children():
		var c := Vector2i(spot.position / T)
		for dy in range(-2, 3):
			for dx in range(-2, 3):
				var tx := c.x + dx
				var ty := c.y + dy
				if tx >= 0 and ty >= 0 and tx < w and ty < h:
					no_trees[ty * w + tx] = 1
	var n := 0
	# The ring: bushes become a tree line with shrubs and ferns, rocks become
	# granite boulders. (The tiles underneath still collide.)
	var trees := ["tree_ponderosa", "tree_incense_cedar", "tree_black_oak", "tree_white_fir", "tree_dogwood"]
	for y in h:
		for x in w:
			var t := _atlas(x, y)
			if t != BUSH and t != ROCK:
				continue
			# a gate leaves the ring open; leave a clear margin around it
			if no_trees[y * w + x] == 1 and _near_spawn(x, y):
				continue
			var pos := Vector2(x * T + rng.randf_range(3.0, 13.0), (y + 1) * T - rng.randf_range(0.0, 3.0))
			var roll := rng.randf()
			var prop := ""
			if t == ROCK:
				prop = _pick("rock_granite" if roll < 0.6 else "rock_mossy")
			elif roll < 0.5 and (x + y) % 2 == 0:
				prop = _pick(trees[rng.randi() % trees.size()])
			elif roll < 0.8:
				prop = _pick("plant_shrub")
			else:
				prop = _pick("plant_fern")
			if prop == "":
				continue
			var body := _prop(prop, pos, "Dec_%d" % n)
			if body != null:
				n += 1
	# The meadow: wildflowers, tall grass, a few boulders and shrubs.
	var inner := Rect2i(1, 1, w - 2, h - 2)
	_scatter_decor("plant_wildflowers", [Terrain.MEADOW], 70, inner, 1)
	_scatter_decor("plant_lupine", [Terrain.MEADOW], 10, inner, 1)
	_scatter_decor("plant_paintbrush", [Terrain.MEADOW], 6, inner, 1)
	_scatter_decor("plant_tall_grass", [Terrain.MEADOW], 40, inner, 1)
	_scatter_decor("plant_shrub", [Terrain.MEADOW], 14, inner, 2)
	_scatter_decor("plant_cattails", [Terrain.MEADOW], 8, Rect2i(27, 1, 6, h - 2), 0)
	_scatter_decor("rock_granite", [Terrain.MEADOW], 8, inner, 2)
	_scatter_decor("rock_river", [Terrain.MEADOW], 6, Rect2i(27, 1, 6, h - 2), 0)
	_scatter_decor("log_fallen", [Terrain.MEADOW], 2, inner, 3)
	# The scatter helper names its props after their sprites; mark them all as
	# ours so a rebuild can find them.
	for child in _entities.get_children():
		if child is StaticBody2D and not _is_original(child):
			if not str(child.name).begins_with("Dec_"):
				child.name = "Dec_" + str(child.name)


func _near_spawn(x: int, y: int) -> bool:
	for spot: Marker2D in _root.get_node("Spawns").get_children():
		var c := Vector2i(spot.position / T)
		if absi(c.x - x) <= 2 and absi(c.y - y) <= 2:
			return true
	return false


## True for the pieces the scene already had (never renamed or removed).
func _is_original(node: Node) -> bool:
	return node.scene_file_path != "" or node.name in ["Forage"]
