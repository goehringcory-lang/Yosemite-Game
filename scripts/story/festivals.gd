extends Node
## The Valley's calendar of festivals (autoload "Festivals"), one a season,
## like Stardew Valley's: on the day, a note in the morning says what's on,
## where and when, everyone's in a good mood (a first talk that day counts
## double), and the host has something for you while it's on.
##
## They're the park's own, and true to their history:
## - The Wildflower Walk (spring): Enid Michael led wildflower walks as a
##   ranger-naturalist from 1921 and kept the Museum's wildflower garden.
## - Fourth of July at Camp Curry (summer): the Currys' camp kept the Fourth
##   with a big supper, and the night ended with the Firefall from Glacier
##   Point, which the game already plays every evening.
## - The Yosemite Facelift (fall): since 2004 climbers have gathered each
##   fall to clean up the park. Litter turns up around the Valley that day;
##   bring some to Wren at the foot of Firefall Slab.
## - The Bracebridge Dinner (winter): a Christmas pageant and feast at the
##   Ahwahnee since 1927, which Ansel Adams staged for decades.
## Native gatherings (an acorn time, Indian Field Days) wait for the tribal
## review, like the rest of the Native cast's new lines.

signal changed

## Talk points on a festival day are multiplied by this.
const TALK_BONUS := 2
## Litter spread round each Valley area on Facelift day, and how much Wren
## wants.
const LITTER_PER_AREA := 4
const LITTER_WANTED := 5
const LITTER := "litter"

## Each festival: its day (season, day of the season), its hours (from,
## to), its host (it's wherever they are that day), what the host says when
## you come, and what they give (items, and friendship points).
const FESTIVALS := [
	{"id": "wildflower_walk", "name": "The Wildflower Walk", "season": 0, "day": 12, "hours": [9, 13],
		"host": "enid_michael",
		"lines": [
			"You came! Good. We walk slowly and we look closely. That's the whole of it.",
			"See the miner's lettuce, the leaf wrapped right round the stem? The forty-niners ate it against scurvy. Taste one.",
			"And that's a shooting star, nodding over the wet ground. Every flower here had a name before mine, remember.",
		],
		"reward": {"spring_greens": 1}, "points": 60},
	{"id": "fourth_of_july", "name": "The Fourth at Camp Curry", "season": 1, "day": 4, "hours": [17, 22],
		"host": "jennie_curry",
		"lines": [
			"Happy Fourth! Supper's on the long tables tonight, and everyone eats.",
			"Stay till nine. When David calls up to Glacier Point, the whole camp goes quiet for the Firefall.",
		],
		"reward": {"bread_pudding": 2}, "points": 60},
	{"id": "facelift", "name": "The Yosemite Facelift", "season": 2, "day": 20, "hours": [8, 18],
		"host": "wren_alvarez",
		"lines": [
			"Facelift day! Climbers from everywhere come and clean up the park. Grab a bag!",
			"Cans, wrappers, old tape at the base of the routes. Bring me five pieces of litter and I'll trade you something good.",
		],
		"done_lines": [
			"Five! The Valley looks better already. Thanks for pitching in.",
		],
		"reward": {"chocolate_bar": 2, "trail_mix": 1}, "points": 80},
	{"id": "bracebridge", "name": "The Bracebridge Dinner", "season": 3, "day": 24, "hours": [17, 22],
		"host": "ahwahnee_chef",
		"lines": [
			"Welcome to Bracebridge Hall! For one night the Dining Room is an English manor at Christmas.",
			"The squire, the parson, carols, and seven courses with a fanfare for each. Mr. Adams staged it for years, you know.",
			"Here, a plate from the kitchen for the road. Joyeux Noël.",
		],
		"reward": {"cheddar_wedge": 1, "bread_pudding": 1, "chocolate_bar": 1}, "points": 60},
]

## Festival id -> the year you last went (talked with its host on the day).
var attended: Dictionary = {}


func _ready() -> void:
	add_to_group("persist")
	GameClock.day_started.connect(_on_day_started.unbind(3))


func start_new_game() -> void:
	attended = {}
	changed.emit()


func get_festival(id: String) -> Dictionary:
	for festival: Dictionary in FESTIVALS:
		if festival.id == id:
			return festival
	return {}


## The festival on today's date, or {}.
func today() -> Dictionary:
	for festival: Dictionary in FESTIVALS:
		if festival.season == GameClock.season and festival.day == GameClock.day:
			return festival
	return {}


