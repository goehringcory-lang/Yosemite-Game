extends Node
## Checks what makes the park feel lived in: the ground clutter of the areas
## outside the towns (tools/hubs/dress_wilds.gd), people's emotes and life
## while standing about (Emote, NPC.on_line, NPC._idle_life), the cast's
## days (NPC.timetable on people with quests), the story's moments
## (StoryMoments, StoryVista) and the rivers' sound (SoundEmitter.attach_rivers).
## Run: godot --headless --path . res://tests/living_test.tscn
## Exit code is the number of failed checks.

const DressWilds := preload("res://tools/hubs/dress_wilds.gd")
## Areas whose walk grid is checked with and without their clutter.
const WALKED := ["tuolumne_meadows", "wawona", "yosemite_village", "upper_pines"]

var failures := 0


func check(cond: bool, what: String) -> void:
	print(("PASS  " if cond else "FAIL  ") + what)
	if not cond:
		failures += 1


func _ready() -> void:
	SaveManager.save_path = "user://living_test_save.json"
	SaveManager.delete_save()
	var world: Node = load("res://scenes/world/world.tscn").instantiate()
	add_child(world)
	await get_tree().process_frame
	await get_tree().process_frame
	GameClock.paused = true
	GameClock.minutes = 12 * 60
	test_dressing_files()
	for region_id: String in WALKED:
		await world.go_to_region(region_id, "arrival")
		for i in 3:
			await get_tree().physics_frame
		test_dressing(world.region)
	await test_emotes(world)
	await test_cast_days(world)
	await test_moments(world)
	await test_rivers(world)
	SaveManager.delete_save()
	print("OK: %d failure(s)" % failures if failures == 0 else "FAILED: %d failure(s)" % failures)
	get_tree().quit(failures)


# ------------------------------------------------------------------ clutter

func test_dressing_files() -> void:
	for region_id: String in DressWilds.REGIONS:
		var path := "res://scenes/regions/dressing/wild/%s.tscn" % region_id
		check(ResourceLoader.exists(path), "%s has its ground clutter laid out" % region_id)
	for sprite: String in ["wild_needles_a", "wild_cones", "wild_slab_a", "camp_cooler", "camp_crashpad"]:
		var tex := load("res://assets/sprites/clutter/%s.png" % sprite) as Texture2D
		# drawn at 16px and upgraded to the 32px art, like the other clutter
		check(tex != null and tex.get_width() % 2 == 0 and tex.get_width() >= 16, "the %s is drawn at the 32px scale (%s)" % [sprite, tex.get_size() if tex else "missing"])


func test_dressing(region: Region) -> void:
	var id := region.region_id
	var wild := region.get_node_or_null("Entities/WildDressing")
	check(wild != null, "%s adds its ground clutter when it loads" % id)
	if wild == null:
		return
	check(region.entities.find_children("WildDressing", "", false, false).size() == 1, "%s adds it once" % id)
	var detail := wild.get_node_or_null("GroundDetail") as CanvasItem
	check(detail != null and detail.get_child_count() > 0, "%s has things lying on the ground (%d)" % [id, detail.get_child_count() if detail else 0])
	check(detail != null and detail.material is ShaderMaterial, "%s's needles and slabs turn with the seasons, as the ground does" % id)
	# Nothing new stands on a road, trail, lot or bridge.
	var ground := region.get_ground()
	var on_paths := []
	for node in wild.get_children():
		if not node is Node2D or node == detail:
			continue
		var cell := ground.local_to_map(ground.to_local((node as Node2D).global_position))
		var kind := ground.get_cell_atlas_coords(cell).y
		if kind in [Terrain.ROAD, Terrain.TRAIL, Terrain.PARKING, Terrain.BRIDGE, Terrain.PAVED]:
			on_paths.append(String(node.name))
	check(on_paths.is_empty(), "%s: nothing stands on a road, trail, lot or bridge %s" % [id, on_paths])
	# Every spot reachable without the clutter is still reachable with it.
	var with_grid := WalkGrid.of(region)
	var lost := []
	var from: Marker2D = region.get_spawn("arrival")
	var spots: Array[Marker2D] = []
	for parent in ["Markers", "Spawns", "Map/Spawns"]:
		var node := region.get_node_or_null(parent)
		if node:
			for child in node.get_children():
				if child is Marker2D:
					spots.append(child)
	var reach_with := {}
	for spot in spots:
		var path := with_grid.route(with_grid.nearest_open(from.global_position), spot.global_position)
		reach_with[spot.name] = not path.is_empty() and path[path.size() - 1].distance_to(spot.global_position) < 64.0
	# the same walk without the clutter's solid things
	region.remove_meta("walk_grid")
	var solids: Array[CollisionShape2D] = []
	for shape in wild.find_children("*", "CollisionShape2D", true, false):
		if not (shape as CollisionShape2D).disabled:
			(shape as CollisionShape2D).disabled = true
			solids.append(shape)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var bare_grid := WalkGrid.new()
	bare_grid._build(region)
	for spot in spots:
		var path := bare_grid.route(bare_grid.nearest_open(from.global_position), spot.global_position)
		var reach_bare: bool = not path.is_empty() and path[path.size() - 1].distance_to(spot.global_position) < 64.0
		if reach_bare and not reach_with[spot.name]:
			lost.append(String(spot.name))
	for shape in solids:
		shape.disabled = false
	region.set_meta("walk_grid", with_grid)
	check(lost.is_empty(), "%s: the clutter cuts no spot off (%d spots walked to) %s" % [id, spots.size(), lost])


