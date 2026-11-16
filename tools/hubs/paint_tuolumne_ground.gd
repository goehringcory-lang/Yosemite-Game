extends "res://tools/hubs/build_tuolumne.gd"
## Paints Tuolumne Meadows' ground again and nothing else: the region scene,
## the domes, the buildings and the trees are left as they are. Run
## tools/hubs/repaint_tuolumne_ground.sh, which runs this:
##
##   godot --headless --path . res://tools/hubs/paint_tuolumne_ground.tscn
##
## and then moves the picture onto the game's 32px grid. The layout is the
## same _layout() the full rebuild (rebuild_tuolumne.sh) uses, so the ground
## still lines up with what stands on it.


func _ready() -> void:
	_layout()
	var painter = TuolumneGround.new()
	painter.smooth_granite = true
	var im: Image = painter.paint(kind, w, h, 1889)
	im.save_png(ProjectSettings.globalize_path(S + "ground_tuolumne_meadows.png"))
	print("Painted ", S, "ground_tuolumne_meadows.png")
	get_tree().quit()
