extends Node
## Search and rescue from Camp 4 (autoload "Rescues"). Camp 4 climbers have
## helped with park rescues for decades, and the rescue site is still in the
## campground. Once you can belay, Jo Tolliver, who runs the rescue site,
## takes you on as a volunteer (Mateo Reyes at the cache kits you out), and
## after that some mornings the radio there calls for help, and you answer
## with what the game has already taught you: reading tracks, climbing,
## carrying, and knowing the trails. Everyone gets found. Nobody dies.
##
## A call is a short run of stages, from CALLS:
##   "search"  follow fresh prints from a named spot to the person, and reach
##             them (RescueField lays the prints and places them)
##   "feed"    share food worth some energy with them, there and then
##   "carry"   carry them back to Jo at Camp 4; you walk slower meanwhile
##             (speed_factor, read by Player)
##   "climb"   climb their route to reach them (ClimbStart hands over to
##             climb_to_party), then lower them on the rope (RescueLower)
##   "report"  go back and tell Jo
## Calls come in by season and weather, and the ones on a climb only once
## you've ticked that route. A call you don't finish by NIGHTFALL is wrapped
## up by the team by headlamp, so nothing is lost but the credit.
##
## Each rescue goes in the rescue log (the Journal), and the next morning a
## thank-you note from the person you helped is pinned on the Camp 4 board.
## The people you find are invented visitors, not historical figures.

signal changed
## Sent when a rescue is finished by you (for the day's page).
signal rescued(call: Dictionary)

## Jo's character id, Jo's quest that signs you up as a volunteer (its id is
## from when Ranger Hodges gave it, kept so saves carry over), and Jo's
## quest whose first call teaches the job.
const LEAD := "jo_tolliver"
const JOIN_QUEST := "hodges_rescue_team"
const FIRST_QUEST := "jo_first_call"
## The ability Jo's first quest waits on, set when the first call is done.
const FIRST_DONE := "first_rescue"
const FIRST_CALL := "cooks_meadow_child"
## The chance of a call on the radio on a morning once you're on the team.
const CALL_CHANCE := 0.5
## No new search after this hour; a call still open at NIGHTFALL goes to
## the team.
const LAST_CALL_HOUR := 16
const NIGHTFALL := 21
## How fast you walk while carrying someone (Long Carry makes it easier).
const CARRY_SPEED := 0.6
## Friendship with Jo for a rescue, and the perk stat it counts toward.
const POINTS := 20
const STAT := "rescues"

