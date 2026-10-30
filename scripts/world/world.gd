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
## Regions that are gone, and where a save made in one picks up instead.
## The big Valley map became separate areas joined by trail scenes.
const RETIRED_REGIONS := {"yosemite_valley": "yosemite_village"}

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
## Region scenes loaded in the background before the player needs them, so
## walking through a door or driving to a hub doesn't stall on reading the
## scene: paths waiting their turn, the one loading now, and the finished
## scenes (path -> PackedScene) until the region is first entered.
var _preload_queue: Array[String] = []
var _preloading := ""
var _preloaded: Dictionary = {}
var _busy := false
var _place_check := 0.0
## The door the player last went through into a room, when it was a second
## door (see remember_door): {into, from, spawn}, or empty.
var _door_back := {}
## The clock hit the pass-out hour while World or a dialogue was busy; the
## player passes out as soon as both are done.
var _curfew_pending := false

@onready var player: Player = $Player
@onready var hud: HUD = $HUD
@onready var park_map: ParkMap = $ParkMap
## Today's events, for the page at bedtime.
var day_log: DayLog


func _ready() -> void:
	add_to_group("world")
	add_to_group("persist")
	add_to_group("persist_provider")
	GameClock.curfew_reached.connect(_on_curfew)
	park_map.travel_requested.connect(travel)
	park_map.shuttle_requested.connect(_on_shuttle_requested)
	park_map.closed.connect(_set_paused.bind(false))
	day_log = DayLog.new()
	add_child(day_log)
	add_child(Critters.new())
	add_child(Bears.new())
	add_child(Deer.new())
	add_child(RescueField.new())
	add_child(Rustle.new())
	add_child(StringLights.new())
	player.add_child(Lantern.new())
	add_child(WaterSurface.new())
	add_child(SunLight.new())
	add_child(AirGlow.new())
	add_child(RoomLight.new())
	# over the world and the atmosphere pass, under the HUD
	var tilt := TiltShift.new()
	add_child(tilt)
	move_child(tilt, $Atmosphere.get_index() + 1)
	LitSprites.attach_sprite(player.sprite)
	# before the save loads, so it gets back which moments were seen
	add_child(StoryMoments.new())
	var saved := SaveManager.peek_node(name)
	var start := str(saved.get("region", Park.HOME_REGION))
	start = RETIRED_REGIONS.get(start, start)
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
		Cooking.start_new_game()
		QuestLog.start_new_game()
		Perks.start_new_game()
		Friendship.start_new_game()
		Herbarium.start_new_game()
		BoardRequests.start_new_game()
		Rescues.start_new_game()
		FieldLog.start_new_game()
		Festivals.start_new_game()
		Stewardship.start_new_game()
		if forage:
			forage.respawn()
	hud.bind_player(player)
	Sound.set_ambience("world")
	add_child(Journal.new())
	add_child(PauseMenu.new())
	_update_location()


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		# Collect a background load still running, so it doesn't outlive World.
		if _preloading != "":
			ResourceLoader.load_threaded_get(_preloading)
		for cached: Region in _regions.values():
			if is_instance_valid(cached) and cached.get_parent() == null:
				cached.free()


func _process(delta: float) -> void:
	if _curfew_pending and not _busy and not _dialogue_open():
		sleep(true)
	_pump_preload()
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
		KEY_F4:
			Park.unlock_hub("glacier_point")
			go_to_region("glacier_point", "arrival")


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


## Called by a BuildingDoor the player is going through. A second door into
## the same room (BuildingDoor.exit_spawn) is remembered, so walking back out
## of the room comes out at that door, not the building's first one.
func remember_door(door: BuildingDoor) -> void:
	_door_back = {}
	if door.exit_spawn != "" and region:
		_door_back = {"into": door.target_region, "from": region.region_id, "spawn": door.exit_spawn}


