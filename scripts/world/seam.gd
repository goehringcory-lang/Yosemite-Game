class_name Seam
extends RefCounted
## Where two outdoor regions meet at a road or trail that runs off the edge
## of one map and onto the edge of the next, like Northside Drive from
## Yosemite Village into Leidig Meadow. World lays the next region beside
## this one at the seam, so the player walks across without a fade.
##
## A seam is one RegionExit on a map edge whose target spawn sits on the
## facing edge of the next region. Exits that take clock time (long trails
## and drives) or keep hours (shop doors) aren't seams: they still fade.

## An exit or spawn this close to a map edge is on that edge.
const EXIT_SLACK := 48.0
const SPAWN_SLACK := 160.0

## The exit in the region the player is in.
var exit: RegionExit
## The region it leads to, and where that region sits in this one's
## coordinates when the two are laid side by side.
var neighbor: Region
var offset := Vector2.ZERO
## The edge of this region the seam is on: (-1, 0) west, (1, 0) east,
## (0, -1) north, (0, 1) south.
var side := Vector2i.ZERO
## Where the exit meets the edge, in this region's coordinates.
var point := Vector2.ZERO
## The blocker cells taken out of the two maps' rims while the seam is open:
## [TileMapLayer, cell, source, atlas coords, alternative].
var _opened: Array = []

## Each map is ringed by blocker cells just past its edge. Across a seam
## they are taken out for this many pixels either side of the road, so the
## road walks on; further along the edge the rims stay, like a hedge.
const CORRIDOR := 192.0


## The exits in [param region] that could be seams, before the regions they
## lead to are loaded: the walking exits on a map edge.
static func candidates(region: Region) -> Array[RegionExit]:
	var exits: Array[RegionExit] = []
	if region.indoors:
		return exits
	var bounds := region.get_bounds()
	for node in region.find_children("*", "RegionExit", true, false):
		var exit := node as RegionExit
		if exit.target_region == "" or exit.minutes > 0 or exit.open_hour != 0 or exit.close_hour != 24:
			continue
		if _side_of(bounds, region.to_local(exit.global_position), EXIT_SLACK) != Vector2i.ZERO:
			exits.append(exit)
	return exits


## The seam from [param region] through [param exit] into [param neighbor],
## or null if the two maps don't meet edge to edge there.
static func make(region: Region, exit: RegionExit, neighbor: Region) -> Seam:
	if neighbor.indoors:
		return null
	var bounds := region.get_bounds()
	var exit_at := region.to_local(exit.global_position)
	var side := _side_of(bounds, exit_at, EXIT_SLACK)
	var landing := _landing(region, exit, neighbor, -side)
	if side == Vector2i.ZERO or landing == Vector2.INF:
		return null
	var seam := Seam.new()
	seam.exit = exit
	seam.neighbor = neighbor
	seam.side = side
	seam.point = _onto_edge(bounds, exit_at, side)
	seam.offset = seam.point - _onto_edge(neighbor.get_bounds(), landing, -side)
	return seam


## Where the road comes in on [param neighbor]'s [param edge]: the exit's
## spawn if it's on that edge, or else the neighbor's own exit back along
## the road (some spawns sit well inside the next map, by a gate), or INF.
static func _landing(region: Region, exit: RegionExit, neighbor: Region, edge: Vector2i) -> Vector2:
	var nb := neighbor.get_bounds()
	var spawn := neighbor.get_spawn(exit.target_spawn)
	if spawn and _side_of(nb, neighbor.to_local(spawn.global_position), SPAWN_SLACK) == edge:
		return neighbor.to_local(spawn.global_position)
	for node in neighbor.find_children("*", "RegionExit", true, false):
		var back := node as RegionExit
		var at := neighbor.to_local(back.global_position)
		if back.target_region == region.region_id and back.minutes == 0 and _side_of(nb, at, EXIT_SLACK) == edge:
			return at
	return Vector2.INF