## True while today's festival is on (within its hours).
func is_on() -> bool:
	var festival := today()
	return not festival.is_empty() and GameClock.hour_in_range(festival.hours[0], festival.hours[1])


func went_this_year(id: String) -> bool:
	return int(attended.get(id, 0)) == GameClock.year


## "Summer 4, 5 PM to 10 PM, at Camp Curry": the day, the hours, and where
## the host is.
static func when_text(festival: Dictionary) -> String:
	return "%s %d, %s" % [GameClock.SEASON_NAMES[festival.season], festival.day, hours_text(festival)]


## "5 PM to 10 PM, at Camp Curry".
static func hours_text(festival: Dictionary) -> String:
	var host := QuestLog.get_character(festival.host)
	var where := host.home_now(QuestLog.is_completed) if host else ""
	return "%s to %s%s" % [_hour_text(festival.hours[0]), _hour_text(festival.hours[1]), ", at %s" % where if where != "" else ""]


static func _hour_text(hour: int) -> String:
	var h12 := hour % 12
	return "%d %s" % [12 if h12 == 0 else h12, "AM" if hour < 12 else "PM"]


## Days until [param festival] comes round (0 on the day).
static func days_until(festival: Dictionary) -> int:
	var now := GameClock.season * GameClock.DAYS_PER_SEASON + GameClock.day
	var then: int = festival.season * GameClock.DAYS_PER_SEASON + festival.day
	return posmod(then - now, 4 * GameClock.DAYS_PER_SEASON)


func _on_day_started() -> void:
	var festival := today()
	if festival.is_empty():
		return
	# after the night's page, so the morning note isn't lost under it
	await get_tree().create_timer(4.0).timeout
	get_tree().call_group("hud", "show_message", "Today: %s, %s." % [festival.name, hours_text(festival)])


## Talk points for a first talk today: doubled on a festival day.
func talk_points(points: int) -> int:
	return points * TALK_BONUS if not today().is_empty() else points


## What [param character_id] has to say for today's festival, as dialogue
## lines, and the gift that goes with it. Empty unless they're its host and
## it's on.
func talk_to(character_id: String) -> Array[Dictionary]:
	var lines: Array[Dictionary] = []
	var festival := today()
	if festival.is_empty() or festival.host != character_id or not is_on() or went_this_year(festival.id):
		return lines
	var speaker := _who(character_id)
	if festival.id == "facelift":
		return _facelift(festival, speaker)
	for text: String in festival.lines:
		lines.append({"speaker": speaker, "text": text, "mood": "happy"})
	lines.append({"speaker": "", "text": _give(festival)})
	return lines


## Wren's Facelift: the first talk tells you what to do; with five pieces of
## litter in your pack she takes them and gives the reward.
func _facelift(festival: Dictionary, speaker: String) -> Array[Dictionary]:
	var lines: Array[Dictionary] = []
	if Inventory.count(LITTER) < LITTER_WANTED:
		for text: String in festival.lines:
			lines.append({"speaker": speaker, "text": text, "mood": "happy"})
		lines.append({"speaker": "", "text": "Litter collected: %d of %d." % [Inventory.count(LITTER), LITTER_WANTED]})
		return lines
	Inventory.remove(LITTER, Inventory.count(LITTER))
	for text: String in festival.done_lines:
		lines.append({"speaker": speaker, "text": text, "mood": "happy"})
	lines.append({"speaker": "", "text": _give(festival)})
	return lines


func _give(festival: Dictionary) -> String:
	attended[festival.id] = GameClock.year
	var got := PackedStringArray()
	for id: String in festival.reward:
		var amount := int(festival.reward[id])
		Inventory.add(id, amount)
		var item := ItemDB.get_item(id)
		got.append(ItemDB.count_name(amount, item.display_name if item else id))
	Friendship.add(festival.host, int(festival.points))
	changed.emit()
	return "%s! Received %s." % [festival.name, ", ".join(got)]


## Pieces of litter to scatter round an area of [param hub_id] today.
func litter_today(hub_id: String) -> int:
	return LITTER_PER_AREA if today().get("id", "") == "facelift" and hub_id == "yosemite_valley" else 0


func _who(character_id: String) -> String:
	var character := QuestLog.get_character(character_id)
	return character.display_name if character else character_id


func save_data() -> Dictionary:
	return {"attended": attended}


func load_data(data: Dictionary) -> void:
	attended = {}
	var saved: Dictionary = data.get("attended", {})
	for key in saved:
		attended[str(key)] = int(saved[key])
	changed.emit()
