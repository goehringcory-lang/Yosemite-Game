class_name WorldStream
extends Node
## The open world as one continuous place: which areas are streamed in (laid
## out in the world, beside the one the player is in) and where things are
## across them. World owns the streaming (see World._update_seam and Seam);
## this is the face of it for everything else: the map, markers, wildlife,
## travelers, vistas. Find it with [code]World.stream[/code], or
## [code]get_tree().get_first_node_in_group("world").stream[/code].
##
## How areas join up, and what to put in a new one so it streams: see
## docs/STREAMING.md. In short: a walking RegionExit on the map edge (no
## minutes, no shop hours) whose target spawn sits on the facing edge of the
## next area is a seam, and the two maps are laid side by side there. A long
## trail or road is a chain of "corridor" areas joined by seams, each with
## its [member Region.walk_minutes] (the clock time walking it takes).
##
## The current area always sits at the world's origin, and everything shifts
## when the player crosses into the next one (World.seam_crossed), so keep
## positions in an area's own coordinates, or as longitude/latitude, never
## in world coordinates across frames.

## [param region] has just been laid out in the world: it is in the tree and
## drawn (the area the player went into, or one beside it at a seam).
signal region_streamed_in(region: Region)
## [param region] has just been taken out of the world. It stays in memory
## with every area visited (World._regions), as it was, for next time.
signal region_streamed_out(region: Region)

var world: Node
## The areas laid out now, as of the last sync.
var _laid: Array[Region] = []

## Corridor clock: the area whose walk_minutes are being counted, how far
## along its long side the player has got either way (lo, hi), and the
## minutes of it the clock has had.
var _corridor: Region
var _lo := 0.0
var _hi := 0.0
var _paid := 0.0


func _init(owner_world: Node = null) -> void:
	world = owner_world
	name = "Stream"


func _ready() -> void:
	# after World, which crosses seams at priority 1000
	process_physics_priority = 1001
	if world:
		world.region_changed.connect(_on_region_changed)


## The areas laid out in the world now: the one the player is in first, then
## any beside it.
func loaded_regions() -> Array[Region]:
	return _laid.duplicate()


## Is [param region] laid out in the world now?
func is_streamed(region: Region) -> bool:
	return region in _laid


## [param local] (a spot in [param region]'s own coordinates) in the
## coordinates of the area the player is in, or Vector2.INF if [param region]
## isn't laid out now.
func to_current(region: Region, local: Vector2) -> Vector2:
	if not is_streamed(region):
		return Vector2.INF
	var current: Region = world.region
	return current.to_local(region.to_global(local))


## The laid-out area at [param pos] (in the current area's coordinates): the
## current one if it covers the spot, else a neighbor whose ground does, else
## null.
func region_at(pos: Vector2) -> Region:
	for r in _laid:
		var rect := r.get_bounds()
		rect.position += to_current(r, Vector2.ZERO)
		if rect.has_point(pos):
			return r
	return null


## The player's real-world longitude and latitude (x, y). It carries on
## across seams; hand-made areas without a generated map give their one
## geo_anchor.
func player_lonlat() -> Vector2:
	var current: Region = world.region
	if current == null:
		return Vector2.ZERO
	return current.to_lonlat(current.to_local(world.player.global_position))


## Works out which areas are laid out now and tells listeners what changed.
## World calls it after laying out, dropping or crossing a seam and after
## going somewhere new.
func sync() -> void:
	var now: Array[Region] = []
	var current: Region = world.region
	if current and current.is_inside_tree():
		now.append(current)
	for child in world.get_children():
		if child is Region and child != current and child.is_inside_tree() and child.get_parent() == world \
				and _is_laid_neighbor(child):
			now.append(child)
	var gone: Array[Region] = []
	for r in _laid:
		if not r in now:
			gone.append(r)
	var came: Array[Region] = []
	for r in now:
		if not r in _laid:
			came.append(r)
	_laid = now
	for r in gone:
		if is_instance_valid(r):
			region_streamed_out.emit(r)
	for r in came:
		region_streamed_in.emit(r)


## A region World holds in the tree only while it sets it up for the first
## time (StoryContent needs it there) isn't laid out.
func _is_laid_neighbor(r: Region) -> bool:
	var seam: Seam = world.seam
	return seam != null and seam.neighbor == r


## Corridor areas: the clock moves on by walk_minutes over the walk from one
## end to the other, as the player gets further along (the furthest reached
## either way), so wandering about in it costs nothing extra and stepping
## back and forth at an edge costs nothing at all.
func _on_region_changed(r: Region) -> void:
	_corridor = null
	if r == null or r.indoors or r.walk_minutes <= 0:
		return
	_corridor = r
	_lo = _along(r)
	_hi = _lo
	_paid = 0.0


func _physics_process(_delta: float) -> void:
	if _corridor == null or world.region != _corridor or GameClock.paused:
		return
	var at := _along(_corridor)
	if at >= _lo and at <= _hi:
		return
	_lo = minf(_lo, at)
	_hi = maxf(_hi, at)
	var bounds := _corridor.get_bounds()
	var length := maxf(bounds.size.x, bounds.size.y)
	var due := clampf((_hi - _lo) / maxf(length, 1.0), 0.0, 1.0) * _corridor.walk_minutes
	var whole := floori(due - _paid)
	if whole > 0:
		_paid += whole
		GameClock.advance_minutes(whole)


## How far along [param r]'s longer side the player is, in its coordinates.
func _along(r: Region) -> float:
	var at: Vector2 = r.to_local(world.player.global_position)
	var bounds := r.get_bounds()
	return at.x if bounds.size.x >= bounds.size.y else at.y


## Corridor minutes the clock has had in the corridor the player is in.
func corridor_minutes_paid() -> float:
	return _paid if _corridor else 0.0


## Every way out of an outdoor area that could be a seam (a walking exit on
## its map edge) and whether it really meets the next area edge to edge:
## [{region, exit, target, ok, why}]. For content checks (tests/stream_test)
## and for threads adding areas; [param ids] are region ids, or all region
## scenes when empty.
static func check_links(ids: Array = []) -> Array[Dictionary]:
	var report: Array[Dictionary] = []
	var made := {}
	var get_region := func(id: String) -> Region:
		if not made.has(id):
			var path: String = "res://scenes/regions/%s.tscn" % id
			made[id] = (load(path) as PackedScene).instantiate() if ResourceLoader.exists(path) else null
		return made[id]
	var all := ids.duplicate()
	if all.is_empty():
		for file in DirAccess.get_files_at("res://scenes/regions/"):
			var f := file.trim_suffix(".remap")
			if f.ends_with(".tscn"):
				all.append(f.get_basename())
	for id in all:
		var region: Region = get_region.call(id)
		if region == null or region.indoors:
			continue
		for exit in Seam.candidates(region):
			var entry := {"region": id, "exit": str(exit.name), "target": exit.target_region, "ok": false, "why": ""}
			var neighbor: Region = get_region.call(exit.target_region)
			if neighbor == null:
				entry.why = "no region scene %s" % exit.target_region
			elif neighbor.indoors:
				entry.ok = true
				entry.why = "indoors (a door, not a seam)"
			elif Seam.make(region, exit, neighbor) == null:
				entry.why = "target spawn %s isn't on %s's facing edge, and no exit back is there" % [exit.target_spawn, exit.target_region]
			else:
				entry.ok = true
			report.append(entry)
	for r in made.values():
		if r:
			r.free()
	return report
