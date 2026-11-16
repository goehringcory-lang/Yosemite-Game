extends Node
## Redraws only Tuolumne's buildings-and-props art (tuolumne_art.gd
## save_dressing: the store and lodge halls and the props round them), not
## the region scene or its ground, so it can't disturb anything else:
##
##   tools/hubs/rebuild_tuolumne_dressing.sh

const TuolumneArt = preload("res://tools/hubs/tuolumne_art.gd")


func _ready() -> void:
	TuolumneArt.new().save_dressing()
	get_tree().quit()
