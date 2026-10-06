extends RefCounted
## Gives a generated hub map the Ahwahnee ground: the tile ground is read for
## its terrain types and hillshade, painted once as a detailed picture
## (tools/hubs/ahwahnee_ground.gd), and shown as a GroundArt sprite over it.
## The tile layer stays underneath, hidden, for collision and foraging.
##
## Run through tools/mapgen/upgrade_hubs.tscn (see there), or call apply()
## after a hub's map scene has been regenerated.

const Terrain = preload("res://tools/mapgen/terrain.gd")
const Ground = preload("res://tools/hubs/ahwahnee_ground.gd")
const T := 16
const OUT_DIR := "res://assets/map/ground/"
## Brightness of each hillshade alternative tile (see Terrain.SHADE_MODULATE).
const SHADE_LIGHT := [1.0, 1.1, 0.84, 0.68]


static func apply(hub_id: String, attach_only := false, seed_value := 0) -> bool:
	var map_path := "res://scenes/regions/generated/%s_map.tscn" % hub_id
	var packed: PackedScene = load(map_path)
	if packed == null:
		push_error("no map scene at " + map_path)
		return false
	var map: Node = packed.instantiate(PackedScene.GEN_EDIT_STATE_MAIN)
	if attach_only:
		var stale := map.get_node_or_null("GroundArt")
		if stale != null:
			map.remove_child(stale)
			stale.free()
		return _finish(map, hub_id, map_path)
	var ground := map.get_node("Ground") as TileMapLayer
	var size: Vector2i = map.get("size_in_tiles")
	var w := size.x
	var h := size.y
	var kind := PackedInt32Array()
	var tint := PackedFloat32Array()
	var drawn := PackedByteArray()
	kind.resize(w * h)
	tint.resize(w * h)
	drawn.resize(w * h)
	for y in h:
		for x in w:
			var cell := Vector2i(x, y)
			var k := y * w + x
			if ground.get_cell_source_id(cell) < 0:
				kind[k] = Terrain.FOREST
				tint[k] = 1.0
				continue
			drawn[k] = 1
			kind[k] = ground.get_cell_atlas_coords(cell).y
			tint[k] = SHADE_LIGHT[clampi(ground.get_cell_alternative_tile(cell), 0, 3)]
	var painter := Ground.new()
	painter.tint = tint
	painter.road_shoulders = true
	var im := painter.paint(kind, w, h, seed_value if seed_value != 0 else hub_id.hash() & 0xffff)
	# Where the map has no ground tile (the hazy view below a rim) the picture
	# stays clear so the Below layer shows through.
	for y in h:
		for x in w:
			if drawn[y * w + x] == 0:
				im.fill_rect(Rect2i(x * T, y * T, T, T), Color(0, 0, 0, 0))
	var out := ProjectSettings.globalize_path(OUT_DIR + hub_id + "_ground.png")
	DirAccess.make_dir_recursive_absolute(out.get_base_dir())
	im.save_png(out)

	map.free()
	return true


## Needs the PNG imported first (the tool's second pass).
static func _finish(map: Node, hub_id: String, map_path: String) -> bool:
	var tex := load(OUT_DIR + hub_id + "_ground.png") as Texture2D
	if tex == null:
		map.free()
		return false
	var sprite := Sprite2D.new()
	sprite.name = "GroundArt"
	sprite.texture = tex
	sprite.centered = false
	sprite.z_index = -9
	map.add_child(sprite)
	map.move_child(sprite, 2) # after Below and Ground
	sprite.owner = map
	(map.get_node("Ground") as CanvasItem).visible = false
	var packed := PackedScene.new()
	packed.pack(map)
	var err := ResourceSaver.save(packed, map_path)
	map.free()
	return err == OK
