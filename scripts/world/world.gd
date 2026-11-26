extends Node2D
## Runs the game. Shows one region at a time (a hub such as Yosemite Valley,
## or a smaller area such as the Lamon Homestead), moves the player between
## them, and handles travel and the sleep / new-day sequence.
##
## Other systems reach World through the "world" group, for example:
##   get_tree().call_group("world", "go_to_region", "glacier_point", "apron_top")

signal region_changed(region: Region)
## The player walked over a seam into the region laid beside theirs: it and
## everything with it moved by [param shift] to put the new one at the
## origin, so nothing moved on screen. Anything kept in world pixels outside
## the regions (weather, birds, prints in the snow, calls) moves with it, and
## keeps what's on screen instead of starting afresh as at a door. Sent just
## before region_changed.
signal seam_crossed(shift: Vector2)

## Seen the morning after the player passes out (an Easter egg): the bears
## came by, and the pack was zipped, so nothing is lost.
const BEAR_TRACKS_MESSAGE := "Bear tracks by the fence this morning. Your pack was zipped."
## Seconds to let the "passed out" message show before the tracks message.
const BEAR_TRACKS_DELAY := 3.8
## Regions that are gone, and where a save made in one picks up instead.
## The big Valley map became separate areas joined by trail scenes.
const RETIRED_REGIONS := {"yosemite_valley": "yosemite_village"}
## A saved spot this far off its map's ground (a seam's overlap, an edge
## being walked over) still counts as on the map when the save loads.
const SAVE_SLACK := 256.0
## The next region is laid beside this one once the player is this close (in
## pixels) to a seam, and taken away again past SEAM_FAR.
const SEAM_NEAR := 720.0
const SEAM_FAR := 960.0
## The hubs down the road load ahead only while video memory for pictures
## is under this (bytes); past it they load behind the trip map instead.
const PRELOAD_HUBS_UNDER := 768 * 1048576
## How many regions left behind keep their ground pictures (the rest give
## them back until they're next laid out): on High, and on Low.
const KEEP_PICTURES := 6
const KEEP_PICTURES_LOW := 3
## The seam laid out now counts as this much nearer than another on the same
## edge, so walking along an edge where two regions meet it doesn't flick
## between them.
const SEAM_SWAP := 160.0
## Walking into a seam whose region past it is still loading, the player
## waits at the edge this long (ms) for it before it's set up all at once.
const SEAM_WAIT_MS := 1500
## Arriving within this many pixels of the way back, the player faces away
## from it (see _face_away_from_way_back).
const FACE_AWAY_NEAR := 160.0

## The region the player is in.
var region: Region
## Where the player last arrived, by a door, a fade, a trip or over a seam
## (see use_exit).
var _arrived_at := Vector2.INF
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
## What is read with each region scene (see _extra_loads), by scene path.
var _extra: Dictionary = {}
## Normal maps loaded in the background, held until used (see LitSprites).
var _warm: Dictionary = {}
## Tests set this to keep fewer (or more) pictures than KEEP_PICTURES.
var keep_pictures := -1
## Regions entered, the latest first (see _budget_textures).
var _recent: Array[String] = []
## A seam crossed this tick, and where the camera's smoothing had got to,
## in the new region's pixels (see _hand_camera_over).
var _crossed := false
var _crossed_view := Vector2.ZERO
## Regions part way through their first set-up (see _set_up_step).
var _setting_up: Dictionary = {}
## Set once _ready has loaded the save or set up a new game: places are only
## discovered from then on.
var _started := false
## The region laid beside this one where a road runs off the map edge, while
## the player is near that edge (see Seam), so they walk across with no fade.
var seam: Seam
## Seams found so far, by region id and then exit name: a Seam, or null where
## the exit turned out not to meet the next map edge to edge.
var _seams: Dictionary = {}
var _busy := false
## True while a transition plays out (see _reveal, _step_through, _journey).
var _transitioning := false
## Behind a cover (the door's picture, the trip map), a new place is set up
## a few steps a frame, up to this many microseconds of steps a frame, so
## the window keeps drawing; and the cover waits at most PREPARE_WAIT
## seconds on the disk before setting the rest up at once.
const PREPARE_BUDGET_USEC := 12000
const PREPARE_WAIT := 3.0
## Walking toward a seam, the next region's sprites get their lit material
## this many microseconds' worth a frame (see _set_up_step).
const LIT_BUDGET_USEC := 3000
## Opens the place left behind away going through a door.
const DOOR_WIPE := preload("res://assets/shaders/door_wipe.gdshader")
var _place_check := 0.0
## The door the player last went through into a room, when it was a second
## door (see remember_door): {into, from, spawn}, or empty.
var _door_back := {}
## The clock hit the pass-out hour while World or a dialogue was busy; the
## player passes out as soon as both are done.
var _curfew_pending := false
## The camp you're about to sleep in, made with the backpacking pack
## (camp_out): {"at": Vector2, "problems": Array}, or empty.
var _camp_out := {}
## Where the wilderness ranger stands when you wake up beside them.
const RANGER_BESIDE := Vector2(34, 2)
## Trips that take clock time play on the park map (see Journey) instead of
## fading to black. Shot tools turn it off; headless runs never show it.
var journeys := true
## Tests set this to run the trip map headless too (it never draws there).
var journeys_headless := false

@onready var player: Player = $Player
@onready var hud: HUD = $HUD
@onready var park_map: ParkMap = $ParkMap
## The forest past the map edges, seen only beside a seam.
var backdrop := SeamBackdrop.new()
## Which areas are streamed in, and where things are across them, for
## everything outside World (see WorldStream and docs/STREAMING.md).
var stream: WorldStream
## Tilts the camera up at the cliffs; also carries its lag over a seam.
var framing := LandmarkFraming.new()
## Today's events, for the page at bedtime.
var day_log: DayLog


