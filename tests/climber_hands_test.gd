extends Node
## Headless test of the climber's hands and feet on the wall: every hold of
## every pitch is tagged with how it's taken (HoldShape), the climber is
## painted at the screen's full density with a different hand for each
## shape and a different shoe for each foot technique (ClimberHD), your own
## look still climbs, and the grip close-up (ClimbGripCloseup, ClimbGripView)
## shows each new shape once a pitch.
## Run: godot --headless --path . res://tests/climber_hands_test.tscn
## Exit code is the number of failed checks.

var failures := 0
const KIT := {"climbing_shoes": 1, "chalk_bag": 1, "harness": 1, "quickdraw": 4, "cam": 3}


func check(cond: bool, what: String) -> void:
	print(("PASS  " if cond else "FAIL  ") + what)
	if not cond:
		failures += 1


func _ready() -> void:
	await get_tree().process_frame
	PlayerLook.reset()
	test_tags()
	test_climber()
	test_closeups()
	test_grip_view()
	PlayerLook.reset()
	print("\n%s: %d failure(s)" % ["OK" if failures == 0 else "FAILED", failures])
	get_tree().quit(failures)


func _route(id: String) -> RouteData:
	return load("res://data/routes/%s.tres" % id)


## Every hold on every pitch has a hand shape and a foot technique, cracks
## take jams, slabs take smears, and tagging uses no random numbers.
func test_tags() -> void:
	var untagged := 0
	var shapes := {}
	var feet := {}
	var dir := DirAccess.open("res://data/routes")
	for file in dir.get_files():
		if not file.ends_with(".tres"):
			continue
		var r: RouteData = load("res://data/routes/" + file)
		var state := ClimbState.new(r, 6, 3, {"climbing_shoes": 1, "harness": 1, "quickdraw": 8})
		for p in r.pitches.size():
			state.pitch = p
			state._start_pitch()
			for row: int in state.holds:
				for c: int in state.holds[row]:
					var hold: Dictionary = state.holds[row][c]
					if not HoldShape.HANDS.has(hold.get("shape", "")) or not HoldShape.FEET.has(hold.get("foot", "")):
						untagged += 1
					shapes[hold.get("shape", "")] = true
					feet[hold.get("foot", "")] = true
					if HoldShape.of(hold, state.style(), row, c) != hold.shape:
						untagged += 1
	check(untagged == 0, "every hold on every pitch of every route has a hand shape and a foot technique")
	for s in ["jug", "edge", "crimp", "hand_jam", "finger_jam", "sidepull", "pinch"]:
		check(shapes.has(s), "the park has a hold taken as a %s" % HoldShape.label(s).to_lower())
	for f in ["edge", "smear", "toe_jam"]:
		check(feet.has(f), "the park has a hold the feet take by %s" % HoldShape.foot_label(f).to_lower())
	check(HoldShape.of({"grip": "crimp", "crack": true}, "crack", 3, 2) == "finger_jam" and HoldShape.of({"grip": "jug", "crack": true}, "crack", 3, 2) == "hand_jam",
		"a thin crack takes fingers and a good one a hand jam")
	check(HoldShape.foot_of({"grip": "edge"}, "slab", 4, 1) == "smear" and HoldShape.of({"kind": "ice", "grip": "edge"}, "ice", 2, 2) == "tool",
		"you smear up a slab and swing a tool into ice")
	check(HoldShape.of({"grip": "edge", "name": "Sidepull"}, "slab", 4, 2) == "sidepull", "a hold named for its shape is that shape")
	# The same seed makes the same holds with the tags as without them.
	var a := ClimbState.new(_route("nutcracker"), 6, 11, {"climbing_shoes": 1})
	var b := ClimbState.new(_route("nutcracker"), 6, 11, {"climbing_shoes": 1})
	var same := true
	for row: int in a.holds:
		for c: int in a.holds[row]:
			same = same and b.holds.has(row) and b.holds[row].has(c) and a.holds[row][c].get("grip", "") == b.holds[row][c].get("grip", "") \
				and a.holds[row][c].get("shape", "") == b.holds[row][c].get("shape", "")
	check(same, "a seed still makes the same pitch, shapes and all")


