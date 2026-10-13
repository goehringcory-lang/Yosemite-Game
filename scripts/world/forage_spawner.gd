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
## Conifer shade, and the lodgepole and granite-sand country above it.
const FOREST_TERRAIN := [Terrain.FOREST, Terrain.FIR]
const HIGH_TERRAIN := [Terrain.SUBALPINE]
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
## Habitat -> cells, from _find_habitats(); empty until the first spawn.
var _habitats := {}


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
	for i in int(Perks.bonus("enids_eye")):
		_spawn_extra(habitats, taken)


## Enid's Eye (a perk): one more find of something in season, on a free spot.
func _spawn_extra(habitats: Dictionary, taken: Dictionary) -> void:
	var choices: Array[ItemData] = []
	for item in ItemDB.forage_items():
		if item.is_forageable_in(GameClock.season) and not habitats.get(item.habitat, []).is_empty():
			choices.append(item)
	if choices.is_empty():
		return
	var item := choices[_rng.randi_range(0, choices.size() - 1)]
	var cells: Array = habitats[item.habitat]
	for attempt in PLACE_TRIES:
		var cell: Vector2i = cells[_rng.randi_range(0, cells.size() - 1)]
		if not taken.has(cell) and _is_unblocked(cell):
			taken[cell] = true
			spawn(item.id, cell)
			return


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


## Habitat -> Array of open cells, for PlantSpawner, which shares this scan.
func habitats() -> Dictionary:
	return _find_habitats()


## True if nothing solid stands on [param cell] (see _is_unblocked).
func is_unblocked(cell: Vector2i) -> bool:
	return _is_unblocked(cell)


## Habitat -> Array of open cells. A cell can belong to several habitats.
## The map doesn't change during play, so this is worked out once per spawner
## (it reads every tile of a hub, which takes a noticeable moment) and kept.
func _find_habitats() -> Dictionary:
	if _habitats.is_empty():
		_habitats = _scan_habitats()
	return _habitats


func _scan_habitats() -> Dictionary:
	var oak_cells := {}
	for oak: Node2D in get_tree().get_nodes_in_group("black_oak"):
		if is_ancestor_of(oak) or get_parent().is_ancestor_of(oak):
			oak_cells[world_to_cell(oak.global_position)] = true
	if oak_canopy:
		for cell in oak_canopy.get_used_cells():
			oak_cells[cell] = true
	# Cells within reach of an oak, of water, and of manzanita, marked once
	# from each source cell instead of searched around every ground cell.
	var under_oak := {}
	for oak_cell: Vector2i in oak_cells:
		for dy in range(0, OAK_REACH + 1):
			for dx in range(-OAK_REACH, OAK_REACH + 1):
				under_oak[oak_cell + Vector2i(dx, dy)] = true
	var near_water := {}
	var near_manzanita := {}
	var near_starter_water := {}
	var near_starter_manzanita := {}
	# Read each ground tile once; the second pass below reuses these.
	var cells := ground.get_used_cells()
	var sources := PackedInt32Array()
	sources.resize(cells.size())
	var types := PackedInt32Array()
	types.resize(cells.size())
	for i in cells.size():
		var cell := cells[i]
		var coords := ground.get_cell_atlas_coords(cell)
		var source := ground.get_cell_source_id(cell)
		sources[i] = source
		types[i] = coords.y
		if source == SOURCE_TERRAIN and coords.y in WATER_TERRAIN:
			_mark_around(near_water, cell)
		# Like _touches_tile(), these match the atlas coords from any source.
		if coords == WATER_TILE:
			_mark_around(near_starter_water, cell)
		elif coords == MANZANITA_TILE:
			_mark_around(near_starter_manzanita, cell)
	var flora_cells := {}
	if flora:
		var manzanita := Terrain.frame_coords(Terrain.Flora.MANZANITA)
		for cell in flora.get_used_cells():
			flora_cells[cell] = true
			if flora.get_cell_source_id(cell) == SOURCE_FLORA and flora.get_cell_atlas_coords(cell) == manzanita:
				_mark_around(near_manzanita, cell)

	var result := {}
	for i in cells.size():
		var cell := cells[i]
		var source := sources[i]
		if source == SOURCE_TERRAIN:
			var type := types[i]
			if type not in NATURAL_TERRAIN or flora_cells.has(cell):
				continue
			if type in MEADOW_TERRAIN:
				_add(result, ItemData.Habitat.MEADOW, cell)
			if type == Terrain.SCRUB or near_manzanita.has(cell):
				_add(result, ItemData.Habitat.CHAPARRAL, cell)
			if near_water.has(cell):
				_add(result, ItemData.Habitat.RIVERSIDE, cell)
			if type in FOREST_TERRAIN:
				_add(result, ItemData.Habitat.FOREST, cell)
			if type in HIGH_TERRAIN:
				_add(result, ItemData.Habitat.HIGH_COUNTRY, cell)
		elif source == SOURCE_STARTER:
			var data := ground.get_cell_tile_data(cell)
			if data == null or not data.get_custom_data("open_ground"):
				continue
			_add(result, ItemData.Habitat.MEADOW, cell)
			if near_starter_manzanita.has(cell):
				_add(result, ItemData.Habitat.CHAPARRAL, cell)
			if near_starter_water.has(cell):
				_add(result, ItemData.Habitat.RIVERSIDE, cell)
		else:
			continue
		if under_oak.has(cell):
			_add(result, ItemData.Habitat.OAK_WOODLAND, cell)
	return result


## Marks [param cell] and its eight neighbours in [param cells].
static func _mark_around(cells: Dictionary, cell: Vector2i) -> void:
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			cells[cell + Vector2i(dx, dy)] = true


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
