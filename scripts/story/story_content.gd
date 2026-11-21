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
## Hand-placed scenery a region's builder doesn't make (young trees, props,
## lamps), written by tools such as tools/hubs/tuolumne_dressing.py.
const DRESSING_DIR := "res://scenes/story/dressing/%s.tscn"


static func path_for(region_id: String) -> String:
	return DIR % region_id


## Adds the overlay for [param region], if there is one. Safe to call again:
## it only adds the overlay once.
static func attach(region: Region) -> void:
	if region.has_meta("story_attached"):
		return
	region.set_meta("story_attached", true)
	EasterEggs.dress(region)
	# The Guardian's Year's work spots, and what the work leaves behind.
	Stewardship.dress(region)
	# Your camp at the homestead, and what the story has given it.
	Camp.dress(region)
	# Hidden finds off the paths (data/park/finds.json).
	Finds.dress(region)
	# Wren's slackline can be rigged between trees in any outdoor region.
	if not region.indoors:
		region.add_child(TravelSlackline.new())
	for path in overlay_paths(region.region_id):
		var overlay: Node = load(path).instantiate()
		for child in overlay.get_children():
			overlay.remove_child(child)
			child.owner = null
			region.entities.add_child(child)
		overlay.free()


## The scenes laid over region [param region_id] that exist: its story, the
## doors into its buildings, its dressing. (World reads them in the
## background with the region.)
static func overlay_paths(region_id: String) -> Array[String]:
	var paths: Array[String] = []
	for path in [path_for(region_id), doors_path_for(region_id), DRESSING_DIR % region_id]:
		if ResourceLoader.exists(path):
			paths.append(path)
	return paths


## The doors into a region's buildings, and the spots outside them, written by
## tools/hubs/build_interiors.gd.
static func doors_path_for(region_id: String) -> String:
	return DOORS_DIR % region_id
