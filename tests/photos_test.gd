extends Node
## Headless test of photography (Photos, CameraView, PhotoAlbum): Ansel
## Adams's shot list and what answers it, what a frame holds (landmarks,
## animals, people, plants, the Firefall), titles and stars, the album and
## its print files, saving, Ansel's three quests and the lenses, the
## viewfinder and the album screen driven by keys, and that every landmark
## on the list can be framed from somewhere you can walk to.
## Run: godot --headless --path . res://tests/photos_test.tscn
## Exit code is the number of failed checks.

## Where each landmark on the list is photographed from, for the walk test:
## every region its hint names.
const LANDMARK_REGIONS := {
	"half_dome": ["mirror_lake", "happy_isles", "tunnel_view", "glacier_point"],
	"el_capitan": ["el_capitan_meadow", "tunnel_view"],
	"yosemite_falls": ["yosemite_village"],
	"bridalveil": ["bridalveil_fall", "tunnel_view"],
	"cathedral_rocks": ["bridalveil_fall"],
	"three_brothers": ["leidig_meadow"],
	"sentinel_rock": ["four_mile_trailhead"],
	"royal_arches": ["ahwahnee_meadow", "the_ahwahnee"],
	"mirror_lake": ["mirror_lake"],
	"grizzly_giant": ["wawona"],
	"cathedral_peak": ["tuolumne_meadows"],
}

var failures := 0
var world: Node


func check(cond: bool, what: String) -> void:
	print(("PASS  " if cond else "FAIL  ") + what)
	if not cond:
		failures += 1


func _ready() -> void:
	SaveManager.save_path = "user://photos_test_save.json"
	SaveManager.delete_save()
	_clear_prints()
	world = load("res://scenes/world/world.tscn").instantiate()
	get_tree().root.add_child.call_deferred(world)
	await get_tree().process_frame
	await get_tree().process_frame
	GameClock.paused = true
	_fair_weather()

	test_shot_list()
	test_light()
	test_answers()
	test_titles_and_stars()
	test_toning()
	test_prints_from_a_screen()
	test_album()
	test_saving()
	test_quests()
	await test_subjects_in_the_world()
	await test_viewfinder()
	await test_album_screen()
	await test_landmarks_can_be_framed()
	test_journal_and_logbook()

	SaveManager.delete_save()
	_clear_prints()
	print("\n%s: %d failure(s)" % ["OK" if failures == 0 else "FAILED", failures])
	get_tree().quit(failures)


func _fair_weather() -> void:
	Weather.today()
	Weather._today = {"snow": 0.0, "rain": 0.0, "clouds": 0.3}


func _clear_prints() -> void:
	var folder := DirAccess.open(Photos.dir())
	if folder == null:
		return
	for file in folder.get_files():
		folder.remove(file)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Photos.dir()))


func _new_game() -> void:
	NewGame.reset()
	_clear_prints()


## A view as Photos.observe gives it, for the rules that don't need a world.
func _view(subjects: Array, more := {}) -> Dictionary:
	var list: Array[Dictionary] = []
	for s: Array in subjects:
		list.append({"kind": s[0], "id": s[1], "name": s[2] if s.size() > 2 else str(s[1]).capitalize(), "at": Vector2.ZERO})
	var view := {"region": "el_capitan_meadow", "region_name": "El Capitan Meadow", "where": "El Capitan Meadow", "indoors": false,
		"season": GameClock.Season.SUMMER, "light": "midday", "snow": false, "rain": false, "subjects": list}
	view.merge(more, true)
	return view


func _keys(view: Dictionary) -> Array:
	return Photos.new_for_list(view).map(func(e: Dictionary) -> String: return e.id)


func test_shot_list() -> void:
	var ids := {}
	for entry: Dictionary in Photos.SHOT_LIST:
		check(not ids.has(entry.id), "%s is on the list once" % entry.id)
		ids[entry.id] = true
		check(entry.group in Photos.GROUPS, "%s is in a group the album shows" % entry.id)
		check(str(entry.name) != "" and str(entry.hint).ends_with(".") and str(entry.note).ends_with("."), "%s has a name, where to stand, and a note" % entry.id)
		for tag: String in entry.any:
			var kind := tag.get_slice(":", 0)
			var id := tag.get_slice(":", 1)
			check(kind in ["place", "animal", "group", "kind", "event"], "%s asks for a kind of thing a frame can hold (%s)" % [entry.id, tag])
			if kind == "animal":
				check(not FieldLog.get_animal(id).is_empty(), "%s asks for an animal in the field log (%s)" % [entry.id, id])
			if kind == "group":
				check(id in FieldLog.GROUPS, "%s asks for a group in the field log (%s)" % [entry.id, id])
		for light: String in entry.get("light", []):
			check(Photos.LIGHTS.has(light), "%s asks for a light the camera knows (%s)" % [entry.id, light])
		for region: String in entry.get("regions", []):
			check(ResourceLoader.exists("res://scenes/regions/%s.tscn" % region), "%s is taken in a region that exists (%s)" % [entry.id, region])
	var sum := 0
	for group: String in Photos.GROUPS:
		sum += Photos.in_group(group).size()
	check(sum == Photos.SHOT_LIST.size() and sum >= 20, "the groups hold the whole list (%d)" % sum)
	check(Photos.is_landmark("El Capitan") and Photos.is_landmark("Half Dome") and not Photos.is_landmark("Village Store"), "the park's landmarks are the list's places")
	for id: String in LANDMARK_REGIONS:
		check(not Photos.get_entry(id).is_empty(), "the walk test's %s is on the list" % id)
	for lens: String in Photos.LENSES:
		var frame: Vector2 = Photos.LENS_FRAMES[lens]
		check(is_equal_approx(frame.x / frame.y, 1.5) and (int(frame.x) % Photos.PRINT_SIZE.x == 0 or Photos.PRINT_SIZE.x % int(frame.x) == 0),
			"the %s lens frames three to two, a whole multiple of a print" % lens)
		check(frame.x <= 960 - 8 and frame.y <= 540 - 8, "the %s lens's frame fits on the screen" % lens)
	for film: String in Photos.FILMS:
		check(Photos.FILM_NAMES.has(film), "%s film has a name" % film)
	check(Gear.get_gear(Photos.GEAR) != null and Gear.get_gear(Photos.GEAR).icon != null and Gear.get_gear(Photos.GEAR).icon.get_size() == Vector2(64, 64),
		"the camera is gear with a picture")
	check(Gear.get_gear(Photos.LENSES_GEAR) != null and Gear.get_gear(Photos.LENSES_GEAR).icon != null, "the lenses are gear with a picture")
	check(InputMap.has_action("camera") and not Settings.binding("camera").is_empty(), "the camera has a key, and it's on the Controls page")


