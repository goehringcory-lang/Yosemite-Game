extends SceneTree
## Redraws just the parked cars (CurryAhwahneeArt.car) to
## assets/sprites/curry/car_*.png, the same twelve in the same paints that
## build_curry_village.gd draws, without rebuilding Curry Village. Then:
##   python3 tools/art32/upgrade.py --fresh assets/sprites/curry/car_*.png
##
##   godot --headless --path . -s res://tools/hubs/draw_cars.gd


func _init() -> void:
	var art = load("res://tools/hubs/curry_ahwahnee_art.gd").new()
	var paints := [Color("2f8fa8"), Color("c8402e"), Color("efe2b8"), Color("3f6a4a"), Color("d8a030"), Color("5a6a8a"), Color("8a3a3a"), Color("b8b0a0")]
	for i in 12:
		var im: Image = art.car(i % 5, paints[(i * 3) % paints.size()])
		im.save_png(ProjectSettings.globalize_path("res://assets/sprites/curry/car_%d.png" % i))
	print("cars drawn")
	quit()
