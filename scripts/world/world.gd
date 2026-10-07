extends Node2D
## Runs the game. Shows one region at a time (a hub such as Yosemite Valley,
## or a smaller area such as the Lamon Homestead), moves the player between
## them, and handles travel and the sleep / new-day sequence.
##
## Other systems reach World through the "world" group, for example:
##   get_tree().call_group("world", "go_to_region", "glacier_point", "apron_top")

signal region_changed(region: Region)

## Seen the morning after the player passes out (an Easter egg): the bears
## came by, and the pack was zipped, so nothing is lost.
const BEAR_TRACKS_MESSAGE := "Bear tracks by the fence this morning. Your pack was zipped."
## Seconds to let the "passed out" message show before the tracks message.
const BEAR_TRACKS_DELAY := 3.8

## The region the player is in.
var region: Region
## The forage spawner in the current region, if it has one. Hubs give theirs
## a unique name (Forage_<hub id>), so look for it by type.
var forage: ForageSpawner:
	get:
		if region == null:
			return null
		for child in region.entities.get_children():
			if child is ForageSpawner:
				return child
		return null

## Regions visited this session, by id. They stay in memory while the player
## is elsewhere, so anything that changed in them is still there on return.
var _regions: Dictionary = {}
var _busy := false
var _place_check := 0.0
## The clock hit the pass-out hour while World or a dialogue was busy; the
## player passes out as soon as both are done.
var _curfew_pending := false

@onready var player: Player = $Player
@onready var hud: HUD = $HUD
@onready var park_map: ParkMap = $ParkMap


func _ready() -> void:
	add_to_group("world")
	add_to_group("persist")
	add_to_group("persist_provider")
	GameClock.curfew_reached.connect(_on_curfew)
	park_map.travel_requested.connect(travel)
	park_map.shuttle_requested.connect(_on_shuttle_requested)
	park_map.closed.connect(_set_paused.bind(false))
	var saved := SaveManager.peek_node(name)
	var start := str(saved.get("region", Park.HOME_REGION))
	if not ResourceLoader.exists(region_scene_path(start)):
		start = Park.HOME_REGION
	# A loaded save puts the player back where they were; this is the fallback.
	_enter_region(start, Park.HOME_SPAWN if start == Park.HOME_REGION else "arrival")
	if not SaveManager.load_game():
		SaveManager.clear_pending()
		Inventory.start_new_game()
		Park.start_new_game()
		Gear.start_new_game()
		Granary.start_new_game()
		Recipes.start_new_game()
		QuestLog.start_new_game()
		Perks.start_new_game()
		if forage:
			forage.respawn()
	hud.bind_player(player)
	add_child(Journal.new())
	add_child(PauseMenu.new())
	_update_location()


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		for cached: Region in _regions.values():
			if is_instance_valid(cached) and cached.get_parent() == null:
				cached.free()


func _process(delta: float) -> void:
	if _curfew_pending and not _busy and not _dialogue_open():
		sleep(true)
	_place_check -= delta
	if _place_check <= 0.0:
		_place_check = 0.25
		_update_location()


func _on_curfew() -> void:
	_curfew_pending = true


## True while a conversation, shop, or cooking menu is on screen.
func _dialogue_open() -> bool:
	return get_tree().get_nodes_in_group("dialogue_box").any(func(box: Node) -> bool: return not box.is_queued_for_deletion())


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("map") and not _busy and player.can_act:
		open_map()
		get_viewport().set_input_as_handled()
		return
	# Debug shortcuts, only in editor/debug builds.
	if not OS.is_debug_build() or not (event is InputEventKey and event.pressed and not event.echo):
		return
	match event.keycode:
		KEY_F2:
			GameClock.advance_minutes(60)
		KEY_F3:
			sleep()


static func region_scene_path(id: String) -> String:
	return "res://scenes/regions/%s.tscn" % id


