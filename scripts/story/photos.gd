extends Node
## Your photographs (autoload "Photos"): the prints in your album, and Ansel
## Adams's shot list.
##
## Ansel Adams lends you a camera at Best's Studio (the "camera" unlock, from
## his quest "The Box Brownie"). Raise it (CameraView), frame a piece of the
## park and press the shutter: the picture is what the screen showed inside
## the frame, toned by the film in the camera, and kept as a small PNG beside
## the save. Each print remembers what was in it (the landmarks, animals,
## people and plants standing inside the frame), where and when it was made,
## and the light.
##
## The shot list is the collecting half: 25 pictures Ansel would like to see,
## from the park's great views to a deer, the Firefall, and a landmark in the
## last light of day. A photograph fills every entry it answers, and the list
## keeps what it's seen even if you take the print out of the album.
##
## What can be photographed is asked of the world, not kept here: any node in
## the "photo_subjects" group answers photo_subjects() with what it's showing
## ({kind, id, name, at}, [code]at[/code] in global pixels), and a region's
## Places name its landmarks.

signal changed
## Sent when a picture goes in the album.
signal taken(photo: Dictionary)
## Sent the first time a picture answers a shot-list entry.
signal list_ticked(entry: Dictionary)

## The QuestLog unlock that says you carry the camera, and the gear it shows
## as in the Backpack.
const ABILITY := "camera"
const GEAR := "camera"
## The gear that is the other two lenses (Ansel's second quest gives it).
const LENSES_GEAR := "camera_lenses"
## The first picture ever taken sets this unlock, which Ansel's first quest
## waits on.
const FIRST_PHOTO := "first_photograph"
## A print's size in pixels: three to two, like a 35mm frame.
const PRINT_SIZE := Vector2i(360, 240)
## How many prints the album holds.
const ALBUM_SIZE := 48
## Where prints are kept for the real saves. A test's save file (or any other
## SaveManager.base_path) gets a folder of its own beside it: see [method dir].
const REAL_DIR := "user://photos/"
const REAL_SAVE := "user://save.json"

## The films, and what the camera calls them.
const FILMS := ["color", "silver", "sepia"]
const FILM_NAMES := {"color": "Color", "silver": "Black and white", "sepia": "Sepia"}
## The lenses: how much of the 960x540 view the frame takes, in view pixels.
## Each is PRINT_SIZE times a whole number or half of it, so a print is made
## of whole pixels of the picture.
const LENSES := ["wide", "normal", "long"]
const LENS_NAMES := {"wide": "Wide lens", "normal": "Normal lens", "long": "Long lens"}
const LENS_FRAMES := {"wide": Vector2(720, 480), "normal": Vector2(360, 240), "long": Vector2(180, 120)}

## The light a picture was made in: what a caption calls it, and whether it's
## the kind of light worth waiting for.
const LIGHTS := {
	"first_light": {"name": "first light", "good": true},
	"morning": {"name": "morning", "good": false},
	"midday": {"name": "midday", "good": false},
	"afternoon": {"name": "afternoon", "good": false},
	"last_light": {"name": "last light", "good": true},
	"alpenglow": {"name": "alpenglow", "good": true},
	"dusk": {"name": "dusk", "good": false},
	"moonlight": {"name": "moonlight", "good": true},
	"night": {"name": "night", "good": false},
	"indoors": {"name": "indoors", "good": false},
}
## Animals few people ever get on film.
const SHY := ["black_bear", "bobcat", "great_gray_owl", "peregrine_falcon"]
## How long the first and the last light last, in hours.
const GOLDEN_HOURS := 1.25