## Every call: where, the stages, the seasons (GameClock.Season) it comes in,
## and what's said. "region" and "start" are where the prints begin, "near"
## and "offset" where the person is ("near" a marker in that region). "route"
## is the climb for a "climb" stage; it must be ticked for the call to come
## in. "feed" is the energy to share. "scale" draws a child smaller.
const CALLS: Array[Dictionary] = [
	{"id": "cooks_meadow_child", "title": "Lost in Cook's Meadow", "who": "Toby Lindqvist", "look": "visitor_tourist", "scale": 0.8,
		"stages": ["search", "carry"], "seasons": [0, 1, 2, 3],
		"region": "yosemite_village", "start": "cooks_meadow", "near": "cooks_meadow", "offset": Vector2(-330, 90),
		"place": "Cook's Meadow",
		"radio": "Lindqvist party at the Cook's Meadow boardwalk. Their boy, nine years old, went after a deer about an hour ago and hasn't come back. Blue jacket.",
		"found": ["I'm not lost. I was following the deer.", "...Okay, I'm a little lost. My shoe came off in the mud and my foot hurts."],
		"done": "Toby rode most of the way on your back, telling you about the deer.",
		"thanks": "Dear Camp 4 rescue, thank you for finding Toby. He says the deer was a buck with four points. He also says you're his best friend now. -The Lindqvists",
		"gift": {"chocolate_bar": 1}},
	{"id": "four_mile_overdue", "title": "Overdue on the Four Mile Trail", "who": "Dale Pruitt", "look": "visitor_backpacker",
		"stages": ["search", "feed", "report"], "feed": 8, "seasons": [0, 1, 2],
		"region": "four_mile_trailhead", "start": "trailhead", "near": "four_mile_trail", "offset": Vector2(-60, 10),
		"place": "the Four Mile Trail",
		"radio": "Hiker overdue from Glacier Point on the Four Mile Trail. Went up at dawn with one water bottle and no lunch. His wife's waiting at the trailhead.",
		"found": ["Oh, thank God. I sat down for a minute and my legs just quit.", "I thought going down would be the easy part."],
		"done": "Dale got his legs back after something to eat and walked down to his wife on his own.",
		"thanks": "To whoever found me on the Four Mile: I've bought a second water bottle, and a sandwich, and a map. Thank you. -Dale Pruitt",
		"gift": {"trail_mix": 2}},
	{"id": "mirror_lake_ankle", "title": "A turned ankle at Mirror Lake", "who": "June Abernathy", "look": "visitor_photographer",
		"stages": ["search", "carry"], "seasons": [0, 1, 2],
		"region": "mirror_lake", "start": "arrival", "near": "lakeshore", "offset": Vector2(260, -60),
		"place": "Mirror Lake",
		"radio": "Photographer with a bad ankle somewhere around Mirror Lake. She went off the path for the reflection shot and can't put weight on it.",
		"found": ["The light was perfect. Then the rock wasn't.", "I can't walk on it. I'm so sorry to be a bother."],
		"done": "June held her camera the whole way, and took a picture of Half Dome over your shoulder.",
		"thanks": "Thank you for the long carry from Mirror Lake. The ankle is only sprained. I'm sending a print of the photo I took on your back. -June Abernathy",
		"gift": {"dried_apricots": 2}},
	{"id": "happy_isles_cold", "title": "Cold and wet at Happy Isles", "who": "Ray Okada", "look": "visitor_camper",
		"stages": ["search", "feed", "carry"], "feed": 10, "seasons": [0, 3],
		"region": "happy_isles", "start": "isles", "near": "isles", "offset": Vector2(628, 195),
		"place": "Happy Isles",
		"radio": "Camper fell in the Merced at Happy Isles and walked off into the trees soaked through. Snowmelt water. He'll be getting cold fast.",
		"found": ["I'm f-fine. I'm f-f-fine.", "Is it warm where you're from? I'd like to go there."],
		"done": "Ray warmed up on the way down, and by Camp 4 was already telling the story better than it happened.",
		"thanks": "Rescuers: I am warm. I am dry. I have learned that river is not for wading in May. Thank you. -Ray Okada",
		"gift": {"cheddar_wedge": 1}},
	{"id": "el_cap_meadow_snow", "title": "Lost in the snow by El Capitan", "who": "Vera Hollis", "look": "visitor_tourist",
		"stages": ["search", "feed", "report"], "feed": 6, "seasons": [3],
		"region": "el_capitan_meadow", "start": "shuttle", "near": "meadow", "offset": Vector2(-240, 120),
		"place": "El Capitan Meadow",
		"radio": "Visitor out for a snowshoe in El Capitan Meadow hasn't come back to her car. Fresh snow since noon. Her tracks will still be there if you go now.",
		"found": ["Every direction looked the same. Even El Capitan looked the same, and that's hard to do.", "I've been walking in a circle, haven't I?"],
		"done": "Vera followed her own tracks back to her car with you, and laughed at how small the circle was.",
		"thanks": "Thank you for following my circles. I'll carry a compass and leave earlier. -Vera Hollis",
		"gift": {"pilot_bread": 2}},
	{"id": "swan_slab_stuck", "title": "Stuck on Swan Slab", "who": "Andy Brandt", "look": "visitor_dirtbag",
		"stages": ["climb", "report"], "route": "swan_slab", "seasons": [0, 1, 2],
		"region": "yosemite_village", "place": "Swan Slab",
		"radio": "Somebody's stuck on Swan Slab, right behind Camp 4. Scrambled up without a rope and can't reverse the moves. Grab a rope and go get him down.",
		"found": ["Up was fine! Down is the problem! Down is a big problem!"],
		"done": "Andy's feet touched the ground and he sat right down on it.",
		"thanks": "Thanks for the lower off Swan Slab. I'm taking a class from the Mountain Shop before I go up anything again. -Andy",
		"gift": {"trail_mix": 2}},
	{"id": "apron_stuck", "title": "Off route on the Apron", "who": "Leo Castellanos", "look": "visitor_shop_climber",
		"stages": ["climb", "report"], "route": "glacier_point_apron", "seasons": [0, 1, 2],
		"region": "curry_village", "place": "the Glacier Point Apron",
		"radio": "Climber off route on the Glacier Point Apron, above Curry Village. Partner's on the ground. He wandered onto blank slab and can't go up or down.",
		"found": ["The topo said there'd be a bolt. There isn't a bolt. I've been standing on this dime for an hour."],
		"done": "Leo's partner was waiting at the bottom with an apology and a sandwich for you both.",
		"thanks": "I owe you a rope's length of thanks. The bolt was twenty feet left. It's always twenty feet left. -Leo Castellanos",
		"gift": {"dried_apples": 2}},
	{"id": "royal_arches_benighted", "title": "Benighted on Royal Arches", "who": "the Harmon brothers", "look": "visitor_backpacker",
		"stages": ["climb", "report"], "route": "royal_arches", "seasons": [0, 1, 2],
		"region": "the_ahwahnee", "place": "Royal Arches",
		"radio": "Two climbers on Royal Arches started late and are stuck on a ledge partway up the arches. One dropped the rope. They need a rope and a lower before dark.",
		"found": ["We heard you coming and Pete started crying. I'm not saying which Pete. We're both Pete."],
		"done": "Both Petes were lowered off the arches, and promised never to drop a rope again.",
		"thanks": "Thank you for the lower off Royal Arches. We have bought a new rope and named it after you. -Pete and Pete Harmon",
		"gift": {"beef_jerky": 1}},
]

