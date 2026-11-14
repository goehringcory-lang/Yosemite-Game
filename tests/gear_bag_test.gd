extends Node
## Headless test of the gear bag and the gear rack at camp (Gear, CampPiece):
## the bag's room, new gear that won't fit going to camp, packing and
## hanging up, packing for a climb (every route's kit fits), what a climb
## asks for, the save, and the rack's menus.
## Run: godot --headless --path . res://tests/gear_bag_test.tscn
## Exit code is the number of failed checks.

var failures := 0


func check(cond: bool, what: String) -> void:
	print(("PASS  " if cond else "FAIL  ") + what)
	if not cond:
		failures += 1


func _ready() -> void:
	await get_tree().process_frame
	test_room()
	test_overflow()
	test_packing()
	test_every_route_fits()
	test_climb_words()
	test_save()
	test_menus()
	Gear.start_new_game()
	print("\n%s: %d failure(s)" % ["OK" if failures == 0 else "FAILED", failures])
	get_tree().quit(failures)


func _kit(gear: Dictionary) -> void:
	Gear.start_new_game()
	for id: String in gear:
		Gear.owned[id] = int(gear[id])


func test_room() -> void:
	Gear.start_new_game()
	check(Gear.bag_used() == 0 and Gear.bag_room() == Gear.BAG_ROOM and not Gear.any_cached(), "a new game starts with an empty bag of %d room" % Gear.BAG_ROOM)
	_kit({"rope": 1, "harness": 1, "cam": 4, "quickdraw": 5, "chalk_bag": 1})
	check(Gear.bag_used() == 4 + 1 + 4 + 5, "a rope takes 4, a cam or a draw 1, a chalk bag none")
	check(Gear.carried("cam") == 4 and Gear.carried_all().get("rope") == 1, "gear set straight in the save is all in the bag")
	Gear.owned["haul_bag"] = 1
	check(Gear.bag_room() == Gear.BAG_ROOM + Gear.HAUL_BAG_ROOM, "a haul bag adds room")


func test_overflow() -> void:
	_kit({"rope": 1, "harness": 1, "climbing_shoes": 1, "cam": 10, "quickdraw": 7})
	check(Gear.bag_used() == 23, "a full rack nearly fills the bag")
	var sent := []
	var on_sent := func(id: String, n: int) -> void: sent.append([id, n])
	Gear.sent_to_camp.connect(on_sent)
	Gear.add("quickdraw", 2)
	Gear.sent_to_camp.disconnect(on_sent)
	check(Gear.count("quickdraw") == 9 and Gear.carried("quickdraw") == 8 and Gear.cached_count("quickdraw") == 1, "two more draws: one fits, one goes to camp")
	check(sent == [["quickdraw", 1]], "and the game says so")
	check(Gear.bag_used() <= Gear.bag_room(), "the bag isn't over its room")
	Gear.add("chalk_bag")
	check(Gear.carried("chalk_bag") == 1, "something that takes no room always fits")


func test_packing() -> void:
	_kit({"rope": 1, "harness": 1, "cam": 6, "fly_rod": 1})
	check(Gear.unpack("rope") == 1 and Gear.carried("rope") == 0 and Gear.cached_count("rope") == 1, "the rope hangs up")
	check(Gear.unpack("rope") == 0, "you can't hang up what isn't in the bag")
	check(Gear.pack("rope") == 1 and Gear.carried("rope") == 1, "and packs again")
	check(Gear.unpack_all() > 0 and Gear.bag_used() == 0 and Gear.count("cam") == 6, "hang up everything empties the bag, and you still own it all")
	Gear.owned["cam"] = 30
	Gear.cached["cam"] = 30
	check(Gear.pack_all() > 0 and Gear.bag_used() == Gear.bag_room(), "pack what fits fills it to the brim")
	check(Gear.carried("harness") == 1 and Gear.carried("rope") == 1, "the harness and rope go in before the extra cams")
	check(Gear.pack("fly_rod") == 0, "nothing more fits in a full bag")
	# the haul bag stays while the wall kit needs its room
	_kit({"rope": 1, "harness": 1, "cam": 10, "quickdraw": 6, "aiders": 2, "ascenders": 2, "haul_bag": 1, "portaledge": 1})
	check(Gear.bag_used() > Gear.BAG_ROOM and Gear.unpack("haul_bag") == 0, "the haul bag can't come off while the wall kit is in it")
	Gear.unpack("portaledge")
	Gear.unpack("cam", 6)
	check(Gear.unpack("haul_bag") == 1 and Gear.bag_room() == Gear.BAG_ROOM, "once it fits without, it can")