func test_light() -> void:
	GameClock.season = GameClock.Season.SUMMER
	GameClock.day = 3
	var seen := {}
	for minutes in range(5 * 60, 26 * 60, 10):
		GameClock.minutes = minutes
		var light := Photos.light_now()
		check(Photos.LIGHTS.has(light), "the light at %d:%02d has a name (%s)" % [minutes / 60, minutes % 60, light]) if not Photos.LIGHTS.has(light) else null
		seen[light] = true
	for light in ["first_light", "morning", "midday", "afternoon", "last_light", "alpenglow", "night"]:
		check(seen.has(light), "a summer day passes through %s" % light)
	check(not seen.has("moonlight"), "no moonlight on day 3")
	GameClock.day = GameClock.FULL_MOON_DAY
	GameClock.minutes = 23 * 60
	check(Photos.light_now() == "moonlight", "a full moon night is moonlight")
	GameClock.minutes = 12 * 60
	check(Photos.light_now() == "midday" and Photos.light_now(true) == "indoors", "noon is midday, and indoors is indoors")
	GameClock.day = 3


func test_answers() -> void:
	_new_game()
	var cap := _view([["place", "El Capitan"]])
	check(Photos.answers(Photos.get_entry("el_capitan"), cap), "El Capitan in the frame answers El Capitan")
	check(not Photos.answers(Photos.get_entry("half_dome"), cap), "and not Half Dome")
	check(_keys(cap) == ["el_capitan"], "at noon it answers only that (%s)" % str(_keys(cap)))
	var dusk := _view([["place", "El Capitan"]], {"light": "last_light"})
	check("last_light" in _keys(dusk) and "el_capitan" in _keys(dusk), "in the last light it answers two lines")
	check("last_light" in _keys(_view([["place", "El Capitan"]], {"light": "alpenglow"})), "alpenglow counts as the last light")
	check("first_light" in _keys(_view([["place", "Half Dome"]], {"light": "first_light"})), "a landmark at first light")
	check("moon" in _keys(_view([["place", "Half Dome"]], {"light": "moonlight"})), "a landmark by moonlight")
	check(not "last_light" in _keys(_view([["place", "Village Store"]], {"light": "last_light"})), "the Village Store at sunset isn't a landmark in the last light")
	check(not "last_light" in _keys(_view([["animal", "mule_deer"]], {"light": "last_light"})), "nor is a deer")
	var deer := _view([["animal", "mule_deer", "Mule Deer"], ["place", "El Capitan"]], {"light": "last_light"})
	check(_keys(deer).size() == 3 and "deer" in _keys(deer), "a deer under El Capitan at sunset is three lines (%s)" % str(_keys(deer)))
	check(_keys(_view([["animal", "stellers_jay"]])) == ["bird"], "a jay is a bird")
	check("bird" in _keys(_view([["animal", "peregrine_falcon"]])) and "raptor" in _keys(_view([["animal", "peregrine_falcon"]])), "a peregrine is a bird and a raptor")
	check(_keys(_view([["animal", "great_gray_owl"]])).has("raptor"), "so is a great gray owl")
	check(_keys(_view([["animal", "douglas_squirrel"]])) == ["squirrel"], "a chickaree is a squirrel")
	check(_keys(_view([["animal", "butterfly_2"]])) == ["butterfly"], "an admiral is a butterfly")
	check(_keys(_view([["animal", "black_bear"]])) == ["bear"], "a bear is a bear")
	check(_keys(_view([["person", "john_muir", "John Muir"]])) == ["portrait"], "John Muir is a portrait")
	check(_keys(_view([["plant", "pacific_dogwood"]])) == ["blossom"], "a plant from the press book")
	check(_keys(_view([["event", "firefall", "The Firefall"]])) == ["firefall"], "the Firefall")
	check(_keys(_view([["event", "moonbow", "The Moonbow"]])).is_empty(), "the moonbow isn't on the list (it's a bonus)")
	var board := _view([], {"region": "half_dome", "where": "The Diving Board"})
	check(_keys(board) == ["monolith"], "any picture from the Diving Board is the face of Half Dome")
	check(_keys(_view([], {"region": "half_dome", "where": "Sub Dome"})).is_empty(), "but not from Sub Dome")
	var storm := {"region": "tunnel_view", "where": "Tunnel View", "season": GameClock.Season.WINTER, "snow": true}
	check(_keys(_view([], storm)) == ["winter_storm"], "Tunnel View in falling winter snow is the winter storm")
	storm.snow = false
	check(_keys(_view([], storm)).is_empty(), "not on a clear winter day")
	storm.snow = true
	storm.season = GameClock.Season.SPRING
	check(_keys(_view([], storm)).is_empty(), "and not in spring")
	check(_keys({}).is_empty() and not Photos.answers(Photos.get_entry("portrait"), {}), "nothing to see answers nothing")
	# Every line can be answered by something.
	var samples := {
		"half_dome": _view([["place", "Half Dome"]]), "monolith": board, "el_capitan": cap,
		"yosemite_falls": _view([["place", "Lower Yosemite Fall"]]), "bridalveil": _view([["place", "Bridalveil Fall"]]),
		"cathedral_rocks": _view([["place", "Cathedral Rocks"]]), "three_brothers": _view([["place", "Three Brothers"]]),
		"sentinel_rock": _view([["place", "Sentinel Rock"]]), "royal_arches": _view([["place", "Royal Arches"]]),
		"mirror_lake": _view([["place", "Mirror Lake"]]), "grizzly_giant": _view([["place", "Grizzly Giant"]]),
		"cathedral_peak": _view([["place", "Cathedral Peak"]]), "deer": _view([["animal", "mule_deer"]]),
		"bear": _view([["animal", "black_bear"]]), "bird": _view([["animal", "robin"]]),
		"squirrel": _view([["animal", "western_gray_squirrel"]]), "butterfly": _view([["animal", "butterfly_0"]]),
		"raptor": _view([["animal", "great_gray_owl"]]), "last_light": dusk,
		"first_light": _view([["place", "El Capitan"]], {"light": "first_light"}), "moon": _view([["place", "El Capitan"]], {"light": "moonlight"}),
		"winter_storm": _view([], {"region": "tunnel_view", "season": GameClock.Season.WINTER, "snow": true}),
		"firefall": _view([["event", "firefall"]]), "blossom": _view([["plant", "snow_plant"]]),
		"portrait": _view([["person", "wren_alvarez"]]),
	}
	for entry: Dictionary in Photos.SHOT_LIST:
		check(samples.has(entry.id) and Photos.answers(entry, samples[entry.id]), "something answers %s" % entry.id)


