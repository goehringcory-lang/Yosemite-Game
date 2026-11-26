extends Node
## Reasons to explore: vistas (Vistas, VistaSpot, VistaView), the Landmark
## log (Landmarks), gear caches seen from vistas (Finds), and the registers
## and sketch spots (Challenges). The lists are sound, every spot can be
## walked to and is laid out, taking in a view puts the areas below on the
## map and sights its landmarks and hints its cache once, the peak-finder
## and the panoramas work, walking to a landmark opens its note, registers
## pay out at their milestones, sketches keep their hours, and it all saves.
## Run: godot --headless --path . res://tests/vistas_test.tscn
## Exit code is the number of failed checks.

const WalkCheck := preload("res://scripts/story/find_walk.gd")

var failures := 0


func check(cond: bool, what: String) -> void:
	print(("PASS  " if cond else "FAIL  ") + what)
	if not cond:
		failures += 1


func _ready() -> void:
	NewGame.reset()
	_check_lists()
	_check_panoramas()
	await _check_spots()
	_check_survey()
	_check_peak_finder()
	_check_landmarks()
	_check_challenges()
	_check_saves()
	await _check_view()
	print("\n%s: %d failure(s)" % ["OK" if failures == 0 else "FAILED", failures])
	get_tree().quit(failures)


func _region_exists(region_id: String) -> bool:
	return ResourceLoader.exists("res://scenes/regions/%s.tscn" % region_id)


func _check_lists() -> void:
	check(Vistas.total() >= 10, "there are %d vistas (10 or more)" % Vistas.total())
	check(Landmarks.total() >= 36, "there are %d landmarks (36 or more)" % Landmarks.total())
	var hubs := {}
	var ids := {}
	var sighted := {}
	for vista: Dictionary in Vistas.all():
		var id := str(vista.id)
		check(not ids.has(id), "%s: has an id of its own" % id)
		ids[id] = true
		check(_region_exists(vista.region), "%s: stands in a region that exists" % id)
		check(vista.has("pos"), "%s: has a spot" % id)
		check(str(vista.get("line", "")) != "" and str(vista.get("title", "")) != "", "%s: has a title and a line" % id)
		check((vista.get("lonlat", []) as Array).size() == 2 and float(vista.get("radius_m", 0)) > 0.0, "%s: says where it is for the park map" % id)
		for region_id in vista.get("sights", []):
			check(_region_exists(str(region_id)), "%s: sights %s, a region that exists" % [id, region_id])
		check(not (vista.get("sights", []) as Array).is_empty(), "%s: sights some areas" % id)
		for landmark_id in vista.get("landmarks", []):
			check(not Landmarks.get_landmark(str(landmark_id)).is_empty(), "%s: sights %s, a landmark" % [id, landmark_id])
			sighted[str(landmark_id)] = true
		check(str(vista.quiz) in vista.landmarks, "%s: its peak-finder asks about a landmark it sights" % id)
		check(vista.has("view") != vista.has("panorama"), "%s: has one panorama" % id)
		if vista.has("view"):
			check(BinocularView.VIEWS.has(vista.view), "%s: its view %s is a binocular view" % [id, vista.view])
		var region := load("res://scenes/regions/%s.tscn" % vista.region) as PackedScene
		if region:
			var r: Region = region.instantiate()
			hubs[r.hub_id] = true
			r.free()
	# Every corner of the park has one.
	for hub in ["yosemite_valley", "glacier_point", "tuolumne_meadows", "wawona"]:
		check(hubs.has(hub), "a vista in the %s hub" % hub)
	for landmark: Dictionary in Landmarks.all():
		for key in ["id", "name", "hub", "kind", "seen", "note"]:
			check(str(landmark.get(key, "")) != "", "%s: has a %s" % [landmark.get("id", "?"), key])
		for region_id in landmark.get("visit", []):
			check(_region_exists(str(region_id)), "%s: is visited in %s, a region that exists" % [landmark.id, region_id])
		check(sighted.has(landmark.id) or not (landmark.get("visit", []) as Array).is_empty(), "%s: can be sighted from a vista or walked to" % landmark.id)
	# Caches: one per vista, gear kept rare.
	var caches := 0
	var cams := 0
	for find: Dictionary in Finds.all():
		if Finds.is_cache(find):
			caches += 1
			check(not Vistas.get_vista(str(find.vista)).is_empty(), "%s: is seen from a vista that exists" % find.id)
			cams += int(find.reward.get("cam", 0))
	check(caches >= Vistas.total(), "every vista has a cache to spot (%d)" % caches)
	check(cams <= 1, "the caches hold at most one cam (%d)" % cams)
	# Challenges: in several hubs, rewards are gear.
	check(Challenges.registers().size() >= 8, "%d registers to sign" % Challenges.registers().size())
	check(Challenges.sketches().size() >= 6, "%d sketch spots" % Challenges.sketches().size())
	for entry: Dictionary in Challenges.registers() + Challenges.sketches():
		check(_region_exists(entry.region) and entry.has("pos"), "%s: lies in a region and has a spot" % entry.id)
		check(str(entry.get("title", "")) != "" and str(entry.get("text", "")) != "", "%s: has a title and text" % entry.id)
	for sketch: Dictionary in Challenges.sketches():
		check((sketch.get("hours", []) as Array).size() == 2 and str(sketch.get("early", "")) != "", "%s: has hours and a hint for the wrong time" % sketch.id)
	for milestone: Dictionary in Challenges.MILESTONES:
		for gear_id: String in milestone.reward:
			check(Gear.get_gear(gear_id) != null, "a register milestone gives %s, a piece of gear" % gear_id)


