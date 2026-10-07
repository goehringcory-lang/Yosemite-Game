extends SceneTree
## Draws the fall, winter and spring looks of the Valley's black oaks,
## dogwoods, meadow plants and conifers into assets/sprites/ahwahnee/seasons/.
##   godot --headless --path . -s res://tools/hubs/build_seasonal_art.gd
const SeasonalArt = preload("res://tools/hubs/seasonal_art.gd")


func _init() -> void:
	SeasonalArt.new().save_all()
	quit()
