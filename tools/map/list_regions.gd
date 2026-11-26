extends Node
## Writes res://data/park/regions.json: every region's real-world position
## (longitude/latitude of its middle) and the regions its exits and doors
## lead to, for the world map.
##
##   godot --headless --path . res://tools/map/list_regions.tscn

const DATA := "res://data/park/regions.json"


func _ready() -> void:
	var list := await collect(self)
	var file := FileAccess.open(DATA, FileAccess.WRITE)
	file.store_string(JSON.stringify({
		"_note": "Written by tools/map/list_regions.tscn. Run it again after adding a region or an exit.",
		"regions": list,
	}, "\t") + "\n")
	file.close()
	print("%d regions" % list.size())
	get_tree().quit()


static func collect(host: Node) -> Array:
	var ids := PackedStringArray()
	for file in DirAccess.get_files_at("res://scenes/regions/"):
		if file.ends_with(".tscn"):
			ids.append(file.get_basename())
	ids.sort()
	var list: Array = []
	for id in ids:
		var region: Region = (load("res://scenes/regions/%s.tscn" % id) as PackedScene).instantiate()
		host.add_child(region)
		StoryContent.attach(region)
		await host.get_tree().process_frame
		var lonlat := Wayfinding.lonlat_of(region, region.get_bounds().get_center())
		var points := {}
		for node in region.find_children("*", "RegionExit", true, false):
			var exit := node as RegionExit
			_note(points, exit.target_region, exit, exit.label)
			_note(points, exit.stop_region, exit, exit.label)
		for node in region.find_children("*", "RegionDoor", true, false):
			var door := node as RegionDoor
			_note(points, door.target_region, door, door.label)
		var exits := PackedStringArray(points.keys())
		exits.sort()
		var exit_points := {}
		for target in exits:
			exit_points[target] = points[target]
		list.append({
			"id": id,
			"name": region.display_name,
			"hub": region.hub_id,
			"indoors": region.indoors,
			"lonlat": [snappedf(lonlat.x, 0.00001), snappedf(lonlat.y, 0.00001)],
			"exits": Array(exits),
			"exit_points": exit_points,
		})
		region.free()
	return list


static func _note(points: Dictionary, target: String, node: Node2D, label: String) -> void:
	if target == "" or points.has(target):
		return
	var at := node.global_position
	points[target] = {"at": [roundi(at.x), roundi(at.y)], "label": label}