## What Jo says as the radio calls come in, and when there's nothing on it.
const RADIO_IN := "The radio's going. %s"
const QUIET := ["Quiet morning on the radio. That's how we like it.", "Nothing on the radio. Go climb something, I'll holler if it goes off."]
## What Jo says while a call is underway, by stage.
const REMINDERS := {
	"search": "Fresh prints from %s. Read the ground and follow them. Quick, before dark.",
	"feed": "They'll need something to eat before they can move. Share some of your food.",
	"carry": "Bring them here. Slow is fine. Don't drop them.",
	"climb": "Rack up and climb %s to reach them. Then lower them down on the rope.",
	"report": "Come and tell me how it went.",
}
## Jo, when it's done.
const WELL_DONE := ["Nice work. Everybody's down, everybody's fine. That's the job.", "Good. That's one in the book. Grab some food, you earned it.", "Clean rescue. I'll write it up."]
## When a call runs past nightfall.
const WRAPPED_UP := "It's dark. The night team found %s by headlamp. Everyone's fine, and Jo says there's always another call."
## What Jo hands over for a rescue.
const REWARD := {"trail_mix": 1}

## The call on the radio today, waiting to be taken ("" for none), and the
## day it came in.
var offered := ""
var offered_day := -1
## The call underway: its id ("" for none), and the stage it's on (an index
## into its "stages").
var current := ""
var stage := 0
## Every rescue you've finished, oldest first: {"id", "day" (Friendship.today)}.
var history: Array[Dictionary] = []
## Call ids whose thank-you note goes up on the Camp 4 board next morning.
var thanks_waiting: PackedStringArray = []
## Notes on the board now, to be read.
var thanks_posted: PackedStringArray = []

var _by_id: Dictionary = {}
## The day Jo last said the radio was quiet, so she says it once a day.
var _quiet_day := -1


func _ready() -> void:
	add_to_group("persist")
	for call: Dictionary in CALLS:
		_by_id[call.id] = call
	GameClock.day_started.connect(_on_day_started.unbind(3))
	GameClock.time_changed.connect(_on_time_changed)
	QuestLog.quest_started.connect(_on_quest_started)