## Ansel's list. Each entry is answered by a photograph that has at least one
## of its "any" subjects in the frame (as "kind:id": "place:Half Dome",
## "animal:mule_deer", "group:bird" for any animal of that field-log group,
## "kind:person" for anyone of that kind) and meets its other keys:
##   "from"      taken standing in that Place
##   "regions"   taken in one of those regions
##   "seasons"   taken in one of those seasons (GameClock.Season)
##   "light"     taken in one of those lights (keys of LIGHTS)
##   "landmark"  true: one of the park's landmarks (LANDMARKS) is in the frame
##   "snow"      true: with snow coming down
## "hint" says where to stand; "note" is a line for the album once it's found.
const SHOT_LIST: Array[Dictionary] = [
	# The park
	{"id": "half_dome", "group": "The park", "name": "Half Dome", "any": ["place:Half Dome"],
		"hint": "From Mirror Lake, Happy Isles, or the railings at Tunnel View and Glacier Point. Put the dome itself in the frame.",
		"note": "The Valley's east end, cut in half by ice and time. Adams photographed it for sixty years and said he never got to the end of it."},
	{"id": "monolith", "group": "The park", "name": "The face of Half Dome", "any": [], "regions": ["half_dome"], "from": "The Diving Board",
		"hint": "From the Diving Board, the ledge under the northwest face, out past the cables.",
		"note": "Adams made \"Monolith, the Face of Half Dome\" from this ledge in 1927, with one glass plate left and a deep red filter to turn the sky black."},
	{"id": "el_capitan", "group": "The park", "name": "El Capitan", "any": ["place:El Capitan"],
		"hint": "From El Capitan Meadow (walk up toward the wall until the view tilts to the rim), or the railing at Tunnel View.",
		"note": "Three thousand feet of granite in one unbroken face. It takes the first sun of a winter morning before anything else in the Valley."},
	{"id": "yosemite_falls", "group": "The park", "name": "Yosemite Falls", "any": ["place:Lower Yosemite Fall", "place:Yosemite Falls"],
		"hint": "At the foot of the falls, north of Yosemite Village.",
		"note": "The tallest waterfall in North America, in three drops. It roars in May and is a dark streak on dry rock by September."},
	{"id": "bridalveil", "group": "The park", "name": "Bridalveil Fall", "any": ["place:Bridalveil Fall"],
		"hint": "At the fall's foot, west of the Cathedral Rocks, or from the railing at Tunnel View.",
		"note": "The wind takes the whole fall and swings it across the cliff. The Ahwahneechee name for it, Pohono, is for that wind."},
	{"id": "cathedral_rocks", "group": "The park", "name": "Cathedral Rocks", "any": ["place:Cathedral Rocks"],
		"hint": "Above the Bridalveil Fall meadow, east along the wall, or from the railing at Tunnel View.",
		"note": "Three leaning summits across the Valley from El Capitan, with the two Cathedral Spires standing off their shoulder."},
	{"id": "three_brothers", "group": "The park", "name": "The Three Brothers", "any": ["place:Three Brothers"],
		"hint": "From Leidig Meadow, looking north.",
		"note": "Three gables of granite stepping up to Eagle Peak, each tilted the same way along the same joints in the rock."},
	{"id": "sentinel_rock", "group": "The park", "name": "Sentinel Rock", "any": ["place:Sentinel Rock"],
		"hint": "From the Four Mile Trailhead, looking up the south wall.",
		"note": "A flat-faced tower on the south rim, straight across from Yosemite Falls. Its north face is the Steck-Salathé."},
	{"id": "royal_arches", "group": "The park", "name": "The Royal Arches", "any": ["place:Royal Arches"],
		"hint": "From Ahwahnee Meadow, or the lawns of the Ahwahnee.",
		"note": "Great shells of granite peeled away in arcs, one inside another, the way an onion comes apart."},
	{"id": "mirror_lake", "group": "The park", "name": "Mirror Lake", "any": ["place:Mirror Lake"],
		"hint": "On the shore of Mirror Lake, up Tenaya Creek. Spring, when it's full, is best.",
		"note": "A pool in Tenaya Creek that holds Mount Watkins upside down in spring, and is a sandy meadow by fall."},
	{"id": "grizzly_giant", "group": "The park", "name": "The Grizzly Giant", "any": ["place:Grizzly Giant"],
		"hint": "In the Mariposa Grove, south of Wawona.",
		"note": "A giant sequoia some three thousand years old, with limbs thicker than most trees' trunks. It was old when Rome was founded."},
	{"id": "cathedral_peak", "group": "The park", "name": "Cathedral Peak", "any": ["place:Cathedral Peak"],
		"hint": "South of Tuolumne Meadows, in the high country.",
		"note": "A spire of granite the glaciers flowed round and never over, which is why its top is still sharp."},
	# Wildlife
	{"id": "deer", "group": "Wildlife", "name": "A mule deer", "any": ["animal:mule_deer"],
		"hint": "They graze the meadows at dawn and dusk. Walk, don't run, and let the long lens do the reaching.",
		"note": "Big ears, a black-tipped tail, and no fear of a tripod at all."},
	{"id": "bear", "group": "Wildlife", "name": "A black bear", "any": ["animal:black_bear"],
		"hint": "One may wander by at dawn or dusk, most often in fall. Keep your distance and your lunch.",
		"note": "Brown, cinnamon or blond more often than black. The picture to get is the one from far away."},
	{"id": "bird", "group": "Wildlife", "name": "A bird", "any": ["group:bird"],
		"hint": "Jays, robins and quail peck about on open ground by day. Go slowly, or they're off.",
		"note": "A bird holds still for exactly as long as it takes to focus."},
	{"id": "squirrel", "group": "Wildlife", "name": "A squirrel", "any": ["animal:western_gray_squirrel", "animal:california_ground_squirrel", "animal:douglas_squirrel", "animal:golden_mantled_ground_squirrel"],
		"hint": "Among the oaks and pines by day, or on the high country's granite.",
		"note": "Gray squirrels in the oaks, ground squirrels on the granite, chickarees scolding from the firs."},
	{"id": "butterfly", "group": "Wildlife", "name": "A butterfly", "any": ["group:butterfly"],
		"hint": "They drift over the meadows on fair spring and summer days.",
		"note": "Swallowtails, sisters and admirals, none of which will pose."},
	{"id": "raptor", "group": "Wildlife", "name": "A falcon or an owl", "any": ["animal:peregrine_falcon", "animal:great_gray_owl"],
		"hint": "A peregrine under the big walls by day, or a great gray owl over the meadows at Crane Flat and Wawona at dusk.",
		"note": "The fastest bird alive, or the biggest owl on the continent. Either one is a lucky day."},
	# Light and season
	{"id": "last_light", "group": "Light and season", "name": "A landmark in the last light", "any": [], "landmark": true, "light": ["last_light", "alpenglow"],
		"hint": "Any of the park's landmarks in the last hour of sun, or in the pink light after it sets.",
		"note": "The cliffs go gold, then rose, then gray, in about as long as it takes to set up a tripod."},
	{"id": "first_light", "group": "Light and season", "name": "A landmark at first light", "any": [], "landmark": true, "light": ["first_light"],
		"hint": "Any of the park's landmarks in the first hour of sun.",
		"note": "Adams made \"El Capitan, Winter, Sunrise\" in 1968. The early light is the cleanest of the day."},
	{"id": "moon", "group": "Light and season", "name": "A landmark by moonlight", "any": [], "landmark": true, "light": ["moonlight"],
		"hint": "Any of the park's landmarks at night, in the three nights round the full moon (day 14 of a season).",
		"note": "Adams made \"Moon and Half Dome\" in 1960, the moon rising beside the face in the last sun."},
	{"id": "winter_storm", "group": "Light and season", "name": "A winter storm from Tunnel View", "any": [], "regions": ["tunnel_view"], "seasons": [3], "snow": true,
		"hint": "From Tunnel View on a winter day with snow coming down.",
		"note": "Adams made \"Clearing Winter Storm\" from near here: El Capitan, Bridalveil Fall and the Cathedral Rocks coming out of the cloud."},
	{"id": "firefall", "group": "Light and season", "name": "The Firefall", "any": ["event:firefall"],
		"hint": "From Curry Village on a summer night, a little after nine, looking up at the wall.",
		"note": "Embers pushed off Glacier Point, falling three thousand feet in the dark. It takes a long exposure and a steady hand."},
	{"id": "blossom", "group": "Light and season", "name": "A plant from the press book", "any": ["kind:plant"],
		"hint": "Any plant that goes in the press book: a wildflower in its season, a fern, a branch of dogwood.",
		"note": "Adams photographed dogwood blossoms and oak leaves as carefully as he did cliffs."},
	# People
	{"id": "portrait", "group": "People", "name": "A portrait", "any": ["kind:person"],
		"hint": "Anyone in the park who'll stand still for it.",
		"note": "\"My pictures mostly leave the people out,\" Adams says. Yours needn't."},
]

