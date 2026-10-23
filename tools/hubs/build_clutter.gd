extends SceneTree
## Draws the town clutter (tools/hubs/town_clutter_art.gd) at the 16px scale.
## Use tools/hubs/rebuild_clutter.sh, which also upgrades it to the 32px art.

const TownClutterArt = preload("res://tools/hubs/town_clutter_art.gd")


func _init() -> void:
	TownClutterArt.new().save_all()
	print("clutter drawn")
	quit()
