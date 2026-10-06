extends Node
## Redraws the Camp Curry Store and Mountain Shop picture files
## (assets/sprites/curry/interiors/) without rebuilding the scenes:
##   godot --headless --path . res://tools/hubs/repaint_interiors.tscn
## then `godot --headless --path . --import`.

func _ready() -> void:
	load("res://tools/hubs/interior_ahwahnee_art.gd").new().save_all()
	print("interiors repainted")
	get_tree().quit()