func test_titles_and_stars() -> void:
	check(Photos.title_for(_view([])) == "El Capitan Meadow", "a picture of nothing is named for where you stood")
	check(Photos.title_for(_view([], {"where": ""})) == "El Capitan Meadow", "or for the region")
	check(Photos.title_for(_view([["place", "El Capitan"]])) == "El Capitan", "a landmark names the picture")
	check(Photos.title_for(_view([["place", "El Capitan Meadow"], ["place", "El Capitan"]])) == "El Capitan", "a landmark before the meadow it stands over")
	check(Photos.title_for(_view([["place", "El Capitan"], ["animal", "mule_deer", "Mule Deer"]])) == "Mule Deer, El Capitan", "an animal comes first, then the landmark")
	check(Photos.title_for(_view([["animal", "mule_deer", "Mule Deer"], ["animal", "mule_deer", "Mule Deer"]])) == "Mule Deer", "two deer are one name")
	check(Photos.title_for(_view([["event", "firefall", "The Firefall"], ["person", "jennie_curry", "Jennie Curry"]])) == "The Firefall, Jennie Curry", "what's happening comes before who's watching")
	check(Photos.stars_for(_view([])) == 1, "a picture of nothing in particular is one star")
	check(Photos.stars_for(_view([], {"light": "last_light"})) == 1, "even in good light")
	check(Photos.stars_for(_view([["place", "El Capitan"]])) == 1, "El Capitan at noon is one star")
	check(Photos.stars_for(_view([["place", "El Capitan"]], {"light": "last_light"})) == 2, "in the last light, two")
	check(Photos.stars_for(_view([["place", "El Capitan"]], {"snow": true})) == 2, "or with snow coming down")
	check(Photos.stars_for(_view([["place", "El Capitan"], ["animal", "mule_deer"]])) == 2, "a deer under it at noon is two")
	check(Photos.stars_for(_view([["place", "El Capitan"], ["animal", "mule_deer"]], {"light": "alpenglow"})) == 3, "and three in the alpenglow")
	check(Photos.stars_for(_view([["animal", "bobcat"]], {"light": "first_light"})) == 3, "a bobcat at dawn is three by itself")
	check(Photos.stars_for(_view([["event", "firefall"]])) == 2 and Photos.stars_for(_view([["event", "firefall"]], {"light": "moonlight"})) == 3, "the Firefall is worth the wait")
	check(Photos.stars_for(_view([["place", "Village Store"], ["place", "Camp 6 parking"]], {"light": "last_light"})) == 2, "two parking lots don't make a third star")
	check(Photos.stars_for(_view([["place", "Half Dome"], ["animal", "stellers_jay"]], {"light": "last_light"})) == 2, "nor does a jay in the corner of Half Dome")
	check(Photos.stars_for(_view([["place", "Half Dome"], ["person", "john_muir"]], {"light": "last_light"})) == 3, "John Muir in front of Half Dome does")
	check(Photos.title_for(_view([["place", "Half Dome"], ["animal", "stellers_jay", "Steller's Jay"]])) == "Half Dome", "a jay in the corner doesn't rename Half Dome")
	check(Photos.title_for(_view([["animal", "stellers_jay", "Steller's Jay"], ["place", "Camp 4"]])) == "Steller's Jay", "a jay with nothing bigger is the picture")
	check(Photos.title_for(_view([["person", "john_muir", "John Muir"], ["place", "Half Dome"]])) == "Half Dome, John Muir", "a landmark comes before the person in front of it")
	check(Photos.title_for(_view([["place", "El Capitan"], ["place", "Half Dome"], ["place", "Bridalveil Fall"]], {"where": "Tunnel View"})) == "Tunnel View",
		"a view with three landmarks in it is named for where you stood")
	check(Photos.title_for(_view([["animal", "black_bear", "American Black Bear"], ["place", "El Capitan"], ["place", "Half Dome"], ["place", "Bridalveil Fall"]], {"where": "Tunnel View"})) == "American Black Bear, El Capitan",
		"unless a bear walks into it")


func test_toning() -> void:
	var image := Image.create_empty(4, 2, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.2, 0.5, 0.9))
	image.set_pixel(0, 0, Color.WHITE)
	image.set_pixel(1, 0, Color.BLACK)
	var color := image.duplicate()
	Photos.tone(color, "color")
	check(color.get_pixel(2, 1) == image.get_pixel(2, 1), "color film leaves the picture alone")
	var silver: Image = image.duplicate()
	Photos.tone(silver, "silver")
	var gray := silver.get_pixel(2, 1)
	check(is_equal_approx(gray.r, gray.g) and is_equal_approx(gray.g, gray.b), "black and white film has no color in it")
	check(silver.get_pixel(0, 0).r > 0.95 and silver.get_pixel(1, 0).r < 0.05, "white stays white and black stays black")
	var sepia: Image = image.duplicate()
	Photos.tone(sepia, "sepia")
	var brown := sepia.get_pixel(2, 1)
	check(brown.r > brown.g and brown.g > brown.b, "sepia film is warm")
	var sky := Image.create_empty(1, 1, false, Image.FORMAT_RGB8)
	sky.fill(Color(0.3, 0.5, 0.9))
	var rock := Image.create_empty(1, 1, false, Image.FORMAT_RGB8)
	rock.fill(Color(0.8, 0.75, 0.7))
	Photos.tone(sky, "silver")
	Photos.tone(rock, "silver")
	check(sky.get_pixel(0, 0).r < rock.get_pixel(0, 0).r - 0.2, "a blue sky prints darker than granite")


## A print is cut out of a picture of the window: checked here on a made-up
## window, since nothing is drawn headless.
func test_prints_from_a_screen() -> void:
	# A 1920x1080 window showing the 960x540 view at twice its size, with a
	# red block where the normal lens's frame is.
	var shot := Image.create_empty(1920, 1080, false, Image.FORMAT_RGB8)
	shot.fill(Color(0, 0, 1))
	var frame := Rect2(150, 75, 180, 120) # UI pixels
	shot.fill_rect(Rect2i(600, 300, 720, 480), Color(1, 0, 0))
	shot.fill_rect(Rect2i(600, 300, 2, 2), Color(0, 1, 0)) # one view pixel, top left
	var twice := Transform2D(0.0, Vector2(2, 2), 0.0, Vector2.ZERO)
	var print_image := CameraView.print_from(shot, frame, twice, "color")
	check(print_image != null and print_image.get_size() == Photos.PRINT_SIZE, "a print is %d x %d" % [Photos.PRINT_SIZE.x, Photos.PRINT_SIZE.y])
	check(print_image.get_pixel(0, 0).is_equal_approx(Color(0, 1, 0)) and print_image.get_pixel(1, 0).is_equal_approx(Color(1, 0, 0)),
		"the normal lens keeps the view's pixels one for one")
	check(print_image.get_pixel(359, 239).is_equal_approx(Color(1, 0, 0)), "and takes exactly what was in the frame")
	var wide := CameraView.print_from(shot, Rect2(60, 15, 360, 240), twice, "color")
	check(wide.get_size() == Photos.PRINT_SIZE and wide.get_pixel(2, 2).is_equal_approx(Color(0, 0, 1)) and wide.get_pixel(180, 120).is_equal_approx(Color(1, 0, 0)),
		"the wide lens takes four times the view into the same print")
	var long := CameraView.print_from(shot, Rect2(150, 75, 90, 60), twice, "color")
	check(long.get_size() == Photos.PRINT_SIZE and long.get_pixel(0, 0).is_equal_approx(Color(0, 1, 0)) and long.get_pixel(1, 1).is_equal_approx(Color(0, 1, 0))
		and long.get_pixel(2, 2).is_equal_approx(Color(1, 0, 0)), "the long lens doubles each pixel")
	var letterboxed := Transform2D(0.0, Vector2(2, 2), 0.0, Vector2(0, 60))
	var tall := Image.create_empty(1920, 1200, false, Image.FORMAT_RGB8)
	tall.fill(Color(0, 0, 1))
	tall.fill_rect(Rect2i(600, 360, 720, 480), Color(1, 0, 0))
	var boxed := CameraView.print_from(tall, frame, letterboxed, "silver")
	check(boxed.get_pixel(0, 0).r == boxed.get_pixel(0, 0).b and boxed.get_pixel(0, 0) == boxed.get_pixel(359, 239), "a window with bars round the view is cut in the right place, and toned")
	check(CameraView.print_from(shot, Rect2(2000, 2000, 180, 120), twice, "color") == null, "a frame off the picture gives no print")


