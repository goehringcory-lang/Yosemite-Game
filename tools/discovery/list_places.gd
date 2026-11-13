extends Node
## Writes res://data/park/places.json, the list of places to discover
## (Discoveries): every outdoor region, and each Place inside it (with its
## story overlay) that you can walk into (radius > 0).
##
##   godot --headless --path . res://tools/discovery/list_places.tscn
##
## tests/open_world_test.tscn checks the list is up to date.


func _ready() -> void:
	var list := await collect(self)
	var file := FileAccess.open(Discoveries.DATA, FileAccess.WRITE)
	file.store_string(JSON.stringify({
		"_note": "Written by tools/discovery/list_places.tscn. Run it again after adding or renaming a Place.",
		"places": list,
	}, "\t") + "\n")
	file.close()
	print("%d places to discover" % list.size())
	get_tree().quit()


## Every place to discover, in a fixed order (regions by id, then each
## region's own name and its places as they stand in the scene).
static func collect(host: Node) -> Array:
	var ids := PackedStringArray()
	for file in DirAccess.get_files_at("res://scenes/regions/"):
		if file.ends_with(".tscn"):
			ids.append(file.get_basename())
	ids.sort()
	var list: Array = []
	for id in ids:
		var region: Region = (load("res://scenes/regions/%s.tscn" % id) as PackedScene).instantiate()
		if region.indoors:
			region.free()
			continue
		host.add_child(region)
		StoryContent.attach(region)
		await host.get_tree().process_frame
		var seen := {}
		var names := [region.display_name]
		for place in region.get_places():
			if place.radius > 0.0:
				names.append(place.display_name)
		for place_name: String in names:
			if place_name == "" or seen.has(place_name):
				continue
			seen[place_name] = true
			list.append({"key": Discoveries.key_for(id, place_name), "name": place_name, "region": id, "hub": region.hub_id})
		region.free()
	return list