func _ready() -> void:
	# Cross seams after the player's tick, not before it: a walker moved to
	# another parent mid-tick misses its move that tick, and stutters.
	process_physics_priority = 1000
	stream = WorldStream.new(self)
	add_child(stream)
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
	add_child(Bobcats.new())
	add_child(Owls.new())
	add_child(Falcons.new())
	add_child(RescueField.new())
	# today's happenings around the park, in the area you're in
	add_child(HappeningField.new())
	# HUFF crew's secret off-trail forest party after 10 PM
	add_child(HuffPartyField.new())
	# people walking between the Valley's areas on days of their own
	add_child(Travelers.new())
	seam_crossed.connect(Sound.shift_calls)
	add_child(Rustle.new())
	add_child(Footprints.new())
	add_child(Breath.new())
	add_child(Wind.new())
	add_child(StringLights.new())
	player.add_child(Lantern.new())
	add_child(WaterSurface.new())
	add_child(SunLight.new())
	add_child(RadianceGI.new())
	add_child(AirGlow.new())
	add_child(HD2DPost.new())
	add_child(AtmosphericMotes.new())
	add_child(RoomLight.new())
	add_child(GraphicsWatch.new())
	add_child(framing)
	add_child(backdrop)
	# The camera eases to its limits, so when a seam opens the view over the
	# edge (or closes it) it pans there instead of jumping.
	_camera().limit_smoothed = true
	LitSprites.attach_sprite(player.sprite)
	# before the save loads, so it gets back which moments were seen
	add_child(StoryMoments.new())
	var first_day := FirstDay.new()
	add_child(first_day)
	var saved := SaveManager.peek_node(name)
	var saved_region := str(saved.get("region", Park.HOME_REGION))
	var start: String = RETIRED_REGIONS.get(saved_region, saved_region)
	if not ResourceLoader.exists(region_scene_path(start)):
		start = Park.HOME_REGION
	# A loaded save puts the player back where they were; this is the fallback.
	_enter_region(start, Park.HOME_SPAWN if start == Park.HOME_REGION else "arrival")
	var fallback := player.global_position
	if not SaveManager.load_game():
		SaveManager.clear_pending()
		NewGame.reset()
		first_day.start_new_game()
		if forage:
			forage.respawn()
	else:
		# The save put the player back where they were, off the fallback
		# spawn. Saved in an area that has since gone (or been replaced),
		# the spot means nothing here: start from the fallback. Saved on a
		# spot that is off the map now, or that something now stands on (an
		# update moved a fence or added a tent), step them clear.
		if start != saved_region:
			player.global_position = fallback
		elif not region.get_bounds().grow(SAVE_SLACK).has_point(region.to_local(player.global_position)):
			player.global_position = fallback
		_arrived_at = player.global_position
		_update_seam(true)
		_fit_camera()
		_settle_view()
		_unstick_player()
	Achievements.settle()
	player.apply_look() # the look saved with the game just loaded, if any
	hud.bind_player(player)
	Sound.set_ambience("world")
	add_child(Journal.new())
	add_child(PauseMenu.new())
	add_child(LookAway.new())
	add_child(ProblemReport.new())
	# the camera Ansel Adams lends you, and the album its prints go in
	add_child(CameraView.new())
	add_child(PhotoAlbum.new())
	_started = true
	_update_location()


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		# Collect a background load still running, so it doesn't outlive World.
		if _preloading != "":
			ResourceLoader.load_threaded_get(_preloading)
		for cached: Region in _regions.values() + _setting_up.values():
			if is_instance_valid(cached) and cached.get_parent() == null:
				cached.free()


func _process(delta: float) -> void:
	if _crossed:
		_hand_camera_over()
	if _curfew_pending and not _busy and not _dialogue_open():
		sleep(true)
	_pump_preload()
	_update_seam()
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


const REGION_DIR := "res://scenes/regions/"


static func region_scene_path(id: String) -> String:
	return REGION_DIR + "%s.tscn" % id


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
	go_to_region(stop.region, stop.spawn, ShuttleStop.RIDE_MINUTES, {"title": "Valley shuttle"})


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
	# Still standing where they arrived, and not really in it: physics still
	# sees them where they stood in the last place, at the same spot as this
	# exit (the rooms' doors all sit at the bottom middle, and Four Mile's
	# road east is where Bridalveil's road east was). Going now would carry
	# them straight on through, place after place.
	if region.is_ancestor_of(exit) and player.global_position.distance_to(_arrived_at) < 2.0 \
			and exit.overlaps_body(player) and not exit.touches(player):
		exit.watch(player)
		return
	# The next region is laid out past this edge, or this is its own exit
	# back: walk on across (see _physics_process). Called for an exit the
	# player isn't standing at (from a script), it takes them there anyway.
	if seam and (not region.is_ancestor_of(exit) or (exit.target_region == seam.neighbor.region_id \
			and (region.to_local(exit.global_position) - seam.point).length() < Seam.CORRIDOR \
			and player.global_position.distance_to(exit.global_position) < Seam.CORRIDOR)):
		return
	# An edge that is a seam, reached before the region past it was laid out
	# (it was still loading, or the player came straight off a fade beside
	# it): lay it out now and let them walk on over, rather than cutting to
	# the far side. A moment's set-up, not a jump to somewhere else.
	if region.is_ancestor_of(exit) and exit in _seam_exits(region) and _at_exit(exit):
		# not mid-physics (exits fire there), where the maps can't change
		_seam_or_exit.call_deferred(exit)
		return
	_take_exit(exit)


## Lays out the seam through [param exit], or, where the maps don't meet
## edge to edge, takes it. A region past it that isn't set up yet is loaded
## first and set up a step a frame (see _update_seam) while the player waits
## at the edge, so the game doesn't stall a frame on it; only if that takes
## too long is it set up all at once.
func _seam_or_exit(exit: RegionExit) -> void:
	var id := exit.target_region
	if not _regions.has(id):
		var path := region_scene_path(id)
		if not _region_ready(id) and _preloading != path:
			_preload_queue.erase(path)
			_preload_queue.push_front(path)
		var waited := 0
		while not _regions.has(id) and waited < SEAM_WAIT_MS and _at_exit(exit):
			var start := Time.get_ticks_msec()
			await get_tree().process_frame
			waited += Time.get_ticks_msec() - start
	if _busy or not is_instance_valid(exit) or not region.is_ancestor_of(exit) or not _at_exit(exit):
		return
	var found := _seam_for(exit)
	if found:
		if not _same_seam(found, seam):
			_lay_seam(found)
	else:
		_take_exit(exit)


## Is the player standing at [param exit] (not using it from a script)?
func _at_exit(exit: RegionExit) -> bool:
	return player.global_position.distance_to(exit.global_position) < Seam.CORRIDOR


