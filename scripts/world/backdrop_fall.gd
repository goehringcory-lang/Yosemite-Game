class_name BackdropFall
extends AnimatedSprite2D
## A waterfall drawn on a backdrop a story overlay hangs above the map (Upper
## Yosemite Fall, over the Village). The overlay is added after the region's
## SeasonalFalls has gathered the region's own falls, so this hands itself to
## it, to run full in spring and dry up with the others.


func _ready() -> void:
	play()
	var region := get_parent()
	while region != null and not (region is Region):
		region = region.get_parent()
	if region == null:
		return
	for child in region.get_children():
		if child is SeasonalFalls:
			(child as SeasonalFalls).add_fall(self)
			return
