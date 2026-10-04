class_name ForageSpawner
extends Node2D
## Scatters wild forage around a region. What appears, and where, comes from
## each ItemData's forage season and habitat.
##
## Works on two kinds of map:
## - Hand-made areas (the Lamon Homestead), painted with the starter atlas:
##   forage lands on tiles with the "open_ground" flag.
## - Generated hubs: forage lands on walkable natural terrain, read from the
##   terrain type of each Ground tile (see tools/mapgen/terrain.gd). Black oaks
##   are the cells of the OakCanopy layer, and manzanita is a Flora tile.
##
## Forage refreshes once per game day. At home that happens when you sleep;
## in a hub, it happens the first time you arrive on a new day (refresh()).

const Terrain := preload("res://tools/mapgen/terrain.gd")
const FORAGEABLE := preload("res://scenes/objects/forageable.tscn")
## Starter-atlas tiles (source 0) used by the hand-made areas.
const MANZANITA_TILE := Vector2i(7, 0)
const WATER_TILE := Vector2i(3, 0)
## Generated tiles: source ids from tools/mapgen/art.gd.
const SOURCE_STARTER := 0
const SOURCE_TERRAIN := 1
const SOURCE_FLORA := 2
## Terrain where each habitat's forage can land.
const MEADOW_TERRAIN := [Terrain.MEADOW, Terrain.WET_MEADOW, Terrain.FOOTHILL]
const NATURAL_TERRAIN := [Terrain.FOREST, Terrain.MEADOW, Terrain.WET_MEADOW, Terrain.FOOTHILL,
	Terrain.FIR, Terrain.SUBALPINE, Terrain.SCRUB]
const WATER_TERRAIN := [Terrain.RIVER, Terrain.LAKE, Terrain.CREEK]
## How many tiles from a black oak's trunk its acorns (and morels) can land.
## Only the ground south of the trunk counts, so items aren't hidden behind the canopy.
const OAK_REACH := 2
## Tries per item to find a spot that isn't blocked by a tree, rock, or building.
const PLACE_TRIES := 12

## The region's ground layer.
@export var ground: TileMapLayer
## Generated hubs only: the Flora and OakCanopy layers of the Map.
@export var flora: TileMapLayer
@export var oak_canopy: TileMapLayer
## Multiplies each item's forage_per_day. Big hub maps need more than your camp.
@export var amount_scale := 1.0

## The game day this forage was spawned on (see _today()); -1 = never.
var spawned_day := -1

var _rng := RandomNumberGenerator.new()
## Bumped by clear(), so a respawn that's still waiting gives way to a newer
## respawn or a loaded save.
var _generation := 0


func _ready() -> void:
	add_to_group("persist")
	_rng.randomize()


## Respawns if the forage is from an earlier day. Call when the player arrives.
func refresh() -> void:
	if spawned_day != _today():
		await respawn()


## Clears yesterday's forage and spawns today's. Await it before saving.
func respawn() -> void:
	clear()
	var generation := _generation
	await get_tree().physics_frame # let the physics space see every obstacle
	# Give way if a newer respawn or a loaded save took over, or the player
	# left before this finished (the next visit will spawn instead).
	if generation != _generation or not is_inside_tree():
		return
	spawned_day = _today()
	var habitats := _find_habitats()
	var taken := {}
	for item in ItemDB.forage_items():
		if not item.is_forageable_in(GameClock.season):
			continue
		var cells: Array = habitats.get(item.habitat, [])
		if cells.is_empty():
			continue
		for i in maxi(1, roundi(item.forage_per_day * amount_scale)):
			for attempt in PLACE_TRIES:
				var cell: Vector2i = cells[_rng.randi_range(0, cells.size() - 1)]
				if not taken.has(cell) and _is_unblocked(cell):
					taken[cell] = true
					spawn(item.id, cell)
					break


func spawn(item_id: String, cell: Vector2i) -> void:
	var item := ItemDB.get_item(item_id)
	if item == null:
		return
	var forageable: Forageable = FORAGEABLE.instantiate()
	forageable.item = item
	forageable.cell = cell
	forageable.position = to_local(ground.to_global(ground.map_to_local(cell)))
	add_child(forageable)


func clear() -> void:
	_generation += 1
	for child in get_children():
		remove_child(child)
		child.queue_free()