func test_every_route_fits() -> void:
	# everything the game hands out, more than any one climb needs
	var all := {}
	for gear: GearData in Gear.GEAR:
		all[gear.id] = 1
	all.merge({"cam": 12, "quickdraw": 12, "aiders": 2, "ascenders": 2}, true)
	var bad := PackedStringArray()
	for route: RouteData in Guidebook.routes():
		_kit(all)
		Gear.unpack_all()
		if not Gear.pack_for(route.required_gear) or not Gear.packed_all(route.required_gear) or Gear.bag_used() > Gear.bag_room():
			bad.append(route.id)
	check(bad.is_empty(), "every route's kit packs into the bag (%d routes)%s" % [Guidebook.routes().size(), "" if bad.is_empty() else ": not " + ", ".join(bad)])
	_kit(all)
	Gear.owned.erase("haul_bag")
	var nose := {"rope": 1, "harness": 1, "cam": 10, "quickdraw": 6, "aiders": 2, "ascenders": 2, "portaledge": 1}
	check(not Gear.pack_for(nose), "a big wall's kit needs the haul bag")


func test_climb_words() -> void:
	_kit({"rope": 1, "harness": 1, "cam": 4, "quickdraw": 4})
	var need := {"rope": 1, "harness": 1, "cam": 4, "quickdraw": 4}
	check(Gear.packed_all(need) and Gear.at_camp_line(need) == "", "with it all in the bag, nothing's at camp")
	Gear.unpack("rope")
	Gear.unpack("cam", 2)
	check(Gear.has_all(need) and not Gear.packed_all(need), "owning isn't carrying")
	check(Array(Gear.missing_packed(need)) == ["Rope", "2 more Cams"], "a climb names what's missing from the bag: " + ", ".join(Gear.missing_packed(need)))
	check(Gear.at_camp_line(need) == "Your rope and 2 cams are on the gear rack at camp.", "and says where it is: " + Gear.at_camp_line(need))
	Gear.pack("cam", 2)
	check(Gear.at_camp_line(need) == "Your rope is on the gear rack at camp.", "one thing: " + Gear.at_camp_line(need))
	var game: ClimbMinigame = load("res://scenes/climb/climb_minigame.tscn").instantiate()
	game.setup(load("res://data/routes/firefall_slab.tres"), 3)
	check(game._kit.get("rope", 0) == 0 and game._kit.get("cam", 0) == 4, "a climb only has what's in the bag")
	game.free()


func test_save() -> void:
	_kit({"rope": 1, "cam": 3})
	Gear.unpack("cam", 2)
	var data: Dictionary = JSON.parse_string(JSON.stringify(Gear.save_data()))
	Gear.start_new_game()
	Gear.load_data(data)
	check(Gear.count("cam") == 3 and Gear.cached_count("cam") == 2 and Gear.carried("cam") == 1, "the rack and the bag come back from a save")
	Gear.load_data({"owned": {"rope": 1, "cam": 3}})
	check(not Gear.any_cached() and Gear.carried("cam") == 3, "a save from before the bag has everything in it")


func test_menus() -> void:
	_kit({"rope": 1, "harness": 1, "cam": 3, "chalk_bag": 1, "haul_bag": 1})
	var bag := CampPiece.rack_menu(false)
	check("rope" in bag.ids and "haul_bag" in bag.ids and not "chalk_bag" in bag.ids, "Hang gear up lists what takes room, and the haul bag")
	check(CampPiece.rack_menu(true).ids.is_empty(), "Pack your bag is empty with nothing on the rack")
	Gear.unpack("rope")
	check(CampPiece.rack_menu(true).ids == ["rope"], "then lists the rope")
	check(CampPiece.rack_prompt().contains("%d of %d" % [Gear.bag_used(), Gear.bag_room()]), "the rack says how full the bag is")
	check(Camp.describe("gear_rack").contains("Hanging here: Rope"), "looking at it names what hangs there")