## Called by a RegionExit the player walked into.
func use_exit(exit: RegionExit) -> void:
	if _busy or not player.can_act:
		return
	if not exit.is_open_now():
		hud.show_message(exit.closed_message())
		return
	if exit.target_region != "":
		var spawn := exit.target_spawn
		if _door_back.get("into", "") == region.region_id and _door_back.get("from", "") == exit.target_region:
			spawn = str(_door_back.spawn)
		_door_back = {}
		if exit.minutes > 0:
			_drive_road(exit, spawn)
		else:
			go_to_region(exit.target_region, spawn)
	elif exit.drive_to != "":
		_drive_on(exit)
	elif exit.travel_to != "":
		open_travel_map(exit.travel_to)
	elif exit.message != "":
		hud.show_message(exit.message)


## A road some way to the next region, like Big Oak Flat Road up to Crane
## Flat: the clock moves on by the drive.
func _drive_road(exit: RegionExit, spawn: String) -> void:
	if GameClock.is_too_late_for(exit.minutes):
		hud.show_message("It's too late to set out on %s tonight." % exit.label)
		return
	await go_to_region(exit.target_region, spawn, exit.minutes)
	hud.show_message("You drove %s miles to %s (%s)." % [str(exit.miles), region.display_name, Park.format_minutes(exit.minutes)])


## A road that carries straight on to another hub, without the map: the
## leg's closures and locks hold as they do on the map, and the exit's
## minutes and miles are what is left of the drive from here.
func _drive_on(exit: RegionExit) -> void:
	var leg := Park.best_leg(region.hub_id, exit.drive_to, "drive")
	if leg.is_empty():
		open_travel_map(exit.drive_to)
		return
	if not leg.open:
		hud.show_message(leg.closed_reason)
		return
	if exit.minutes > 0:
		leg.minutes = exit.minutes
		leg.miles = exit.miles
	travel(leg)


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


## Ends the day. You wake up at home, unless [param camp_spawn] names a
## spot in this region where you pitched your tent for a night out in the
## backcountry (BackcountryCamp): then you wake up there, and the morning
## says what became of your food.
func sleep(passed_out := false, camp_spawn := "") -> void:
	if _busy:
		return
	_busy = true
	_curfew_pending = false
	_set_paused(true)
	# Down you go, eyes shut, as the screen goes dark.
	player.lie_down(true)
	Emote.pop(player, "sleep")
	await hud.fade_to_black()
	await show_day_summary()

	var fell_asleep_at := ""
	var wake_spawn := Park.HOME_SPAWN
	var night_out := ""
	if camp_spawn != "" and not passed_out:
		wake_spawn = camp_spawn
		night_out = Backcountry.night_out()
	elif region.region_id != Park.HOME_REGION:
		fell_asleep_at = _location_name()
		if passed_out and Backcountry.is_backcountry(region.region_id):
			fell_asleep_at = "backcountry:" + fell_asleep_at
		_enter_region(Park.HOME_REGION, Park.HOME_SPAWN)
	GameClock.start_new_day()
	if forage:
		await forage.respawn()
	# A new season brings up different plants for the press book.
	var plants := PlantSpawner.attach(region)
	if plants:
		await plants.refresh()
	player.global_position = region.get_spawn(wake_spawn).global_position
	player.lie_down(false)
	player.facing = Vector2i.DOWN
	player.interaction_area.position = Vector2(player.facing) * 24.0
	await _unstick_player()
	_camera().reset_smoothing()
	SaveManager.save_game()

	await hud.fade_from_black()
	player.pose("arms_up", 1.0) # a morning stretch
	var message := "Good morning! Your game was saved."
	if night_out != "":
		message = "Good morning in %s! Your game was saved.\n%s" % [region.display_name, night_out]
	elif passed_out and fell_asleep_at.begins_with("backcountry:"):
		message = "You fell asleep on the trail at %s. A ranger on patrol walked you down and drove you back to camp." % fell_asleep_at.trim_prefix("backcountry:")
	elif passed_out and fell_asleep_at != "":
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


