extends Node
## Repaints the ground pictures of the hand-made Valley hubs from the terrain
## tiles in their scenes, without rebuilding the scenes (a rebuild rewrites
## every node id). Use it after changing tools/hubs/ahwahnee_ground.gd.
##   godot --headless --path . res://tools/hubs/repaint_ground.tscn -- [hub ids]
## Hubs: yosemite_village, curry_village, lamon_homestead, ahwahnee_trail.
## The hotel grounds are skipped: they carry the gravel drive and flower-bed
## shapes that only build_ahwahnee.gd knows. Run
## `godot --headless --path . --import` afterwards.

const Ground = preload("res://tools/hubs/ahwahnee_ground.gd")
const Terrain = preload("res://tools/mapgen/terrain.gd")
## [picture, seed, optional tile rect painted as mown lawn]. Curry Village's
## green is meadow in the terrain grid (it drives foraging) but lawn in the
## picture, as in build_curry_village.gd.
const HUBS := {
	"yosemite_village": ["ground_yosemite_village", 1851],
	"curry_village": ["ground_curry_village", 1899, Rect2i(26, 28, 53, 23)],
	"lamon_homestead": ["ground_homestead", 1861],
	"ahwahnee_trail": ["ground_trail", 1927],
}


func _ready() -> void:
	var wanted := Array(OS.get_cmdline_user_args())
	for hub_id: String in HUBS:
		if not wanted.is_empty() and hub_id not in wanted:
			continue
		var started := Time.get_ticks_msec()
		_repaint(hub_id, HUBS[hub_id][0], HUBS[hub_id][1], HUBS[hub_id][2] if HUBS[hub_id].size() > 2 else Rect2i())
		print("%s repainted (%.1f s)" % [hub_id, (Time.get_ticks_msec() - started) / 1000.0])
	get_tree().quit()


func _repaint(hub_id: String, file_name: String, seed_value: int, lawn: Rect2i) -> void:
	var region: Node = (load("res://scenes/regions/%s.tscn" % hub_id) as PackedScene).instantiate()
	var layer := region.get_node("Ground") as TileMapLayer
	var used := layer.get_used_rect()
	var w := used.end.x
	var h := used.end.y
	var kind := PackedInt32Array()
	kind.resize(w * h)
	for y in h:
		for x in w:
			var cell := Vector2i(x, y)
			kind[y * w + x] = layer.get_cell_atlas_coords(cell).y if layer.get_cell_source_id(cell) >= 0 else 0
	for y in range(lawn.position.y, lawn.end.y):
		for x in range(lawn.position.x, lawn.end.x):
			if kind[y * w + x] == Terrain.MEADOW:
				kind[y * w + x] = Terrain.LAWN
	var painter := Ground.new()
	var im := painter.paint(kind, w, h, seed_value)
	im.save_png(ProjectSettings.globalize_path("res://assets/sprites/ahwahnee/%s.png" % file_name))
	region.free()
