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

## How far the next map slides along the edge at each seam so the painted
## road meets itself, measured by tools/seams/measure_seams.tscn:
## {region id: {exit name: pixels}}.
const NUDGES_PATH := "res://data/park/seam_nudges.json"
static var _nudges = null

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
## The two regions whose grounds blend while the seam is open.
var _blended_a: Region
var _blended_b: Region

## The two maps overlap by this many pixels at a seam, and their painted
## grounds blend across the overlap (see seasonal_ground.gdshader).
const OVERLAP := 64.0

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
## or null if the two maps don't meet edge to edge there. [param nudged]
## slides the neighbor by the measured nudge (see NUDGES_PATH).
static func make(region: Region, exit: RegionExit, neighbor: Region, nudged := true) -> Seam:
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
	if nudged:
		seam.offset += Vector2(absf(side.y), absf(side.x)) * nudge(region.region_id, exit.name)
		seam.offset -= Vector2(side) * OVERLAP
	return seam


## The measured slide along the edge for [param region]'s [param exit_name].
static func nudge(region_id: String, exit_name: String) -> float:
	if _nudges == null:
		_nudges = {}
		if FileAccess.file_exists(NUDGES_PATH):
			var parsed = JSON.parse_string(FileAccess.get_file_as_string(NUDGES_PATH))
			if parsed is Dictionary:
				_nudges = parsed
	return float(_nudges.get(region_id, {}).get(exit_name, 0.0))


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


## How far the two maps overlap: OVERLAP once nudged into place, measured
## from where the neighbor's edge sits against this one's.
func _overlap() -> float:
	var nb := neighbor_bounds()
	match side:
		Vector2i.LEFT: return nb.end.x - point.x
		Vector2i.RIGHT: return point.x - nb.position.x
		Vector2i.UP: return nb.end.y - point.y
	return point.y - nb.position.y


## Takes the rims out of both maps around the road (see CORRIDOR), and
## blends their painted grounds across the overlap.
func open(region: Region) -> void:
	close()
	_blend(region, point, side, neighbor_bounds(), point)
	var mine := region.get_bounds()
	mine.position -= offset
	_blend(neighbor, point - offset - Vector2(side) * _overlap(), -side, mine, point - offset)
	_open_rim(region, point, side, neighbor_bounds())
	_open_rim(neighbor, point - offset - Vector2(side) * _overlap(), -side, mine)


## Puts the rims back and the grounds' edges as they were.
func close() -> void:
	for r in [_blended_a, _blended_b]:
		if is_instance_valid(r):
			for ground in _grounds(r):
				(ground.material as ShaderMaterial).set_shader_parameter("seam_on", false)
	_blended_a = null
	_blended_b = null
	for cell in _opened:
		var layer: TileMapLayer = cell[0]
		if is_instance_valid(layer):
			layer.set_cell(cell[1], cell[2], cell[3], cell[4])
	_opened.clear()


## Sets [param r]'s painted ground to blend over its [param edge] (whose
## point near the road is [param at]) into [param other]'s ground, in r's
## coordinates. [param origin] is the same spot for both maps.
func _blend(r: Region, at: Vector2, edge: Vector2i, other: Rect2, origin: Vector2) -> void:
	if _blended_a == null:
		_blended_a = r
	else:
		_blended_b = r
	var depth := _overlap()
	if depth <= 0.0:
		return
	var axis := 0 if edge.x != 0 else 1
	var inner := at - Vector2(edge) * depth
	for ground in _grounds(r):
		var mat := ground.material as ShaderMaterial
		var to_tex := func(p: Vector2) -> Vector2: return ground.to_local(r.to_global(p))
		var a: Vector2 = to_tex.call(at)
		var b: Vector2 = to_tex.call(inner)
		var lo: Vector2 = to_tex.call(other.position)
		var hi: Vector2 = to_tex.call(other.end)
		mat.set_shader_parameter("seam_on", true)
		mat.set_shader_parameter("seam_axis", axis)
		mat.set_shader_parameter("seam_band", Vector2(a.x, b.x) if axis == 0 else Vector2(a.y, b.y))
		mat.set_shader_parameter("seam_span", Vector2(lo.y, hi.y) if axis == 0 else Vector2(lo.x, hi.x))
		mat.set_shader_parameter("seam_origin", to_tex.call(origin))
		mat.set_shader_parameter("seam_flip", edge == Vector2i.RIGHT or edge == Vector2i.DOWN)


## The painted grounds of [param r] that take the seasonal ground shader.
static func _grounds(r: Region) -> Array[Sprite2D]:
	var found: Array[Sprite2D] = []
	for ground_name in ["GroundArt", "GroundPainting"]:
		var ground := r.get_node_or_null(ground_name) as Sprite2D
		if ground and ground.material is ShaderMaterial and (ground.material as ShaderMaterial).shader.resource_path.ends_with("seasonal_ground.gdshader"):
			found.append(ground)
	return found


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
	# the neighbor's own edge, OVERLAP back from this one's
	back.point = point - offset - Vector2(side) * _overlap()
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