func test_album() -> void:
	_new_game()
	check(Photos.album.is_empty() and Photos.listed_count() == 0 and Photos.total == 0 and not Photos.has_camera(), "a new game has no camera and no prints")
	check(Photos.dir() == "user://photos_test_save_photos/", "a test's prints are kept beside its own save (%s)" % Photos.dir())
	var taken: Array = []
	var ticked: Array = []
	var on_taken := func(photo: Dictionary) -> void: taken.append(photo.id)
	var on_ticked := func(entry: Dictionary) -> void: ticked.append(entry.id)
	Photos.taken.connect(on_taken)
	Photos.list_ticked.connect(on_ticked)
	GameClock.season = GameClock.Season.SUMMER
	GameClock.day = 3
	GameClock.minutes = 18 * 60 + 10
	Photos.film = "sepia"
	var photo := Photos.develop(_view([["place", "El Capitan"], ["animal", "mule_deer", "Mule Deer"]], {"light": "last_light"}))
	check(photo.title == "Mule Deer, El Capitan" and photo.stars == 3 and photo.film == "sepia" and photo.where == "El Capitan Meadow", "a photograph is developed with its title, stars and film")
	check(photo.new.size() == 3 and ticked == ["el_capitan", "deer", "last_light"], "it ticks three lines of the list (%s)" % str(ticked))
	check(Photos.album.size() == 1 and Photos.total == 1 and Photos.best_ever == 3 and taken == [photo.id], "it goes in the album")
	check(FileAccess.file_exists(Photos.path_of(photo.id)), "its print is a file")
	var texture := Photos.texture(photo.id)
	check(texture != null and Vector2i(texture.get_size()) == Photos.PRINT_SIZE, "and a picture the album can show")
	check(FieldLog.has("mule_deer"), "a deer on film is a deer in the field log")
	check(QuestLog.is_unlocked(Photos.FIRST_PHOTO), "the first photograph is marked")
	check(Photos.caption(photo) == "Summer 3, year 1 · 6:10 PM · last light", "its back says when and in what light (%s)" % Photos.caption(photo))
	check(Achievements.has("first_print") and Achievements.has("three_stars") and not Achievements.has("portfolio"), "First Exposure and Worth the Wait are earned")
	var again := Photos.develop(_view([["place", "El Capitan"]]))
	check(again.new.is_empty() and Photos.listed_count() == 3, "El Capitan again ticks nothing new")
	var red := Image.create_empty(720, 480, false, Image.FORMAT_RGB8)
	red.fill(Color(1, 0, 0))
	var real := Photos.develop(_view([["person", "john_muir", "John Muir"]]), red)
	check(not real.blank and Vector2i(Photos.texture(real.id).get_size()) == Photos.PRINT_SIZE, "a print of any size is brought to print size")
	check(Image.load_from_file(Photos.path_of(real.id)).get_pixel(10, 10).is_equal_approx(Color(1, 0, 0)), "and what's on file is the picture")
	# taking one out
	Photos.remove(photo.id)
	check(Photos.album.size() == 2 and not FileAccess.file_exists(Photos.path_of(photo.id)), "a print taken out is gone, file and all")
	check(Photos.is_listed("deer") and Photos.best_ever == 3 and Photos.total == 3, "the list and the tally keep what it showed")
	# the album fills up
	while not Photos.is_full():
		Photos.develop(_view([]))
	check(Photos.album.size() == Photos.ALBUM_SIZE and Photos.develop(_view([])).is_empty() and Photos.album.size() == Photos.ALBUM_SIZE, "a full album takes no more")
	check(Photos.develop({}).is_empty(), "and there's no photograph of nothing at all")
	Photos.taken.disconnect(on_taken)
	Photos.list_ticked.disconnect(on_ticked)


func test_saving() -> void:
	_new_game()
	Photos.film = "silver"
	var a := Photos.develop(_view([["place", "Half Dome"]], {"light": "moonlight"}))
	var b := Photos.develop(_view([["animal", "black_bear", "American Black Bear"]]))
	var saved: Dictionary = JSON.parse_string(JSON.stringify(Photos.save_data()))
	# a print nobody's album shows: lost by quitting without saving
	Photos.blank_print().save_png(Photos.path_of("stray"))
	Photos.start_new_game()
	check(Photos.album.is_empty() and Photos.film == "color", "a new game starts the album over")
	Photos.load_data(saved)
	check(Photos.album.size() == 2 and Photos.album[0].id == a.id and Photos.album[1].title == "American Black Bear", "the album comes back from a save")
	check(Photos.album[0].stars == a.stars and Photos.album[0].light == "moonlight" and Photos.album[0].film == "silver", "each print with its stars, light and film")
	check(Photos.is_listed("half_dome") and Photos.is_listed("moon") and Photos.is_listed("bear") and Photos.listed_count() == 3, "the list comes back")
	check(Photos.film == "silver" and Photos.total == 2 and Photos.best_ever == a.stars, "and the film in the camera, and the tallies")
	check(not FileAccess.file_exists(Photos.path_of("stray")), "loading sweeps out prints no album shows")
	check(FileAccess.file_exists(Photos.path_of(a.id)) and FileAccess.file_exists(Photos.path_of(b.id)), "and keeps the ones it does")
	# a print a save in another slot still shows stays on disk
	SaveManager.save_game()
	Photos.remove(b.id)
	check(FileAccess.file_exists(Photos.path_of(b.id)), "a print taken out stays on disk while a save still shows it")
	SaveManager.delete_save()
	check(Photos.sweep() == 1 and not FileAccess.file_exists(Photos.path_of(b.id)), "and is swept once no save does")
	# a missing file doesn't break the album
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Photos.path_of(a.id)))
	Photos._textures.clear()
	check(Photos.texture(a.id) != null, "a print whose file is gone shows a plain card")
	Photos.load_data({"album": [{"id": ""}, "junk", {"id": "x", "stars": 9}], "listed": {"nonsense": {}, "deer": 3}, "film": "infrared", "lens": "fisheye"})
	check(Photos.album.size() == 1 and Photos.album[0].stars == 3 and Photos.listed.keys() == ["deer"] and Photos.film == "color" and Photos.lens == "normal",
		"a damaged save loads what it can")
	Photos.load_data({})
	check(Photos.album.is_empty() and Photos.listed.is_empty(), "a save from before the camera loads with an empty album")