## The wall climber is a full-density picture reporting the old size, with a
## hand for each shape and a shoe for each foot technique.
func test_climber() -> void:
	var base := ClimbSprites.stance(0)
	var tex := ClimbSprites.climber(base, KIT)
	check(tex.get_size() == Vector2(ClimbSprites.SIZE) and tex.get_image().get_size() == ClimberHD.SIZE,
		"the climber is painted at twice the density and lands at its old size")
	var pictures := {}
	for shape: String in HoldShape.HANDS:
		var pose := base.duplicate()
		pose["gr"] = shape
		pictures[shape] = ClimbSprites.climber(pose, KIT, {"snow": shape == "tool"}).get_image()
	var alike := 0
	var names: Array = pictures.keys()
	for i in names.size():
		for j in range(i + 1, names.size()):
			if _differences(pictures[names[i]], pictures[names[j]]) == 0:
				alike += 1
				print("      alike: %s %s" % [names[i], names[j]])
	check(alike == 0, "every hand shape paints a different hand")
	var shoes := {}
	for f: String in HoldShape.FEET:
		var pose := base.duplicate()
		pose["gr"] = "jug"
		pose["ftr"] = f
		pose["ftl"] = f
		shoes[f] = ClimbSprites.climber(pose, KIT).get_image()
	check(_differences(shoes.edge, shoes.smear) > 0 and _differences(shoes.edge, shoes.toe_jam) > 0 and _differences(shoes.smear, shoes.step) > 0,
		"edging, smearing, a toe jam and a flat step each show a different shoe")
	var left := base.duplicate()
	left["gr"] = "crimp"
	left["gl"] = "hand_jam"
	var right := base.duplicate()
	right["gr"] = "crimp"
	right["gl"] = "crimp"
	check(_differences(ClimbSprites.climber(left, KIT).get_image(), ClimbSprites.climber(right, KIT).get_image()) > 0,
		"each hand shows the hold it's on")
	# Your own look climbs in its own colors.
	var shipped: Image = pictures.jug
	PlayerLook.set_choice("top", 4)
	var pose_jug := base.duplicate()
	pose_jug["gr"] = "jug"
	var mine := ClimbSprites.climber(pose_jug, KIT).get_image()
	var shirt := ClimbSprites.SHIRT
	var found := false
	for y in mine.get_height():
		for x in mine.get_width():
			found = found or mine.get_pixel(x, y).to_rgba32() == shirt.to_rgba32()
	check(_differences(shipped, mine) > 0 and found, "a look of your own puts its shirt on the full-density climber")
	PlayerLook.reset()
	check(_differences(shipped, ClimbSprites.climber(pose_jug, KIT).get_image()) == 0, "and the shipped look comes back as it was")
	# Standing on a ledge and hanging on the rope still paint.
	for p in [ClimbSprites.stand_pose(), ClimbSprites.hang_pose(), ClimbSprites.fall_pose(), ClimbSprites.cheer_pose()]:
		check(ClimbSprites.climber(p, KIT).get_image().get_used_rect().size.y > 60, "the climber paints whole in a pose off the rock")


## A close-up for every hand shape and foot technique, mirrored for the left.
func test_closeups() -> void:
	var rock := Color("a29ea8")
	var ok := true
	var pics := {}
	for shape: String in HoldShape.HANDS:
		var im := ClimbGripCloseup.image(shape, true, rock)
		ok = ok and im.get_size() == Vector2i(ClimbGripCloseup.SIZE, ClimbGripCloseup.SIZE)
		pics[shape] = im
		ok = ok and _differences(im, ClimbGripCloseup.image(shape, false, rock)) > 0
	for f: String in HoldShape.FEET:
		var im := ClimbGripCloseup.image(f, true, rock, false, true)
		ok = ok and im.get_size() == Vector2i(ClimbGripCloseup.SIZE, ClimbGripCloseup.SIZE)
	check(ok, "every hand and foot has a close-up, and the left one is mirrored")
	check(_differences(pics.crimp, pics.jug) > 0 and _differences(pics.hand_jam, pics.fist_jam) > 0 and _differences(pics.hand_jam, pics.finger_jam) > 0,
		"a crimp's close-up isn't a jug's, and the three jams differ")


## The close-up shows each shape the first time on a pitch, and again on a
## crux; a new pitch starts afresh.
func test_grip_view() -> void:
	var view := ClimbGripView.new()
	var rock := Color("a29ea8")
	view.took({"shape": "crimp", "foot": "edge"}, true, rock)
	check(view.shape() == "crimp", "a new shape pops up its close-up")
	view.update(ClimbGripView.POP + ClimbGripView.HOLD + ClimbGripView.FADE + 0.01)
	check(not view.showing(), "and it goes after a second")
	view.took({"shape": "crimp", "foot": "edge"}, false, rock)
	check(not view.showing(), "the same shape again on the pitch doesn't")
	view.took({"shape": "crimp", "foot": "edge", "crux": true}, false, rock)
	check(view.shape() == "crimp", "but on a crux hold it does")
	view.took({"shape": "crimp", "foot": "smear"}, true, rock)
	check(view.shape() == "smear", "a first smear shows the feet")
	view.clear()
	check(not view.showing(), "the next move clears it at once")
	view.reset()
	view.took({"shape": "crimp", "foot": "edge"}, true, rock)
	check(view.shape() == "crimp", "a new pitch shows its shapes afresh")


func _differences(a: Image, b: Image) -> int:
	if a.get_size() != b.get_size():
		return -1
	var n := 0
	for y in a.get_height():
		for x in a.get_width():
			var p := a.get_pixel(x, y)
			var q := b.get_pixel(x, y)
			if (p.a > 0.5) != (q.a > 0.5) or (p.a > 0.5 and p.to_rgba32() != q.to_rgba32()):
				n += 1
	return n
