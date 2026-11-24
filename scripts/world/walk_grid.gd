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
## This grid's cell and body sizes (CELL and FOOT unless built finer).
var _cell_size := CELL
var _foot := FOOT
## The region the grid is for. Positions in and out are the world's, and
## the grid is in the region's own pixels: a region isn't always at the
## world's origin (a seam lays it beside the one you're in, and moves the
## one behind you once you cross).
var _region: Node2D


## The region's grid, built on first use and kept on the region.
static func of(region: Region) -> WalkGrid:
	if region.has_meta("walk_grid"):
		return region.get_meta("walk_grid")
	var grid := WalkGrid.new()
	grid._build(region)
	region.set_meta("walk_grid", grid)
	return grid


## A grid of [param cell] px cells for a body of [param foot] (finer than the
## usual, to find the narrow bridges a player fits over), not kept. For tools.
static func finer(region: Region, cell: int, foot: Vector2) -> WalkGrid:
	var grid := WalkGrid.new()
	grid._cell_size = cell
	grid._foot = foot
	grid._build(region)
	return grid


func _build(region: Region) -> void:
	_region = region
	var to_world := region.get_global_transform() if region.is_inside_tree() else Transform2D.IDENTITY
	var bounds := region.get_bounds()
	_origin = bounds.position
	var cells := Vector2i((bounds.size / _cell_size).ceil())
	_astar.region = Rect2i(Vector2i.ZERO, cells)
	_astar.cell_size = Vector2(_cell_size, _cell_size)
	_astar.offset = _origin + Vector2(_cell_size, _cell_size) / 2.0
	_astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	_astar.update()
	var space := region.get_world_2d().direct_space_state
	var query := PhysicsShapeQueryParameters2D.new()
	query.collision_mask = 1
	query.collide_with_areas = false
	query.exclude = _actor_rids(region)
	var base := _astar.offset + Vector2(0, -6)
	var leaf_box := RectangleShape2D.new()
	leaf_box.size = _foot
	# Fast 4x4 -> 1x1 pruning when to_world is pure translation (all regions).
	if to_world.x == Vector2.RIGHT and to_world.y == Vector2.DOWN:
		var world_base := base + to_world.origin
		var box4 := RectangleShape2D.new()
		box4.size = _foot + Vector2(3 * _cell_size + 0.5, 3 * _cell_size + 0.5)
		var edge_box := RectangleShape2D.new()
		for y0 in range(0, cells.y, 4):
			var h := mini(4, cells.y - y0)
			for x0 in range(0, cells.x, 4):
				var w := mini(4, cells.x - x0)
				if w == 4 and h == 4:
					query.shape = box4
				else:
					edge_box.size = _foot + Vector2((w - 1) * _cell_size + 0.5, (h - 1) * _cell_size + 0.5)
					query.shape = edge_box
				query.transform = Transform2D(
					0.0,
					world_base + Vector2((x0 + (w - 1) * 0.5) * _cell_size, (y0 + (h - 1) * 0.5) * _cell_size)
				)
				if space.intersect_shape(query, 1).is_empty():
					continue
				query.shape = leaf_box
				for y in range(y0, y0 + h):
					var wy := world_base.y + y * _cell_size
					for x in range(x0, x0 + w):
						query.transform = Transform2D(0.0, Vector2(world_base.x + x * _cell_size, wy))
						if _cell_blocked(space, query):
							_astar.set_point_solid(Vector2i(x, y))
		return
	query.shape = leaf_box
	for y in cells.y:
		for x in cells.x:
			query.transform = Transform2D(0.0, to_world * (base + Vector2(x, y) * _cell_size))
			if _cell_blocked(space, query):
				_astar.set_point_solid(Vector2i(x, y))


static func _cell_blocked(space: PhysicsDirectSpaceState2D, query: PhysicsShapeQueryParameters2D) -> bool:
	var hits := space.intersect_shape(query, 1)
	if hits.is_empty():
		return false
	var body: Object = hits[0].collider
	if not (body is NPC or body is Player):
		return true
	# Rare fallback if an unexcluded NPC/Player wasn't in the exclude list.
	for hit: Dictionary in space.intersect_shape(query, 8):
		var other: Object = hit.collider
		if not (other is NPC or other is Player):
			return true
	return false


static func _actor_rids(region: Region) -> Array[RID]:
	var rids: Array[RID] = []
	var seen := {}
	if region.is_inside_tree():
		var tree := region.get_tree()
		for group in ["talkers", "persist", Footprints.GROUP]:
			for node in tree.get_nodes_in_group(group):
				if node is NPC or node is Player:
					var rid: RID = (node as CollisionObject2D).get_rid()
					if not seen.has(rid):
						seen[rid] = true
						rids.append(rid)
	if region.entities:
		for i in region.entities.get_child_count():
			var child := region.entities.get_child(i)
			if child is NPC or child is Player:
				var rid: RID = (child as CollisionObject2D).get_rid()
				if not seen.has(rid):
					seen[rid] = true
					rids.append(rid)
	return rids


func _cell(pos: Vector2) -> Vector2i:
	return Vector2i(((_local(pos) - _origin) / _cell_size).floor())


## [param pos] from the world into the region's own pixels, and back.
func _local(pos: Vector2) -> Vector2:
	return _region.to_local(pos) if _region and _region.is_inside_tree() else pos


func _global(pos: Vector2) -> Vector2:
	return _region.to_global(pos) if _region and _region.is_inside_tree() else pos


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
			return _global(_astar.offset + Vector2(best) * _cell_size)
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
	return _global(_astar.offset + Vector2(cell) * _cell_size)


## True if a straight walk from [param a] to [param b] stays on open ground.
func _clear(a: Vector2, b: Vector2) -> bool:
	var steps := ceili(a.distance_to(b) / (_cell_size / 2.0))
	for s in range(1, steps + 1):
		var cell := _cell(a.lerp(b, float(s) / steps))
		if not _astar.is_in_boundsv(cell) or _astar.is_point_solid(cell):
			return false
	return true