func test_quests() -> void:
	_new_game()
	for id in ["ansel_brownie", "ansel_portfolio", "ansel_exhibition"]:
		var quest := QuestLog.get_quest(id)
		check(quest != null and quest.giver == "ansel_adams" and RegisterPages.HISTORY.has(id), "%s is Ansel's, with a Register note" % id)
	check(QuestLog.get_quest("ansel_portfolio").unhurried and QuestLog.get_quest("ansel_exhibition").unhurried, "the portfolio and the back wall are unhurried")
	check(QuestLog.available_from("ansel_adams") == null, "Ansel has nothing for you before Clark's Register")
	QuestLog.completed.append("clark_register")
	var gear_seen: Array = []
	var on_gear := func(id: String, _amount: int) -> void: gear_seen.append(id)
	Gear.added.connect(on_gear)
	var lines := QuestLog.talk_to("ansel_adams")
	check(QuestLog.active.has("ansel_brownie") and Photos.has_camera(), "Ansel lends you the Box Brownie")
	check(Gear.count(Photos.GEAR) == 1 and gear_seen == [Photos.GEAR], "it goes in the Backpack as gear")
	check(lines.any(func(l: Dictionary) -> bool: return l.text.begins_with("Received the camera.") and "F" in l.text), "and you're told how to raise it")
	lines = QuestLog.talk_to("ansel_adams")
	check(QuestLog.active.has("ansel_brownie") and lines.size() == 1, "he waits for a photograph")
	check(QuestLog.marker_for("ansel_adams") == "", "with nothing over his head")
	Photos.develop(_view([["place", "Camp 4"]]))
	check(QuestLog.marker_for("ansel_adams") == "?", "a first photograph is something to show him")
	QuestLog.talk_to("ansel_adams")
	check(QuestLog.is_completed("ansel_brownie") and Photos.has_camera(), "The Box Brownie is finished, and the camera stays yours")
	check(RegisterPages.written().any(func(p: Dictionary) -> bool: return p.by == "Ansel Adams" and "Brownie" in p.text), "his page goes in the Register")
	QuestLog.talk_to("ansel_adams")
	check(QuestLog.active.has("ansel_portfolio"), "next he asks for a portfolio")
	check(QuestLog.objective_text(QuestLog.get_quest("ansel_portfolio")).ends_with("(0 of 8)"), "the quest counts pictures from the list (%s)" % QuestLog.objective_text(QuestLog.get_quest("ansel_portfolio")))
	# The portfolio is unhurried: his other stories aren't held up by it.
	QuestLog.completed.append("leonard_belay")
	QuestLog.talk_to("ansel_adams")
	check(QuestLog.active.has("ansel_monolith") and QuestLog.active.has("ansel_portfolio"), "Monolith is offered while the portfolio is open")
	QuestLog.active.erase("ansel_monolith")
	QuestLog.completed.append("ansel_monolith")
	check(not Photos.has_lenses() and Photos.lenses() == ["normal"], "one lens to start with")
	for sample in [[["place", "El Capitan"]], [["place", "Half Dome"]], [["animal", "mule_deer"]], [["animal", "robin"]],
			[["person", "wren_alvarez"]], [["plant", "black_oak"]], [["place", "Mirror Lake"]]]:
		Photos.develop(_view(sample))
	check(Photos.listed_count() == 7 and QuestLog.objective_text(QuestLog.get_quest("ansel_portfolio")).ends_with("(7 of 8)"), "seven of eight")
	check(not QuestLog.is_step_done(QuestLog.current_step(QuestLog.get_quest("ansel_portfolio"))), "seven isn't a portfolio")
	Photos.develop(_view([["place", "Bridalveil Fall"]]))
	check(QuestLog.marker_for("ansel_adams") == "?" and Achievements.has("portfolio"), "eight is")
	check("Show Ansel Adams" in QuestLog.objective_text(QuestLog.get_quest("ansel_portfolio")), "the quest says to show him")
	gear_seen.clear()
	lines = QuestLog.talk_to("ansel_adams")
	check(QuestLog.is_completed("ansel_portfolio") and Photos.has_lenses() and Photos.lenses().size() == 3, "A Portfolio earns the wide and the long lens")
	check(lines.any(func(l: Dictionary) -> bool: return "Ansel's Lenses" in l.text), "and says so")
	# The back wall waits for his other stories to be offered first.
	QuestLog.completed.append_array(["ansel_high_country", "ansel_diving_board"])
	QuestLog.talk_to("ansel_adams")
	check(QuestLog.active.has("ansel_exhibition"), "then the back wall")
	for entry: Dictionary in Photos.SHOT_LIST:
		if Photos.listed_count() >= 17:
			break
		Photos.listed[entry.id] = {"day": 1, "title": "test"}
	check(not QuestLog.is_step_done(QuestLog.current_step(QuestLog.get_quest("ansel_exhibition"))), "seventeen isn't enough")
	for entry: Dictionary in Photos.SHOT_LIST:
		Photos.listed[entry.id] = {"day": 1, "title": "test"}
	QuestLog.talk_to("ansel_adams")
	check(QuestLog.is_completed("ansel_exhibition"), "The Back Wall is finished")
	Achievements.check()
	check(Achievements.has("whole_valley"), "the whole list is The Whole Valley on Paper")
	Gear.added.disconnect(on_gear)
	# A step can ask for particular pictures too.
	_new_game()
	var step := {"type": "photographed", "count": 1, "shots": ["bear"]}
	Photos.develop(_view([["animal", "mule_deer"]]))
	check(not QuestLog.is_step_done(step), "a step that asks for a bear isn't done by a deer")
	Photos.develop(_view([["animal", "black_bear"]]))
	check(QuestLog.is_step_done(step), "and is by a bear")


func _camera_view() -> CameraView:
	return get_tree().get_first_node_in_group("camera_view") as CameraView


func _album_screen() -> PhotoAlbum:
	return get_tree().get_first_node_in_group("photo_album") as PhotoAlbum


func _settle(frames := 6) -> void:
	for i in frames:
		await get_tree().physics_frame
		await get_tree().process_frame


func _press(action: String) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	Input.parse_input_event(event)
	await get_tree().process_frame
	var release := InputEventAction.new()
	release.action = action
	release.pressed = false
	Input.parse_input_event(release)
	await get_tree().process_frame


func _key(physical: Key) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = physical
	event.keycode = physical
	event.pressed = true
	Input.parse_input_event(event)
	await get_tree().process_frame
	var release := InputEventKey.new()
	release.physical_keycode = physical
	release.keycode = physical
	release.pressed = false
	Input.parse_input_event(release)
	await get_tree().process_frame