func _take_exit(exit: RegionExit) -> void:
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
func _drive_road(exit: RegionExit, spawn: String, to_region := "") -> void:
	if GameClock.is_too_late_for(exit.minutes):
		hud.show_message("It's too late to set out on %s tonight." % exit.label)
		return
	var to := to_region if to_region != "" else exit.target_region
	await go_to_region(to, spawn, exit.minutes, {"title": exit.label, "miles": exit.miles})
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
	if exit.stop_region != "":
		_drive_road(exit, exit.stop_spawn, exit.stop_region)
		return
	if exit.minutes > 0:
		leg.minutes = exit.minutes
		leg.miles = exit.miles
	travel(leg)


## Moves the player to a spawn point in another region. Use this for doors
## between a hub and its smaller areas, and for climbs that end somewhere
## new. A way that takes no time (a door, a gate) steps straight through
## (see _step_through); one that takes [param minutes] fades, and advances
## the clock.
##
## [param trip] describes a trip with minutes for the map that shows it (see
## _journey): {title, miles, on_foot, path}. Without it the trip is a walk.
func go_to_region(id: String, spawn_name := "arrival", minutes := 0, trip := {}) -> void:
	if _busy:
		return
	if minutes == 0:
		await _step_through(id, spawn_name)
		return
	if _journeys_on():
		var info := trip.duplicate()
		if not info.has("title"):
			info.title = "On the trail"
			info.on_foot = true
		await _journey(id, spawn_name, minutes, info)
		return
	_busy = true
	_set_paused(true)
	await hud.fade_to_black()
	if minutes > 0:
		GameClock.advance_minutes(minutes)
	_enter_region(id, spawn_name)
	await _unstick_player()
	await _reveal()
	_set_paused(false)
	_busy = false


## Under the cover, waits for the new place to draw evenly, then wipes the
## cover away (see Transition).
func _reveal() -> void:
	_transitioning = true
	await _settle()
	await hud.fade_from_black()
	_transitioning = false


func _journeys_on() -> bool:
	return journeys and Settings.journeys and (journeys_headless or DisplayServer.get_name() != "headless")


## A trip that takes [param minutes]: the park map opens over the world and
## a marker runs the road or trail while the clock runs (see Journey). The
## clock moves on once, by all of it, and the new place is laid out under
## the map, which then lifts off it. No black screen.
func _journey(id: String, spawn_name: String, minutes: int, info: Dictionary) -> void:
	_busy = true
	_set_paused(true)
	var from_region := region.region_id
	var from := Wayfinding.lonlat_of(region, region.to_local(player.global_position))
	var start := GameClock.minutes
	# start reading the new place off the disk now, while the map opens
	_want_loaded(id)
	var journey := Journey.new()
	add_child(journey)
	_transitioning = true
	# The HUD's clock would jump straight to the end; the map has its own.
	# The HUD fades out under the veil rather than vanishing in a frame.
	_fade_hud(0.0, Transition.MAP_COVER_TIME)
	await journey.cover()
	# Fully dark for the swap, so the old place never cuts to the new one
	# through the veil.
	await journey.hold()
	hud.visible = false
	# (the map drawn fully open first)
	await get_tree().process_frame
	# The map is open and still: set the new place up under it, a few steps
	# a frame, and lay it out, before the marker sets off.
	await _prepare_region(id)
	GameClock.advance_minutes(minutes)
	_enter_region(id, spawn_name, true)
	await _settle_seams()
	await _settle()
	info.merge({
		"from": from,
		"to": Wayfinding.lonlat_of(region, region.to_local(player.global_position)),
		"from_region": from_region,
		"to_region": id,
		"start_minutes": start,
		"minutes": minutes,
		"subtitle": "%s to %s" % [Journey.place_name(from_region), Journey.place_name(id)],
	})
	await journey.travel(info)
	await _unstick_player()
	hud.visible = true
	_fade_hud(1.0, Transition.MAP_LIFT_TIME)
	await journey.lift()
	journey.queue_free()
	hud.opacity = 1.0
	_transitioning = false
	_set_paused(false)
	_busy = false


## Fades the HUD to [param alpha] over [param seconds], not waiting on it.
func _fade_hud(alpha: float, seconds: float) -> void:
	var from: float = hud.opacity
	Transition.run(hud, seconds, func(t: float) -> void: hud.opacity = lerpf(from, alpha, t))


## Goes through a door, gate or short way that takes no time: the new place
## is laid out under a picture of the last frame here, which then opens away
## from where the player stands (door_wipe.gdshader). No dark screen, and
## the player walks on as soon as they're through.
func _step_through(id: String, spawn_name: String) -> void:
	_busy = true
	_set_paused(true)
	var picture := await _snapshot()
	var cover: CanvasLayer = null
	if picture:
		cover = _door_cover(picture)
		# Under the still picture: set the new place up, lay it out, and let
		# its first slow frames pass before the picture opens away.
		await _prepare_region(id)
	_enter_region(id, spawn_name, cover != null)
	if cover:
		await _settle_seams()
	await _unstick_player()
	if cover == null:
		_set_paused(false)
		_busy = false
		return
	# The picture of the old place stays up until the new one draws evenly,
	# then opens over smooth frames (see Transition).
	_transitioning = true
	await _settle()
	_set_paused(false)
	_busy = false
	var wipe := (cover.get_child(0) as CanvasItem).material as ShaderMaterial
	var at := player.get_global_transform_with_canvas().origin / get_viewport().get_visible_rect().size
	wipe.set_shader_parameter("center", at.clamp(Vector2.ZERO, Vector2.ONE))
	await Transition.run(cover, Transition.DOOR_TIME, func(t: float) -> void: wipe.set_shader_parameter("progress", t))
	_transitioning = false
	if is_instance_valid(cover):
		cover.queue_free()


## The last frame drawn, as a texture, once it is drawn, or null where
## nothing is drawn (headless, in the tests).
func _snapshot() -> Texture2D:
	# Either way, wait for the frame to finish: a door is often walked into
	# during physics, where the region can't be swapped.
	if DisplayServer.get_name() == "headless":
		await get_tree().process_frame
		return null
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	return ImageTexture.create_from_image(image) if image and not image.is_empty() else null


## Lays [param picture] over the whole view, under the HUD.
func _door_cover(picture: Texture2D) -> CanvasLayer:
	var cover := CanvasLayer.new()
	cover.name = "DoorCover"
	cover.layer = hud.layer
	var rect := TextureRect.new()
	rect.texture = picture
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var view := get_viewport().get_visible_rect()
	rect.position = view.position
	rect.size = view.size
	var wipe := ShaderMaterial.new()
	wipe.shader = DOOR_WIPE
	wipe.set_shader_parameter("rect_size", view.size)
	rect.material = wipe
	cover.add_child(rect)
	add_child(cover)
	move_child(cover, hud.get_index())
	return cover