func start_new_game() -> void:
	offered = ""
	offered_day = -1
	current = ""
	stage = 0
	history = []
	thanks_waiting = []
	thanks_posted = []
	changed.emit()


func get_call(id: String) -> Dictionary:
	return _by_id.get(id, {})


## True once Jo has taken you on (her first quest is underway or done).
func on_team() -> bool:
	return QuestLog.active.has(FIRST_QUEST) or QuestLog.is_completed(FIRST_QUEST)


## The call underway, or {}.
func active_call() -> Dictionary:
	return get_call(current)


## The stage the call underway is on ("search", "carry"...), or "".
func current_stage() -> String:
	var call := active_call()
	if call.is_empty() or stage >= call.stages.size():
		return ""
	return call.stages[stage]


## Walking speed while you carry someone, 1 otherwise (read by Player).
func speed_factor() -> float:
	if current_stage() != "carry":
		return 1.0
	return minf(1.0, CARRY_SPEED + Perks.bonus("long_carry"))


## How many people you've helped.
func count() -> int:
	return history.size()


## The calls that could come in today: in season, on a climb you've ticked,
## and not the call you just did. Climbs wait out rain and snow.
func eligible() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var weather := Weather.today()
	var wet: bool = weather.rain > 0.0 or weather.snow > 0.0
	var last: String = history[-1].id if not history.is_empty() else ""
	for call: Dictionary in CALLS:
		if call.id == FIRST_CALL or call.id == last or not GameClock.season in call.seasons:
			continue
		if call.has("route") and (wet or not QuestLog.has_climbed(call.route)):
			continue
		out.append(call)
	return out


## Puts the morning's call on the radio, or none, once a day.
func refresh() -> void:
	var today := Friendship.today()
	if offered_day == today:
		return
	offered_day = today
	offered = ""
	if current != "" or not QuestLog.is_completed(FIRST_QUEST):
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("rescue:%d" % today)
	if rng.randf() >= CALL_CHANCE:
		return
	var choices := eligible()
	if not choices.is_empty():
		offered = choices[rng.randi() % choices.size()].id
	changed.emit()


## True if a call is on the radio and it's not too late to go.
func call_waiting() -> bool:
	refresh()
	return offered != "" and GameClock.hour < LAST_CALL_HOUR


## Starts [param id] as the call underway.
func begin(id: String) -> void:
	current = id
	stage = 0
	if offered == id:
		offered = ""
	changed.emit()


## What to do next, for the Quests tab and Jo's reminder.
func objective() -> String:
	var call := active_call()
	match current_stage():
		"search":
			return "Find %s: follow the fresh prints from %s (%s). Before dark." % [call.who, _spot_text(call), call.place]
		"feed":
			return "Share food worth %d energy with %s. You have %d." % [int(call.feed), call.who, FoodDB.carried_energy()]
		"carry":
			return "Carry %s back to Jo at the Camp 4 rescue site." % call.who
		"climb":
			return "Climb %s to reach %s, then lower them down." % [_route_name(call.route), call.who]
		"report":
			return "Tell Jo at the Camp 4 rescue site how it went."
	return ""


## Lines for talking to [param character_id]: from Jo, today's call, the end
## of a rescue, or a reminder. Empty for anyone else, or when Jo has nothing
## to say about rescues (her quests and idle lines follow).
func talk_to(character_id: String) -> Array[Dictionary]:
	var lines: Array[Dictionary] = []
	if character_id != LEAD:
		return lines
	var who := _lead_name()
	var at := current_stage()
	if at == "carry" or at == "report":
		var call := active_call()
		lines.append({"speaker": "", "text": call.done})
		lines.append({"speaker": who, "text": WELL_DONE[count() % WELL_DONE.size()], "mood": "happy"})
		lines.append({"speaker": "", "text": _finish()})
		return lines
	if at != "":
		var reminder: String = REMINDERS[at]
		if reminder.contains("%s"):
			var call := active_call()
			reminder = reminder % (_spot_text(call) if at == "search" else _route_name(call.get("route", "")))
		lines.append({"speaker": who, "text": reminder})
		return lines
	if not QuestLog.is_completed(FIRST_QUEST):
		return lines
	if call_waiting():
		var call := get_call(offered)
		begin(call.id)
		lines.append({"speaker": who, "text": RADIO_IN % call.radio})
		lines.append({"speaker": "", "text": "Rescue call: %s. %s" % [call.title, objective()]})
	elif Friendship.today() != _quiet_day:
		_quiet_day = Friendship.today()
		lines.append({"speaker": who, "text": QUIET[Friendship.today() % QUIET.size()]})
	return lines


