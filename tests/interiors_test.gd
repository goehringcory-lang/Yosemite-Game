extends Node
## Checks the insides of the park's buildings (tools/hubs/build_interiors.gd):
## every main building has a door you face and use (it wins over the
## building's own sign), it opens into a room of its own, you arrive inside
## the doorway and walk back out to the doorstep, closed buildings stay shut
## after hours, the Ahwahnee's and the Wawona Hotel's rooms join up both ways,
## and everything you can read inside can be reached and read.
## Run: godot --headless --path . res://tests/interiors_test.tscn
## Exit code is the number of failed checks.

const Builder = preload("res://tools/hubs/build_interiors.gd")

var failures := 0


func check(cond: bool, what: String) -> void:
	print(("PASS  " if cond else "FAIL  ") + what)
	if not cond:
		failures += 1


func _ready() -> void:
	SaveManager.save_path = "user://interiors_test_save.json"
	SaveManager.delete_save()
	Engine.time_scale = 20.0
	var world: Node = load("res://scenes/world/world.tscn").instantiate()
	add_child(world)
	await get_tree().process_frame
	await get_tree().process_frame
	GameClock.paused = true
	GameClock.minutes = 12 * 60
	# Glacier Point and Tuolumne are unlocked by climbs; open them for the tour.
	for hub in ["glacier_point", "tuolumne_meadows"]:
		Park.unlock_hub(hub)

	var builder: Node = Builder.new()
	var specs: Array = builder.rooms()
	builder.free()
	check(specs.size() >= 35, "%d rooms are built" % specs.size())
	var ahwahnee := specs.filter(func(s: Dictionary) -> bool: return s.id.begins_with("ahwahnee_"))
	check(ahwahnee.size() >= 5, "the Ahwahnee has %d rooms inside" % ahwahnee.size())
	var by_id := {}
	for spec: Dictionary in specs:
		by_id[spec.id] = spec

	for spec: Dictionary in specs:
		_check_room_scene(spec)
	for spec: Dictionary in specs:
		if spec.has("outside"):
			await _walk_in_and_out(world, spec)
	await _check_links(world, specs)
	await _check_readables(world, specs)
	await _check_hours(world, by_id)

	world.free()
	SaveManager.delete_save()
	print("\n%s: %d failure(s)" % ["OK" if failures == 0 else "FAILED", failures])
	get_tree().quit(failures)


## The room's scene: indoors, in the right hub, a spot inside each doorway.
func _check_room_scene(spec: Dictionary) -> void:
	var path := "res://scenes/regions/%s.tscn" % spec.id
	if not ResourceLoader.exists(path):
		check(false, "%s has a scene" % spec.id)
		return
	var room: Region = load(path).instantiate()
	var ok: bool = room.region_id == spec.id and room.indoors and room.display_name == spec.name
	for door: Dictionary in spec.doors:
		ok = ok and room.get_spawn(door.get("spot", "door")) != null
	var exits := room.find_children("*", "RegionExit", true, false) + room.find_children("*", "BuildingDoor", true, false)
	check(ok and exits.size() == spec.doors.size(), "%s is an inside room with %d way(s) out" % [spec.name, exits.size()])
	room.free()


## Outside, face the door: it's what the button uses. Go in, arrive in the
## doorway, walk out the front, and land on the doorstep again.
func _walk_in_and_out(world: Node, spec: Dictionary) -> void:
	var outside: String = spec.outside.region
	var player: Player = world.player
	world._enter_region(outside, "")
	var door: BuildingDoor = world.region.find_child("DoorTo" + spec.id.to_pascal_case(), true, false)
	var step: Marker2D = world.region.get_spawn(spec.id + "_door")
	if door == null or step == null:
		check(false, "%s has a door and a doorstep in %s" % [spec.name, outside])
		return
	player.global_position = step.global_position
	player.facing = Vector2i.UP
	player.interaction_area.position = Vector2(0, -24)
	for i in 3:
		await get_tree().physics_frame
	check(not player.test_move(player.global_transform, Vector2.ZERO), "%s: the doorstep is open ground" % spec.name)
	# walk up to the door
	Input.action_press("move_up")
	for i in 40:
		await get_tree().physics_frame
		if player.get_target() == door:
			break
	Input.action_release("move_up")
	check(player.get_target() == door and Player.prompt_for(door).begins_with("Enter"),
		"%s: walking up to it, the door is what you use (%s)" % [spec.name, Player.prompt_for(player.get_target()) if player.get_target() else "nothing"])
	door.interact(player)
	await _settle(world)
	check(world.region.region_id == spec.id, "%s: the door leads inside (now in %s)" % [spec.name, world.region.region_id])
	var inside: Marker2D = world.region.get_spawn("door")
	check(inside != null and player.global_position.distance_to(inside.global_position) < 4.0 and not player.test_move(player.global_transform, Vector2.ZERO),
		"%s: you arrive inside the doorway" % spec.name)
	Input.action_press("move_down")
	for i in 120:
		await get_tree().physics_frame
		if world.region.region_id != spec.id:
			break
	Input.action_release("move_down")
	await _settle(world)
	check(world.region.region_id == outside and player.global_position.distance_to(step.global_position) < 40.0,
		"%s: walking out the front door lands you on its doorstep in %s" % [spec.name, world.region.region_id])


