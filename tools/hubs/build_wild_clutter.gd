extends SceneTree
## Draws the outdoor clutter (tools/hubs/wild_clutter_art.gd) at the 16px
## scale. Use tools/hubs/rebuild_wild_dressing.sh, which also upgrades it to
## the 32px art and lays it out.

const WildClutterArt = preload("res://tools/hubs/wild_clutter_art.gd")


func _init() -> void:
	WildClutterArt.new().save_all()
	print("wild clutter drawn")
	quit()
