extends Node
## Writes every seam between two outdoor areas (see Seam) as the game lays
## it out, nudged and overlapped, to a JSON file, for the tools that work on
## the maps' edges (tools/seams/morph_seams.py).
## Run: godot --headless --path . res://tools/seams/export_seams.tscn -- OUT.json


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var out: String = args[0] if args.size() > 0 else "user://seams.json"
	var regions := {}
	for file in DirAccess.get_files_at("res://scenes/regions/"):
		if file.ends_with(".tscn"):
			var region: Region = (load("res://scenes/regions/" + file) as PackedScene).instantiate()
			if region.indoors:
				region.free()
			else:
				regions[region.region_id] = region
	var seams := []
	for id in regions:
		var region: Region = regions[id]
		for exit in Seam.candidates(region):
			if not regions.has(exit.target_region):
				continue
			var seam := Seam.make(region, exit, regions[exit.target_region])
			if seam == null:
				continue
			var b := region.get_bounds()
			var nb := seam.neighbor_bounds()
			seams.append({
				"region": id, "exit": String(exit.name), "neighbor": exit.target_region,
				"side": [seam.side.x, seam.side.y], "point": [seam.point.x, seam.point.y],
				"offset": [seam.offset.x, seam.offset.y],
				"bounds": [b.position.x, b.position.y, b.size.x, b.size.y],
				"neighbor_bounds": [nb.position.x, nb.position.y, nb.size.x, nb.size.y],
			})
	var f := FileAccess.open(out, FileAccess.WRITE)
	f.store_string(JSON.stringify(seams, "\t"))
	f.close()
	print("wrote %d seams to %s" % [seams.size(), out])
	for region: Region in regions.values():
		region.free()
	get_tree().quit()
