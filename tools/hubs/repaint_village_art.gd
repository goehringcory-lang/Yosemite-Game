extends Node
## Redraws the Yosemite Village sprites in assets/sprites/buildings/ (the
## buildings, Indian Village umachas and chuckah, bear boxes, shuttle stop) and
## Curry Village's cabins and buildings
## without rebuilding the scene:
##   godot --headless --path . res://tools/hubs/repaint_village_art.tscn
## then `godot --headless --path . --import`.


func _ready() -> void:
	load("res://tools/hubs/valley_art.gd").new().save_all()
	load("res://tools/hubs/camp4_art.gd").new().save_all()
	load("res://tools/hubs/curry_ahwahnee_art.gd").new().save_all()
	print("village art repainted")
	get_tree().quit()
