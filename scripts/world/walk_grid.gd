class_name WalkGrid
extends RefCounted
## Where people can walk in a region, for routes across it: a grid of 16 px
## cells, each open unless a person standing there would touch the map, a
## building or a prop (physics layer 1; people and the player don't count).
## Built once per region, the first time someone asks for a route.
##
##   var grid := WalkGrid.of(region)
##   var points := grid.route(from, to)   # world positions, start excluded

const CELL := 16
## A person's feet (scenes/story/npc.tscn's body shape), slightly fattened so
## routes don't scrape corners.
const FOOT := Vector2(22, 14)

var _astar := AStarGrid2D.new()
var _origin := Vector2.ZERO


## The region's grid, built on first use and kept on the region.
static func of(region: Region) -> WalkGrid:
	if region.has_meta("walk_grid"):
		return region.get_meta("walk_grid")
	var grid := WalkGrid.new()
	grid._build(region)
	region.set_meta("walk_grid", grid)
	return grid


func _build(region: Region) -> void:
	var bounds := region.get_bounds()
	_origin = bounds.position
	var cells := Vector2i((bounds.size / CELL).ceil())
	_astar.region = Rect2i(Vector2i.ZERO, cells)
	_astar.cell_size = Vector2(CELL, CELL)
	_astar.offset = _origin + Vector2(CELL, CELL) / 2.0
	_astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	_astar.update()
	var space := region.get_world_2d().direct_space_state
	var query := PhysicsShapeQueryParameters2D.new()
	var box := RectangleShape2D.new()
	box.size = FOOT
	query.shape = box
	query.collision_mask = 1
	query.collide_with_areas = false
	for y in cells.y:
		for x in cells.x:
			query.transform = Transform2D(0.0, _astar.offset + Vector2(x, y) * CELL + Vector2(0, -6))
			for hit: Dictionary in space.intersect_shape(query, 8):
				var body: Object = hit.collider
				if not (body is NPC or body is Player):
					_astar.set_point_solid(Vector2i(x, y))
					break


func _cell(pos: Vector2) -> Vector2i:
	return Vector2i(((pos - _origin) / CELL).floor())


## True if [param pos] is on open ground.
func is_open(pos: Vector2) -> bool:
	var cell := _cell(pos)
	return _astar.is_in_boundsv(cell) and not _astar.is_point_solid(cell)


## The open cell nearest [param pos] (searching outward a few cells), as a
## world position; [param pos] itself if nothing is open nearby.
func nearest_open(pos: Vector2, reach := 12) -> Vector2:
	var cell := _cell(pos)
	if _astar.is_in_boundsv(cell) and not _astar.is_point_solid(cell):
		return pos
	for ring in range(1, reach + 1):
		var best := Vector2i(-1, -1)
		var best_d := INF
		for dy in range(-ring, ring + 1):
			for dx in range(-ring, ring + 1):
				if maxi(absi(dx), absi(dy)) != ring:
					continue
				var c := cell + Vector2i(dx, dy)
				if _astar.is_in_boundsv(c) and not _astar.is_point_solid(c):
					var d := Vector2(dx, dy).length_squared()
					if d < best_d:
						best = c
						best_d = d
		if best_d < INF:
			return _astar.offset + Vector2(best) * CELL
	return pos


## The way from [param from] to [param to] over open ground, as the turning
## points to walk through (straight runs merged), ending at [param to] or the
## open ground nearest it. Empty if there's no way.
func route(from: Vector2, to: Vector2) -> PackedVector2Array:
	var start := _cell(nearest_open(from))
	var goal_pos := nearest_open(to)
	var goal := _cell(goal_pos)
	if not (_astar.is_in_boundsv(start) and _astar.is_in_boundsv(goal)):
		return PackedVector2Array()
	var cells := _astar.get_id_path(start, goal)
	if cells.is_empty():
		return PackedVector2Array()
	# Pull the string: from each corner, go as far as a straight line stays
	# on open ground.
	var out := PackedVector2Array()
	var here := from
	var i := 0
	while i < cells.size() - 1:
		var j := cells.size() - 1
		while j > i + 1 and not _clear(here, _center(cells[j])):
			j -= 1
		here = _center(cells[j])
		out.append(here)
		i = j
	if out.is_empty() or out[out.size() - 1].distance_to(goal_pos) > 1.0:
		out.append(goal_pos)
	return out


func _center(cell: Vector2i) -> Vector2:
	return _astar.offset + Vector2(cell) * CELL


## True if a straight walk from [param a] to [param b] stays on open ground.
func _clear(a: Vector2, b: Vector2) -> bool:
	var steps := ceili(a.distance_to(b) / (CELL / 2.0))
	for s in range(1, steps + 1):
		var cell := _cell(a.lerp(b, float(s) / steps))
		if not _astar.is_in_boundsv(cell) or _astar.is_point_solid(cell):
			return false
	return true