## The landmarks in the far views painted past an overlook's rim (Tunnel
## View, Glacier Point: assets/shaders/vista.gdshader), as region id ->
## {place name: its pixel in the painting}. The painting hangs nearly still
## on the screen as you walk, so where a landmark is in the world depends on
## where the camera is (see _vista_subjects).
const VISTAS := {
	"tunnel_view": {
		"El Capitan": Vector2(270, 190), "Half Dome": Vector2(540, 250),
		"Bridalveil Fall": Vector2(761, 300), "Cathedral Rocks": Vector2(830, 200),
	},
	"glacier_point": {
		"Yosemite Falls": Vector2(255, 190), "Half Dome": Vector2(1240, 110),
		"Nevada Fall": Vector2(1519, 202), "Vernal Fall": Vector2(1513, 298),
	},
}
const VISTA_SHADER := "res://assets/shaders/vista.gdshader"
## The color the vista's sprite is painted where the far view shows.
const VISTA_MARKER := Color(0.137, 0.337, 0.475)
## The game's view in pixels.
const VIEW_SIZE := Vector2(960, 540)

## The order the album lists the groups in.
const GROUPS := ["The park", "Wildlife", "Light and season", "People"]

## The prints in the album, oldest first. Each is {"id", "title", "where",
## "region", "day" (Friendship.today()), "minutes", "light", "film", "lens",
## "stars" (1 to 3), "subjects" (their names), "blank" (true when no picture
## could be drawn, as in the headless tests)}.
var album: Array[Dictionary] = []
## Shot-list id -> {"day", "title"} of the first photograph that answered it.
var listed: Dictionary = {}
## The film and lens last used, so the camera comes up as you left it.
var film := "color"
var lens := "normal"
## How many pictures you've ever taken (the album only holds ALBUM_SIZE),
## and the most stars any of them had.
var total := 0
var best_ever := 0

var _textures: Dictionary = {}
## The places a "landmark" entry accepts: every Place named by The park's entries.
var _landmarks: Dictionary = {}
var _counter := 0