## What the real world puts in a frame: its places, animals, people, plants
## and the Firefall.
func test_subjects_in_the_world() -> void:
	_new_game()
	GameClock.season = GameClock.Season.SUMMER
	GameClock.day = 3
	GameClock.minutes = 12 * 60
	await world.go_to_region("curry_village", "arrival")
	await _settle()
	var player: Player = world.player
	var here := player.global_position
	var around := Rect2(here - Vector2(180, 120), Vector2(360, 240))
	var view := Photos.observe(around, here)
	check(view.region == "curry_village" and view.region_name == "Curry Village" and view.light == "midday" and not view.indoors, "a look round Curry Village at noon")
	check(view.season == GameClock.Season.SUMMER and not view.snow and not view.rain, "in fair summer weather")
	var standing: Place = world.region.place_at(world.region.to_local(here))
	check(view.where == (standing.display_name if standing else ""), "it knows where you stand (%s)" % view.where)
	# a place's anchor in the frame
	var plaza: Place = null
	for place in world.region.get_places():
		if place.display_name == "Camp Curry Plaza":
			plaza = place
	check(plaza != null, "Curry Village has its plaza")
	var at_plaza := Photos.observe(Rect2(plaza.global_position - Vector2(50, 50), Vector2(100, 100)), here)
	check(at_plaza.subjects.any(func(s: Dictionary) -> bool: return s.kind == "place" and s.id == "Camp Curry Plaza"), "a place is in the frame when its marker is")
	var beside := Photos.observe(Rect2(plaza.global_position + Vector2(60, 60), Vector2(100, 100)), here)
	check(not beside.subjects.any(func(s: Dictionary) -> bool: return s.id == "Camp Curry Plaza"), "and not when the frame is beside it")
	# animals
	var critters: Critters = null
	var deer: Deer = null
	var falcons: Falcons = null
	for child in world.get_children():
		if child is Critters:
			critters = child
		elif child is Deer:
			deer = child
		elif child is Falcons:
			falcons = child
	critters.add_bird("stellers_jay", here + Vector2(40, 30))
	critters.add_squirrel("western_gray_squirrel", here + Vector2(-60, 20))
	deer.add_group(here + Vector2(90, -40), here + Vector2(400, -40))
	view = Photos.observe(around, here)
	var ids: Array = view.subjects.filter(func(s: Dictionary) -> bool: return s.kind == "animal").map(func(s: Dictionary) -> String: return s.id)
	check("stellers_jay" in ids and "western_gray_squirrel" in ids and "mule_deer" in ids, "a jay, a squirrel and a deer are in the frame (%s)" % str(ids))
	check(view.subjects.any(func(s: Dictionary) -> bool: return s.id == "stellers_jay" and s.name == "Steller's Jay"), "by their field-log names")
	var far := Photos.observe(Rect2(here + Vector2(600, 600), Vector2(360, 240)), here)
	check(not far.subjects.any(func(s: Dictionary) -> bool: return s.kind == "animal"), "and not in a frame somewhere else")
	var falcon := falcons.send_one()
	if not falcon.is_empty():
		var up: Vector2 = falcons.to_global(falcon.pos - Vector2(0, falcon.height))
		var sky := Photos.observe(Rect2(up - Vector2(40, 40), Vector2(80, 80)), here)
		check(sky.subjects.any(func(s: Dictionary) -> bool: return s.id == "peregrine_falcon"), "a falcon is where it flies, not where its shadow is")
	else:
		check(true, "(no falcon over Curry Village to frame)")
	# people
	var someone: NPC = null
	for node in get_tree().get_nodes_in_group("talkers"):
		if node is NPC and node.character != null and node.is_visible_in_tree() and world.region.is_ancestor_of(node):
			someone = node
			break
	check(someone != null, "there's somebody in Curry Village")
	if someone:
		var portrait := Photos.observe(Rect2(someone.global_position - Vector2(60, 80), Vector2(120, 120)), here)
		check(portrait.subjects.any(func(s: Dictionary) -> bool: return s.kind == "person" and s.name == someone.character.display_name), "%s is in a frame put round them" % someone.character.display_name)
		check("portrait" in _keys(portrait), "which makes a portrait")
	# plants
	var plant: PlantSpecimen = null
	for node in get_tree().get_nodes_in_group("photo_subjects"):
		if node is PlantSpecimen and world.region.is_ancestor_of(node):
			plant = node
			break
	check(plant != null, "a press-book plant grows in Curry Village in summer")
	if plant:
		var study := Photos.observe(Rect2(plant.global_position - Vector2(40, 40), Vector2(80, 80)), here)
		check(study.subjects.any(func(s: Dictionary) -> bool: return s.kind == "plant" and s.id == plant.plant_id), "and is in a frame put round it")
	# the Firefall
	var firefall: Firefall = null
	for node in get_tree().get_nodes_in_group("photo_subjects"):
		if node is Firefall:
			firefall = node
	check(firefall != null, "Curry Village has its Firefall")
	if firefall:
		var wall := Rect2(firefall.global_position - Vector2(100, 40), Vector2(200, 240))
		check(not Photos.observe(wall, here).subjects.any(func(s: Dictionary) -> bool: return s.kind == "event"), "nothing falls at noon")
		firefall.level = 1.0
		firefall.visible = true
		check("firefall" in _keys(Photos.observe(wall, here)), "while it burns, a frame on the wall holds the Firefall")
		firefall.level = 0.0
		firefall.visible = false
	# indoors
	await world.go_to_region("bests_studio", "arrival")
	await _settle()
	here = world.player.global_position
	view = Photos.observe(Rect2(here - Vector2(180, 120), Vector2(360, 240)), here)
	check(view.indoors and view.light == "indoors" and not view.snow, "inside Best's Studio the light is indoors")


