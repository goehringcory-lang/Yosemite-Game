extends Node
## Fills in where each fast-travel point is (data/park/trailheads.json):
## pos (in its region), spawn (where a trip there lands you) and lonlat (for
## the map). A point at a kiosk ("node") lands you at the spot nearest the
## kiosk; a point with a "spawn" gets its sign put down beside that spot, on
## open ground clear of it.
## Run: godot --headless --path . res://tools/travel/place_trailheads.tscn

const DATA := "res://data/park/trailheads.json"
## Where a sign may go, from its spot: beside it first, then above, below.
const OFFSETS := [Vector2(40, -8), Vector2(-40, -8), Vector2(48, 16), Vector2(-48, 16),
		Vector2(0, -48), Vector2(0, 48), Vector2(64, -32), Vector2(-64, -32), Vector2(72, 24), Vector2(-72, 24)]


func _ready() -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(DATA))
	var problems := 0
	for point: Dictionary in data.points:
		var region: Region = (load("res://scenes/regions/%s.tscn" % point.region) as PackedScene).instantiate()
		add_child(region)
		await get_tree().physics_frame
		await get_tree().physics_frame
		var pos := Vector2.ZERO
		if point.has("node"):
			var kiosk := region.find_child(point.node, true, false) as Node2D
			if kiosk == null:
				push_error("%s: no %s in %s" % [point.id, point.node, point.region])
				problems += 1
				region.free()
				continue
			pos = region.to_local(kiosk.global_position)
			point.spawn = _nearest_spot(region, pos)
			var spot := region.get_spawn(point.spawn)
			var far := pos.distance_to(spot.position) if spot else INF
			if far > 400.0:
				print("NOTE  %s: the nearest spot (%s) is %d px from the kiosk" % [point.id, point.spawn, far])
		else:
			var spot := region.get_spawn(point.spawn)
			if spot == null:
				push_error("%s: no spot %s in %s" % [point.id, point.spawn, point.region])
				problems += 1
				region.free()
				continue
			var grid := WalkGrid.of(region)
			pos = spot.position + OFFSETS[0]
			for offset: Vector2 in OFFSETS:
				var at: Vector2 = spot.position + offset
				if grid.is_open(region.to_global(at)) and grid.is_open(region.to_global(at + Vector2(0, 16))) \
						and grid.is_open(region.to_global(at + Vector2(0, -16))):
					pos = at
					break
			pos = pos.round()
		point.pos = [pos.x, pos.y]
		var lonlat := Wayfinding.lonlat_of(region, pos)
		point.lonlat = [snappedf(lonlat.x, 0.00001), snappedf(lonlat.y, 0.00001)]
		print("%-16s %-24s spawn %-14s pos %s lonlat %s" % [point.id, point.region, point.spawn, pos, lonlat])
		region.free()
	var lines: PackedStringArray = []
	for point: Dictionary in data.points:
		lines.append("\t\t" + JSON.stringify(point))
	var text := "{\n\t\"_about\": %s,\n\t\"points\": [\n%s\n\t]\n}\n" % [JSON.stringify(data._about), ",\n".join(lines)]
	var file := FileAccess.open(DATA, FileAccess.WRITE)
	file.store_string(text)
	file.close()
	print("wrote %s (%d problems)" % [DATA, problems])
	get_tree().quit(problems)


func _nearest_spot(region: Region, pos: Vector2) -> String:
	var best := "arrival"
	var low := INF
	for parent_path in ["Markers", "Map/Spawns", "Spawns"]:
		var parent := region.get_node_or_null(parent_path)
		if parent == null:
			continue
		for node in parent.get_children():
			if node is Marker2D and not node is Place and node.position.distance_to(pos) < low:
				low = node.position.distance_to(pos)
				best = node.name
	return best
