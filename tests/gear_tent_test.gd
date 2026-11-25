extends Node
## Headless test of sized gear and the gear tent (Gear, GearData,
## GearTent, GearTentView): a "cam" hands out the next size, routes take any
## size or length, old saves split their cams into sizes, the climbing
## screen's rack list, selling a cam, the tent's pitching, its tarp layout,
## and packing and leaving pieces from inside it.
## Run: godot --headless --path . res://tests/gear_tent_test.tscn
## Exit code is the number of failed checks.

var failures := 0


func check(cond: bool, what: String) -> void:
	print(("PASS  " if cond else "FAIL  ") + what)
	if not cond:
		failures += 1


func _ready() -> void:
	await get_tree().process_frame
	test_data()
	test_cam_sizes()
	test_kinds()
	test_old_save()
	test_rack_carried()
	test_remove()
	test_pitched()
	await test_view()
	Gear.start_new_game()
	print("\n%s: %d failure(s)" % ["OK" if failures == 0 else "FAILED", failures])
	get_tree().quit(failures)


func test_data() -> void:
	var widths := {}
	for id: String in Gear.of_kind("cam"):
		var gear := Gear.get_gear(id)
		widths[gear.width_min] = id
		check(gear.width_min == gear.width_max and gear.size != "" and gear.icon != null, "%s fits one width and has a size and icon" % id)
	check(widths.size() == 8 and widths.keys().min() == 0 and widths.keys().max() == 7, "the cams run #0.3 to #4, one per width (%s)" % [widths])
	for id: String in Gear.of_kind("nut"):
		var gear := Gear.get_gear(id)
		check(gear.width_min >= 0 and gear.width_max >= gear.width_min and gear.icon != null, "%s covers a range of widths" % id)
	check(Gear.get_gear("cam").generic and not "cam" in Gear.of_kind("cam"), "\"cam\" is a stand-in, never on the rack")
	check(Gear.of_kind("rope") == ["rope", "rope_70"], "two ropes: 60 m and 70 m")
	for gear: GearData in Gear.GEAR:
		check(gear.generic or Gear.bulk(gear.id) > 0 or not gear.kind in ["cam", "nut", "rope", "draw"], "%s takes room in the bag" % gear.id)


func test_cam_sizes() -> void:
	Gear.start_new_game()
	var got: Array[String] = []
	for i in 6:
		got.append(Gear.next_cam())
		Gear.add("cam")
	check(got == ["cam_075", "cam_1", "cam_2", "cam_3", "cam_075", "cam_1"], "a \"cam\" is the next size the rack is missing (%s)" % [got])
	check(Gear.count("cam") == 6 and Gear.count("cam_075") == 2 and not Gear.owned.has("cam"), "count(\"cam\") is every size")
	Gear.add("cam_4")
	check(Gear.count("cam") == 7 and Gear.next_cam() == "cam_2", "a #4 counts as a cam but doesn't change the fill order")


func test_kinds() -> void:
	Gear.start_new_game()
	Gear.owned = {"rope_70": 1, "harness": 1, "cam_2": 2, "cam_05": 2, "quickdraw": 2}
	Gear.cached = {}
	var route := {"rope": 1, "harness": 1, "cam": 4, "quickdraw": 2}
	check(Gear.has_all(route) and Gear.packed_all(route), "a 70 m rope and any four cams do for a route that needs a rope and 4 cams")
	check(Gear.count("rope") == 0 and Gear.have("rope") == 1, "but the shop still sees no 60 m rope")
	Gear.unpack_all()
	check(not Gear.packed_all(route) and Gear.at_camp_line(route).contains("4 cams"), "hung up, the climb says where they are: %s" % Gear.at_camp_line(route))
	check(Gear.pack_for(route, false), "packing for it packs the 70 m rope and the cams")
	check(Gear.carried("cam_2") == 2 and Gear.carried("cam_05") == 2 and Gear.carried("rope_70") == 1, "spread across the sizes")
	Gear.add("cam_3")
	check(Gear.cached_count("cam_3") == 0 or Gear.bag_used() > Gear.bag_room() - 1, "new gear goes in the bag while it fits")
	Gear.unpack_all()
	Gear.pack("cam", 3)
	check(Gear.carried("cam") == 3 and Gear.carried("cam_2") == 1 and Gear.carried("cam_05") == 1, "pack(\"cam\", 3) takes one of each size first")