## The viewfinder, driven by keys.
func test_viewfinder() -> void:
	_new_game()
	GameClock.minutes = 12 * 60
	await world.go_to_region("curry_village", "arrival")
	await _settle()
	var camera := _camera_view()
	var player: Player = world.player
	check(camera != null and not camera.is_open(), "World has a camera, put away")
	await _press("camera")
	check(not camera.is_open() and world.hud.message_label.text == CameraView.NO_CAMERA, "with no camera, the key says who lends one")
	QuestLog.unlocks.append(Photos.ABILITY)
	await _press("camera")
	check(camera.is_open() and not player.can_act, "with one, it raises the viewfinder, and you stand still")
	await _settle(3)
	check(world.hud.is_covered(), "the HUD hides behind it")
	check(not GameClock.paused or true, "(the test holds the clock)")
	var frame := camera.frame_rect()
	check(frame.size == Vector2(180, 120) and Rect2(Vector2.ZERO, UiScale.SCREEN).encloses(frame), "the frame is a print's shape, on the screen")
	var in_world := camera.world_rect()
	check(in_world.size.is_equal_approx(Vector2(360, 240)), "it covers 360 x 240 of the world (%s)" % str(in_world.size))
	check(in_world.grow(40).has_point(player.global_position), "round about where you stand")
	check("Shutter" in camera._hints.text and "Film" in camera._hints.text and "Album" in camera._hints.text and not "Lens" in camera._hints.text,
		"the hints name the shutter, the film and the album (%s)" % camera._hints.text)
	check("Normal lens" in camera._status.text and "Color film" in camera._status.text and "0 of %d prints" % Photos.ALBUM_SIZE in camera._status.text,
		"the status names the lens, the film and the album's room (%s)" % camera._status.text)
	# the frame moves, and stops at the screen's edge
	camera.nudge(Vector2(-1000, -1000))
	check(camera.frame_rect().position == Vector2(2, 2), "the frame stops at the screen's corner")
	camera.nudge(Vector2(1000, 1000))
	check(camera.frame_rect().end == UiScale.SCREEN - Vector2(2, 2), "and at the other")
	camera.nudge(-(UiScale.SCREEN / 2.0 - Vector2(92, 62)))
	var before := camera.frame_rect().position
	Input.action_press("move_right")
	await _settle(8)
	Input.action_release("move_right")
	check(camera.frame_rect().position.x > before.x and player.velocity == Vector2.ZERO, "the walking keys move the frame, not you")
	# it names what it holds
	var critters: Critters = null
	for child in world.get_children():
		if child is Critters:
			critters = child
	critters._birds.clear()
	critters._squirrels.clear()
	critters._flies.clear()
	critters.add_bird("robin", camera.world_rect().get_center())
	camera._look_now()
	check(camera.view().subjects.any(func(s: Dictionary) -> bool: return s.id == "robin") and camera._subject.text != "", "the viewfinder names what's in the frame (%s)" % camera._subject.text)
	check(camera._note.text == "New for Ansel's list: A bird", "and says when it's new for the list (%s)" % camera._note.text)
	# film
	await _key(KEY_T)
	check(Photos.film == "silver" and "Black and white film" in camera._status.text, "T changes the film")
	# one lens
	await _key(KEY_R)
	check(Photos.lens == "normal" and "One lens" in camera._note.text, "R says there's one lens for now")
	# the shutter
	critters.add_bird("robin", camera.world_rect().get_center())
	await _press("interact")
	await _settle(4)
	check(Photos.album.size() == 1 and Photos.album[0].film == "silver" and "American Robin" in Photos.album[0].subjects, "the shutter takes the picture (%s)" % (Photos.album[0].title if not Photos.album.is_empty() else "none"))
	check(Photos.album[0].blank, "with nothing drawn headless, the print is a plain card")
	check(Photos.is_listed("bird") and FieldLog.has("robin"), "the robin is on the list and in the field log")
	check("New in the field log: American Robin" in camera._card_note.text, "and the print says it's new in the field log")
	check(camera._card.visible and camera._card_title.text == Photos.album[0].title and "A bird" in camera._card_note.text, "the print shows in the corner, with what it did for the list")
	check(camera.is_open() and "1 of %d prints" % Photos.ALBUM_SIZE in camera._status.text, "and the camera stays up for another")
	# a full album
	var kept := Photos.album.duplicate()
	while not Photos.is_full():
		Photos.album.append(kept[0].duplicate())
	await _press("interact")
	await _settle(2)
	check(Photos.album.size() == Photos.ALBUM_SIZE and "full" in camera._note.text, "a full album says so and takes no picture")
	Photos.album.assign(kept)
	# lenses
	Gear.add(Photos.LENSES_GEAR)
	camera.nudge(Vector2.ZERO)
	await _key(KEY_R)
	check(Photos.lens == "long" and camera.frame_rect().size == Vector2(90, 60), "with Ansel's lenses, R fits the long lens")
	check(camera.world_rect().size.is_equal_approx(Vector2(180, 120)), "which holds half as much")
	await _key(KEY_R)
	check(Photos.lens == "wide" and camera.frame_rect().size == Vector2(360, 240) and Rect2(Vector2.ZERO, UiScale.SCREEN).encloses(camera.frame_rect()), "then the wide one, still on the screen")
	await _key(KEY_R)
	check(Photos.lens == "normal", "and round to the normal lens")
	check("Lens" in camera._hints.text, "the hints name the lens key now")
	# nothing else answers while it's up
	await _press("journal")
	check(not get_tree().get_first_node_in_group("journal").is_open(), "the journal stays shut behind the viewfinder")
	await _press("map")
	check(not world.park_map.is_open(), "and the map")
	# the album, and back
	await _press("ui_focus_next")
	var album := _album_screen()
	check(album.is_open() and camera.is_open(), "Tab opens the album over the viewfinder")
	await _press("ui_cancel")
	check(not album.is_open() and camera.is_open(), "Esc closes the album, back to the viewfinder")
	await _press("ui_cancel")
	check(not camera.is_open() and player.can_act, "and Esc again puts the camera away")
	await _settle(3)
	check(not world.hud.is_covered(), "the HUD comes back")
	await _press("camera")
	await _press("camera")
	check(not camera.is_open() and player.can_act, "the camera key raises it and puts it away")
	# a conversation takes over
	await _press("camera")
	var box := DialogueBox.open(player)
	await _settle(2)
	check(not camera.is_open() and not player.can_act, "the camera goes away when someone talks to you, and you stay put to listen")
	box.close()
	await _settle(4)
	player.can_act = true
	Photos.film = "color"


## The album screen, driven by keys.
func test_album_screen() -> void:
	_new_game()
	QuestLog.unlocks.append(Photos.ABILITY)
	var album := _album_screen()
	var camera := _camera_view()
	var player: Player = world.player
	player.can_act = true
	await _press("camera")
	await _press("ui_focus_next")
	check(album.is_open() and album.page() == PhotoAlbum.Page.ALBUM and album.chosen().is_empty(), "an empty album opens on its first page")
	check(album._empty.visible and "Take out" not in album._footer.text, "and says there's nothing in it yet")
	check(GameClock.paused, "the clock waits while you look")
	await _press("ui_cancel")
	GameClock.minutes = 18 * 60 + 10
	for sample in [[["place", "El Capitan"]], [["animal", "mule_deer", "Mule Deer"], ["place", "Half Dome"]], [["person", "john_muir", "John Muir"]],
			[["plant", "snow_plant", "Snow Plant"]], [["place", "Mirror Lake"]]]:
		Photos.develop(_view(sample, {"light": "last_light"}))
	await _press("ui_focus_next")
	await _settle(2)
	check(album._thumbs.size() == 5 and album.chosen().title == "Mirror Lake", "five prints, the newest chosen")
	check(album._title.text == "Mirror Lake" and album._where.text == "El Capitan Meadow" and "last light" in album._when.text, "its back is written out beside it")
	check("Normal lens" in album._made.text and "color film" in album._made.text, "with the lens and film")
	check(album._big.texture == Photos.texture(album.chosen().id), "and the print itself")
	check("5 of %d" % Photos.ALBUM_SIZE in album._tab_labels[0].text and "of %d" % Photos.SHOT_LIST.size() in album._tab_labels[1].text, "the tabs count the prints and the list")
	await _press("ui_left")
	check(album.chosen().title == "Snow Plant", "Left chooses the print before")
	await _press("ui_up")
	check(album.chosen().title == "El Capitan", "Up the one above")
	await _press("ui_right")
	check(album.chosen().title == "Mule Deer, Half Dome" and album._stars_count == 3, "Right the next, with its stars")
	album.look()
	check("In the frame: Mule Deer, Half Dome" in album._subjects.text, "looked at on its own, it names what's in the frame")
	album._look.visible = false
	await _press("ui_up")
	check(album.chosen().title == "Mule Deer, Half Dome", "there's no row above the top one")
	await _press("ui_down")
	check(album.chosen().title == "Mirror Lake", "Down comes back")
	# looking at one
	await _press("interact")
	check(album.is_looking() and album._look_print.texture == Photos.texture(album.chosen().id), "E looks at the print on its own")
	await _press("ui_cancel")
	check(not album.is_looking() and album.is_open(), "Esc goes back to the album")
	# taking one out asks first
	await _key(KEY_DELETE)
	check(album.is_asking() and "for good" in album._footer.text and Photos.album.size() == 5, "Delete asks first")
	await _press("ui_cancel")
	check(not album.is_asking() and Photos.album.size() == 5 and album.is_open(), "Esc keeps it")
	await _key(KEY_DELETE)
	await _press("interact")
	await _settle(2)
	check(Photos.album.size() == 4 and album.chosen().title == "Snow Plant" and album._thumbs.size() == 4, "E takes it out, and the cursor stays in the album")
	check(Photos.is_listed("mirror_lake"), "the list keeps Mirror Lake")
	# the list
	await _press("ui_focus_next")
	check(album.page() == PhotoAlbum.Page.LIST, "Tab turns to Ansel's list")
	var page := ""
	for label in album._list_body.find_children("*", "Label", true, false):
		page += label.text + "\n"
	for group: String in Photos.GROUPS:
		check(page.contains("%s (%d of %d)" % [group, Photos.listed_in(group), Photos.in_group(group).size()]), "the list counts %s" % group)
	check(page.contains(Photos.get_entry("el_capitan").note) and not page.contains(Photos.get_entry("el_capitan").hint), "a picture you've made shows its note")
	check(page.contains(Photos.get_entry("bear").hint) and not page.contains(Photos.get_entry("bear").note), "one you haven't says where to look")
	await _press("ui_focus_next")
	check(album.page() == PhotoAlbum.Page.ALBUM, "Tab turns back")
	await _press("ui_cancel")
	await _press("ui_cancel")
	check(not album.is_open() and not camera.is_open() and player.can_act and not GameClock.paused or GameClock.paused, "everything closes")
	GameClock.paused = true


