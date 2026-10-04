class_name RegionExit
extends Area2D
## Walking into this area leaves the region. Depending on what's set, it
## goes to another region, opens the park map to travel (roads leaving a
## hub), or just shows a message (roads leaving the park).

@export var label := ""
@export var target_region := ""
@export var target_spawn := ""
## Hub to preselect on the travel map.
@export var travel_to := ""
@export_multiline var message := ""
## Shop hours: the doorway only opens from [member open_hour] up to (not
## including) [member close_hour], in 24-hour time. The defaults never close.
@export_range(0, 24) var open_hour := 0
@export_range(0, 24) var close_hour := 24


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2 # player
	monitorable = false
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if body is Player:
		get_tree().call_group("world", "use_exit", self)


func is_open_now() -> bool:
	var hour := GameClock.hour
	return hour >= open_hour and hour < close_hour


## "Camp Curry Store is closed. It's open from 7 AM to 9 PM."
func closed_message() -> String:
	return "%s is closed. It's open from %s to %s." % [label, _clock_text(open_hour), _clock_text(close_hour)]


static func _clock_text(hour: int) -> String:
	var h12 := hour % 12
	return "%d %s" % [12 if h12 == 0 else h12, "PM" if hour % 24 >= 12 else "AM"]