## Drives along one of the routes from Park.legs_from().
func travel(leg: Dictionary) -> void:
	if _busy or not leg.open:
		return
	var hub := Park.get_hub(leg.to)
	if GameClock.is_too_late_for(int(leg.minutes)):
		hud.show_message("It's too late to set out for %s tonight." % hub.display_name)
		return
	# Some hubs greet drivers in a smaller area, like Yosemite Village.
	var arrive_in: String = hub.arrival_region if hub.arrival_region != "" else leg.to
	if _journeys_on():
		await _journey(arrive_in, leg.spawn, int(leg.minutes), {"title": str(leg.get("via", "")), "miles": float(leg.miles), "path": leg.get("path", [])})
		hud.show_message("You drove %s miles to %s (%s)." % [str(leg.miles), hub.display_name, Park.format_minutes(leg.minutes)])
		return
	_busy = true
	_set_paused(true)
	await hud.fade_to_black()
	GameClock.advance_minutes(leg.minutes)
	_enter_region(arrive_in, leg.spawn)
	await _unstick_player()
	await _reveal()
	hud.show_message("You drove %s miles to %s (%s)." % [str(leg.miles), hub.display_name, Park.format_minutes(leg.minutes)])
	_set_paused(false)
	_busy = false


## Ends the day. You wake up at home, unless [param camp_spawn] names a
## spot in this region where you pitched your tent for a night out in the
## backcountry (BackcountryCamp): then you wake up there, and the morning
## says what became of your food.
func sleep(passed_out := false, camp_spawn := "", extra_nights := 0) -> void:
	if _busy:
		return
	# a camp made anywhere with the backpacking pack (camp_out)
	var camp := _camp_out
	_camp_out = {}
	if passed_out:
		camp = {}
	_busy = true
	_curfew_pending = false
	_set_paused(true)
	# Down you go, eyes shut, as the screen goes dark.
	player.lie_down(true)
	Emote.pop(player, "sleep")
	await hud.fade_to_black()
	await show_day_summary()

	var fell_asleep_at := ""
	var message_extra := ""
	var wake_spawn := Park.HOME_SPAWN
	var night_out := ""
	if not camp.is_empty():
		wake_spawn = ""
		# a clean camp keeps its food in the canister; a bad one meets the
		# ranger in the morning, who takes it all anyway
		if camp.problems.is_empty():
			Backpacking.mark(Backpacking.CLEAN_CAMP)
			night_out = "You packed up and left no trace. " + Backcountry.night_out()
	elif camp_spawn != "" and not passed_out:
		wake_spawn = camp_spawn
		night_out = Backcountry.night_out()
	elif region.region_id == Cabin.ROOM_REGION and Camp.has("rope_bed"):
		# home in your own bed: wake up beside it
		wake_spawn = CabinRoom.BED_SPOT
	elif region.region_id != Park.HOME_REGION:
		fell_asleep_at = _location_name()
		if passed_out and Backcountry.is_backcountry(region.region_id):
			fell_asleep_at = "backcountry:" + fell_asleep_at
		_enter_region(Park.HOME_REGION, Park.HOME_SPAWN)
	GameClock.start_new_day()
	# sleeping through the winter: every day still turns over (food spoils,
	# the seasons change), you just don't see them
	for i in extra_nights:
		GameClock.start_new_day()
	if extra_nights > 0:
		message_extra = "You slept through to %s %d. The Tioga Road is open." % [GameClock.SEASON_NAMES[GameClock.season], GameClock.day]
	if forage:
		await forage.respawn()
	# A new season brings up different plants for the press book.
	var plants := PlantSpawner.attach(region)
	if plants:
		await plants.refresh()
	player.global_position = camp.at if not camp.is_empty() else region.get_spawn(wake_spawn).global_position
	var ranger: Sprite2D = null
	if not camp.is_empty() and not camp.problems.is_empty():
		# standing over your tent when you wake
		ranger = Backpacking.ranger_figure()
		region.entities.add_child(ranger)
		ranger.global_position = player.global_position + RANGER_BESIDE
	player.lie_down(false)
	player.facing = Vector2i.DOWN
	player.interaction_area.position = Vector2(player.facing) * 24.0
	_update_seam(true)
	_fit_camera()
	_settle_view()
	await _unstick_player()
	var saved := SaveManager.save_game()

	await _reveal()
	if ranger:
		var morning := Backpacking.ranger_morning(camp.problems)
		player.facing = Vector2i.RIGHT
		await DialogueBox.say_to(player, morning.lines)
		night_out = morning.summary
		saved = SaveManager.save_game()
		if is_instance_valid(ranger):
			ranger.frame = CharacterSheet.frame(ranger.texture, Vector2i.RIGHT, CharacterSheet.Col.STEP_A)
			var leave := ranger.create_tween()
			leave.tween_property(ranger, "global_position", ranger.global_position + Vector2(140, 0), 1.6)
			leave.parallel().tween_property(ranger, "modulate:a", 0.0, 1.6)
			leave.tween_callback(ranger.queue_free)
	player.pose("arms_up", 1.0) # a morning stretch
	var save_status := "Your game was saved." if saved else "Couldn't save. Check that the game can write to its save folder."
	var message := "Good morning! " + save_status
	if night_out != "":
		message = "Good morning in %s! %s\n%s" % [region.display_name, save_status, night_out]
	elif passed_out and fell_asleep_at.begins_with("backcountry:"):
		message = "You fell asleep on the trail at %s. A ranger on patrol walked you down and drove you back to camp." % fell_asleep_at.trim_prefix("backcountry:")
	elif passed_out and fell_asleep_at != "":
		message = "You fell asleep at %s. A ranger drove you back to camp." % fell_asleep_at
	elif passed_out:
		message = "You stayed out too late and passed out..."
	if message_extra != "":
		message += "\n" + message_extra
	var sky_note := Climate.forecast_note()
	if sky_note != "":
		message += "\n" + sky_note
	var cold_note := Warmth.morning_note()
	if cold_note != "":
		message += "\n" + cold_note
	if Perks.has("high_country_timing") and GameClock.season == GameClock.Season.SUMMER:
		var storm := HighCountry.storm_hour()
		if storm > 0.0:
			var sh := int(round(storm))
			var h12 := sh % 12
			message += "\nHigh-country forecast: afternoon storm expected over Tuolumne around %d %s." % [12 if h12 == 0 else h12, "AM" if sh < 12 else "PM"]
	if Larder.last_spoiled != "":
		message += "\n" + Larder.last_spoiled
	if Camp.last_spoiled != "":
		message += "\n" + Camp.last_spoiled
	hud.show_message(message)
	if passed_out:
		_show_bear_tracks() # once per pass-out, so it never repeats on later mornings
	_set_paused(false)
	_busy = false