## The day's page (DaySummary), over the black, until the player goes on.
## Headless (the tests) it is skipped.
func show_day_summary() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var page := DaySummary.open(self, day_log)
	await page.closed


## The morning after passing out, once the first message has had its moment.
func _show_bear_tracks() -> void:
	await get_tree().create_timer(BEAR_TRACKS_DELAY).timeout
	if is_inside_tree():
		hud.show_message(BEAR_TRACKS_MESSAGE)
		await get_tree().create_timer(BEAR_TRACKS_DELAY).timeout
		if is_inside_tree():
			FieldLog.spot("black_bear", false, "tracks")


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
		var scene := _load_region_scene(id)
		region = scene.instantiate()
		_regions[id] = region
	add_child(region)
	move_child(region, 0)
	if first_visit:
		StoryContent.attach(region)
		SaveManager.restore(region)
		_connect_tents(region)
		SoundEmitter.attach_waterfalls(region)
		SoundEmitter.attach_rivers(region)
		SunShadows.attach(region)
		LampLights.attach(region)
		LitSprites.attach(region)
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
	var plants := PlantSpawner.attach(region)
	if plants:
		plants.refresh()
	if not region.indoors:
		Chongo.visit(region)
	region_changed.emit(region)
	_update_location()
	_preload_neighbors()


## The scene for region [param id]: one loaded in the background if it's ready
## (or waiting for it if it's loading now), otherwise loaded now.
func _load_region_scene(id: String) -> PackedScene:
	var path := region_scene_path(id)
	var scene: PackedScene = _preloaded.get(path)
	_preloaded.erase(path)
	_preload_queue.erase(path)
	if scene == null and _preloading == path:
		_preloading = ""
		scene = ResourceLoader.load_threaded_get(path) as PackedScene
	return scene if scene else load(path)


## Queues background loads of the regions the player can reach next from
## here: through its doors and exits first, then its hub and home (where a
## ranger takes you if you pass out), then the hubs down the road.
func _preload_neighbors() -> void:
	if not region.has_meta("exit_targets"):
		var targets: Array[String] = []
		for node in region.find_children("*", "", true, false):
			if node is RegionExit or node is RegionDoor:
				targets.append(node.target_region)
		region.set_meta("exit_targets", targets)
	var ids: Array[String] = []
	ids.append_array(region.get_meta("exit_targets"))
	ids.append(region.hub_id)
	ids.append(Park.HOME_REGION)
	for leg in Park.legs_from(region.hub_id):
		var hub := Park.get_hub(leg.to)
		ids.append(hub.arrival_region if hub.arrival_region != "" else hub.id)
	for id in ids:
		var path := region_scene_path(id)
		if id == "" or _regions.has(id) or _preloaded.has(path) or _preloading == path or path in _preload_queue \
				or ResourceLoader.has_cached(path) or not ResourceLoader.exists(path):
			continue
		_preload_queue.append(path)


## Loads the queued regions one at a time on a background thread.
func _pump_preload() -> void:
	if _preloading != "":
		match ResourceLoader.load_threaded_get_status(_preloading):
			ResourceLoader.THREAD_LOAD_IN_PROGRESS:
				return
			ResourceLoader.THREAD_LOAD_LOADED:
				_preloaded[_preloading] = ResourceLoader.load_threaded_get(_preloading)
		_preloading = ""
	while _preloading == "" and not _preload_queue.is_empty():
		var path: String = _preload_queue.pop_front()
		if ResourceLoader.load_threaded_request(path) == OK:
			_preloading = path


## Makes sure the player isn't standing inside something solid (a spawn that
## landed in a tree, say): waits for physics, then looks outward in rings for
## the nearest free spot.
func _unstick_player() -> void:
	await get_tree().physics_frame
	if not player.test_move(player.global_transform, Vector2.ZERO):
		return
	var origin := player.global_position
	for radius in range(8, 200, 8):
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