# ------------------------------------------------------------------ people

func test_emotes(world: Node) -> void:
	check(Emote.for_line("Oh! You found it.", "surprised") == "surprised", "a surprised line shows '!'")
	check(Emote.for_line("Thank you, truly.", "happy") == "heart", "a line of thanks shows a heart")
	check(Emote.for_line("That's grand!", "happy") == "glad", "a glad line shows a note")
	check(Emote.for_line("I lost it in the fire.", "sad") == "sad", "a sad line shows a drop")
	check(Emote.for_line("Where did you come up from?", "neutral") == "question", "a question shows '?'")
	check(Emote.for_line("The trail starts by the store.", "neutral") == "", "a plain line shows nothing")
	await world.go_to_region("yosemite_village", "degnans_bakery")
	await get_tree().process_frame
	var degnan := _npc(world.region, "bridget_degnan")
	check(degnan != null, "Bridget Degnan is at the bakery")
	if degnan == null:
		return
	# Only the person speaking, and only while they talk with you.
	degnan.on_line("Bridget Degnan", "Oh! Fresh bread.", "surprised")
	check(degnan.get_node_or_null("Emote") == null, "nobody shows an emote when they aren't talking with you")
	degnan._talking = true
	degnan.on_line("Ansel Adams", "Oh! A print.", "surprised")
	check(degnan.get_node_or_null("Emote") == null, "nor for someone else's line")
	degnan.on_line("Bridget Degnan", "Oh! Fresh bread.", "surprised")
	var bubble := degnan.get_node_or_null("Emote") as Emote
	check(bubble != null and bubble.kind == "surprised", "their own surprised line pops a '!' over their head")
	degnan.on_line("Bridget Degnan", "Oh! And more bread.", "surprised")
	check(degnan.get_children().filter(func(n: Node) -> bool: return n is Emote and not n.is_queued_for_deletion()).size() <= 1, "and never two bubbles at once")
	degnan._talking = false
	# A real conversation shows them too: the box tells whoever speaks.
	var box := DialogueBox.open(world.player)
	degnan._talking = true
	degnan._last_emote = ""
	box.say([{"speaker": "Bridget Degnan", "text": "Thank you for the flour!"}])
	await get_tree().process_frame
	var shown := degnan.get_node_or_null("Emote") as Emote
	check(shown != null and shown.kind == "heart", "a line in the dialogue box pops its emote over the speaker (%s)" % (shown.kind if shown else "none"))
	box.close()
	degnan._talking = false
	# Life while standing about: a breath, a glance round, a wave to a friend.
	for child in degnan.get_children():
		if child is Emote:
			child.free()
	degnan.velocity = Vector2.ZERO
	degnan._route = PackedVector2Array()
	var base: float = degnan._base_offset_y
	var offsets := {}
	for i in 30:
		degnan._idle_life(0.1)
		offsets[degnan._sprite.offset.y] = true
	check(offsets.has(base) and offsets.has(base - 2.0), "standing about, they breathe (the sprite rises and settles)")
	var facings := {}
	degnan._glance = 0.0
	for i in 40:
		degnan._idle_life(0.2)
		facings[degnan.facing] = true
	check(facings.size() >= 2, "and glance about now and then (%d facings)" % facings.size())
	Friendship.points["bridget_degnan"] = Friendship.POINTS_PER_HEART * 2
	degnan._greeted_day = -1
	world.player.global_position = degnan.global_position + Vector2(40, 0)
	degnan._idle_life(0.016)
	var wave := degnan.get_node_or_null("Emote") as Emote
	check(wave != null and wave.kind in ["glad", "heart"], "a friend walking up gets a wave")
	check(degnan.facing == Vector2i.RIGHT, "and they turn to you")
	for child in degnan.get_children():
		if child is Emote:
			child.free()
	degnan._idle_life(0.016)
	check(degnan.get_node_or_null("Emote") == null, "only once a day")
	Friendship.points.erase("bridget_degnan")
	world.player.global_position = world.region.get_spawn("degnans_bakery").global_position