func _ready() -> void:
	add_to_group("persist")
	for entry: Dictionary in SHOT_LIST:
		if entry.group != "The park":
			continue
		for tag: String in entry.any:
			if tag.begins_with("place:"):
				_landmarks[tag.trim_prefix("place:")] = true
	QuestLog.quest_started.connect(_on_quest_started)


func start_new_game() -> void:
	album = []
	listed = {}
	film = "color"
	lens = "normal"
	total = 0
	best_ever = 0
	_textures.clear()
	changed.emit()


## True once Ansel has lent you the camera.
func has_camera() -> bool:
	return QuestLog.is_unlocked(ABILITY)


## True once you have the wide and long lenses.
func has_lenses() -> bool:
	return Gear.count(LENSES_GEAR) > 0


## The lenses you can fit now.
func lenses() -> Array:
	return LENSES if has_lenses() else ["normal"]


## The camera goes in the Backpack (as gear) when a quest hands it over.
func _on_quest_started(quest: QuestData) -> void:
	if ABILITY in quest.start_unlocks and Gear.get_gear(GEAR) != null and Gear.count(GEAR) == 0:
		Gear.add(GEAR)


func is_full() -> bool:
	return album.size() >= ALBUM_SIZE


func get_entry(id: String) -> Dictionary:
	for entry: Dictionary in SHOT_LIST:
		if entry.id == id:
			return entry
	return {}


func is_listed(id: String) -> bool:
	return listed.has(id)


## How many of the shot list you've photographed.
func listed_count() -> int:
	return listed.size()


func listed_in(group: String) -> int:
	var n := 0
	for entry: Dictionary in SHOT_LIST:
		if entry.group == group and listed.has(entry.id):
			n += 1
	return n


func in_group(group: String) -> Array:
	return SHOT_LIST.filter(func(e: Dictionary) -> bool: return e.group == group)


## The most stars any print in the album has (0 for an empty album).
func best_stars() -> int:
	var best := 0
	for photo: Dictionary in album:
		best = maxi(best, int(photo.get("stars", 1)))
	return best


## True if [param place_name] is one of the park's landmarks.
func is_landmark(place_name: String) -> bool:
	return _landmarks.has(place_name)


# ---------------------------------------------------------------- looking

## The light right now: a key of LIGHTS. The first and last light are the
## GOLDEN_HOURS after sunrise and before sunset (Sun.times, so they move
## with the season); alpenglow is the pink on the granite once the sun has
## gone, and moonlight is a night within a day of the full moon.
func light_now(indoors := false) -> String:
	if indoors:
		return "indoors"
	var hour := fposmod(Sun.hour_now(), 24.0)
	var sun := Sun.times()
	if Sun.night() > 0.75:
		return "moonlight" if GameClock.is_full_moon() else "night"
	if hour < 12.0:
		if hour < sun.x + GOLDEN_HOURS:
			return "first_light"
		return "morning" if hour < 10.5 else "midday"
	if hour < 14.5:
		return "midday"
	if hour < sun.y - GOLDEN_HOURS:
		return "afternoon"
	if hour < sun.y - 0.25:
		return "last_light"
	return "alpenglow" if Sun.alpenglow() > 0.35 else "dusk"


## What a picture of [param rect] (in global pixels) would hold, taken by
## someone standing at [param stand]: {"region", "region_name", "where" (the
## Place you stand in), "indoors", "season", "light", "snow", "rain",
## "subjects" ([{kind, id, name, at}], the nearest the middle of the frame
## first within each kind)}. Empty with no world to look at.
func observe(rect: Rect2, stand: Vector2) -> Dictionary:
	var world := get_tree().get_first_node_in_group("world")
	var region: Region = world.region if world and "region" in world else null
	if region == null:
		return {}
	var subjects: Array[Dictionary] = []
	for subject in landmarks_in(region):
		if rect.has_point(subject.at):
			subjects.append(subject)
	for node in get_tree().get_nodes_in_group("photo_subjects"):
		if not node.has_method("photo_subjects") or (node is CanvasItem and not node.is_visible_in_tree()):
			continue
		for subject: Dictionary in node.photo_subjects():
			if rect.has_point(subject.at):
				subjects.append(subject)
	var middle := rect.get_center()
	subjects.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return middle.distance_squared_to(a.at) < middle.distance_squared_to(b.at))
	var standing := region.place_at(region.to_local(stand))
	var weather := Weather.today()
	return {
		"region": region.region_id,
		"region_name": region.display_name if region.display_name != "" else region.region_id.capitalize(),
		"where": standing.display_name if standing else "",
		"indoors": region.indoors,
		"season": GameClock.season,
		"light": light_now(region.indoors),
		"snow": not region.indoors and float(weather.get("snow", 0.0)) > 0.0,
		"rain": not region.indoors and float(weather.get("rain", 0.0)) > 0.0,
		"subjects": subjects,
	}