## Reaching the person you're searching for (RescueSubject). Returns what's
## said: their lines, then the next stage. Shares food if they need it and
## you have it; if not, they wait for you to come back with some.
func reach() -> Array[Dictionary]:
	var lines: Array[Dictionary] = []
	var call := active_call()
	var at := current_stage()
	if at == "search":
		for text: String in call.found:
			lines.append({"speaker": call.who, "text": text, "mood": "sad"})
		_advance()
		at = current_stage()
	if at == "feed":
		if Barter.can_afford(int(call.feed)):
			var paid := Barter.pay(int(call.feed))
			lines.append({"speaker": "", "text": "You share %s. Color comes back into %s's face." % [Barter.describe(paid), call.who]})
			_advance()
		else:
			lines.append({"speaker": "", "text": "%s needs something to eat before moving: food worth %d energy. You have %d." % [call.who, int(call.feed), FoodDB.carried_energy()]})
			return lines
	match current_stage():
		"carry":
			lines.append({"speaker": "", "text": "You get %s up on your back. Next: %s" % [call.who, objective()]})
		"report":
			lines.append({"speaker": "", "text": "Next: %s" % objective()})
	return lines


## True if a call underway needs you on [param route_id] (ClimbStart).
func wants_climb(route_id: String) -> bool:
	return current_stage() == "climb" and active_call().get("route", "") == route_id


## Answering a call on a climb, from its ClimbStart: climb to the party on
## the climbing screen, then lower them in RescueLower. A fall off the climb
## leaves the call open, to try again.
func climb_to_party(player: Player, start: ClimbStart) -> void:
	var call := active_call()
	var route := start.route
	if ClimbState.starts_too_late(route, GameClock.minutes):
		DialogueBox.say_to(player, [{"speaker": "", "text": "It's too late to start up %s. The night team will have to go." % route.display_name}])
		return
	var missing := Gear.missing(route.required_gear)
	if not missing.is_empty():
		DialogueBox.say_to(player, [{"speaker": "", "text": "You need more gear to climb to them: %s." % ", ".join(missing)}])
		return
	player.can_act = false
	var box := DialogueBox.open(player)
	var choice := await box.choose("%s is stuck up %s. Climb to them with a rescue rope?" % [call.who, route.display_name], ["Climb", "Not yet"])
	box.close()
	if choice != 0:
		player.can_act = true
		return
	var success := await start.climb(player, false)
	if not success:
		DialogueBox.say_to(player, [{"speaker": "", "text": "You didn't reach them. Catch your breath and try again: %s is still up there." % call.who}])
		return
	player.can_act = false
	var lines: Array[Dictionary] = []
	for text: String in call.found:
		lines.append({"speaker": call.who, "text": text, "mood": "surprised"})
	lines.append({"speaker": "", "text": "You build an anchor, clip %s to the rescue rope, and get ready to lower." % call.who})
	await DialogueBox.say_to(player, lines)
	player.can_act = false
	var lower := RescueLower.new()
	player.get_tree().root.add_child(lower)
	var visitor_path := RescueField.VISITOR_DIR % call.get("look", "")
	var visitor: CharacterData = load(visitor_path) if ResourceLoader.exists(visitor_path) else null
	lower.start(route, visitor.sprite_sheet if visitor else null)
	GameClock.paused = true
	await lower.finished
	GameClock.paused = false
	var how := lower.outcome_text()
	lower.queue_free()
	_advance()
	player.can_act = true
	DialogueBox.say_to(player, [{"speaker": "", "text": "%s Next: %s" % [how, objective()]}])