func _npc(region: Region, character_id: String) -> NPC:
	for node in region.find_children("*", "NPC", true, false):
		var npc := node as NPC
		if npc.character and npc.character.id == character_id:
			return npc
	return null


## People with quests keep a day of their own too, and through the middle of
## the day they're at the spot the Journal names.
func test_cast_days(world: Node) -> void:
	for town: String in ["yosemite_village", "curry_village"]:
		await world.go_to_region(town, "arrival")
		await get_tree().process_frame
		var keepers := 0
		for node in world.region.find_children("*", "NPC", true, false):
			var npc := node as NPC
			if npc.character == null or npc.character.visitor or npc.timetable.is_empty():
				continue
			keepers += 1
			check(not npc.character.needs_tribal_review and npc.character.affiliation.find("Miwuk") < 0,
				"%s: %s's day isn't one awaiting tribal review" % [town, npc.character.display_name])
			var stops := NPC.parse_timetable(npc.timetable)
			check(stops[0][1] == npc.spot, "%s: %s's day starts and ends at their spot (%s)" % [town, npc.character.display_name, npc.spot])
			# (lunch is their own: Jennie Curry at the Pavilion, Wren at the shop)
			for minutes in [10 * 60, 11 * 60, 14 * 60, 15 * 60]:
				npc._stops = stops
				check(stops[npc.stop_index(minutes)][1] == npc.spot, "%s: %s is at %s at %d:00" % [town, npc.character.display_name, npc.spot, minutes / 60])
			for stop: Array in stops:
				check(world.region.get_spawn(stop[1]) != null, "%s: %s's stop '%s' is a spot" % [town, npc.character.display_name, stop[1]])
		check(keepers >= 3, "%s: people with quests keep a day (%d)" % [town, keepers])
	# Evenings, the Camp 4 fire and Camp Curry's program draw a crowd.
	var at_fire := 0
	await world.go_to_region("yosemite_village", "arrival")
	for node in world.region.find_children("*", "NPC", true, false):
		var npc := node as NPC
		if npc.timetable.is_empty():
			continue
		npc._stops = NPC.parse_timetable(npc.timetable)
		if npc._stops[npc.stop_index(20 * 60)][1] == "camp_4_fire":
			at_fire += 1
	check(at_fire >= 3, "at 8 PM the Camp 4 fire has company (%d)" % at_fire)
	# A person with quests walks to their next stop when it's time, and stays out at night.
	var adams := _npc(world.region, "ansel_adams")
	adams.travel_speed = 480.0
	GameClock.minutes = 17 * 60 + 35
	adams._routine_check = 0.0
	adams._process(0.016)
	await _until(func() -> bool: return not adams.is_travelling(), 20.0)
	var meadow: Vector2 = world.region.get_spawn("cooks_meadow").global_position
	check(adams.global_position.distance_to(meadow) < 64.0, "Ansel Adams walks out to Cook's Meadow for the evening light (%d px away)" % adams.global_position.distance_to(meadow))
	GameClock.minutes = 23 * 60
	adams._routine_check = 0.0
	adams._process(0.016)
	await _until(func() -> bool: return not adams.is_travelling(), 20.0)
	check(adams.visible, "and doesn't go in at night: people with quests stand at their spot")
	check(NPC.is_dozing_hour(), "late at night they doze on their feet")
	adams.travel_speed = NPC.TRAVEL_SPEED
	GameClock.minutes = 12 * 60