## Every named place a camera could find in [param region] right now, as
## subjects ({kind "place", id, name, at}): its Place markers, where they
## stand, and at an overlook the landmarks of the far view, where the
## painting shows them just now. (An overlook's markers for far-off things
## are labels for the map, not where the thing is seen, so they're left out
## there.)
func landmarks_in(region: Region) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var far := _vista_subjects(region)
	var overlook := VISTAS.has(region.region_id)
	for place in region.get_places():
		if place.display_name == "" or (overlook and place.radius <= 0.0):
			continue
		out.append({"kind": "place", "id": place.display_name, "name": place.display_name, "at": place.global_position})
	out.append_array(far)
	return out


## Where the landmark called [param place_name] is in the world right now
## (the nearest the middle of the screen, if it's about twice), or
## Vector2.INF if this region has none.
func find_landmark(place_name: String) -> Vector2:
	var world := get_tree().get_first_node_in_group("world")
	var region: Region = world.region if world and "region" in world else null
	if region == null:
		return Vector2.INF
	var middle := get_viewport().get_canvas_transform().affine_inverse() * (VIEW_SIZE / 2.0)
	var best := Vector2.INF
	for subject in landmarks_in(region):
		if subject.id == place_name and (best == Vector2.INF or middle.distance_squared_to(subject.at) < middle.distance_squared_to(best)):
			best = subject.at
	return best


## The far view's landmarks that are on the screen now and not behind the
## land: the vista shader shows painting pixel
## [code]screen + offset + (camera - anchor) * parallax[/code] wherever the
## overlook's sprite is its marker color, so a landmark's place on the
## screen, and from that in the world, is worked back from the camera.
func _vista_subjects(region: Region) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if not VISTAS.has(region.region_id):
		return out
	var sprite := _vista_sprite(region)
	if sprite == null:
		return out
	var material := sprite.material as ShaderMaterial
	var anchor: Vector2 = material.get_shader_parameter("anchor")
	var offset: Vector2 = material.get_shader_parameter("offset")
	var parallax: Vector2 = material.get_shader_parameter("parallax")
	var camera := get_viewport().get_canvas_transform().affine_inverse().origin
	var shape: Image = sprite.get_meta("photo_shape") if sprite.has_meta("photo_shape") else null
	if shape == null and sprite.texture:
		shape = sprite.texture.get_image()
		sprite.set_meta("photo_shape", shape)
	var landmarks: Dictionary = VISTAS[region.region_id]
	for place_name: String in landmarks:
		var on_screen: Vector2 = landmarks[place_name] - offset - (camera - anchor) * parallax
		if not Rect2(Vector2.ZERO, VIEW_SIZE).has_point(on_screen):
			continue
		var at := camera + on_screen
		# Only where the sprite lets the painting through (the rim's shadow
		# is stippled, so anywhere within a few pixels will do).
		var texel := Vector2i((sprite.to_local(at) - (Vector2.ZERO if not sprite.centered else -sprite.texture.get_size() / 2.0) - sprite.offset).floor())
		if shape == null or not _shows_painting(shape, texel):
			continue
		out.append({"kind": "place", "id": place_name, "name": place_name, "at": at})
	return out


## True if [param shape] (the overlook sprite's picture) is the marker color
## at [param texel] or within three pixels of it.
func _shows_painting(shape: Image, texel: Vector2i) -> bool:
	var bounds := Rect2i(Vector2i.ZERO, shape.get_size())
	var marker := Vector3(VISTA_MARKER.r, VISTA_MARKER.g, VISTA_MARKER.b)
	for dy in range(-3, 4):
		for dx in range(-3, 4):
			var at := texel + Vector2i(dx, dy)
			if not bounds.has_point(at):
				continue
			var color := shape.get_pixelv(at)
			if color.a > 0.5 and Vector3(color.r, color.g, color.b).distance_to(marker) < 0.03:
				return true
	return false


## The sprite in [param region] drawn with the vista shader, or null.
func _vista_sprite(region: Region) -> Sprite2D:
	if region.has_meta("photo_vista"):
		return region.get_meta("photo_vista") as Sprite2D
	var found: Sprite2D = null
	for child in region.find_children("*", "Sprite2D", true, false):
		var material := (child as Sprite2D).material as ShaderMaterial
		if material and material.shader and material.shader.resource_path == VISTA_SHADER:
			found = child
			break
	region.set_meta("photo_vista", found)
	return found


