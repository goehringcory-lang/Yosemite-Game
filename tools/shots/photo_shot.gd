extends Node
## Takes the pictures of photography for the README: the viewfinder on El
## Capitan in the last light with a deer under it, and at the railing at
## Tunnel View; the prints the camera really makes there and around the
## Valley (on each film); the album, a print looked at on its own, Ansel's
## list, and the Controls page with the camera's key.
## Needs a window (not --headless). Environment:
##   SHOT_DIR  folder for the PNGs (default user://)
## Run: SHOT_DIR=/tmp/shots xvfb-run -a godot --path . res://tools/shots/photo_shot.tscn

var world: Node
var dir := "user://"


func _ready() -> void:
	SaveManager.save_path = "user://photo_shot_save.json"
	SaveManager.delete_save()
	if OS.get_environment("SHOT_DIR") != "":
		dir = OS.get_environment("SHOT_DIR")
	world = load("res://scenes/world/world.tscn").instantiate()
	add_child(world)
	await _frames(2)
	GameClock.paused = true
	GameClock.season = GameClock.Season.SUMMER
	GameClock.day = 6
	Weather.today()
	Weather._today = {"snow": 0.0, "rain": 0.0, "clouds": 0.25}
	QuestLog.unlocks.append(Photos.ABILITY)
	Gear.add(Photos.GEAR)
	Gear.add(Photos.LENSES_GEAR)
	var camera := get_tree().get_first_node_in_group("camera_view") as CameraView
	var album := get_tree().get_first_node_in_group("photo_album") as PhotoAlbum

	# El Capitan in the last light, a deer in the meadow under it.
	await _stand_under("el_capitan_meadow", "El Capitan", 18 * 60 + 50)
	var deer: Deer = null
	for child in world.get_children():
		if child is Deer:
			deer = child
	var here: Vector2 = world.player.global_position
	deer.add_group(here + Vector2(-150, -70), here + Vector2(-90, -70), 0, 1)
	await _frames(20)
	Photos.lens = "wide"
	Photos.film = "color"
	camera.open()
	await _aim(camera, "El Capitan", Vector2(0, 60))
	await _frames(10)
	await _snap("photo_viewfinder")
	await _shoot(camera, "photo_print_el_capitan")
	Photos.film = "silver"
	await _shoot(camera, "photo_print_el_capitan_silver")
	Photos.lens = "long"
	camera.nudge(Vector2.ZERO)
	var on_deer: Vector2 = get_viewport().get_canvas_transform() * deer.animals()[0].global_position / UiScale.FACTOR
	camera.nudge(on_deer + Vector2(0, -8) - camera.frame_rect().get_center())
	Photos.film = "color"
	await _frames(4)
	await _snap("photo_viewfinder_long")
	await _shoot(camera, "photo_print_deer")
	camera.close()

	# Half Dome over Mirror Lake at first light, on black and white film.
	await _stand_under("mirror_lake", "Half Dome", 6 * 60 + 40)
	Photos.lens = "wide"
	Photos.film = "silver"
	camera.open()
	await _aim(camera, "Half Dome", Vector2(0, 70))
	await _shoot(camera, "photo_print_half_dome")
	camera.close()

	# Yosemite Falls at noon, in sepia.
	await _stand_under("yosemite_village", "Lower Yosemite Fall", 12 * 60)
	Photos.film = "sepia"
	camera.open()
	await _aim(camera, "Lower Yosemite Fall", Vector2(0, 20))
	await _shoot(camera, "photo_print_falls")
	camera.close()

	# The Three Brothers, alpenglow.
	await _stand_under("leidig_meadow", "Three Brothers", 19 * 60 + 40)
	Photos.film = "color"
	camera.open()
	await _aim(camera, "Three Brothers", Vector2(0, 60))
	await _shoot(camera, "photo_print_three_brothers")
	camera.close()

	# The whole Valley from the railing at Tunnel View.
	GameClock.minutes = 16 * 60
	await world.go_to_region("tunnel_view", "overlook")
	GameClock.paused = true
	world.player.get_node("Camera").reset_smoothing()
	await _frames(30)
	Photos.lens = "wide"
	Photos.film = "color"
	camera.open()
	camera.nudge(Vector2(0, -200))
	await _frames(6)
	await _snap("photo_viewfinder_tunnel_view")
	await _shoot(camera, "photo_print_tunnel_view")
	Photos.film = "silver"
	await _shoot(camera, "photo_print_tunnel_view_silver")
	camera.close()

	# The album, a print on its own, and the list.
	GameClock.minutes = 12 * 60
	camera.open()
	album.open()
	await _frames(12)
	album.move_cursor(Vector2i(0, -1))
	album.move_cursor(Vector2i(0, -1))
	album.move_cursor(Vector2i(-1, 0))
	await _frames(6)
	await _snap("photo_album")
	album.look()
	await _frames(6)
	await _snap("photo_album_look")
	album._look.visible = false
	album.show_page(PhotoAlbum.Page.LIST)
	await _frames(12)
	await _snap("photo_album_list")
	album.close()
	camera.close()
	# The Controls page with the camera's key on it.
	var pause := get_tree().get_first_node_in_group("pause_menu")
	pause.open()
	pause._show_page(PauseMenu.Page.CONTROLS)
	await _frames(12)
	await _snap("photo_controls")
	pause.close()
	SaveManager.delete_save()
	get_tree().quit()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


