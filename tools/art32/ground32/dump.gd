extends Node
## Writes what the native 32px ground painter (paint.py, beside this script)
## needs to know about each hand-made outdoor area to a JSON file per area:
## the terrain grid from its Ground tile layer, the ground picture it shows,
## and every sprite standing on it (for the contact shadows painted under
## trees, buildings, rocks and cars).
##   godot --headless --path . res://tools/art32/ground32/dump.tscn -- OUT_DIR [region ids]


func _ready() -> void:
	var args := Array(OS.get_cmdline_user_args())
	var out_dir: String = args.pop_front() if not args.is_empty() else ProjectSettings.globalize_path("user://ground32")
	DirAccess.make_dir_recursive_absolute(out_dir)
	var dir := DirAccess.open("res://scenes/regions")
	for file in dir.get_files():
		if not file.ends_with(".tscn"):
			continue
		var id := file.get_basename()
		if not args.is_empty() and id not in args:
			continue
		var scene: PackedScene = load("res://scenes/regions/" + file)
		var region := scene.instantiate()
		var art := region.get_node_or_null("GroundArt") as Sprite2D
		var layer := region.get_node_or_null("Ground") as TileMapLayer
		if art == null or layer == null:
			region.free()
			continue
		var used := layer.get_used_rect()
		var w := used.end.x
		var h := used.end.y
		var kinds := []
		for y in h:
			for x in w:
				var cell := Vector2i(x, y)
				kinds.append(layer.get_cell_atlas_coords(cell).y if layer.get_cell_source_id(cell) >= 0 else 0)
		var sprites := []
		_collect(region, region, sprites)
		# the animated waterfalls hanging on the cliff walls (walls32 lines the
		# real falls up under them)
		var anims := []
		for a in region.find_children("*", "AnimatedSprite2D", true, false):
			var sp := a as AnimatedSprite2D
			var tex: Texture2D = sp.sprite_frames.get_frame_texture(sp.animation, 0) if sp.sprite_frames else null
			var ap := _pos(sp, region)
			anims.append({
				"name": String(sp.name),
				"tex": tex.resource_path if tex else "",
				"x": ap.x,
				"y": ap.y,
				"centered": sp.centered,
				"w": tex.get_width() if tex else 0,
				"h": tex.get_height() if tex else 0,
				"z": sp.z_index,
			})
		var markers := {}
		for m in region.find_children("*", "Marker2D", true, false):
			var p := _pos(m, region)
			markers[String(m.name)] = [p.x, p.y]
		var data := {
			"id": id,
			"w": w,
			"h": h,
			"tile": layer.tile_set.tile_size.x,
			"ground": art.texture.resource_path,
			"kinds": kinds,
			"sprites": sprites,
			"anims": anims,
			"markers": markers,
		}
		var f := FileAccess.open(out_dir.path_join(id + ".json"), FileAccess.WRITE)
		f.store_string(JSON.stringify(data))
		f.close()
		print("dumped ", id, " ", w, "x", h, " ", sprites.size(), " sprites")
		region.free()
	get_tree().quit()


func _collect(node: Node, root: Node, out: Array) -> void:
	for child in node.get_children():
		if child is Sprite2D and child.name != "GroundArt" and child.texture != null and child.texture.resource_path != "":
			var s := child as Sprite2D
			var pos := _pos(s, root)
			out.append({
				"name": String(s.name),
				"parent": String(s.get_parent().name),
				"tex": s.texture.resource_path,
				"x": pos.x,
				"y": pos.y,
				"ox": s.offset.x,
				"oy": s.offset.y,
				"centered": s.centered,
				"flip": s.flip_h,
				"sx": s.scale.x,
				"sy": s.scale.y,
				"hf": s.hframes,
				"vf": s.vframes,
				"region": [s.region_rect.position.x, s.region_rect.position.y, s.region_rect.size.x, s.region_rect.size.y] if s.region_enabled else [],
				"z": s.z_index,
				"visible": s.visible,
				"material": s.material != null,
			})
		_collect(child, root, out)


## The position in the region's own space (the scene isn't in a tree, so
## global_position isn't available).
func _pos(n: Node2D, root: Node) -> Vector2:
	var t := Transform2D()
	var cur: Node = n
	while cur != root and cur != null:
		if cur is Node2D:
			t = (cur as Node2D).transform * t
		cur = cur.get_parent()
	return t.origin
