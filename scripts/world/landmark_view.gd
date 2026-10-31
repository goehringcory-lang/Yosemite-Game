class_name LandmarkView
extends Node2D
## A place to stand and look up at a landmark. While the player is inside
## [member area], [LandmarkFraming] tilts the camera up until the top of the
## screen reaches [member top], so the whole of the cliff, dome or fall is in
## view with the player standing low in the frame.
##
## Most Valley areas don't need one: [LandmarkFraming] already looks up at a
## region's cliff wall when the player walks toward its foot. Put one in a
## story overlay where the landmark isn't the region's wall, or to frame a
## view more tightly than the wall rule does.

## Where the player stands to see it, in region pixels.
@export var area := Rect2()
## The highest the top of the screen goes, in region pixels. Negative reaches
## above the map, onto a backdrop hung there.
@export var top := 0.0
## How far in from the edges of [member area] the tilt takes to come in
## fully, in pixels.
@export var feather := 160.0
## The least the player stands above the bottom of the screen here, in
## pixels; below 0 keeps [constant LandmarkFraming.MARGIN].
@export var margin := -1.0
## The landmark's name, for tests.
@export var landmark := ""


func _ready() -> void:
	add_to_group("landmark_views")


## How strongly this view holds at [param at] (region pixels), 0 .. 1.
func weight_at(at: Vector2) -> float:
	var r := Rect2(global_position + area.position, area.size)
	if not r.has_point(at):
		return 0.0
	var inner := minf(minf(at.x - r.position.x, r.end.x - at.x), minf(at.y - r.position.y, r.end.y - at.y))
	return clampf(inner / maxf(feather, 1.0), 0.0, 1.0)