## Every landmark on the list can be put in the frame from somewhere you
## can walk to from the region's way in, in every region its hint names:
## the camera tilts up at the cliffs and the frame reaches the top of the
## screen, and at the overlooks the far view's landmarks are found where
## the painting shows them.
func test_landmarks_can_be_framed() -> void:
	_new_game()
	QuestLog.unlocks.append(Photos.ABILITY)
	GameClock.minutes = 12 * 60
	var camera := _camera_view()
	var player: Player = world.player
	# One region at a time, so each is loaded once.
	var by_region := {}
	for id: String in LANDMARK_REGIONS:
		for region_id: String in LANDMARK_REGIONS[id]:
			if not by_region.has(region_id):
				by_region[region_id] = []
			by_region[region_id].append(id)
	for region_id: String in by_region:
		await world.go_to_region(region_id, "arrival")
		await _settle()
		check(world.region.region_id == region_id, "the walk test reaches %s" % region_id)
		var grid := WalkGrid.of(world.region)
		var way_in: Marker2D = world.region.get_spawn("arrival")
		var start: Vector2 = grid.nearest_open(way_in.global_position if way_in else player.global_position)
		for id: String in by_region[region_id]:
			var entry := Photos.get_entry(id)
			var names: Array = entry.any.map(func(tag: String) -> String: return tag.trim_prefix("place:"))
			# Where to try standing: at an overlook, its named spots (the far
			# view moves with the camera); elsewhere below the landmark,
			# nearer first, a little to either side if need be.
			var spots: Array[Vector2] = []
			if Photos.VISTAS.has(region_id):
				for marker in world.region.get_node("Markers").get_children():
					spots.append(marker.global_position)
				for place in world.region.get_places():
					if place.radius > 0.0:
						spots.append(place.global_position)
			else:
				var place: Place = null
				for p in world.region.get_places():
					if p.display_name in names:
						place = p
				check(place != null, "%s has a place for %s" % [region_id, entry.name])
				if place == null:
					continue
				for down in [60, 120, 180, 240, 300, 360, 440, 520, 600]:
					for across in [0, -96, 96, -200, 200]:
						if place.global_position.y + down >= place.global_position.y:
							spots.append(place.global_position + Vector2(across, down))
			var framed := false
			var tried := 0
			for want in spots:
				if framed:
					break
				var spot: Vector2 = grid.nearest_open(want, 3)
				if not grid.is_open(spot) or grid.route(start, spot).is_empty():
					continue
				tried += 1
				player.global_position = spot
				player.can_act = true
				world._camera().reset_smoothing()
				await _settle(3)
				world._camera().reset_smoothing()
				await _settle(2)
				for landmark: String in names:
					var at := Photos.find_landmark(landmark)
					if at == Vector2.INF or framed:
						continue
					camera.open()
					var on_screen: Vector2 = get_viewport().get_canvas_transform() * at / UiScale.FACTOR
					camera.nudge(on_screen - camera.frame_rect().get_center())
					framed = Photos.answers(entry, camera.view())
					camera.close()
			check(framed, "%s can be framed in %s from somewhere you can walk to (%d spots tried)" % [entry.name, region_id, tried])
	# An overlook's map labels for far-off things aren't where they're seen.
	await world.go_to_region("tunnel_view", "arrival")
	await _settle()
	var label: Place = null
	for p in world.region.get_places():
		if p.display_name == "Half Dome":
			label = p
	check(label != null and label.radius <= 0.0, "Tunnel View has a map label for Half Dome")
	if label:
		var view := Photos.observe(Rect2(label.global_position - Vector2(20, 20), Vector2(40, 40)), player.global_position)
		check(not view.subjects.any(func(s: Dictionary) -> bool: return s.id == "Half Dome"), "a frame on the label isn't a picture of Half Dome")
	player.can_act = true


func test_journal_and_logbook() -> void:
	_new_game()
	var journal: Journal = get_tree().get_first_node_in_group("journal")
	journal.open(Journal.Tab.JOURNAL)
	var page := _page(journal)
	check(not page.contains("Photographs:"), "the Journal says nothing of photographs before you have the camera")
	journal.close()
	QuestLog.unlocks.append(Photos.ABILITY)
	Photos.develop(_view([["place", "El Capitan"]]))
	journal.open(Journal.Tab.JOURNAL)
	page = _page(journal)
	check(page.contains("Photographs: 1 of %d on Ansel's list" % Photos.SHOT_LIST.size()) and page.contains("1 print in the album"), "with it, the Journal counts the list and the prints")
	journal.show_tab(Journal.Tab.LOGBOOK)
	page = _page(journal)
	check(page.contains("PHOTOGRAPHY") and page.contains("First Exposure"), "the Logbook has the Photography achievements")
	journal.close()
	# the day's page
	var log: DayLog = world.day_log
	check(log.photos >= 1 and "El Capitan" in log.shots, "the day's page counts today's photographs")
	var saved: Dictionary = JSON.parse_string(JSON.stringify(log.save_data()))
	log.clear()
	check(log.photos == 0 and log.shots.is_empty(), "and starts over in the morning")
	log.load_data(saved)
	check(log.photos >= 1 and not log.is_empty(), "a day with only a photograph in it isn't an empty page")
	world.player.can_act = true


func _page(journal: Journal) -> String:
	var text := ""
	for child in journal._body.get_children():
		if child is Label:
			text += child.text + "\n"
	return text