## Sleeps the night where you stand, camped with the backpacking pack
## (CampSpot): you wake up at [param at] in this region. [param problems]
## are the Leave No Trace rules broken there (Backpacking.problems); with
## any, a wilderness ranger is waiting in the morning.
func camp_out(at: Vector2, problems: Array) -> void:
	if _busy:
		return
	_camp_out = {"at": at, "problems": problems}
	await sleep()


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
## if that spot exists, and otherwise keeps their position. With
## [param staged_seams] a region beside the spot that isn't set up yet is
## left for _settle_seams to lay out over the next frames.
func _enter_region(id: String, spawn_name := "", staged_seams := false) -> void:
	# the fires and falls here fade out instead of stopping dead
	Sound.let_go(region)
	var left := region.region_id if region else ""
	_drop_seam()
	var at := player.global_position
	if player.get_parent():
		player.get_parent().remove_child(player)
	if region:
		remove_child(region)
	region = _get_region(id)
	RegionTextures.restore(region)
	add_child(region)
	move_child(region, 0)
	var spawn: Marker2D = region.get_spawn(spawn_name) if spawn_name != "" else null
	if spawn:
		at = spawn.global_position
	elif spawn_name != "":
		push_warning("Region %s has no spawn point named %s" % [id, spawn_name])
	# On the spot before joining the region: added where they stood in the
	# last one, an exit here at that spot (the rooms' doors all sit at the
	# bottom middle) would see them and fire as soon as they arrive.
	player.position = region.entities.to_local(at)
	region.entities.add_child(player)
	player.global_position = at
	_arrived_at = at
	if spawn:
		_face_away_from_way_back(left)
	# Beside a seam, lay the next region out now, while the screen is dark,
	# so the camera starts out looking over the edge.
	_update_seam(not staged_seams, staged_seams)
	_fit_camera()
	_settle_view()
	_arrive()
	stream.sync()


## Frames the view where the player has just arrived, so it shows settled
## from the first frame: the drawn player on the player (no glide from the
## place left behind), the tilt for here and no lead, the camera's smoothing
## caught up, and the view moved there this frame (not on the camera's next
## turn, which a door's wipe or a fade would show as a slide).
func _settle_view() -> void:
	var camera := _camera()
	(player.get_node("SmoothMotion") as SmoothMotion).settle()
	framing.settle(region, player, camera)
	camera.reset_smoothing()
	camera.force_update_scroll()
	LandmarkFraming.set_offset_on_pixel(camera, camera.offset)


## All RegionDoor and RegionExit nodes in [param r], cached on the region.
static func _region_ways(r: Region) -> Array:
	if not r.has_meta("region_ways"):
		var ways: Array = []
		for node in r.find_children("*", "", true, false):
			if node is RegionDoor or node is RegionExit:
				ways.append(node)
		r.set_meta("region_ways", ways)
	return r.get_meta("region_ways")


## Through a door or along a way, the player arrives facing on into the new
## place, away from the way back to [param left] beside them, instead of
## however they faced when they left (often into the wall by the door).
func _face_away_from_way_back(left: String) -> void:
	if left == "" or left == region.region_id:
		return
	var at := player.global_position
	var nearest := FACE_AWAY_NEAR
	var away := Vector2.ZERO
	for node in _region_ways(region):
		if not is_instance_valid(node) or node.target_region != left:
			continue
		var gap := at - (node as Node2D).global_position
		var dist := gap.length()
		if dist < nearest and dist > 1.0:
			nearest = dist
			away = gap
	if away == Vector2.ZERO:
		return
	if absf(away.x) > absf(away.y):
		player.facing = Vector2i.RIGHT if away.x > 0.0 else Vector2i.LEFT
	else:
		player.facing = Vector2i.DOWN if away.y > 0.0 else Vector2i.UP
	player.interaction_area.position = Vector2(player.facing) * 24.0


## Everything that follows the player into a region, by a door or a fade or
## across a seam.
func _arrive() -> void:
	# first, so everything below (and every region_changed listener) asks
	# about the weather and snow of where you are now
	Climate.arrive(region.region_id, region.hub_id)
	$DayNight.visible = not region.indoors
	Warmth.outdoors = not region.indoors
	if region.region_id == "mirror_lake" and GameClock.season == GameClock.Season.FALL:
		QuestLog.mark_event("saw_dry_mirror_lake", "Mirror Lake has dried back to a sandy meadow for the fall.")
	if forage:
		forage.refresh()
	var plants := PlantSpawner.attach(region)
	if plants:
		plants.refresh()
	if not region.indoors:
		Chongo.visit(region)
	RoomWindows.attach(region)
	region_changed.emit(region)
	_update_location()
	_preload_neighbors()
	_budget_textures()


## Region [param id], from those visited this session, or made now (with its
## story, saved state, sounds and lights) on the first visit.
func _get_region(id: String) -> Region:
	while not _regions.has(id):
		_set_up_step(id)
	return _regions[id]