## True if a photograph of [param view] (from [method observe]) answers
## shot-list [param entry].
func answers(entry: Dictionary, view: Dictionary) -> bool:
	if view.is_empty():
		return false
	if entry.has("regions") and not view.get("region", "") in entry.regions:
		return false
	if entry.has("seasons") and not int(view.get("season", -1)) in entry.seasons:
		return false
	if entry.has("from") and view.get("where", "") != entry.from:
		return false
	if entry.has("light") and not view.get("light", "") in entry.light:
		return false
	if entry.get("snow", false) and not view.get("snow", false):
		return false
	var subjects: Array = view.get("subjects", [])
	if entry.get("landmark", false) and not subjects.any(func(s: Dictionary) -> bool: return s.kind == "place" and is_landmark(s.id)):
		return false
	var wanted: Array = entry.get("any", [])
	if wanted.is_empty():
		return true
	for subject: Dictionary in subjects:
		if _tags(subject).any(func(tag: String) -> bool: return tag in wanted):
			return true
	return false


## The ways a shot-list entry can ask for [param subject].
func _tags(subject: Dictionary) -> Array:
	var tags := ["%s:%s" % [subject.kind, subject.id], "kind:%s" % subject.kind]
	if subject.kind == "animal":
		tags.append("group:%s" % str(FieldLog.get_animal(subject.id).get("group", "")))
	return tags


## The entries [param view] would be the first to answer.
func new_for_list(view: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for entry: Dictionary in SHOT_LIST:
		if not listed.has(entry.id) and answers(entry, view):
			out.append(entry)
	return out


## The subjects of [param view] a caption names, the most striking first:
## what's happening, then the shy animals, deer, landmarks, people, the
## small animals (butterflies last), plants, other places. One of each
## name; within a rank, the nearest the middle of the frame first.
func named_subjects(view: Dictionary) -> Array[Dictionary]:
	var ranked: Array[Dictionary] = []
	var seen := {}
	for rank in 9:
		for subject: Dictionary in view.get("subjects", []):
			if _rank(subject) == rank and not seen.has(subject.name):
				seen[subject.name] = true
				ranked.append(subject)
	return ranked


## Where a subject comes in a caption (0 first). Up to MAIN_RANK it's
## something a picture can be about with something else in it: the rest
## (a jay in the corner of a wide view, a fern, the car park) only name a
## picture that has nothing bigger.
const MAIN_RANK := 4


func _rank(subject: Dictionary) -> int:
	match str(subject.kind):
		"event":
			return 0
		"animal":
			if subject.id in SHY:
				return 1
			if subject.id == "mule_deer":
				return 2
			return 6 if str(subject.id).begins_with("butterfly_") else 5
		"place":
			return 3 if is_landmark(subject.id) else 8
		"person":
			return 4
		"plant":
			return 7
	return 8


## What to call a picture of [param view]: its best subject, and the best of
## another kind with it if that's a subject in its own right ("Mule Deer, El
## Capitan", not "El Capitan, Steller's Jay"). A view with three landmarks
## or more in it is named for where you stood ("Tunnel View"); a picture of
## nothing in particular too.
func title_for(view: Dictionary) -> String:
	var names := named_subjects(view)
	var where := str(view.get("where", ""))
	if names.is_empty():
		return where if where != "" else str(view.get("region_name", "Untitled"))
	var landmarks := names.filter(func(s: Dictionary) -> bool: return s.kind == "place" and is_landmark(s.id))
	if landmarks.size() >= 3 and where != "" and _rank(names[0]) >= 3:
		return where
	for other: Dictionary in names:
		if other.kind != names[0].kind and _rank(other) <= MAIN_RANK:
			return "%s, %s" % [names[0].name, other.name]
	return names[0].name


## One to three stars. One for any picture. A second for good light (the
## first or last sun, alpenglow, a full moon) or weather coming down. A
## third for a subject worth the wait: a shy animal, something that only
## happens now and then, or two kinds of main subject in one frame (a deer
## or a person with a landmark behind). A jay in the corner doesn't make a
## view a wildlife picture, and a picture of nothing in particular stays
## at one.
func stars_for(view: Dictionary) -> int:
	var subjects: Array = view.get("subjects", [])
	if subjects.is_empty():
		return 1
	var stars := 1
	if LIGHTS.get(view.get("light", ""), {}).get("good", false) or view.get("snow", false) or view.get("rain", false):
		stars += 1
	var kinds := {}
	var striking := false
	for subject: Dictionary in subjects:
		var rank := _rank(subject)
		if rank <= 1:
			striking = true
		if rank <= MAIN_RANK:
			kinds[subject.kind] = true
	if striking or kinds.size() >= 2:
		stars += 1
	return stars


# ---------------------------------------------------------------- the album

## Puts a photograph of [param view] in the album, with [param image] as its
## print (null where nothing is drawn: a plain card stands in). Logs any
## animal in it in the field log, ticks the shot list, and returns the
## photo's record with "new" (the list entries it was first to answer) and
## "logged" (the animals it put in the field log) added, or {} when the
## album is full.
func develop(view: Dictionary, image: Image = null) -> Dictionary:
	if is_full() or view.is_empty():
		return {}
	_counter += 1
	var id := "p%d_%d_%d" % [int(Time.get_unix_time_from_system()), Time.get_ticks_msec() % 100000, _counter]
	var names := PackedStringArray()
	for subject: Dictionary in named_subjects(view):
		names.append(subject.name)
	var photo := {
		"id": id,
		"title": title_for(view),
		"where": str(view.get("where", "")) if str(view.get("where", "")) != "" else str(view.get("region_name", "")),
		"region": str(view.get("region", "")),
		"day": Friendship.today(),
		"minutes": GameClock.minutes,
		"light": str(view.get("light", "midday")),
		"film": film,
		"lens": lens,
		"stars": stars_for(view),
		"subjects": Array(names),
		"blank": image == null,
	}
	var print_image := image if image != null else blank_print(photo.title)
	if print_image.get_size() != PRINT_SIZE:
		print_image.resize(PRINT_SIZE.x, PRINT_SIZE.y, Image.INTERPOLATE_BILINEAR)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir()))
	var err := print_image.save_png(path_of(id))
	if err != OK:
		push_warning("Could not write photograph %s: %s" % [path_of(id), error_string(err)])
	_textures[id] = ImageTexture.create_from_image(print_image)
	album.append(photo)
	total += 1
	best_ever = maxi(best_ever, int(photo.stars))
	# A good look through a lens is a good look: the print says so itself,
	# so the field log stays quiet.
	var logged := PackedStringArray()
	for subject: Dictionary in view.get("subjects", []):
		if subject.kind == "animal" and FieldLog.spot(subject.id, true):
			logged.append(subject.name)
	var fresh: Array[Dictionary] = []
	for entry: Dictionary in SHOT_LIST:
		if not listed.has(entry.id) and answers(entry, view):
			listed[entry.id] = {"day": Friendship.today(), "title": photo.title}
			fresh.append(entry)
	if not QuestLog.is_unlocked(FIRST_PHOTO):
		QuestLog.unlocks.append(FIRST_PHOTO)
		QuestLog.changed.emit()
	var result := photo.duplicate()
	result["new"] = fresh
	result["logged"] = Array(logged)
	taken.emit(photo)
	for entry in fresh:
		list_ticked.emit(entry)
	changed.emit()
	if not fresh.is_empty():
		QuestLog.changed.emit() # a "photographed" step may be done now
	Achievements.check()
	return result