func world_to_cell(world_position: Vector2) -> Vector2i:
	return ground.local_to_map(ground.to_local(world_position))


## Habitat -> Array of open cells. A cell can belong to several habitats.
func _find_habitats() -> Dictionary:
	var oak_cells := {}
	for oak: Node2D in get_tree().get_nodes_in_group("black_oak"):
		if is_ancestor_of(oak) or get_parent().is_ancestor_of(oak):
			oak_cells[world_to_cell(oak.global_position)] = true
	if oak_canopy:
		for cell in oak_canopy.get_used_cells():
			oak_cells[cell] = true

	var result := {}
	for cell in ground.get_used_cells():
		var source := ground.get_cell_source_id(cell)
		if source == SOURCE_TERRAIN:
			var type := ground.get_cell_atlas_coords(cell).y
			if type not in NATURAL_TERRAIN or _has_flora(cell):
				continue
			if type in MEADOW_TERRAIN:
				_add(result, ItemData.Habitat.MEADOW, cell)
			if type == Terrain.SCRUB or _touches_flora(cell, Terrain.Flora.MANZANITA):
				_add(result, ItemData.Habitat.CHAPARRAL, cell)
			if _touches_terrain(cell, WATER_TERRAIN):
				_add(result, ItemData.Habitat.RIVERSIDE, cell)
		elif source == SOURCE_STARTER:
			var data := ground.get_cell_tile_data(cell)
			if data == null or not data.get_custom_data("open_ground"):
				continue
			_add(result, ItemData.Habitat.MEADOW, cell)
			if _touches_tile(cell, MANZANITA_TILE):
				_add(result, ItemData.Habitat.CHAPARRAL, cell)
			if _touches_tile(cell, WATER_TILE):
				_add(result, ItemData.Habitat.RIVERSIDE, cell)
		else:
			continue
		if _under_oak(cell, oak_cells):
			_add(result, ItemData.Habitat.OAK_WOODLAND, cell)
	return result


func _under_oak(cell: Vector2i, oak_cells: Dictionary) -> bool:
	for dy in range(0, OAK_REACH + 1):
		for dx in range(-OAK_REACH, OAK_REACH + 1):
			if oak_cells.has(cell - Vector2i(dx, dy)):
				return true
	return false


## Nothing solid (a tree trunk, rock, sign, or building) is on this cell.
func _is_unblocked(cell: Vector2i) -> bool:
	var query := PhysicsPointQueryParameters2D.new()
	query.position = ground.to_global(ground.map_to_local(cell))
	query.collision_mask = 1
	return get_world_2d().direct_space_state.intersect_point(query, 1).is_empty()


func _has_flora(cell: Vector2i) -> bool:
	return flora != null and flora.get_cell_source_id(cell) != -1


func _touches_tile(cell: Vector2i, atlas_coords: Vector2i) -> bool:
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			if ground.get_cell_atlas_coords(cell + Vector2i(dx, dy)) == atlas_coords:
				return true
	return false


func _touches_terrain(cell: Vector2i, types: Array) -> bool:
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			var n := cell + Vector2i(dx, dy)
			if ground.get_cell_source_id(n) == SOURCE_TERRAIN and ground.get_cell_atlas_coords(n).y in types:
				return true
	return false


func _touches_flora(cell: Vector2i, kind: int) -> bool:
	if flora == null:
		return false
	var frame := Terrain.frame_coords(kind)
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			var n := cell + Vector2i(dx, dy)
			if flora.get_cell_source_id(n) == SOURCE_FLORA and flora.get_cell_atlas_coords(n) == frame:
				return true
	return false


func _add(result: Dictionary, habitat: ItemData.Habitat, cell: Vector2i) -> void:
	if not result.has(habitat):
		result[habitat] = []
	result[habitat].append(cell)


static func _today() -> int:
	return ((GameClock.year - 1) * 4 + GameClock.season) * GameClock.DAYS_PER_SEASON + GameClock.day


func save_data() -> Dictionary:
	var items := []
	for child: Forageable in get_children():
		items.append({"id": child.item.id, "x": child.cell.x, "y": child.cell.y})
	return {"items": items, "day": spawned_day}


func load_data(data: Dictionary) -> void:
	clear()
	spawned_day = int(data.get("day", _today()))
	for saved: Dictionary in data.get("items", []):
		spawn(str(saved.id), Vector2i(int(saved.x), int(saved.y)))