## Rooms joined to rooms (the Ahwahnee, the Wawona Hotel): each way through
## lands on a spot that exists, beside a way straight back.
func _check_links(world: Node, specs: Array) -> void:
	var broken := PackedStringArray()
	var count := 0
	for spec: Dictionary in specs:
		for door: Dictionary in spec.doors:
			if door.side == "front" and spec.has("outside"):
				continue
			count += 1
			world._enter_region(door.to, door.spawn)
			await get_tree().physics_frame
			var there: Region = world.region
			var spot := there.get_spawn(door.spawn)
			if spot == null:
				broken.append("%s -> %s/%s (no spot)" % [spec.id, door.to, door.spawn])
				continue
			var back := (there.find_children("*", "RegionExit", true, false) + there.find_children("*", "BuildingDoor", true, false)).filter(
				func(e: Node2D) -> bool: return e.target_region == spec.id and e.global_position.distance_to(spot.global_position) < 120.0)
			if back.is_empty():
				broken.append("%s -> %s/%s (no way back)" % [spec.id, door.to, door.spawn])
	check(count >= 10 and broken.is_empty(), "%d doors between rooms all lead back the way they came (%s)" % [count, ", ".join(broken)])
	# The Ahwahnee from the front door to a guest room and the Great Lounge's fire.
	world._enter_region("ahwahnee_lobby", "door")
	var lift: BuildingDoor = world.region.find_child("ToAhwahneeMuralRoom", true, false)
	check(lift != null, "the lobby's back door leads to the elevator lobby")
	world._enter_region("ahwahnee_mural_room", "door")
	var elevator: BuildingDoor = world.region.find_child("ToAhwahneeGuestRoom", true, false)
	check(elevator != null and elevator.label.contains("Elevator"), "an elevator goes up to the guest rooms")


## Every sign, panel and readable piece of furniture inside can be walked up
## to and read, and the doors between rooms can be used.
func _check_readables(world: Node, specs: Array) -> void:
	var player: Player = world.player
	var unreadable := PackedStringArray()
	var count := 0
	for spec: Dictionary in specs:
		world._enter_region(spec.id, "door")
		await get_tree().physics_frame
		var targets: Array = world.region.entities.get_children().filter(func(n: Node) -> bool: return n is InfoSign or n is BuildingDoor)
		for target: Node2D in targets:
			count += 1
			if not await _can_use(player, target):
				unreadable.append("%s/%s" % [spec.id, target.name])
	check(count >= 55 and unreadable.is_empty(), "all %d signs and doors inside can be reached and used (%s)" % [count, ", ".join(unreadable)])


## Standing in front of [param target] (below it, facing up) on open floor,
## is it what the button uses? Tries a few spots along its front.
func _can_use(player: Player, target: Node2D) -> bool:
	player.facing = Vector2i.UP
	player.interaction_area.position = Vector2(0, -24)
	for dy in [10.0, 18.0, 26.0]:
		for dx in [0.0, -12.0, 12.0]:
			player.global_position = target.global_position + Vector2(dx, dy)
			await get_tree().physics_frame
			await get_tree().physics_frame
			if not player.test_move(player.global_transform, Vector2.ZERO) and player.get_target() == target:
				return true
	return false


## Buildings with hours: shut at night (a message, and you stay outside),
## open by day. Hotels never close.
func _check_hours(world: Node, by_id: Dictionary) -> void:
	var player: Player = world.player
	world._enter_region("yosemite_village", "degnans_door")
	var degnans: BuildingDoor = world.region.find_child("DoorToDegnans", true, false)
	GameClock.minutes = 23 * 60
	check(not degnans.is_open_now(), "Degnan's is closed at 11 PM")
	degnans.interact(player)
	await _settle(world)
	check(world.region.region_id == "yosemite_village" and world.hud.message_label.text.contains("closed"),
		"a closed door says when it opens (%s)" % world.hud.message_label.text)
	var lodge: BuildingDoor = world.region.find_child("DoorToValleyLodgeLobby", true, false)
	check(lodge.is_open_now(), "the Lodge is open all night")
	GameClock.minutes = 12 * 60
	check(degnans.is_open_now(), "Degnan's is open at noon")
	check(by_id.has("ahwahnee_lobby"), "the Ahwahnee can be entered")


func _settle(world: Node) -> void:
	for i in 60:
		await get_tree().process_frame
		if not world._busy:
			break
	await get_tree().physics_frame
