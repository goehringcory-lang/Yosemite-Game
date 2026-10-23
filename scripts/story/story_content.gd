class_name StoryContent
extends RefCounted
## Story overlays: the people, climbs, and cooking spots placed in a region.
##
## Each region can have an overlay at res://scenes/story/content/<region_id>.tscn.
## Its children are moved into the region's Entities node on first visit, so
## they y-sort with the player. Keeping them out of scenes/regions/ means
## tools/mapgen can regenerate a hub without touching the story.

const DIR := "res://scenes/story/content/%s.tscn"
const DOORS_DIR := "res://scenes/story/doors/%s.tscn"


static func path_for(region_id: String) -> String:
	return DIR % region_id


## Adds the overlay for [param region], if there is one. Safe to call again:
## it only adds the overlay once.
static func attach(region: Region) -> void:
	if region.has_meta("story_attached"):
		return
	region.set_meta("story_attached", true)
	EasterEggs.dress(region)
	for path in [path_for(region.region_id), doors_path_for(region.region_id)]:
		if not ResourceLoader.exists(path):
			continue
		var overlay: Node = load(path).instantiate()
		for child in overlay.get_children():
			overlay.remove_child(child)
			child.owner = null
			region.entities.add_child(child)
		overlay.free()


## The doors into a region's buildings, and the spots outside them, written by
## tools/hubs/build_interiors.gd.
static func doors_path_for(region_id: String) -> String:
	return DOORS_DIR % region_id
