extends Node
## Measures the walks the Travelers take (Travelers.PLANS) on the maps, and
## writes res://data/park/walks.json for Travelers to read:
##   links   every walking exit from one outdoor area into the next (a road
##           or trail that takes no clock time), and the spot it lands on
##   spots   where each plan's stops are (a spot, or where someone stands
##           off it: Travelers.point_of)
##   routes  the way over open ground (WalkGrid.finer) for every walk of every
##           plan: from a spot or the spot you come in at, to the next spot
##           or the road out ("exit:<name>")
## Then prints each traveler's day, to check the times read well.
## Run: godot --headless --path . res://tools/travelers/measure_walks.tscn

const REGION_DIR := "res://scenes/regions/"
## The ways are found on a grid finer than the townsfolk's (WalkGrid), for a
## body the player's size, so they take the narrow bridges a player can.
const CELL := 8
const BODY := Vector2(20, 12)


func _ready() -> void:
	var links := _links()
	Travelers.forget()
	Travelers._walks = {"links": links}
	# What to measure in each area: where each plan's stops are (a spot, or
	# a stand off one: see Travelers.point_of) and the walks it takes there.
	var wanted := {}
	for id: String in Travelers.PLANS:
		var stops: Array = Travelers.PLANS[id].stops
		for i in stops.size():
			var here: Dictionary = wanted.get_or_add(stops[i].region, {"spots": {}, "walks": {}})
			here.spots[Travelers.point_of(id, stops[i])] = [stops[i].spot, stops[i].get("offset", [0, 0])]
			if i == 0:
				continue
			for walk: Dictionary in Travelers.walk_segments(id, stops[i - 1], stops[i]):
				var there: Dictionary = wanted.get_or_add(walk.region, {"spots": {}, "walks": {}})
				there.walks[[walk.a, walk.b]] = true
	var spots := {}
	var routes := {}
	var regions: Array = wanted.keys()
	regions.sort()
	for id: String in regions:
		var region: Region = (load(REGION_DIR + id + ".tscn") as PackedScene).instantiate()
		add_child(region)
		StoryContent.attach(region)
		# the walk grid reads the physics space, which sees the map's bodies
		# only after a physics frame
		await get_tree().physics_frame
		await get_tree().physics_frame
		var grid := WalkGrid.finer(region, CELL, BODY)
		var points := {}
		for point: String in wanted[id].spots:
			var spot: Array = wanted[id].spots[point]
			var marker := region.get_spawn(spot[0])
			if marker == null:
				push_error("%s: no spot named %s" % [id, spot[0]])
				continue
			var at := grid.nearest_open(region.to_local(marker.global_position) + Vector2(spot[1][0], spot[1][1]))
			points[point] = at
			spots.get_or_add(id, {})[point] = [roundi(at.x), roundi(at.y)]
		for pair: Array in wanted[id].walks:
			var a: Vector2 = points.get(pair[0], _point(region, grid, pair[0]))
			var b: Vector2 = points.get(pair[1], _point(region, grid, pair[1]))
			if a == Vector2.INF or b == Vector2.INF:
				push_error("%s: can't find %s or %s" % [id, pair[0], pair[1]])
				continue
			var way := grid.route(a, b)
			if way.is_empty():
				push_error("%s: no way from %s to %s" % [id, pair[0], pair[1]])
				continue
			way.insert(0, a)
			var flat := []
			for p in way:
				flat.append_array([roundi(p.x), roundi(p.y)])
			routes.get_or_add(id, {})["%s|%s" % pair] = flat
			print("%-20s %-24s -> %-24s %5d px" % [id, pair[0], pair[1], roundi(Travelers.length_of(way))])
		remove_child(region)
		region.free()
	var walks := {"links": links, "spots": spots, "routes": routes}
	var file := FileAccess.open(Travelers.WALKS_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(walks, "\t", true) + "\n")
	file.close()
	Travelers.forget()
	_print_days()
	get_tree().quit()


## Every walking exit from an outdoor area into another, by area and then
## the area it leads to: [exit name, spawn name there].
func _links() -> Dictionary:
	var outdoor := {}
	var exits := {}
	for file in DirAccess.get_files_at(REGION_DIR):
		if not file.ends_with(".tscn"):
			continue
		var region: Region = (load(REGION_DIR + file) as PackedScene).instantiate()
		if not region.indoors:
			outdoor[region.region_id] = true
			for node in region.find_children("*", "RegionExit", true, false):
				var exit := node as RegionExit
				if exit.target_region != "" and exit.minutes == 0 and exit.open_hour == 0 and exit.close_hour == 24:
					exits.get_or_add(region.region_id, {})[exit.target_region] = [String(exit.name), exit.target_spawn]
		region.free()
	var links := {}
	for id: String in exits:
		for to: String in exits[id]:
			if outdoor.has(to):
				links.get_or_add(id, {})[to] = exits[id][to]
	return links


## Where [param point] (a spot, or "exit:<name>") is in [param region], on
## open ground; INF if there's no such thing.
func _point(region: Region, grid: WalkGrid, point: String) -> Vector2:
	var node: Node2D = null
	if point.begins_with("exit:"):
		node = region.find_child(point.trim_prefix("exit:"), true, false) as Node2D
	else:
		node = region.get_spawn(point)
	if node == null:
		return Vector2.INF
	return grid.nearest_open(region.to_local(node.global_position))


func _print_days() -> void:
	for id: String in Travelers.PLANS:
		for wet in [false, true]:
			print("\n%s (%s summer day)" % [id, "wet" if wet else "dry"])
			for segment: Dictionary in Travelers.day_of(id, GameClock.Season.SUMMER, wet):
				var what: String = segment.point if segment.kind == "stop" else "%s -> %s" % [segment.a, segment.b]
				print("  %s-%s  %-18s %s" % [_time(segment.from), _time(segment.to), segment.region, what])


static func _time(minutes: float) -> String:
	return "%d:%02d" % [int(minutes) / 60, int(minutes) % 60]