## Takes print [param id] out of the album for good. The shot list keeps
## what the picture showed.
func remove(id: String) -> void:
	for i in album.size():
		if album[i].id == id:
			album.remove_at(i)
			_textures.erase(id)
			if FileAccess.file_exists(path_of(id)) and not _used_by_a_save(id):
				DirAccess.remove_absolute(ProjectSettings.globalize_path(path_of(id)))
			changed.emit()
			return


func get_photo(id: String) -> Dictionary:
	for photo: Dictionary in album:
		if photo.id == id:
			return photo
	return {}


## The print of photo [param id] as a texture (a plain card if its file has
## gone missing).
func texture(id: String) -> Texture2D:
	if _textures.has(id):
		return _textures[id]
	var image: Image = null
	if FileAccess.file_exists(path_of(id)):
		image = Image.load_from_file(path_of(id))
	if image == null or image.is_empty():
		image = blank_print(str(get_photo(id).get("title", "")))
	_textures[id] = ImageTexture.create_from_image(image)
	return _textures[id]


## "Summer 3, year 1 · 6:10 PM · last light" for a print.
func caption(photo: Dictionary) -> String:
	var minutes := int(photo.get("minutes", 0))
	var hour := (minutes / 60) % 24
	var h12 := 12 if hour % 12 == 0 else hour % 12
	var parts := PackedStringArray()
	var date := Achievements.day_text(int(photo.get("day", -1)))
	if date != "":
		parts.append(date)
	parts.append("%d:%02d %s" % [h12, minutes % 60, "AM" if hour < 12 else "PM"])
	parts.append(str(LIGHTS.get(photo.get("light", ""), {}).get("name", "")))
	return " · ".join(parts)


## "2 stars", for a line of text.
static func stars_text(stars: int) -> String:
	return "1 star" if stars == 1 else "%d stars" % stars


# ---------------------------------------------------------------- files

## The folder this game's prints are in: user://photos/ for the real saves,
## and a folder beside the save file for anything else (the tests each use a
## save of their own, so they never touch real photographs).
func dir() -> String:
	if SaveManager.base_path == REAL_SAVE:
		return REAL_DIR
	return SaveManager.base_path.get_basename() + "_photos/"


func path_of(id: String) -> String:
	return dir() + id + ".png"


## A plain card to stand for a print that can't be drawn or found: paper,
## a ruled border, and a few bars where the picture would be.
func blank_print(title := "") -> Image:
	var image := Image.create_empty(PRINT_SIZE.x, PRINT_SIZE.y, false, Image.FORMAT_RGB8)
	image.fill(Color("3b3027"))
	image.fill_rect(Rect2i(6, 6, PRINT_SIZE.x - 12, PRINT_SIZE.y - 12), Color("5a4a3a"))
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(title)
	for i in 5:
		var h := rng.randi_range(18, 70)
		image.fill_rect(Rect2i(24 + i * 64, PRINT_SIZE.y - 30 - h, 48, h), Color("7a6650"))
	return image


