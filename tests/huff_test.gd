extends Node
## Headless test of HUFF (the employee tent community near Curry Village) and
## the HUFF crew's random after-10PM off-trail forest & boulder parties with
## speakers, dance lights, beer, weed and LSD.
## Run: godot --headless --path . res://tests/huff_test.tscn
## Exit code is the number of failed checks. Uses its own save file.

const Terrain := preload("res://scripts/world/terrain.gd")
const FindWalk := preload("res://scripts/story/find_walk.gd")

var failures := 0
var world: Node


func check(cond: bool, what: String) -> void:
	print(("PASS  " if cond else "FAIL  ") + what)
	if not cond:
		failures += 1


func set_time(season: int, day: int, hour: int, minute := 0) -> void:
	GameClock.season = season
	GameClock.day = day
	GameClock.minutes = hour * 60 + minute


func _ready() -> void:
	await get_tree().process_frame
	SaveManager.save_path = "user://huff_test_save.json"
	SaveManager.delete_save()
	world = load("res://scenes/world/world.tscn").instantiate()
	get_tree().root.add_child(world)
	await get_tree().process_frame
	GameClock.paused = true

	await test_huff_camp()
	test_schedule_randomness()
	await test_all_party_regions_off_trail()
	await test_party_site_and_substances()

	world.queue_free()
	await get_tree().process_frame
	SaveManager.delete_save()
	print("\n%s: %d failure(s)" % ["OK" if failures == 0 else "FAILED", failures])
	get_tree().quit(failures)


func test_huff_camp() -> void:
	set_time(GameClock.Season.SUMMER, 5, 12)
	world._enter_region("curry_village", "plaza")
	await get_tree().physics_frame
	await get_tree().physics_frame
	var region: Region = world.region
	var huff_place: Place = null
	for p: Place in region.get_places():
		if p.display_name == "HUFF":
			huff_place = p
			break
	check(huff_place != null and huff_place.radius > 100.0 and huff_place.show_banner, "Curry Village has the HUFF Place")
	check(region.get_spawn("huff") != null, "Curry Village has a huff spawn marker")
	var tents := region.find_children("HuffTent*", "StaticBody2D", true, false)
	check(tents.size() >= 6, "HUFF has its cluster of employee tents (%d)" % tents.size())
	var huff_sign := region.entities.get_node_or_null("HuffSign") as HuffSign
	var huff_box := region.entities.get_node_or_null("HuffBearBox") as InfoSign
	check(huff_sign != null and "employee tent housing" in huff_sign.text, "HUFF has its entrance signpost")
	check(huff_box != null and "King Cobra" in huff_box.text, "HUFF has a readable employee bear box")
	var grid := WalkGrid.of(region)
	var plaza_pos := region.get_spawn("plaza").global_position
	var huff_pos := region.get_spawn("huff").global_position
	check(not grid.route(plaza_pos, huff_pos).is_empty(), "the player can walk from Curry Village Plaza to HUFF")
	check(not grid.route(region.get_spawn("homestead").global_position, huff_pos).is_empty(), "and from the Homestead orchard gate to HUFF")

	var residents := region.entities.get_children().filter(func(n: Node) -> bool: return n is HuffResident)
	check(residents.size() == 4, "four HUFF employees live in the tent community (%d)" % residents.size())
	for res: HuffResident in residents:
		check(res.character != null and res.character.visitor and QuestLog.get_character(res.character.id) == null,
			"%s is a visitor employee, not in the Register" % res.name)
		check(Portraits.for_speaker(res.character.display_name) != null,
			"%s has a dialogue portrait" % res.character.display_name)
		check(res.is_out(), "%s is around HUFF at noon" % res.character.display_name)
	check(not huff_sign.extra_active() and huff_sign.current_text() == huff_sign.text, "by day the HUFF sign shows only its base text")

	# After 10 PM: residents slip out to the forest party and the sign carries the note.
	set_time(GameClock.Season.SUMMER, 5, 22, 30)
	check(huff_sign.extra_active() and "Follow the bass" in huff_sign.current_text(), "after 10 PM the HUFF sign hints where the speakers went")
	check(residents.all(func(r: HuffResident) -> bool: return not r.is_out()), "HUFF residents head out of camp after 10 PM for the party")
	set_time(GameClock.Season.SUMMER, 5, 12)