## Sets region [param id] up for its first visit a step at a time, one step a
## call, so walking up to a seam never stalls a frame on it: makes it, then
## gives it its story, saved state and sounds, then its light (a slice of
## its sprites a call, LIT_BUDGET_USEC long, unless [param all_at_once]).
## Once done it is in [member _regions].
func _set_up_step(id: String, all_at_once := true) -> void:
	var made: Region = _setting_up.get(id)
	var step: int = made.get_meta("set_up_step", 0) if made else 0
	match step:
		0:
			made = _load_region_scene(id).instantiate()
			_setting_up[id] = made
		1:
			# The story and saved state need it in the tree (its Entities ready).
			add_child(made)
			StoryContent.attach(made)
			SaveManager.restore(made)
			_connect_tents(made)
			SoundEmitter.attach_waterfalls(made)
			SoundEmitter.attach_rivers(made)
			SunShadows.attach(made)
			LampLights.attach(made)
			remove_child(made)
		2:
			# the lit material and wind sway, sprite by sprite (most of the
			# sprites in a big region), a slice a call while walking
			if not made.has_meta("lit_sprites"):
				made.set_meta("lit_sprites", LitSprites.sprites_in(made))
			var sprites: Array = made.get_meta("lit_sprites")
			var from: int = made.get_meta("lit_next", 0)
			var until := Time.get_ticks_usec() + LIT_BUDGET_USEC
			while from < sprites.size() and (all_at_once or Time.get_ticks_usec() < until):
				var raw: Variant = sprites[from]
				if is_instance_valid(raw):
					var sprite := raw as Sprite2D
					LitSprites.attach_sprite(sprite)
					Wind.attach_sprite(sprite)
				from += 1
			if from < sprites.size():
				made.set_meta("lit_next", from)
				return
			made.remove_meta("lit_sprites")
			made.remove_meta("lit_next")
		_:
			LitSprites.attach_ground(made)
			made.remove_meta("set_up_step")
			_setting_up.erase(id)
			_regions[id] = made
			return
	made.set_meta("set_up_step", step + 1)


## Is region [param id] ready to show without waiting on the disk: visited
## already, or loaded in the background?
func _region_ready(id: String) -> bool:
	var path := region_scene_path(id)
	# Part way set up counts: its first step takes the background-loaded
	# scene, which then isn't cached any more, and the rest never came.
	return _regions.has(id) or _setting_up.has(id) or (_preloaded.has(path) or ResourceLoader.has_cached(path)) and not _loading(id)


## Is the disk still being read for region [param id]: its scene, or the
## normal maps and story scenes that go with it, waiting or loading now?
func _loading(id: String) -> bool:
	var path := region_scene_path(id)
	if _preloading == path or path in _preload_queue:
		return true
	for extra in _extra_loads(path):
		if _preloading == extra or extra in _preload_queue:
			return true
	return false


## What else is read for the region scene at [param path] once it's loaded:
## the story scenes laid over it (StoryContent) and the normal maps of the
## sprites in both (LitSprites). Worked out once, after the scene is read.
func _extra_loads(path: String) -> Array[String]:
	var known: Array[String] = []
	if _extra.has(path):
		known.assign(_extra[path])
		return known
	if not (_preloaded.has(path) or ResourceLoader.has_cached(path)):
		return known
	for scene in [path] + StoryContent.overlay_paths(path.get_file().get_basename()):
		if scene != path:
			known.append(scene)
		for normal in LitSprites.normals_for_scene(scene):
			if not normal in known:
				known.append(normal)
	_extra[path] = known
	return known


## Puts region [param id] at the front of the background loads, if it isn't
## loaded or set up yet.
func _want_loaded(id: String) -> void:
	var path := region_scene_path(id)
	if id == "" or _regions.has(id) or _setting_up.has(id) or _preloaded.has(path) or _preloading == path \
			or ResourceLoader.has_cached(path) or not ResourceLoader.exists(path):
		return
	_preload_queue.erase(path)
	_preload_queue.push_front(path)


## Sets region [param id] up behind a cover (the door's picture or the trip
## map): waits for the background load of it (at most PREPARE_WAIT
## seconds), then sets it up a few steps a frame. Done at once if there is
## nothing to wait for.
func _prepare_region(id: String) -> void:
	if _regions.has(id) or not ResourceLoader.exists(region_scene_path(id)):
		return
	_want_loaded(id)
	var started := Time.get_ticks_msec()
	while not _regions.has(id):
		if _loading(id) and Time.get_ticks_msec() - started < PREPARE_WAIT * 1000.0:
			await get_tree().process_frame
			continue
		var until := Time.get_ticks_usec() + PREPARE_BUDGET_USEC
		while not _regions.has(id) and Time.get_ticks_usec() < until:
			_set_up_step(id)
		if not _regions.has(id):
			await get_tree().process_frame


## After _enter_region(..., true): lays out the region beside the arrival
## spot, if one is near and wasn't set up yet, setting it up a step a frame
## behind the cover; then snaps the camera to the view it gives.
func _settle_seams() -> void:
	var started := Time.get_ticks_msec()
	while Time.get_ticks_msec() - started < PREPARE_WAIT * 1000.0:
		var pending := _seam_targets_pending()
		if pending.is_empty():
			break
		for id in pending:
			_want_loaded(id)
		var until := Time.get_ticks_usec() + PREPARE_BUDGET_USEC
		for id in pending:
			if not _region_ready(id):
				continue
			while not _regions.has(id) and Time.get_ticks_usec() < until:
				_set_up_step(id)
		await get_tree().process_frame
	_update_seam(true)
	_fit_camera()
	_settle_view()


## The regions past the seams near the player that aren't set up yet.
func _seam_targets_pending() -> Array[String]:
	var pending: Array[String] = []
	if region == null or region.indoors:
		return pending
	var at := region.to_local(player.global_position)
	var bounds := region.get_bounds()
	for exit in _seam_exits(region):
		var id: String = exit.target_region
		if _regions.has(id) or id in pending or not ResourceLoader.exists(region_scene_path(id)):
			continue
		if Seam.edge_gap(bounds, region.to_local(exit.global_position), at) < SEAM_FAR:
			pending.append(id)
	return pending


## Waits for the frames after a new place is laid out to come quick again,
## the one settle step every transition uses (see Transition.settle).
func _settle() -> void:
	await Transition.settle(self)


## Lays the next region beside this one while the player is near a seam
## (the nearest open stretch of edge, within SEAM_NEAR; see Seam.span), and
## takes it away again once they have walked off, past SEAM_FAR. Walking
## about, a region set up for the first time waits for the next frame;
## [param now] (arriving behind a fade) does it all at once. [param busy_ok]
## lays out only regions already set up, even while World is busy.
func _update_seam(now := false, busy_ok := false) -> void:
	if region == null or (_busy and not now and not busy_ok) or region.indoors:
		return
	var at := region.to_local(player.global_position)
	var bounds := region.get_bounds()
	var best: Seam = null
	var best_gap := SEAM_NEAR
	var made := false
	for exit in _seam_exits(region):
		# a rough guide first: is the player near that edge at all?
		if Seam.edge_gap(bounds, region.to_local(exit.global_position), at) >= SEAM_FAR:
			continue
		if not (now or _region_ready(exit.target_region)):
			continue
		# Setting up a region for the first time takes a few frames: a
		# step a frame, and it's laid out once it's ready.
		if not _regions.has(exit.target_region) and not now:
			if not made and not busy_ok:
				made = true
				_set_up_step(exit.target_region, false)
			continue
		var found := _seam_for(exit)
		if found == null:
			continue
		var gap := found.gap_to(at)
		# The one laid out now stays until the player is well away from it
		# (SEAM_FAR), or clearly at another stretch of the same edge.
		if _same_seam(found, seam):
			gap = gap - SEAM_SWAP if gap < SEAM_FAR else INF
		if gap < best_gap:
			best = found
			best_gap = gap
	if _same_seam(best, seam):
		return
	_lay_seam(best)