## Goes to [param region_id] at [param minutes] past midnight and stands at
## the nearest spot below the place called [param place_name] that can be
## walked to from the way in.
func _stand_under(region_id: String, place_name: String, minutes: int) -> void:
	GameClock.minutes = minutes
	await world.go_to_region(region_id, "arrival")
	await _frames(6)
	GameClock.paused = true
	var place := _place(place_name)
	var grid := WalkGrid.of(world.region)
	var start: Vector2 = grid.nearest_open(world.region.get_spawn("arrival").global_position)
	for down in [60, 120, 180, 240, 300, 360, 440, 520, 600]:
		var spot: Vector2 = grid.nearest_open(place.global_position + Vector2(0, down), 3)
		if grid.is_open(spot) and spot.y >= place.global_position.y and not grid.route(start, spot).is_empty():
			world.player.global_position = spot
			break
	print("%s: standing at %s under %s at %s" % [region_id, world.player.global_position, place_name, place.global_position])
	world.player.get_node("Camera").reset_smoothing()
	await _frames(30)
	world.player.get_node("Camera").reset_smoothing()
	await _frames(10)


func _place(place_name: String) -> Place:
	for place in world.region.get_places():
		if place.display_name == place_name:
			return place
	return null


## Puts the middle of the frame on the place called [param place_name],
## [param below] UI pixels under its marker.
func _aim(camera: CameraView, place_name: String, below := Vector2.ZERO) -> void:
	var on_screen: Vector2 = get_viewport().get_canvas_transform() * _place(place_name).global_position / UiScale.FACTOR
	camera.nudge(on_screen + below - camera.frame_rect().get_center())
	await _frames(4)


func _shoot(camera: CameraView, shot_name: String) -> void:
	var photo: Dictionary = await camera.shoot()
	await _frames(4)
	if photo.is_empty():
		print("no photograph for %s" % shot_name)
		return
	print("%s: %s, %d stars, new for the list: %s" % [shot_name, photo.title, photo.stars, str(photo.new.map(func(e: Dictionary) -> String: return e.id))])
	var image := Image.load_from_file(Photos.path_of(photo.id))
	image.resize(image.get_width() * 2, image.get_height() * 2, Image.INTERPOLATE_NEAREST)
	image.save_png("%s/%s.png" % [dir, shot_name])


func _snap(shot_name: String) -> void:
	await _frames(8)
	var image := get_viewport().get_texture().get_image()
	print("window %s" % str(image.get_size()))
	image.save_png("%s/%s.png" % [dir, shot_name])