## Tones [param image] for [param film_id] in place: "silver" is black and
## white with the contrast pulled out, the blacks left deep; "sepia" is the
## same print warmed to brown. "color" is left alone.
static func tone(image: Image, film_id: String) -> void:
	if film_id == "color" or image == null or image.is_empty():
		return
	image.convert(Image.FORMAT_RGB8)
	var data := image.get_data()
	var sepia := film_id == "sepia"
	# A lookup for the contrast curve, so the loop is three reads and writes.
	var curve := PackedByteArray()
	curve.resize(256)
	for v in 256:
		var t := v / 255.0
		curve[v] = int(clampf(lerpf(t, smoothstep(0.0, 1.0, t), 0.65), 0.0, 1.0) * 255.0)
	for i in range(0, data.size(), 3):
		# A red filter's black and white: skies go dark, granite stays bright.
		var l: int = curve[(data[i] * 107 + data[i + 1] * 120 + data[i + 2] * 29) >> 8]
		if sepia:
			data[i] = mini(255, (l * 276 >> 8) + 6)
			data[i + 1] = l * 240 >> 8
			data[i + 2] = l * 196 >> 8
		else:
			data[i] = l
			data[i + 1] = l
			data[i + 2] = l
	image.set_data(image.get_width(), image.get_height(), false, Image.FORMAT_RGB8, data)


## True if a save in any slot still shows print [param id] (a game saved in
## one slot and carried on in another shares its earlier prints).
func _used_by_a_save(id: String) -> bool:
	return _ids_in_saves().has(id)


func _ids_in_saves() -> Dictionary:
	var ids := {}
	for n in range(1, SaveManager.SLOTS + 1):
		if not SaveManager.slot_used(n):
			continue
		var data = JSON.parse_string(FileAccess.get_file_as_string(SaveManager.slot_path(n)))
		if typeof(data) != TYPE_DICTIONARY or typeof(data.get("nodes")) != TYPE_DICTIONARY:
			continue
		var mine = data.nodes.get(str(name), {})
		if typeof(mine) != TYPE_DICTIONARY:
			continue
		for photo in mine.get("album", []):
			if photo is Dictionary:
				ids[str(photo.get("id", ""))] = true
	return ids


## Deletes print files no album shows any more: not this game's, and not a
## save's in any slot (pictures taken and then lost by quitting unsaved).
## Returns how many went.
func sweep() -> int:
	var folder := DirAccess.open(dir())
	if folder == null:
		return 0
	var kept := _ids_in_saves()
	for photo: Dictionary in album:
		kept[photo.id] = true
	var gone := 0
	for file in folder.get_files():
		if file.ends_with(".png") and not kept.has(file.get_basename()):
			folder.remove(file)
			gone += 1
	return gone


func save_data() -> Dictionary:
	return {"album": album, "listed": listed, "film": film, "lens": lens, "total": total, "best_ever": best_ever}


func load_data(data: Dictionary) -> void:
	album = []
	for saved in data.get("album", []):
		if not saved is Dictionary or str(saved.get("id", "")) == "":
			continue
		var subjects: Array = []
		for subject in saved.get("subjects", []):
			subjects.append(str(subject))
		album.append({
			"id": str(saved.id),
			"title": str(saved.get("title", "Untitled")),
			"where": str(saved.get("where", "")),
			"region": str(saved.get("region", "")),
			"day": int(saved.get("day", -1)),
			"minutes": int(saved.get("minutes", 0)),
			"light": str(saved.get("light", "midday")),
			"film": str(saved.get("film", "color")),
			"lens": str(saved.get("lens", "normal")),
			"stars": clampi(int(saved.get("stars", 1)), 1, 3),
			"subjects": subjects,
			"blank": bool(saved.get("blank", false)),
		})
	listed = {}
	var saved_list = data.get("listed", {})
	if saved_list is Dictionary:
		for key in saved_list:
			var entry = saved_list[key]
			if get_entry(str(key)).is_empty():
				continue
			listed[str(key)] = {"day": int(entry.get("day", -1)), "title": str(entry.get("title", ""))} if entry is Dictionary else {"day": -1, "title": ""}
	film = str(data.get("film", "color")) if str(data.get("film", "color")) in FILMS else "color"
	lens = str(data.get("lens", "normal")) if str(data.get("lens", "normal")) in LENSES else "normal"
	total = maxi(int(data.get("total", album.size())), album.size())
	best_ever = clampi(maxi(int(data.get("best_ever", 0)), best_stars()), 0, 3)
	_textures.clear()
	sweep()
	changed.emit()