## Every panorama paints, with each of its targets on the skyline.
func _check_panoramas() -> void:
	var pal := ClimbSky.palette(12.0)
	for vista: Dictionary in Vistas.all():
		var spec: Dictionary = vista.panorama if vista.has("panorama") else BinocularView.VIEWS.get(vista.get("view", ""), {})
		var found_target := false
		for t: Dictionary in spec.get("targets", []):
			check(t.has("stat") and t.has("mi") and str(t.get("text", "")) != "" and str(t.get("name", "")) != "", "%s: %s has a name, numbers and a line for the plaque" % [vista.id, t.get("id", "?")])
			if t.has("k"):
				check(ClimbLandscape.LANDMARKS.has(t.k), "%s: %s is painted as %s, a landscape kind" % [vista.id, t.id, t.k])
			if str(t.id) == str(vista.get("quiz_target", "")):
				found_target = true
		check(found_target, "%s: the peak-finder's arrow has a target (%s)" % [vista.id, vista.get("quiz_target", "")])
		if vista.has("panorama"):
			var scale := BinocularView.make_scale(spec)
			var painted := BinocularView.paint(spec, pal, 12.0, scale)
			check(painted.has("land") and (painted.land.layers as Array).size() >= 3, "%s: its panorama paints" % vista.id)
			check(scale[-1] >= 600.0, "%s: its panorama is wider than the screen (%d px)" % [vista.id, int(scale[-1])])


## Every spot can be walked to (from the arrival, or the summit for Half
## Dome's) and is laid out in its area.
func _check_spots() -> void:
	var walker := WalkCheck.new()
	var by_region := {}
	for vista: Dictionary in Vistas.all():
		(by_region.get_or_add(vista.region, []) as Array).append(["Vista_", vista])
	for entry: Dictionary in Challenges.registers() + Challenges.sketches():
		(by_region.get_or_add(entry.region, []) as Array).append(["Challenge_", entry])
	for region_id: String in by_region:
		var region: Region = (load("res://scenes/regions/%s.tscn" % region_id) as PackedScene).instantiate()
		add_child(region)
		StoryContent.attach(region)
		await get_tree().physics_frame
		await get_tree().physics_frame
		var walks := {}
		for pair: Array in by_region[region_id]:
			var entry: Dictionary = pair[1]
			var start_name := str(entry.get("spot", {}).get("start", ""))
			if not walks.has(start_name):
				var start: Marker2D = region.get_spawn(start_name) if start_name != "" else WalkCheck.start_of(region)
				walks[start_name] = walker.walk(region, start.global_position)
			var pos := Vector2(entry.pos[0], entry.pos[1])
			check(WalkCheck.reaches(walks[start_name], pos), "%s: can be walked to in %s, at %s" % [entry.id, region_id, pos])
			var node := region.entities.get_node_or_null(str(pair[0]) + str(entry.id))
			check(node != null and (node as Node2D).position == pos, "%s: is laid out in the area" % entry.id)
			if node and node.has_method("get_prompt"):
				check(str(node.get_prompt()) != "", "%s: has a prompt" % entry.id)
		remove_child(region)
		region.free()


