extends Node
## Headless test that moving between areas carries on smoothly instead of
## starting afresh: walking over a seam the petals in the air, the birds
## pecking about, a deer walking by, the tracks in the snow, the cloud
## shadows, the morning mist and a bird's call all stay where they were on
## screen (World.seam_crossed); and going through a door the campfire you
## leave fades out (Sound.let_go) while the place sounds of the new one fade
## in (SoundEmitter.FADE_IN), instead of cutting off and starting at full.
## Run: godot --headless --path . res://tests/continuity_test.tscn
## Exit code is the number of failed checks. Uses its own save.

## Weather table dates (Weather.on_day, year 1): spring day 3 is dry (petals
## on the breeze), winter day 14 has deep snow on a clear day.
const PETAL_DAY := 3
const SNOW_DAY := 14

var failures := 0
var world: Node


func check(cond: bool, what: String) -> void:
	print(("PASS  " if cond else "FAIL  ") + what)
	if not cond:
		failures += 1


func _ready() -> void:
	SaveManager.save_path = "user://continuity_test_save.json"
	SaveManager.delete_save()
	GameClock.year = 1
	_set_day(GameClock.Season.WINTER, SNOW_DAY, 12.0)
	world = load("res://scenes/world/world.tscn").instantiate()
	add_child(world)
	await get_tree().process_frame
	await get_tree().process_frame
	await world.go_to_region("yosemite_village", "west_road")
	_set_day(GameClock.Season.WINTER, SNOW_DAY, 12.0)
	for i in 10:
		await get_tree().process_frame
	await _walk_over_in_snow()
	_test_shifts()
	await _test_petals_and_calls()
	await _test_place_sounds()
	world.queue_free()
	await get_tree().process_frame
	SaveManager.delete_save()
	print("%d failure(s)" % failures)
	get_tree().quit(failures)


func _set_day(season: int, day: int, hour: float) -> void:
	GameClock.season = season
	GameClock.day = day
	GameClock.minutes = int(hour * 60.0)
	GameClock.paused = true


func _child(type: Variant) -> Node:
	for child in world.get_children():
		if is_instance_of(child, type):
			return child
	return null


func _view_center() -> Vector2:
	return (world.player.get_node("Camera") as Camera2D).get_screen_center_position()


## Walks left from the Village into Leidig Meadow, with a bird pecking and a
## deer walking just behind, until a step past the edge.
func _walk_over_in_snow() -> void:
	var critters: Critters = _child(Critters)
	var deer: Deer = _child(Deer)
	var prints: Footprints = world.get_node("Footprints")
	var bird: Dictionary = {}
	var animal: Wanderer = null
	var bird_on_screen := Vector2.ZERO
	var deer_on_screen := Vector2.ZERO
	var prints_before := 0
	var crossed := false
	Input.action_press("move_left")
	for i in 900:
		var region: Region = world.region
		var at: Vector2 = region.to_local(world.player.global_position)
		if bird.is_empty() and world.seam and at.x - region.get_bounds().position.x < 80.0:
			bird = critters.add_bird("stellers_jay", world.player.global_position + Vector2(90, 20))
			animal = deer.add_group(world.player.global_position + Vector2(140, -40), world.player.global_position + Vector2(400, -40))
		if not bird.is_empty():
			bird_on_screen = bird.pos - _view_center()
			if is_instance_valid(animal):
				deer_on_screen = animal.global_position - _view_center()
			prints_before = prints.print_count()
		await get_tree().process_frame
		if world.region != region:
			crossed = true
			# the camera hands over as this frame is drawn: look a frame on
			# (the walk moves things a step or two more)
			await get_tree().process_frame
			break
	Input.action_release("move_left")
	check(crossed and world.region.region_id == "leidig_meadow", "walked over the seam into Leidig Meadow")
	check(not bird.is_empty() and bird in critters._birds, "the jay pecking by the edge is still there over the seam")
	if not bird.is_empty():
		var moved: float = (bird.pos - _view_center() - bird_on_screen).length()
		check(moved < 24.0, "and stays where it was on screen (moved %.1f px)" % moved)
	check(is_instance_valid(animal) and animal in deer._animals, "the deer walking by is still there over the seam")
	if is_instance_valid(animal):
		var moved := (animal.global_position - _view_center() - deer_on_screen).length()
		check(moved < 24.0, "and stays where it was on screen (moved %.1f px)" % moved)
		check(animal.target.distance_to(animal.global_position) < 600.0, "and heads on the way it was going, not back over the map")
	check(prints_before > 0, "the walk left tracks in the snow (%d)" % prints_before)
	check(prints.print_count() >= prints_before, "and the trail stays behind you over the seam (%d of %d)" % [prints.print_count(), prints_before])
	# walking on a while, the animals left behind go once out of sight
	for i in 20:
		await get_tree().physics_frame