## Lays [param next] out beside this region (or none, if null), in place of
## the seam laid out now.
func _lay_seam(next: Seam) -> void:
	_drop_seam()
	if next == null:
		return
	seam = next
	seam.neighbor.position = seam.offset
	RegionTextures.restore(seam.neighbor)
	add_child(seam.neighbor)
	seam.open(region)
	# behind the region the player is in, which draws over its own edges
	move_child(seam.neighbor, 0)
	_fit_camera()
	stream.sync()


## Do [param a] and [param b] lay out the same neighbor through the same
## exit? (The seam back after a crossing is a new Seam for the same edge.)
static func _same_seam(a: Seam, b: Seam) -> bool:
	if a == null or b == null:
		return a == b
	return a == b or (a.exit == b.exit and a.neighbor == b.neighbor)


## The walking exits on this region's edges that may be seams.
func _seam_exits(r: Region) -> Array:
	if not r.has_meta("seam_exits"):
		r.set_meta("seam_exits", Seam.candidates(r))
	return r.get_meta("seam_exits")


## The seam through [param exit], worked out once the region it leads to is
## loaded; null if the two maps don't meet edge to edge there.
func _seam_for(exit: RegionExit) -> Seam:
	var known: Dictionary = _seams.get_or_add(region.region_id, {})
	if not known.has(exit.name):
		var neighbor := _get_region(exit.target_region)
		known[exit.name] = Seam.make(region, exit, neighbor)
	return known[exit.name]


## Takes the neighbor away (it stays in memory with the other visited regions).
func _drop_seam() -> void:
	if seam == null:
		return
	seam.close()
	if seam.neighbor.get_parent() == self:
		remove_child(seam.neighbor)
	seam.neighbor.position = Vector2.ZERO
	seam = null
	if region:
		_fit_camera()
	stream.sync()


func _physics_process(_delta: float) -> void:
	if seam and not _busy and seam.is_across(region.to_local(player.global_position), region.get_bounds()):
		_cross_seam()
	elif not _busy and region and not region.indoors and not _seam_exits(region).is_empty():
		_keep_on_map()


## Some map rims have gaps (where a river runs off the edge), and walking
## off the map there before the region past it is ready would leave the
## player in the void: hold them on the edge until it's laid out.
func _keep_on_map() -> void:
	var bounds := region.get_bounds()
	var at := region.to_local(player.global_position)
	if bounds.has_point(at) or (seam and seam.neighbor_bounds().has_point(at)):
		return
	player.global_position = region.to_global(at.clamp(bounds.position, bounds.end - Vector2.ONE))


## The player has walked over the seam: the neighbor becomes the region they
## are in, and this one the neighbor behind them. Both shift so the one the
## player is in sits at the origin again, and the player and camera shift
## with them, so nothing moves on screen.
func _cross_seam() -> void:
	var behind := region
	var back := seam.reversed(behind)
	# The rims stay open; the seam back is the one that closes them later.
	back._opened = seam._opened
	back._blended_a = seam._blended_a
	back._blended_b = seam._blended_b
	seam._opened = []
	seam._blended_a = null
	seam._blended_b = null
	var shift := -seam.offset
	var camera := _camera()
	# Where the camera's smoothing had got to (the view, less its offset),
	# for _hand_camera_over to carry on from this frame.
	_crossed_view = camera.get_screen_center_position() - camera.offset + shift
	_crossed = true
	var at := player.global_position + shift
	region = seam.neighbor
	region.position = Vector2.ZERO
	# before the player moves in, so the exit back they land on stays quiet
	seam = back
	_known_back(behind, back)
	player.get_parent().remove_child(player)
	region.entities.add_child(player)
	player.global_position = at
	_arrived_at = at
	(player.get_node("SmoothMotion") as SmoothMotion).shift(shift)
	_fit_camera()
	framing.crossed(region, shift)
	seam_crossed.emit(shift)
	_arrive()
	stream.sync()


## Just after crossing a seam, before the camera moves this frame (and after
## SmoothMotion has placed it on the drawn player): the camera's smoothing
## was in the old region's pixels, so start it afresh here and carry its lag
## over through the offset (LandmarkFraming.carry), one frame's easing on,
## as the camera would have moved. The view glides on as if nothing changed.
func _hand_camera_over() -> void:
	_crossed = false
	var camera := _camera()
	var target := camera.global_position
	var eased := clampf(camera.position_smoothing_speed * get_process_delta_time(), 0.0, 1.0)
	framing.carry = (_crossed_view - target) * (1.0 - eased)
	camera.offset = Vector2(framing.carry.x + framing.lead.x, framing.tilt + framing.carry.y + framing.lead.y)
	camera.reset_smoothing()
	LandmarkFraming.set_offset_on_pixel(camera, camera.offset)


## Remembers the seam back the way the player came, so it lines up exactly.
func _known_back(behind: Region, back: Seam) -> void:
	if back.exit:
		var known: Dictionary = _seams.get_or_add(region.region_id, {})
		var seen: Seam = known.get(back.exit.name)
		if seen == null or seen.offset != back.offset:
			known[back.exit.name] = back
	behind.position = back.offset


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
		for node in _region_ways(region):
			if is_instance_valid(node):
				targets.append(node.target_region)
		region.set_meta("exit_targets", targets)
	var ids: Array[String] = []
	ids.append_array(region.get_meta("exit_targets"))
	ids.append(region.hub_id)
	ids.append(Park.HOME_REGION)
	# The hubs down the road arrive behind the trip map, which waits for
	# them, so they only load ahead where there's memory to spare: a whole
	# hub's pictures are a lot of video memory for an older computer.
	if not Settings.low() and Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED) < PRELOAD_HUBS_UNDER:
		for leg in Park.legs_from(region.hub_id):
			var hub := Park.get_hub(leg.to)
			ids.append(hub.arrival_region if hub.arrival_region != "" else hub.id)
	# Regions kept from earlier visits that gave back their ground pictures
	# (RegionTextures) get them loaded again ahead, like a new region.
	var pictures: Array[String] = []
	for id in ids:
		var kept: Region = _regions.get(id)
		if kept and RegionTextures.is_released(kept):
			pictures.append_array(RegionTextures.paths(kept))
	_let_go_of_preloads(ids, pictures)
	for path in pictures:
		if not (_warm.has(path) or _preloading == path or path in _preload_queue or ResourceLoader.has_cached(path)):
			_preload_queue.append(path)
	for id in ids:
		var path := region_scene_path(id)
		if id == "" or _regions.has(id) or _preloaded.has(path) or _preloading == path or path in _preload_queue \
				or ResourceLoader.has_cached(path) or not ResourceLoader.exists(path):
			continue
		_preload_queue.append(path)