## Opens the map to look around. Travel starts from kiosks and road exits.
func open_map() -> void:
	if _busy:
		return
	_set_paused(true)
	park_map.open(region, player.global_position, false)


## Opens the map ready to travel, with [param preselect] highlighted.
func open_travel_map(preselect := "") -> void:
	if _busy:
		return
	_set_paused(true)
	park_map.open(region, player.global_position, true, preselect)


## Opens the Valley map to choose a shuttle stop. [param stop_name] is the
## stop the player is standing at.
func open_shuttle_map(stop_name: String) -> void:
	if _busy:
		return
	_set_paused(true)
	park_map.open_shuttle(region, player.global_position, stop_name)


func _on_shuttle_requested(stop: Dictionary) -> void:
	go_to_region(stop.region, stop.spawn, ShuttleStop.RIDE_MINUTES)


## Called by a RegionExit the player walked into.
func use_exit(exit: RegionExit) -> void:
	if _busy or not player.can_act:
		return
	if not exit.is_open_now():
		hud.show_message(exit.closed_message())
		return
	if exit.target_region != "":
		go_to_region(exit.target_region, exit.target_spawn)
	elif exit.travel_to != "":
		open_travel_map(exit.travel_to)
	elif exit.message != "":
		hud.show_message(exit.message)


## Moves the player to a spawn point in another region, with a fade. Use this
## for doors between a hub and its smaller areas, and for climbs that end
## somewhere new. [param minutes] advances the clock.
func go_to_region(id: String, spawn_name := "arrival", minutes := 0) -> void:
	if _busy:
		return
	_busy = true
	_set_paused(true)
	await hud.fade_to_black()
	if minutes > 0:
		GameClock.advance_minutes(minutes)
	_enter_region(id, spawn_name)
	await _unstick_player()
	await hud.fade_from_black()
	_set_paused(false)
	_busy = false


## Drives along one of the routes from Park.legs_from().
func travel(leg: Dictionary) -> void:
	if _busy or not leg.open:
		return
	var hub := Park.get_hub(leg.to)
	if GameClock.is_too_late_for(int(leg.minutes)):
		hud.show_message("It's too late to set out for %s tonight." % hub.display_name)
		return
	_busy = true
	_set_paused(true)
	await hud.fade_to_black()
	GameClock.advance_minutes(leg.minutes)
	# Some hubs greet drivers in a smaller area, like Yosemite Village.
	_enter_region(hub.arrival_region if hub.arrival_region != "" else leg.to, leg.spawn)
	await _unstick_player()
	await hud.fade_from_black()
	hud.show_message("You drove %s miles to %s (%s)." % [str(leg.miles), hub.display_name, Park.format_minutes(leg.minutes)])
	_set_paused(false)
	_busy = false


func sleep(passed_out := false) -> void:
	if _busy:
		return
	_busy = true
	_curfew_pending = false
	_set_paused(true)
	await hud.fade_to_black()

	var fell_asleep_at := ""
	if region.region_id != Park.HOME_REGION:
		fell_asleep_at = _location_name()
		_enter_region(Park.HOME_REGION, Park.HOME_SPAWN)
	GameClock.start_new_day()
	if forage:
		await forage.respawn()
	player.global_position = region.get_spawn(Park.HOME_SPAWN).global_position
	player.facing = Vector2i.DOWN
	player.interaction_area.position = Vector2(player.facing) * 12.0
	await _unstick_player()
	_camera().reset_smoothing()
	SaveManager.save_game()

	await hud.fade_from_black()
	var message := "Good morning! Your game was saved."
	if passed_out and fell_asleep_at != "":
		message = "You fell asleep at %s. A ranger drove you back to camp." % fell_asleep_at
	elif passed_out:
		message = "You stayed out too late and passed out..."
	if Larder.last_spoiled != "":
		message += "\n" + Larder.last_spoiled
	hud.show_message(message)
	if passed_out:
		_show_bear_tracks() # once per pass-out, so it never repeats on later mornings
	_set_paused(false)
	_busy = false