## The sky things World moves at a seam, one at a time.
func _test_shifts() -> void:
	var by := Vector2(-1234, 56)
	var clouds: Node = world.get_node("CloudShadows")
	var drift: Vector2 = clouds._drift
	var air: Node = world.get_node("ValleyAir")
	var anchor: Vector2 = air._anchor
	world.seam_crossed.emit(by)
	check(clouds._drift == drift - by, "the cloud shadows move with the world over a seam")
	check(air._anchor.is_equal_approx(anchor + by), "and so does the morning mist")
	var falcons: Falcons = _child(Falcons)
	var falcon := {"pos": Vector2(10, 20), "vel": Vector2(5, 0), "height": 80.0}
	falcons._falcons.append(falcon)
	world.seam_crossed.emit(by)
	check(falcon.pos == Vector2(10, 20) + by and falcon.vel == Vector2(5, 0), "a falcon in the sky moves with it, at the same speed")
	falcons._falcons.erase(falcon)
	# a door starts the tracks afresh; a seam (just above) doesn't
	var prints: Footprints = world.get_node("Footprints")
	world.region_changed.emit(world.region) # (the one after the falcon's seam)
	prints._add(Vector2(5, 5), 1.0, true)
	world.region_changed.emit(world.region)
	check(prints.print_count() == 0, "a new place through a door starts with fresh snow")


## Back over the seam on a spring day: the petals on the breeze and a jay's
## call carry on where they were.
func _test_petals_and_calls() -> void:
	_set_day(GameClock.Season.SPRING, PETAL_DAY, 12.0)
	var weather: Weather = world.get_node("Weather")
	for i in 5:
		await get_tree().process_frame
	check(weather._pos.size() > 0, "petals drift in the spring air (%d)" % weather._pos.size())
	var call := Sound.play_call("call_jay")
	var before := PackedVector2Array()
	var call_before := Vector2.ZERO
	var crossed := false
	Input.action_press("move_right")
	for i in 900:
		var region: Region = world.region
		before = PackedVector2Array()
		var center := _view_center()
		for p in weather._pos:
			before.append(p - center)
		if call:
			call.global_position = center + Vector2(200, -100)
			call_before = call.global_position - center
		await get_tree().process_frame
		if world.region != region:
			crossed = true
			await get_tree().process_frame
			break
	Input.action_release("move_right")
	check(crossed and world.region.region_id == "yosemite_village", "walked back over into the Village")
	# each petal drifts and the view moves a step a frame; the whole lot
	# jumping (or wrapping round) at once would move them hundreds
	var center := _view_center()
	var jumped := 0
	for i in mini(before.size(), weather._pos.size()):
		var now := weather._pos[i] - center
		if now.distance_to(before[i]) > 40.0:
			jumped += 1
	check(before.size() > 0 and jumped <= before.size() / 10, "the petals stay where they were on screen (%d of %d jumped)" % [jumped, before.size()])
	if call:
		var moved := (call.global_position - center - call_before).length()
		check(moved < 24.0, "a jay's call keeps its place beside you (moved %.1f px)" % moved)


## Through a door from beside a campfire: it fades out rather than stopping,
## and coming back out it fades in.
func _test_place_sounds() -> void:
	await world.go_to_region("yosemite_village", "arrival")
	for i in 5:
		await get_tree().process_frame
	var fire: SoundEmitter = null
	for node in world.region.find_children("Sound_campfire", "", true, false):
		fire = node as SoundEmitter
		break
	check(fire != null, "Camp 4 has a campfire to listen to")
	if fire == null:
		return
	world.player.global_position = fire.global_position + Vector2(0, 40)
	world._camera().reset_smoothing()
	for i in 60:
		await get_tree().process_frame
	check(fire.playing and fire.volume_linear > 0.5 * fire.target_volume(), "the fire crackles (%.2f)" % fire.volume_linear)
	var tails := Sound.let_go(world.region)
	check(tails > 0, "leaving, the fire you're sitting by fades out instead of stopping (%d)" % tails)
	# these were only counted; let the door make its own
	for tail: Array in Sound._tails:
		tail[0].queue_free()
	Sound._tails.clear()
	await world.go_to_region("welcome_center", "door")
	check(not Sound._tails.is_empty(), "going in through a door the fire fades out behind you")
	var level: float = Sound._tails[0][0].volume_linear if not Sound._tails.is_empty() else 0.0
	await get_tree().process_frame
	await get_tree().process_frame
	var later: float = Sound._tails[0][0].volume_linear if not Sound._tails.is_empty() else 0.0
	check(later < level or Sound._tails.is_empty(), "softer each frame (%.3f -> %.3f)" % [level, later])
	var waited := 0.0
	while not Sound._tails.is_empty() and waited < 3.0:
		waited += get_process_delta_time()
		await get_tree().process_frame
	check(Sound._tails.is_empty() and waited < Sound.TAIL_FADE * 2.0 + 0.2, "and is gone in a moment (%.2f s)" % waited)
	await world.go_to_region("yosemite_village", "welcome_center_door")
	fire._refresh_level()
	check(fire.volume_linear < fire.target_volume(), "back outside, the fire comes in softly (%.2f of %.2f)" % [fire.volume_linear, fire.target_volume()])
	for i in 120:
		await get_tree().process_frame
	check(is_equal_approx(fire.volume_linear, fire.target_volume()), "up to its level in a moment")
