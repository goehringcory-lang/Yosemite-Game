class_name LandmarkFraming
extends Node
## Looks up at the landmarks. The camera follows the player with them in the
## middle of the screen, which on a 540-pixel screen cuts El Capitan, the
## Three Brothers or Yosemite Falls off at the knees: the wall paintings are
## taller than half a screen. So when the player walks toward the foot of a
## region's cliff wall, or into a [LandmarkView], the camera tilts slowly up
## (through [member Camera2D.offset], which nothing else uses) until the top
## of the screen reaches the rim, keeping the player at least [constant MARGIN]
## pixels above the bottom of the screen. Walk away and it eases back.
##
## The wall rule: a region's cliff wall is a Sprite2D child named "...Wall"
## drawn from the region's top-left corner (El Capitan Meadow's ElCapitanWall,
## Leidig Meadow's ThreeBrothersWall...). Within [constant WALL_FULL] pixels of
## its foot the tilt is full, fading out over the next [constant WALL_FADE].
##
## Added to the World by world.gd.

## The least the player stands above the bottom of the screen, in pixels.
const MARGIN := 84.0
## How quickly the tilt follows (per second): slow, like lifting your head.
const SPEED := 1.8
## Below a cliff wall's foot: full tilt within this many pixels...
const WALL_FULL := 220.0
## ...fading to none over this many more.
const WALL_FADE := 260.0
## A move of more than this many pixels in one frame is a jump (a spawn, a
## door), which frames the view at once instead of easing.
const JUMP := 48.0

## The camera's current tilt, in pixels (0 or less).
var tilt := 0.0
## Added to the camera's offset on top of the tilt: the camera's lag carried
## over a seam between regions, which World eases back to zero.
var carry := Vector2.ZERO

var _region: Node = null
var _walls: Array[float] = []
var _last_at := Vector2.INF


func _ready() -> void:
	name = "LandmarkFraming"
	process_priority = 10 # after SmoothMotion has placed the camera


func _process(delta: float) -> void:
	var world := get_parent()
	var player: Node2D = world.get("player")
	var region: Node = world.get("region")
	if player == null or not is_instance_valid(region):
		return
	var camera := player.get_node_or_null("Camera") as Camera2D
	if camera == null:
		return
	var at := player.global_position
	var arrived := region != _region
	if arrived:
		_region = region
		_walls = _wall_feet(region)
	var target := target_tilt(camera, at)
	# Arriving somewhere (a new region, a spawn, a door) frames the view at
	# once, as the camera itself does; only walking eases the tilt.
	if arrived or _last_at.distance_to(at) > JUMP:
		tilt = target
	_last_at = at
	tilt = lerpf(tilt, target, 1.0 - exp(-SPEED * delta))
	if absf(tilt - target) < 0.25:
		tilt = target
	camera.offset = Vector2(carry.x, roundf(tilt) + carry.y)


## The player walked over a seam into [param region] and everything shifted
## by [param by] (see World._cross_seam): not an arrival, so the tilt keeps
## easing from where it was instead of jumping.
func crossed(region: Node, by: Vector2) -> void:
	_region = region
	_walls = _wall_feet(region)
	if _last_at != Vector2.INF:
		_last_at += by


## The tilt the camera is easing toward with the player at [param at].
func target_tilt(camera: Camera2D, at: Vector2) -> float:
	var look := view_at(at)
	if look.weight <= 0.0:
		return 0.0
	var height := camera.get_viewport_rect().size.y / camera.zoom.y
	# Where the camera's top would be with no tilt, from the player and the
	# camera's limits (not the smoothed camera, so it is the same every frame
	# the player stands still, however fast the frames come).
	var natural_top := clampf(at.y - height / 2.0, camera.limit_top, camera.limit_bottom - height)
	var margin: float = look.margin if look.margin >= 0.0 else MARGIN
	var want_top := maxf(look.top, at.y - (height - margin))
	return minf(0.0, want_top - natural_top) * look.weight


## The view at [param at]: {top, weight, margin, landmark}, the strongest of the wall rule and
## the region's [LandmarkView]s.
func view_at(at: Vector2) -> Dictionary:
	var best := {"top": 0.0, "weight": 0.0, "margin": -1.0, "landmark": ""}
	for foot in _walls:
		var below := at.y - foot
		var w := 1.0 - clampf((below - WALL_FULL) / WALL_FADE, 0.0, 1.0)
		if w > best.weight:
			best = {"top": 0.0, "weight": w, "margin": -1.0, "landmark": ""}
	for view in get_tree().get_nodes_in_group("landmark_views"):
		if not (view is LandmarkView) or not is_instance_valid(_region) or not _region.is_ancestor_of(view):
			continue
		# A view placed by hand wins over the wall rule where both hold fully.
		var w: float = view.weight_at(at)
		if w > 0.0 and w >= best.weight:
			best = {"top": view.top, "weight": w, "margin": view.margin, "landmark": view.landmark}
	return best


## The feet (bottom edges, in region pixels) of the cliff walls painted
## across the top of [param region].
static func _wall_feet(region: Node) -> Array[float]:
	var feet: Array[float] = []
	for child in region.get_children():
		var sprite := child as Sprite2D
		if sprite == null or sprite.texture == null or sprite.centered:
			continue
		if not String(sprite.name).ends_with("Wall") or sprite.position.y > 0.5:
			continue
		feet.append(sprite.position.y + sprite.texture.get_height() * sprite.scale.y)
	return feet
