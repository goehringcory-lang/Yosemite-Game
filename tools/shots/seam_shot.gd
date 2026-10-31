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
	# SHOT_RAW=1 lays the maps edge to edge with no nudge, overlap or blend.
	var raw := OS.get_environment("SHOT_RAW") == "1"
	var only := OS.get_environment("SHOT_ONLY")
	for pair in PAIRS:
		if only != "" and not (pair[0] + "_" + pair[1]).contains(only):
			continue
		var a: Region = load("res://scenes/regions/%s.tscn" % pair[0]).instantiate()
		var exit: RegionExit = a.find_child(pair[1], true, false)
		var b: Region = load("res://scenes/regions/%s.tscn" % exit.target_region).instantiate()
		viewport.add_child(b)
		viewport.add_child(a)
		var seam := Seam.make(a, exit, b, not raw)
		if seam == null:
			push_warning("no seam at %s %s" % pair)
			a.free()
			b.free()
			continue
		b.position = seam.offset
		if not raw:
			seam.open(a)
		camera.position = seam.point
		for i in 6:
			await get_tree().process_frame
		viewport.get_texture().get_image().save_png("%s/%s_%s%s.png" % [dir, pair[0], pair[1], "_raw" if raw else ""])
		seam.close()
		a.free()
		b.free()
	get_tree().quit()

