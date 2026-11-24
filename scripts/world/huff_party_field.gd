class_name HuffPartyField
extends Node
## Manages the HUFF crew's secret late-night forest party in the current
## region (World adds one beside HappeningField). Whenever the clock passes
## 10 PM and the player is in tonight's random heavy-forest / boulder region,
## it spawns HuffPartySite in a random reachable off-trail clearing and fades
## it in; when morning comes or the player leaves, it cleans up cleanly.

const CHECK_EVERY := 0.5
const FADE_IN := 0.6

var site: HuffPartySite
var _region: Region
var _site_key := ""
var _check := 0.0
var _placing := false
## A party left behind over a seam stays until out of view.
var _behind: Array[Node2D] = []
var _crossed := false


func _ready() -> void:
	var world := _world()
	if world and world.has_signal("seam_crossed"):
		world.seam_crossed.connect(func(_shift: Vector2) -> void: _crossed = true)


func _world() -> Node:
	return get_parent()


func _process(delta: float) -> void:
	var world := _world()
	var region: Region = world.region if world and "region" in world else null
	if region != _region:
		_region = region
		if _crossed:
			_leave_behind()
		else:
			_clear()
		_crossed = false
		refresh()
		return
	_crossed = false
	_retire_behind()
	_check -= delta
	if _check <= 0.0:
		_check = CHECK_EVERY
		refresh()


## Spawns or removes the HUFF forest party to match the current region and hour.
func refresh() -> void:
	if _region == null or not is_instance_valid(_region) or not _region.is_inside_tree() or _region.indoors:
		_clear_site()
		return
	var target_region := HuffParty.where_now()
	var want_key := "%s:%s" % [HuffParty.today_key(), _region.region_id]
	if target_region != _region.region_id:
		_clear_site()
		return
	if is_instance_valid(site) and _site_key == want_key:
		return
	_clear_site()
	if not _placing:
		_place_async(_region, want_key)


func _place_async(region: Region, key: String) -> void:
	_placing = true
	# WalkGrid queries the physics space, which needs a physics frame after entry.
	await get_tree().physics_frame
	_placing = false
	if region != _region or not is_instance_valid(region) or not region.is_inside_tree():
		return
	if HuffParty.where_now() != region.region_id:
		return
	if is_instance_valid(site) and _site_key == key:
		return
	var spot := HuffParty.pick_spot(region, key)
	if spot == Vector2.INF:
		return
	var made := HuffPartySite.new()
	region.entities.add_child(made)
	made.setup(region, spot)
	made.modulate.a = 0.0
	made.create_tween().tween_property(made, "modulate:a", 1.0, FADE_IN)
	site = made
	_site_key = key


func _clear_site() -> void:
	_site_key = ""
	if is_instance_valid(site):
		site.queue_free()
	site = null


func _clear() -> void:
	_clear_site()
	for node in _behind:
		if is_instance_valid(node):
			node.queue_free()
	_behind.clear()


func _leave_behind() -> void:
	if is_instance_valid(site):
		_behind.append(site)
	site = null
	_site_key = ""


func _retire_behind() -> void:
	if _behind.is_empty():
		return
	var view := get_viewport().get_visible_rect()
	var camera := get_viewport().get_camera_2d()
	if camera:
		var size := view.size / camera.zoom
		view = Rect2(camera.get_screen_center_position() - size / 2.0, size).grow(96.0)
	for i in range(_behind.size() - 1, -1, -1):
		var node := _behind[i]
		if not is_instance_valid(node):
			_behind.remove_at(i)
		elif not node.is_inside_tree() or not view.has_point(node.global_position):
			node.queue_free()
			_behind.remove_at(i)