func test_schedule_randomness() -> void:
	set_time(GameClock.Season.SUMMER, 4, 21, 50)
	check(HuffParty.where_now() == "", "no forest party before 10:00 PM")
	set_time(GameClock.Season.SUMMER, 4, 22, 0)
	check(HuffParty.where_now() in HuffParty.PARTY_REGIONS, "a forest party starts at 10:00 PM (%s)" % HuffParty.where_now())
	set_time(GameClock.Season.SUMMER, 4, 25, 30)
	check(HuffParty.where_now() in HuffParty.PARTY_REGIONS, "still going at 1:30 AM")

	var seen := {}
	var repeated := false
	var prev := ""
	for d in range(1, 29):
		var r := HuffParty.party_region_for(1, GameClock.Season.SUMMER, d)
		if r == prev:
			repeated = true
		prev = r
		seen[r] = true
	check(not repeated, "the party never repeats the same region two nights running")
	check(seen.size() >= 8, "the party moves around the map over a season (%d regions)" % seen.size())


func test_all_party_regions_off_trail() -> void:
	set_time(GameClock.Season.SUMMER, 1, 12)
	for id: String in HuffParty.PARTY_REGIONS:
		world._enter_region(id)
		await get_tree().physics_frame
		await get_tree().physics_frame
		var region: Region = world.region
		var spots := HuffParty.candidate_spots(region)
		var spot := HuffParty.pick_spot(region, "1-1-5")
		var ground := region.get_ground()
		var off_ok := spot != Vector2.INF and HuffParty.is_off_trail(region, spot, 3)
		var forest_ok := false
		if spot != Vector2.INF and ground:
			var cell := ground.local_to_map(ground.to_local(region.to_global(spot)))
			var kind := ground.get_cell_atlas_coords(cell).y
			forest_ok = kind in HuffParty.FOREST_KINDS
		var open_ok := spot != Vector2.INF and WalkGrid.of(region).is_open(region.to_global(spot))
		check(not spots.is_empty() and off_ok and forest_ok and open_ok,
			"%s has reachable off-trail forest/boulder party spots (%d spots, picked %s)" % [id, spots.size(), spot])