## The morning after passing out, once the first message has had its moment.
func _show_bear_tracks() -> void:
	await get_tree().create_timer(BEAR_TRACKS_DELAY).timeout
	if is_inside_tree():
		hud.show_message(BEAR_TRACKS_MESSAGE)


## Swaps regions right away (no fade). The player lands on [param spawn_name]
## if that spot exists, and otherwise keeps their position.
func _enter_region(id: String, spawn_name := "") -> void:
	if player.get_parent():
		player.get_parent().remove_child(player)
	if region:
		remove_child(region)
	region = _regions.get(id)
	var first_visit := region == null
	if first_visit:
		var scene: PackedScene = load(region_scene_path(id))
		region = scene.instantiate()
		_regions[id] = region
	add_child(region)
	move_child(region, 0)
	if first_visit:
		StoryContent.attach(region)
		SaveManager.restore(region)
		_connect_tents(region)
	region.entities.add_child(player)
	var spawn: Marker2D = region.get_spawn(spawn_name) if spawn_name != "" else null
	if spawn:
		player.global_position = spawn.global_position
	elif spawn_name != "":
		push_warning("Region %s has no spawn point named %s" % [id, spawn_name])
	_fit_camera()
	_camera().reset_smoothing()
	$DayNight.visible = not region.indoors
	if forage:
		forage.refresh()
	region_changed.emit(region)
	_update_location()


## Makes sure the player isn't standing inside something solid (a spawn that
## landed in a tree, say): waits for physics, then looks outward in rings for
## the nearest free spot.
func _unstick_player() -> void:
	await get_tree().physics_frame
	if not player.test_move(player.global_transform, Vector2.ZERO):
		return
	var origin := player.global_position
	for radius in range(4, 100, 4):
		for dir in 8:
			var spot := origin + Vector2.from_angle(dir * TAU / 8.0) * radius
			if not player.test_move(Transform2D(0.0, spot), Vector2.ZERO):
				player.global_position = spot
				_camera().reset_smoothing()
				return


func _connect_tents(root: Node) -> void:
	for node in root.find_children("*", "StaticBody2D", true, false):
		if node.has_signal("sleep_requested") and not node.is_connected("sleep_requested", sleep):
			node.connect("sleep_requested", sleep)


func _camera() -> Camera2D:
	return player.get_node("Camera")


func _fit_camera() -> void:
	var camera := _camera()
	var bounds := region.get_bounds()
	camera.limit_left = floori(bounds.position.x)
	camera.limit_top = floori(bounds.position.y)
	camera.limit_right = ceili(bounds.end.x)
	camera.limit_bottom = ceili(bounds.end.y)


func _set_paused(paused: bool) -> void:
	player.can_act = not paused
	GameClock.paused = paused


## "Cook's Meadow" inside a hub, or the region's name.
func _location_name() -> String:
	var place := region.place_at(player.position)
	return place.display_name if place else region.display_name


func _update_location() -> void:
	if region == null or hud == null:
		return
	var hub := Park.get_hub(region.hub_id)
	var parts := PackedStringArray()
	if hub and hub.id != region.region_id:
		parts.append(hub.display_name)
	parts.append(region.display_name)
	var place := region.place_at(player.position)
	if place and place.display_name != region.display_name:
		parts.append(place.display_name)
	hud.set_location(" · ".join(parts))


func get_offstage_persist_nodes() -> Array[Node]:
	var nodes: Array[Node] = []
	for cached: Region in _regions.values():
		if cached != region:
			for node in cached.find_children("*", "", true, false):
				if node.is_in_group("persist"):
					nodes.append(node)
	return nodes


func save_data() -> Dictionary:
	return {"region": region.region_id}


func load_data(_data: Dictionary) -> void:
	pass # The saved region was loaded first, in _ready().