## The thank-you notes on the board this morning, as text, taken down as
## they're read, with the gifts tucked in (BulletinBoard).
func read_thanks() -> String:
	if thanks_posted.is_empty():
		return ""
	var parts := PackedStringArray()
	for id: String in thanks_posted:
		var call := get_call(id)
		if call.is_empty():
			continue
		var got := PackedStringArray()
		for item_id: String in call.gift:
			Inventory.add(item_id, int(call.gift[item_id]))
			var item := ItemDB.get_item(item_id)
			got.append(ItemDB.count_name(int(call.gift[item_id]), item.display_name if item else item_id))
		parts.append("A note pinned up for you: \"%s\"\nTucked behind it: %s." % [call.thanks, ", ".join(got)])
	thanks_posted = []
	changed.emit()
	return "\n\n".join(parts)


func _advance() -> void:
	stage += 1
	changed.emit()


## Ends the call underway as your rescue. Returns the line saying what Jo
## hands over.
func _finish() -> String:
	var call := active_call()
	history.append({"id": call.id, "day": Friendship.today()})
	thanks_waiting.append(call.id)
	current = ""
	stage = 0
	if QuestLog.active.has(FIRST_QUEST) and not QuestLog.is_unlocked(FIRST_DONE):
		QuestLog.unlocks.append(FIRST_DONE)
		QuestLog.changed.emit()
	var got := PackedStringArray()
	for item_id: String in REWARD:
		Inventory.add(item_id, int(REWARD[item_id]))
		var item := ItemDB.get_item(item_id)
		got.append(ItemDB.count_name(int(REWARD[item_id]), item.display_name if item else item_id))
	Friendship.add(LEAD, POINTS)
	Perks.note(STAT)
	rescued.emit(call)
	changed.emit()
	return "Rescue logged: %s. Jo hands you %s." % [call.title, ", ".join(got)]


## Jo's first quest starts the first call.
func _on_quest_started(quest: QuestData) -> void:
	if quest.id == FIRST_QUEST and current == "":
		begin(FIRST_CALL)


func _on_day_started() -> void:
	if current != "":
		_wrap_up()
	for id: String in thanks_waiting:
		thanks_posted.append(id)
	thanks_waiting = []
	refresh()


func _on_time_changed(hour: int, _minute: int) -> void:
	if current != "" and hour >= NIGHTFALL:
		var tree := get_tree()
		var hud := tree.get_first_node_in_group("hud") if tree else null
		var text := _wrap_up()
		if hud and text != "":
			hud.show_message(text)


## The team finishes the call underway. Jo's first call can't be missed:
## it stays open until you've done it.
func _wrap_up() -> String:
	var call := active_call()
	if current == FIRST_CALL and QuestLog.active.has(FIRST_QUEST):
		return ""
	current = ""
	stage = 0
	changed.emit()
	return WRAPPED_UP % call.get("who", "them")


func _spot_text(call: Dictionary) -> String:
	return "where they were last seen" if call.get("start", "") == "" else call.get("place", "")


func _route_name(route_id: String) -> String:
	for route: RouteData in Guidebook.routes():
		if route.id == route_id:
			return route.display_name
	return route_id


func _lead_name() -> String:
	var character := QuestLog.get_character(LEAD)
	return character.display_name if character else "Jo"


func save_data() -> Dictionary:
	return {"offered": offered, "offered_day": offered_day, "current": current, "stage": stage,
		"log": history, "thanks_waiting": thanks_waiting, "thanks_posted": thanks_posted}


func load_data(data: Dictionary) -> void:
	offered = str(data.get("offered", ""))
	offered_day = int(data.get("offered_day", -1))
	current = str(data.get("current", ""))
	if current != "" and get_call(current).is_empty():
		current = ""
	stage = int(data.get("stage", 0))
	history = []
	for entry in data.get("log", []):
		history.append({"id": str(entry.get("id", "")), "day": int(entry.get("day", 0))})
	thanks_waiting = PackedStringArray(data.get("thanks_waiting", []))
	thanks_posted = PackedStringArray(data.get("thanks_posted", []))
	changed.emit()