## Lets go of regions loaded ahead that aren't a way on from here any more
## (and their story scenes and normal maps), and of queued loads for them.
## Without this every region ever loaded ahead stayed in memory, with all
## its pictures, though it was never set up; next time it loads again.
func _let_go_of_preloads(wanted_ids: Array[String], pictures: Array[String] = []) -> void:
	var wanted := {}
	for path in pictures:
		wanted[path] = true
	for id in wanted_ids:
		var path := region_scene_path(id)
		wanted[path] = true
		for extra in _extra.get(path, []):
			wanted[extra] = true
	for path: String in _preloaded.keys():
		if not wanted.has(path):
			_preloaded.erase(path)
	for path: String in _warm.keys():
		if not wanted.has(path):
			_warm.erase(path)
	_preload_queue.assign(_preload_queue.filter(func(path: String) -> bool: return wanted.has(path)))


## The regions kept from earlier visits beyond the last few give back their
## ground pictures (RegionTextures), so video memory doesn't grow with every
## area the player has been to. The one they're in, the one laid out beside
## it, and any region being set up keep theirs; the pictures come back before
## a region is laid out again.
func _budget_textures() -> void:
	_recent.erase(region.region_id)
	_recent.push_front(region.region_id)
	var keep := keep_pictures if keep_pictures >= 0 else KEEP_PICTURES_LOW if Settings.low() else KEEP_PICTURES
	var ways_on: Array = region.get_meta("exit_targets", [])
	var kept := 0
	for id: String in _recent.duplicate():
		var r: Region = _regions.get(id)
		if r == null:
			continue
		if r == region or (seam and seam.neighbor == r) or r.is_inside_tree() or r.indoors:
			continue
		# a way on from here is about to be wanted (and is loaded ahead)
		if id in ways_on:
			continue
		if kept < keep:
			kept += 1
		else:
			RegionTextures.release(r)


## Loads the queued regions one at a time on a background thread.
func _pump_preload() -> void:
	if _preloading != "":
		match ResourceLoader.load_threaded_get_status(_preloading):
			ResourceLoader.THREAD_LOAD_IN_PROGRESS:
				return
			ResourceLoader.THREAD_LOAD_LOADED:
				var loaded := ResourceLoader.load_threaded_get(_preloading)
				if loaded is PackedScene and _preloading.begins_with(REGION_DIR):
					_preloaded[_preloading] = loaded
					# its story scenes and normal maps next, ahead of the
					# other regions
					var extra := _extra_loads(_preloading).duplicate()
					extra.reverse()
					for path in extra:
						if not path in _preload_queue and not ResourceLoader.has_cached(path):
							_preload_queue.push_front(path)
				elif loaded:
					_warm[_preloading] = loaded
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
				_arrived_at = spot
				# the seam and limits were picked for the spawn
				_update_seam(true)
				_fit_camera()
				_settle_view()
				return


func _connect_tents(root: Node) -> void:
	for node in root.find_children("*", "StaticBody2D", true, false):
		if node.has_signal("sleep_requested") and not node.is_connected("sleep_requested", sleep):
			node.connect("sleep_requested", sleep)
		if node.has_signal("rest_requested") and not node.is_connected("rest_requested", rest):
			node.connect("rest_requested", rest)


## Sleeps [param nights] nights in a row at home, waking on the last
## morning: the tent's "sleep through to the thaw" while the snow has the
## high country shut.
func rest(nights: int) -> void:
	await sleep(false, "", maxi(nights - 1, 0))


func _camera() -> Camera2D:
	return player.get_node("Camera")


## Keeps the camera on the map, or beside a seam on the map and the next
## one. Where one is wider than the other, the SeamBackdrop forest fills in.
func _fit_camera() -> void:
	var camera := _camera()
	var bounds := region.get_bounds()
	if seam:
		bounds = bounds.merge(seam.neighbor_bounds())
	camera.limit_left = floori(bounds.position.x)
	camera.limit_top = floori(bounds.position.y)
	camera.limit_right = ceili(bounds.end.x)
	camera.limit_bottom = ceili(bounds.end.y)
	if seam:
		var maps: Array[Rect2] = [region.get_bounds(), seam.neighbor_bounds()]
		backdrop.cover(bounds, maps, [SeamBackdrop.skies_of(region, maps[0]), SeamBackdrop.skies_of(seam.neighbor, maps[1])])
	else:
		backdrop.cover(Rect2())


func _set_paused(paused: bool) -> void:
	player.can_act = not paused
	GameClock.paused = paused


## Where the player is, for the save menus (see SaveManager.slot_info).
func location_name() -> String:
	return _location_name() if region and player else ""


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
	# (not before the save has loaded or the new game is set up)
	if _started:
		for found in Discoveries.visit(region, place):
			hud.show_discovery(found)


func get_offstage_persist_nodes() -> Array[Node]:
	var nodes: Array[Node] = []
	var offstage: Array = _regions.values()
	# Part way set up and given its saved state already (step 1 of
	# _set_up_step took it out of SaveManager's pending data).
	for made: Region in _setting_up.values():
		if int(made.get_meta("set_up_step", 0)) >= 2:
			offstage.append(made)
	for cached: Region in offstage:
		if cached != region and not cached.is_inside_tree():
			for node in cached.find_children("*", "", true, false):
				if node.is_in_group("persist"):
					nodes.append(node)
	return nodes


func save_data() -> Dictionary:
	return {"region": region.region_id}


func load_data(_data: Dictionary) -> void:
	pass # The saved region was loaded first, in _ready().
