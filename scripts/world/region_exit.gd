class_name RegionExit
extends Area2D
## Walking into this area leaves the region. Depending on what's set, it
## goes to another region, drives straight on to another hub, opens the park
## map to travel (roads leaving a hub), or just shows a message (roads
## leaving the park).

@export var label := ""
@export var target_region := ""
@export var target_spawn := ""
## Hub to preselect on the travel map.
@export var travel_to := ""
## Hub the road drives straight on to, without the map (as from a fork in the
## road, where the way you turn is the choice). The drive's closures and
## locks still hold.
@export var drive_to := ""
## A stop partway along a [member drive_to] road (Tenaya Lake, on the Tioga
## Road from Crane Flat to Tuolumne): the drive's closures and locks hold as
## on the map, but it ends in this region, at [member stop_spawn], after
## [member minutes].
@export var stop_region := ""
@export var stop_spawn := ""
## A road some way to the next place: the minutes and miles of the drive.
## For [member drive_to] they are what is left of it from here; for
## [member target_region] the clock moves on by them.
@export var minutes := 0
@export var miles := 0.0
@export_multiline var message := ""
## Shop hours: the doorway only opens from [member open_hour] up to (not
## including) [member close_hour], in 24-hour time. The defaults never close.
@export_range(0, 24) var open_hour := 0
@export_range(0, 24) var close_hour := 24


## A player physics reported in here who wasn't really (see touches).
var _waiting: Node2D = null


func _ready() -> void:
	set_physics_process(false)
	collision_layer = 0
	collision_mask = 2 # player
	monitorable = false
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if body is Player:
		get_tree().call_group("world", "use_exit", self)


## Physics said [param body] came in, but it isn't really here (see
## touches): watch, and go once they really walk in.
func watch(body: Node2D) -> void:
	_waiting = body
	set_physics_process(true)


func _physics_process(_delta: float) -> void:
	if not is_instance_valid(_waiting) or not overlaps_body(_waiting):
		_waiting = null
		set_physics_process(false)
	elif touches(_waiting):
		_waiting = null
		set_physics_process(false)
		get_tree().call_group("world", "use_exit", self)


## Is [param player]'s body really in this exit now? Just after the player
## arrives somewhere, physics can still report them overlapping where they
## stood in the last place (an exit at that same spot, like the rooms' doors,
## which all sit at the bottom middle), and the exit would fire at once (see
## World.use_exit).
func touches(player: Node2D) -> bool:
	var body := player.get_node_or_null("Collision") as CollisionShape2D
	if body == null or body.shape == null:
		return true
	for node in get_children():
		var shape := node as CollisionShape2D
		if shape and shape.shape and not shape.disabled \
				and shape.shape.collide(shape.global_transform, body.shape, body.global_transform):
			return true
	return false


func is_open_now() -> bool:
	var hour := GameClock.hour
	return hour >= open_hour and hour < close_hour


## "Camp Curry Store is closed. It's open from 7 AM to 9 PM."
func closed_message() -> String:
	return "%s is closed. It's open from %s to %s." % [label, _clock_text(open_hour), _clock_text(close_hour)]


static func _clock_text(hour: int) -> String:
	var h12 := hour % 12
	return "%d %s" % [12 if h12 == 0 else h12, "PM" if hour % 24 >= 12 else "AM"]
