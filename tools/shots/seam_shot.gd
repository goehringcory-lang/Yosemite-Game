extends Node
## Renders the seams between neighbouring outdoor regions: region A with
## region B laid beside it so A's exit lines up with B's spawn.
## Env: SHOT_DIR. Needs a window.

const PAIRS := [
	["yosemite_village", "NorthsideWest"], ["yosemite_village", "SouthsideWest"],
	["yosemite_village", "NorthsideEast"], ["yosemite_village", "SouthsideEast"],
	["leidig_meadow", "ToElCapitan"], ["el_capitan_meadow", "NorthsideDriveWest"],
	["el_capitan_meadow", "ToElCapBridge"], ["bridalveil_fall", "ToTunnelView"],
	["bridalveil_fall", "ToFourMile"], ["housekeeping_camp", "ToCurry"],
	["curry_village", "EastRoad"], ["curry_village", "HomesteadGate"],
	["upper_pines", "ToHappyIsles"], ["happy_isles", "ToTenayaCreek"],
	["tenaya_creek", "ToMirrorLake"], ["mirror_lake", "ToCrowsCamp"],
	["ahwahnee_meadow", "ToAhwahnee"], ["the_ahwahnee", "ToStonemanBridge"],
	["ahwahnee_trail", "ToHomestead"],
]


func _ready() -> void:
	var dir := OS.get_environment("SHOT_DIR") if OS.get_environment("SHOT_DIR") != "" else "user://"
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280, 720)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport)
	var camera := Camera2D.new()
	viewport.add_child(camera)
	for pair in PAIRS:
		var a: Region = load("res://scenes/regions/%s.tscn" % pair[0]).instantiate()
		var exit: RegionExit = a.find_child(pair[1], true, false)
		var b: Region = load("res://scenes/regions/%s.tscn" % exit.target_region).instantiate()
		viewport.add_child(b)
		viewport.add_child(a)
		var spawn := b.get_spawn(exit.target_spawn)
		var edge := _edge_point(a, exit.global_position)
		var b_edge := _edge_point(b, spawn.global_position)
		b.position = edge - b_edge
		camera.position = edge
		for i in 6:
			await get_tree().process_frame
		viewport.get_texture().get_image().save_png("%s/%s_%s.png" % [dir, pair[0], pair[1]])
		a.free()
		b.free()
	get_tree().quit()


## The point on the region's border nearest [param p].
static func _edge_point(r: Region, p: Vector2) -> Vector2:
	var bounds := r.get_bounds()
	var d := [p.x - bounds.position.x, bounds.end.x - p.x, p.y - bounds.position.y, bounds.end.y - p.y]
	var i: int = d.find(d.min())
	match i:
		0: return Vector2(bounds.position.x, p.y)
		1: return Vector2(bounds.end.x, p.y)
		2: return Vector2(p.x, bounds.position.y)
	return Vector2(p.x, bounds.end.y)