func test_old_save() -> void:
	Gear.start_new_game()
	Gear.load_data({"owned": {"cam": 6, "rope": 1}, "cached": {"cam": 2}})
	check(not Gear.owned.has("cam") and Gear.count("cam") == 6, "an old save's 6 cams become sizes (%s)" % [Gear.owned])
	check(Gear.count("cam_075") == 2 and Gear.count("cam_1") == 2 and Gear.count("cam_2") == 1 and Gear.count("cam_3") == 1, "in the old fill order")
	check(Gear.cached_count("cam") == 2 and Gear.cached_count("cam_075") == 1 and Gear.cached_count("cam_1") == 1, "the 2 at camp are the last sizes handed out, as the rack showed them")
	var saved := Gear.save_data()
	Gear.load_data(saved)
	check(Gear.count("cam") == 6 and Gear.cached_count("cam") == 2, "and they survive a save")
	# a test or tool that sets owned straight still works
	Gear.owned = {"cam": 4}
	Gear.cached = {}
	check(Gear.carried("cam") == 4 and Gear.carried_all().get("cam", 0) == 4, "a straight \"cam\": 4 counts as 4 cams in the bag")


func test_rack_carried() -> void:
	Gear.start_new_game()
	Gear.owned = {"cam_4": 1, "cam_075": 2, "nut_mid": 1, "nut_small": 1, "cam_03": 1, "quickdraw": 4}
	Gear.cached = {"cam_03": 1}
	var rack := Gear.rack_carried()
	var ids: Array = rack.map(func(one: Dictionary) -> String: return one.id)
	check(ids == ["nut_small", "nut_mid", "cam_075", "cam_4"], "the rack is nuts then cams, small to big, bag only (%s)" % [ids])
	check(rack[2].count == 2 and rack[2].width_min == 3 and rack[2].color == Gear.get_gear("cam_075").color and rack[2].name == "Cam #0.75", "each entry has its count, width, color and name")


func test_remove() -> void:
	Gear.start_new_game()
	Gear.owned = {"cam_075": 3, "cam_1": 1, "cam_2": 2}
	Gear.cached = {"cam_2": 1}
	check(Gear.remove("cam") == 1 and Gear.count("cam_2") == 1 and Gear.cached_count("cam") == 0, "selling a cam sells the spare at camp first")
	check(Gear.remove("cam") == 1 and Gear.count("cam_075") == 2, "then the size you have most of")
	check(Gear.remove("cam_1") == 1 and not Gear.owned.has("cam_1"), "a lost piece comes off by its size")


func test_pitched() -> void:
	Gear.start_new_game()
	check(not GearTent.is_pitched(), "no tent with only approach shoes")
	Gear.add("rope")
	check(GearTent.is_pitched(), "a rope of your own pitches it")


func test_view() -> void:
	Gear.start_new_game()
	Gear.owned = {"rope": 1, "harness": 1, "cam_075": 1, "cam_1": 1, "quickdraw": 2, "fly_rod": 1}
	Gear.cached = {"cam_1": 1, "quickdraw": 2}
	var view := GearTentView.new()
	add_child(view)
	await get_tree().process_frame
	var ids: Array = view.slots.map(func(one: Dictionary) -> String: return one.id)
	check(ids.slice(0, 11) == ["nut_small", "nut_mid", "nut_big", "cam_03", "cam_04", "cam_05", "cam_075", "cam_1", "cam_2", "cam_3", "cam_4"], "the tarp's first row is nuts then cams by size (%s)" % [ids.slice(0, 11)])
	check("fly_rod" in ids and not "bear_canister" in ids and not "cam" in ids, "camp things show only if you own them; no stand-in")
	check("aiders" in ids, "climbing gear you haven't got shows as an outline")
	for slot: Dictionary in view.slots:
		check(Rect2(view.TARP).encloses(Rect2(slot.pos, Vector2(view.ICON, view.ICON))), "%s lies on the tarp" % slot.id)
	var found := GearTentView.collected()
	check(found.x == 5 and found.y > 20, "collected counts kinds you own (%d of %d)" % [found.x, found.y])
	view.cursor = ids.find("cam_1")
	view.pack_one()
	check(Gear.carried("cam_1") == 1 and Gear.cached_count("cam_1") == 0, "E packs one into the bag")
	view.pack_one()
	check(view.note.contains("in your bag"), "again says they're all in the bag: %s" % view.note)
	view.leave_one()
	check(Gear.cached_count("cam_1") == 1, "Space leaves one in the tent")
	view.cursor = ids.find("aiders")
	view.pack_one()
	check(view.note.contains("Not on your rack"), "an outline can't be packed")
	view.move(0, 1)
	check(view.slots[view.cursor].row > view.slots[ids.find("aiders")].row, "down goes to the next row")
	view.open_list()
	var last := view.list.size() - 1
	check(view.list[last].action == "back" and view.list[last - 1].action == "none", "the climb list ends with leave everything, then back")
	view.choose(last - 1)
	check(Gear.carried("cam") == 0 and Gear.carried("rope") == 0 and view.list.is_empty(), "leave everything here empties the bag")
	view.open_list()
	view.choose(view.list.size() - 3)
	check(Gear.carried("rope") == 1, "pack everything that fits fills it again")
	view.close()