func _check_survey() -> void:
	NewGame.reset()
	check(not Discoveries.is_name_known("Bridalveil Fall") or not Discoveries.is_listed_name("Bridalveil Fall"), "Bridalveil Fall's name isn't on the map before you've seen it")
	check(Finds.rumors().is_empty(), "no cache lines before any vista")
	var result := Vistas.survey("tunnel_view")
	check(result.first and Vistas.is_surveyed("tunnel_view"), "taking in Tunnel View counts it")
	check(Discoveries.is_region_sighted("bridalveil_fall") and Discoveries.is_name_known("Bridalveil Fall"), "from Tunnel View, Bridalveil Fall goes on the area map")
	check(not Discoveries.is_found(Discoveries.key_for("bridalveil_fall", "Bridalveil Fall")), "but it still isn't walked to")
	check(not Discoveries.valley_seen, "one view isn't the whole Valley from above")
	check(Landmarks.is_sighted("el_capitan") and Landmarks.sighted.el_capitan == "Tunnel View", "El Capitan is sighted from Tunnel View")
	check((result.landmarks as Array).has("half_dome"), "the result names the landmarks newly sighted")
	var rumors := Finds.rumors()
	check(rumors.size() == 1 and str(rumors[0].id) == "tunnel_view_cache", "the view's glint goes in the Logbook")
	var again := Vistas.survey("tunnel_view")
	check(not again.first and (again.landmarks as Array).is_empty() and again.places == 0, "a second look changes nothing")
	Vistas.survey("glacier_point")
	check(Landmarks.sighted.half_dome == "Tunnel View", "a landmark keeps where it was first seen from")
	Finds.take("tunnel_view_cache")
	for find in Finds.rumors():
		check(str(find.id) != "tunnel_view_cache", "a cache's line stops once it's found")
	check(Achievements.has("room_with_a_view"), "the first view earns Room with a View")
	for vista: Dictionary in Vistas.all():
		Vistas.survey(vista.id)
	check(Vistas.count() == Vistas.total() and Achievements.has("every_vista"), "every vista earns Lookout Keeper")


func _check_peak_finder() -> void:
	NewGame.reset()
	for vista: Dictionary in Vistas.all():
		var quiz := Vistas.quiz(vista.id)
		check(quiz.options.size() == 3 and quiz.answer in quiz.options, "%s: the peak-finder offers three names, one right" % vista.id)
		check(Vistas.quiz(vista.id).options == quiz.options, "%s: and asks the same way twice" % vista.id)
	var quiz := Vistas.quiz("lembert_dome")
	var wrong := ""
	for option: String in quiz.options:
		if option != quiz.answer:
			wrong = option
	check(not Vistas.answer("lembert_dome", wrong) and not Vistas.is_named("lembert_dome"), "a wrong name isn't stamped")
	check(Vistas.answer("lembert_dome", quiz.answer) and Vistas.is_named("lembert_dome"), "the right one is")
	for vista: Dictionary in Vistas.all():
		Vistas.answer(vista.id, vista.quiz)
	check(Achievements.has("peak_finder"), "naming them all earns Peak-Finder")


func _check_landmarks() -> void:
	NewGame.reset()
	var fresh := Landmarks.visit_region("hetch_hetchy")
	var ids: Array = []
	for landmark: Dictionary in fresh:
		ids.append(landmark.id)
	check(ids.has("wapama_falls") and ids.has("oshaughnessy_dam"), "walking into Hetch Hetchy visits its landmarks")
	check(Landmarks.is_visited("kolana_rock") and not Landmarks.is_sighted("kolana_rock"), "visited without being sighted first")
	check(Landmarks.visit_region("hetch_hetchy").is_empty(), "and only once")
	check(Landmarks.known_count() == Landmarks.visited_count(), "the log counts what you know")
	var regions := {}
	for landmark: Dictionary in Landmarks.all():
		for region_id in landmark.get("visit", []):
			regions[region_id] = true
	for region_id: String in regions:
		Landmarks.visit_region(region_id)
	check(Achievements.has("landmarks_20"), "walking to 20 landmarks earns Feet on the Ground")