## The neighbor's playable area, in this region's coordinates.
func neighbor_bounds() -> Rect2:
	var rect := neighbor.get_bounds()
	rect.position += offset
	return rect


## Has a spot (in this region's coordinates) gone over the edge onto the
## neighbor's ground?
func is_across(pos: Vector2, bounds: Rect2) -> bool:
	if not neighbor_bounds().has_point(pos):
		return false
	match side:
		Vector2i.LEFT: return pos.x < bounds.position.x
		Vector2i.RIGHT: return pos.x >= bounds.end.x
		Vector2i.UP: return pos.y < bounds.position.y
	return pos.y >= bounds.end.y


## Takes the rims out of both maps around the road (see CORRIDOR).
func open(region: Region) -> void:
	close()
	_open_rim(region, point, side, neighbor_bounds())
	var mine := region.get_bounds()
	mine.position -= offset
	_open_rim(neighbor, point - offset, -side, mine)


## Puts the rims back.
func close() -> void:
	for cell in _opened:
		var layer: TileMapLayer = cell[0]
		if is_instance_valid(layer):
			layer.set_cell(cell[1], cell[2], cell[3], cell[4])
	_opened.clear()


## Takes out [param r]'s rim cells near [param at] on [param edge] that
## stand on [param other]'s ground, in r's coordinates.
func _open_rim(r: Region, at: Vector2, edge: Vector2i, other: Rect2) -> void:
	var layer := r.get_node_or_null("Blocker") as TileMapLayer
	if r.map:
		layer = r.map.get_node_or_null("Blocker") as TileMapLayer
	if layer == null:
		return
	var bounds := r.get_bounds()
	var along := Vector2(absf(edge.y), absf(edge.x))
	var tile := Vector2(layer.tile_set.tile_size)
	var steps := ceili(CORRIDOR / tile.dot(along))
	for depth in 2:
		for step in range(-steps, steps + 1):
			var spot := at + along * tile * step + Vector2(edge) * tile * (depth + 0.5)
			var cell := layer.local_to_map(layer.to_local(r.to_global(spot)))
			var source := layer.get_cell_source_id(cell)
			var middle := r.to_local(layer.to_global(layer.map_to_local(cell)))
			if source == -1 or bounds.has_point(middle) or not other.has_point(middle):
				continue
			_opened.append([layer, cell, source, layer.get_cell_atlas_coords(cell), layer.get_cell_alternative_tile(cell)])
			layer.erase_cell(cell)


## The same seam seen from the other side, once the player has crossed.
func reversed(region: Region) -> Seam:
	var back := Seam.new()
	back.neighbor = region
	back.offset = -offset
	back.side = -side
	back.point = point - offset
	for node in neighbor.find_children("*", "RegionExit", true, false):
		var candidate := node as RegionExit
		if candidate.target_region == region.region_id and (neighbor.to_local(candidate.global_position) - back.point).length() < SPAWN_SLACK * 2.0:
			back.exit = candidate
	return back


## Which edge of [param bounds] [param pos] is on, within [param slack].
static func _side_of(bounds: Rect2, pos: Vector2, slack: float) -> Vector2i:
	var gaps := [pos.x - bounds.position.x, bounds.end.x - pos.x, pos.y - bounds.position.y, bounds.end.y - pos.y]
	var nearest: float = gaps.min()
	if nearest > slack:
		return Vector2i.ZERO
	return [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN][gaps.find(nearest)]


static func _onto_edge(bounds: Rect2, pos: Vector2, side: Vector2i) -> Vector2:
	match side:
		Vector2i.LEFT: return Vector2(bounds.position.x, pos.y)
		Vector2i.RIGHT: return Vector2(bounds.end.x, pos.y)
		Vector2i.UP: return Vector2(pos.x, bounds.position.y)
	return Vector2(pos.x, bounds.end.y)