func _until(done: Callable, seconds: float) -> void:
	var left := seconds
	while left > 0.0 and not done.call():
		await get_tree().physics_frame
		left -= get_physics_process_delta_time()


# ------------------------------------------------------------------ story moments

func test_moments(world: Node) -> void:
	var moments: StoryMoments = world.get_node_or_null("StoryMoments")
	check(moments != null, "World keeps the story's moments")
	if moments == null:
		return
	var sightings := {}
	for sighting: Dictionary in GuardianSearch.SIGHTINGS:
		sightings[sighting.quest] = sighting
	for quest_id: String in StoryMoments.MOMENTS:
		check(sightings.has(quest_id), "the moment for %s is one of the Guardian sightings" % quest_id)
		var words := StoryMoments.words_for(quest_id)
		check(words.get("text", "") == sightings.get(quest_id, {}).get("text", "-"), "and its words are the sighting's own (%s)" % quest_id)
		var who := QuestLog.get_character(sightings.get(quest_id, {}).get("who", ""))
		check(who == null or not who.needs_tribal_review, "and its witness isn't someone whose words await tribal review (%s)" % quest_id)
		check(Portraits.for_speaker(words.get("who", "")) != null, "and the witness has a face to show (%s)" % words.get("who", ""))
	# A finished sighting quest waits for a free moment, then plays once.
	moments.seen = PackedStringArray()
	moments.waiting = PackedStringArray()
	moments._on_quest_completed(QuestLog.get_quest("partner_apron"))
	moments._on_quest_completed(QuestLog.get_quest("partner_apron"))
	check(moments.waiting == PackedStringArray(["partner_apron"]), "a sighting coming true queues its moment once")
	world.player.can_act = false
	for i in 90:
		await get_tree().process_frame
	check(moments._playing == null, "it waits while the player is busy")
	world.player.can_act = true
	await _until(func() -> bool: return moments._playing != null, 4.0)
	check(moments._playing != null, "and plays once they're free")
	check(not world.player.can_act and GameClock.paused, "it holds the player and the clock while it plays")
	var vista := moments._playing
	if vista:
		check(vista.get_node_or_null("Canvas/Words") != null and (vista.get_node("Canvas/Words") as Label).text == StoryMoments.words_for("partner_apron").text, "it shows the witness's words")
		check(vista.rise() >= 0.0 and vista.rise() <= 1.0, "the view rises as it plays")
		var down := InputEventAction.new()
		down.action = "ui_cancel"
		down.pressed = true
		vista._input(down)
		await _until(func() -> bool: return moments._playing == null, 4.0)
	check(moments._playing == null and world.player.can_act, "cancel closes it and hands the player back")
	check("partner_apron" in moments.seen and moments.waiting.is_empty(), "it's marked seen")
	moments._on_quest_completed(QuestLog.get_quest("partner_apron"))
	check(moments.waiting.is_empty(), "and never queues again")
	var saved := moments.save_data()
	moments.load_data({})
	check(moments.seen.is_empty(), "(load clears it)")
	moments.load_data(saved)
	check("partner_apron" in moments.seen, "which moments were seen is saved")
	check(ResourceLoader.exists("res://assets/audio/story_sting.wav"), "a moment opens on its own sting")


# ------------------------------------------------------------------ rivers

func test_rivers(world: Node) -> void:
	check(ResourceLoader.exists("res://assets/audio/river.wav"), "the river loop exists")
	await world.go_to_region("tuolumne_meadows", "arrival")
	await get_tree().process_frame
	var rivers: Array[Node] = world.region.find_children("Sound_river*", "", true, false)
	check(rivers.size() >= 4, "the Tuolumne runs audibly through its meadow (%d emitters)" % rivers.size())
	var far_apart := true
	for a in rivers:
		for b in rivers:
			if a != b and (a as Node2D).global_position.distance_to((b as Node2D).global_position) < 32.0 * SoundEmitter.RIVER_BLOCK / 2.0:
				far_apart = false
	check(far_apart, "spread along the bank, not stacked up")
	SoundEmitter.attach_rivers(world.region)
	check(world.region.find_children("Sound_river*", "", true, false).size() == rivers.size(), "attaching twice adds none")
	await world.go_to_region("degnans", "arrival")
	await get_tree().process_frame
	check(world.region.find_children("Sound_river*", "", true, false).is_empty(), "indoors there's no river")


const Terrain := preload("res://tools/mapgen/terrain.gd")