func test_party_site_and_substances() -> void:
	# Find a summer night when the party is in happy_isles (a classic heavy forest/boulder area).
	GameClock.year = 1
	var day := 1
	while HuffParty.party_region_for(1, GameClock.Season.SUMMER, day) != "happy_isles" and day < 60:
		day += 1
	check(day < 60, "found a night with the party in Happy Isles (day %d)" % day)
	set_time(GameClock.Season.SUMMER, day, 22, 30)
	world._enter_region("happy_isles", "arrival")
	var field := _find_field()
	check(field != null, "World has a HuffPartyField")
	if field == null:
		return
	field.refresh()
	var site: HuffPartySite = null
	for i in 12:
		await get_tree().physics_frame
		site = field.site
		if is_instance_valid(site):
			break
	check(site != null and site.is_inside_tree(), "after 10 PM the HUFF party spawns in tonight's region")
	if site == null:
		return
	var left_sp := site.get_node_or_null("HuffSpeakerLeft")
	var right_sp := site.get_node_or_null("HuffSpeakerRight")
	var emitter := site.get_node_or_null("Sound_huff_party") as SoundEmitter
	var lights := site.get_children().filter(func(n: Node) -> bool: return n is PointLight2D)
	var beams := site.get_node_or_null("DanceBeams")
	check(left_sp != null and right_sp != null, "the party has both PA speakers")
	check(emitter != null and emitter.stream != null, "the speakers play the huff_party audio loop")
	check(lights.size() >= 3 and beams != null, "the party has colored dance lights and sweeping beams (%d lights)" % lights.size())
	check(site.partiers.size() == 4, "four dancing HUFF employees are at the party (%d)" % site.partiers.size())
	check(HuffParty.is_off_trail(world.region, site.position, 3), "the spawned party is off-trail")

	# Leaving and coming back the same night finds them in the exact same clearing.
	var where := site.position
	world._enter_region("upper_pines", "arrival")
	await get_tree().physics_frame
	field.refresh()
	check(field.site == null, "no party in a different region on the same night")
	world._enter_region("happy_isles", "arrival")
	field.refresh()
	site = null
	for i in 12:
		await get_tree().physics_frame
		site = field.site
		if is_instance_valid(site):
			break
	check(site != null and site.position == where, "returning the same night finds the party in the same clearing")
	if site == null or site.partiers.is_empty():
		return

	# Test Beer, Weed, and LSD interactions (just like Crow!).
	var partier: HuffPartier = site.partiers[0]
	var player: Player = world.player
	QuestLog.heard_beats.erase(HuffParty.MET)
	HuffParty.paper_day = ""
	HuffParty.beer_day = ""
	Inventory.remove("king_cobra", Inventory.count("king_cobra"))

	# 1) Beer: option 0 -> confirm 0 -> buzz effect (layer 48) + 1 cold King Cobra once per night.
	var saw_buzz := await _interact_party(partier, player, [0, 0], 48)
	check(HuffParty.has_met(), "first visit records meeting the HUFF party crew")
	check(saw_buzz, "accepting a beer triggers the tipsy buzz effect")
	check(Inventory.count("king_cobra") == 1, "first beer of the night hands you a cold King Cobra for the pack")
	check(player.can_act and not partier._talking, "player regains control after beer")
	_clear_trips()

	# Second beer same night: still buzzes, does not hand out infinite cans.
	var saw_buzz_2 := await _interact_party(partier, player, [0, 0], 48)
	check(saw_buzz_2 and Inventory.count("king_cobra") == 1, "a second beer buzzes without infinitely duplicating cans")
	_clear_trips()

	# 2) Weed: option 1 -> confirm 0 -> smoke + TripEffect.haze (layer 49).
	var saw_haze := await _interact_party(partier, player, [1, 0], 49)
	check(saw_haze, "hitting the joint triggers TripEffect.haze like Crow")
	check(player.can_act and not partier._talking, "player regains control after weed")
	_clear_trips()

	# 3) LSD: option 2 -> confirm 0 -> TripEffect.play (layer 50, intensity > 0.5) -> then pass joint (1).
	var saw_trip := await _interact_party(partier, player, [2, 0, 1], 50, 0.5)
	check(saw_trip, "taking LSD triggers the full psychedelic TripEffect.play like Crow")
	check(HuffParty.paper_day == HuffParty.today_key(), "LSD is limited to one tab a day like Crow")
	check(player.can_act and not partier._talking, "player regains control after LSD trip")
	_clear_trips()

	# Second LSD ask same night: politely declined ("One tab a night").
	var saw_second_trip := await _interact_party(partier, player, [2], 50, 0.2)
	check(not saw_second_trip, "a second LSD ask the same night is turned down")

	# Advancing to morning clears the party.
	set_time(GameClock.Season.SUMMER, day + 1, 9, 0)
	field.refresh()
	await get_tree().process_frame
	check(field.site == null, "the party packs up by morning")


func _find_field() -> HuffPartyField:
	for child in world.get_children():
		if child is HuffPartyField:
			return child
	return null


func _find_box() -> DialogueBox:
	for child in get_tree().root.get_children():
		if child is DialogueBox and not child.is_queued_for_deletion():
			return child
	return null


func _trip_effects() -> Array:
	return get_tree().root.get_children().filter(func(n: Node) -> bool: return n is TripEffect and not n.is_queued_for_deletion())


func _clear_trips() -> void:
	for fx: TripEffect in _trip_effects():
		fx.free()


## Talks to [param partier], picking options from [param picks] in order whenever
## a choice menu appears, and returns true if a TripEffect on [param want_layer]
## reaches [param min_intensity].
func _interact_party(partier: HuffPartier, player: Player, picks: Array[int], want_layer: int, min_intensity := 0.0) -> bool:
	Engine.time_scale = 8.0
	var pick_idx := 0
	var matched := false
	var last_choice_box: DialogueBox = null
	var was_choice := false
	partier.interact(player)
	for i in 4000:
		await get_tree().process_frame
		for fx: TripEffect in _trip_effects():
			if fx.layer == want_layer and fx.intensity >= min_intensity:
				matched = true
		var dialogue := _find_box()
		if dialogue:
			var is_choice: bool = not dialogue._options.is_empty()
			if is_choice:
				if dialogue != last_choice_box or not was_choice:
					last_choice_box = dialogue
					var opt := picks[pick_idx] if pick_idx < picks.size() else 0
					if pick_idx < picks.size():
						pick_idx += 1
					dialogue._cursor = opt
			was_choice = is_choice
			dialogue.press()
		elif not partier._talking:
			break
	Engine.time_scale = 1.0
	return matched
