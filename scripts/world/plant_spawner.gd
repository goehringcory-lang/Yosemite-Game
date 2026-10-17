class_name PlantSpawner
extends Node2D
## Grows the press book's plants in a region (see Herbarium.PLANTS). Unlike
## forage they come up in the same places every day, so a plant you passed in
## spring is where you left it when you come back with the press: each kind
## has a few spots (fewer if it's rare) near the place named in its "grows" entry, chosen once from
## the ground its habitat allows. What shows follows the season.
##
## World adds one to each region that has a ForageSpawner, whose scan of the
## map's habitats it shares.

const SPECIMEN := preload("res://scenes/objects/plant_specimen.tscn")
## Tiles from the named spot to look for ground, widened until enough is found.
const NEAR_TILES := [10, 18, 30]
const PLACE_TRIES := 40

var region: Region
var forage: ForageSpawner
## The season the plants on the map belong to; -1 = not grown yet.
var grown_season := -1

var _growing := false


## Adds a PlantSpawner to [param in_region] if it has ground for one.
static func attach(in_region: Region) -> PlantSpawner:
	var spawner_forage: ForageSpawner = null
	for child in in_region.entities.get_children():
		if child is PlantSpawner:
			return child
		if child is ForageSpawner:
			spawner_forage = child
	if spawner_forage == null:
		return null
	var spawner := PlantSpawner.new()
	spawner.name = "Plants_" + in_region.region_id
	spawner.y_sort_enabled = true
	spawner.region = in_region
	spawner.forage = spawner_forage
	in_region.entities.add_child(spawner)
	return spawner


## Grows this season's plants if they aren't up yet. Call when the player arrives.
func refresh() -> void:
	if grown_season != GameClock.season and not _growing:
		await grow()


## Clears the map's plants and grows the current season's. Await it in tests.
func grow() -> void:
	_growing = true
	for child in get_children():
		remove_child(child)
		child.queue_free()
	await get_tree().physics_frame # let the physics space see every obstacle
	_growing = false
	if not is_inside_tree():
		return
	grown_season = GameClock.season
	var habitats := forage.habitats()
	var taken := {}
	for plant: Dictionary in Herbarium.PLANTS:
		var grows: Dictionary = plant.grows
		if not grows.has(region.region_id) or not Herbarium.in_season(plant, grown_season):
			continue
		var cells: Array = habitats.get(plant.habitat, [])
		if cells.is_empty():
			push_warning("%s: no %s ground for %s" % [region.region_id, ItemData.Habitat.keys()[plant.habitat], plant.id])
			continue
		for cell in _pick_cells(plant.id, Herbarium.patches(plant), cells, str(grows[region.region_id]), taken):
			_add(plant.id, cell)


## Up to [param wanted] open cells for a plant (fewer for rarer plants; see
## Herbarium.PATCHES), the same ones every time.
func _pick_cells(plant_id: String, wanted: int, cells: Array, near: String, taken: Dictionary) -> Array[Vector2i]:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%s@%s" % [plant_id, region.region_id])
	var pool := _near(cells, near, wanted)
	var picked: Array[Vector2i] = []
	for attempt in PLACE_TRIES:
		if picked.size() >= wanted or pool.is_empty():
			break
		var cell: Vector2i = pool[rng.randi_range(0, pool.size() - 1)]
		# Keep a plant's spots a few steps apart, so three don't sit in a row.
		if taken.has(cell) or picked.any(func(other: Vector2i) -> bool: return (other - cell).length() < 3.0):
			continue
		if forage.is_unblocked(cell):
			taken[cell] = true
			picked.append(cell)
	return picked


## The cells of [param cells] close to the spot named [param near]: within
## the first of NEAR_TILES that holds enough ground for [param wanted]
## patches, or all of them.
func _near(cells: Array, near: String, wanted: int) -> Array:
	var spot := _spot(near)
	if spot == null:
		return cells
	var center := forage.world_to_cell(spot.global_position)
	for reach: int in NEAR_TILES:
		var close := cells.filter(func(cell: Vector2i) -> bool: return (cell - center).length() <= reach)
		if close.size() >= wanted * 4:
			return close
	return cells


## A marker or named place in the region, or null.
func _spot(spot_name: String) -> Node2D:
	if spot_name == "":
		return null
	var marker := region.get_spawn(spot_name)
	if marker:
		return marker
	for place in region.get_places():
		if place.name == spot_name:
			return place
	return null


func _add(plant_id: String, cell: Vector2i) -> void:
	var specimen: PlantSpecimen = SPECIMEN.instantiate()
	specimen.plant_id = plant_id
	specimen.cell = cell
	specimen.position = to_local(forage.ground.to_global(forage.ground.map_to_local(cell)))
	add_child(specimen)


## The plants growing here now, as plant id -> how many.
func growing() -> Dictionary:
	var result := {}
	for child: PlantSpecimen in get_children():
		result[child.plant_id] = int(result.get(child.plant_id, 0)) + 1
	return result