func _check_challenges() -> void:
	NewGame.reset()
	var registers := Challenges.registers()
	var before := Gear.count("nut_mid")
	check(Challenges.sign_register(registers[0].id) is Dictionary, "signing a register works")
	check(Challenges.sign_register(registers[0].id) == null, "but only once")
	Challenges.sign_register(registers[1].id)
	var third = Challenges.sign_register(registers[2].id)
	check(third is Dictionary and (third as Dictionary).has("nut_mid") and Gear.count("nut_mid") == before + 1, "the third signature earns a nut")
	check(Challenges.next_milestone().count == 6, "the Logbook says the next one's at six")
	for register: Dictionary in registers:
		Challenges.sign_register(register.id)
	check(Challenges.next_milestone().is_empty() and Achievements.has("every_register"), "signing them all earns Signed In")
	# Sketches keep their hours.
	var alpenglow := Challenges.get_challenge("sketch_alpenglow")
	check(not alpenglow.is_empty(), "there's a sketch of alpenglow on Half Dome")
	GameClock.minutes = 11 * 60
	check(not Challenges.sketch("sketch_alpenglow") and Challenges.is_tried("sketch_alpenglow"), "at noon it isn't time, and the Logbook remembers you tried")
	GameClock.minutes = 18 * 60
	check(Challenges.sketch("sketch_alpenglow") and Challenges.is_sketched("sketch_alpenglow") and not Challenges.is_tried("sketch_alpenglow"), "at dusk it goes in the sketchbook")
	var stars := Challenges.get_challenge("sketch_tuolumne_stars")
	GameClock.minutes = 25 * 60
	check(Challenges.is_sketch_time(stars), "the stars over Tuolumne sketch after midnight")
	GameClock.minutes = 13 * 60
	check(not Challenges.is_sketch_time(stars), "but not at midday")
	for sketch: Dictionary in Challenges.sketches():
		var hours: Array = sketch.hours
		GameClock.minutes = (int(hours[0]) % 24) * 60 + 10
		var seasons: Array = sketch.get("seasons", [])
		if not seasons.is_empty():
			GameClock.season = Finds.SEASONS[seasons[0]]
		check(Challenges.sketch(sketch.id), "%s: can be sketched at its hour" % sketch.id)
	GameClock.minutes = 8 * 60
	check(Achievements.has("full_sketchbook"), "every sketch earns Full Sketchbook")


func _check_saves() -> void:
	NewGame.reset()
	Vistas.survey("olmsted_point")
	Vistas.answer("olmsted_point", "half_dome")
	Landmarks.visit_region("tenaya_lake")
	Challenges.sign_register("register_tenaya_lake")
	GameClock.minutes = 12 * 60
	Challenges.sketch("sketch_alpenglow")
	var saved := [Vistas.save_data(), Landmarks.save_data(), Challenges.save_data(), Discoveries.save_data()]
	saved = JSON.parse_string(JSON.stringify(saved))
	NewGame.reset()
	check(Vistas.count() == 0 and Landmarks.known_count() == 0 and Challenges.signed_count() == 0 and Discoveries.sighted.is_empty(), "a new game starts with none of it")
	Vistas.load_data(saved[0])
	Landmarks.load_data(saved[1])
	Challenges.load_data(saved[2])
	Discoveries.load_data(saved[3])
	check(Vistas.is_surveyed("olmsted_point") and Vistas.is_named("olmsted_point"), "vistas come back from a save")
	check(Landmarks.sighted.get("clouds_rest", "") == "Olmsted Point" and Landmarks.is_visited("tenaya_lake"), "the Landmark log comes back")
	check(Challenges.is_signed("register_tenaya_lake") and Challenges.is_tried("sketch_alpenglow"), "registers and sketches come back")
	check(Discoveries.is_region_sighted("tenaya_lake"), "the areas seen from a vista come back")


## Taking in a view for real: the panorama opens, sweeps, names, and closes.
func _check_view() -> void:
	NewGame.reset()
	var view := VistaView.new()
	view.setup_vista(Vistas.get_vista("tunnel_view"))
	get_tree().root.add_child(view)
	var waited := 0.0
	while not view.done_sweeping and waited < 30.0:
		await get_tree().process_frame
		waited += get_process_delta_time()
	check(view.done_sweeping, "the Tunnel View panorama sweeps to its end")
	check(view.spotted_count() == view._targets.size(), "and names everything in it")
	view.point_at("half_dome")
	check(view.pointing() >= 0, "the peak-finder's arrow finds Half Dome")
	view.close()
	await view.finished
	await get_tree().process_frame
	check(not is_instance_valid(view) or view.is_queued_for_deletion(), "and it closes")
