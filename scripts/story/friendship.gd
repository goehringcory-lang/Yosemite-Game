extends Node
## How well you know each person (autoload "Friendship"), Stardew Valley's
## hearts in this Valley's way: up to five hearts each, from talking with them
## (once a day), finishing their quests, and a gift once a week. Nothing ever
## takes hearts away.
##
## Gifts are food and forage. Everyone likes a fresh find or a good dish; each
## person also has a few things they love, picked from their story where it
## says (John Muir walked the Sierra on dry bread crusts and tea; Enid Michael
## knew every wild green in the Valley).

signal changed
## Sent when someone's hearts go up a whole heart.
signal heart_gained(character_id: String, hearts: int)

const POINTS_PER_HEART := 100
const MAX_HEARTS := 5
const TALK_POINTS := 10
const QUEST_POINTS := 60
const LOVED_POINTS := 80
const LIKED_POINTS := 45
const PLAIN_POINTS := 20
## Days between gifts to the same person.
const GIFT_EVERY := 7

## What each person loves most (item ids). Everyone likes the rest of the
## food that's ready to eat.
const LOVES := {
	"galen_clark": ["yerba_buena_tea", "roasted_morels"],
	"james_lamon": ["bread_pudding", "dried_apples"],
	"tenaya": ["acorn_mush", "manzanita_cider"],
	"maggie_howard": ["acorn_cake", "manzanita_berries"],
	"bridget_degnan": ["elderberry_sauce", "wild_strawberry"],
	"dick_leonard": ["trail_mix", "beef_jerky"],
	"jules_eichorn": ["chocolate_bar", "trail_mix"],
	"bestor_robinson": ["cheddar_wedge", "pilot_bread"],
	"jennie_curry": ["bread_pudding", "spring_greens"],
	"george_anderson": ["beef_jerky", "pilot_bread"],
	"clare_hodges": ["spring_greens", "yerba_buena_tea"],
	"ansel_adams": ["chocolate_bar", "dried_apricots"],
	"lucy_telles": ["acorn_mush", "toasted_toyon"],
	"maria_lebrado": ["acorn_cake", "toyon_berries"],
	"james_mccauley": ["bread_pudding", "cheddar_wedge"],
	"enid_michael": ["miners_lettuce", "yampah", "sierra_onion"],
	"royal_robbins": ["dried_apricots", "trail_mix"],
	"john_salathe": ["miners_lettuce", "cheddar_wedge"],
	"warren_harding": ["manzanita_cider", "chocolate_bar"],
	"beverly_johnson": ["dried_apricots", "chocolate_bar"],
	"john_muir": ["dry_crusts", "yerba_buena_tea"],
	"carrie_bethel": ["acorn_cake", "blue_elderberries"],
	"wren_alvarez": ["trail_mix", "chocolate_bar"],
	"ahwahnee_chef": ["roasted_morels", "elderberry_sauce"],
	"mountain_shop": ["beef_jerky", "pilot_bread"],
	"greg": ["beef_jerky", "manzanita_cider"],
	"jo_tolliver": ["chocolate_bar", "pilot_bread"],
	"mateo_reyes": ["beef_jerky", "trail_mix"],
}
const LOVED_LINES := [
	"Oh! For me? I love these. Thank you!",
	"Oh, how did you know? These are my favorite!",
	"Oh! You remembered. That's wonderful, thank you!",
]
const LIKED_LINES := [
	"Thank you, that's kind of you.",
	"That's a good find. Thanks!",
	"Thanks! I'll enjoy that.",
]
const PLAIN_LINES := [
	"Thanks. That's thoughtful.",
	"Oh, thank you.",
]

## How many of the latest things you did are kept for people to mention.
const NEWS_KEPT := 4
## Animals worth telling people about the first time you see one.
const SIGHTINGS := ["black_bear", "bobcat", "peregrine_falcon", "great_gray_owl"]

## Character id -> points (0 to MAX_HEARTS * POINTS_PER_HEART).
var points: Dictionary = {}
## Character id -> the day (Friendship.today()) you last talked or gave.
var talked: Dictionary = {}
var gifted: Dictionary = {}
## Character id -> the hearts of the last heart scene they shared with you
## (HeartScenes: 3 or 5).
var scenes: Dictionary = {}
## Character id -> the day a close friend last saved you something (HeartScenes).
var saved_for_you: Dictionary = {}
## What you've been up to lately, for people to mention in passing
## (SmallTalk): the last NEWS_KEPT notable things, oldest first, each
## {"id", "kind", "what", "day"} (see [method note_news]).
var news: Array = []
var news_count := 0
## Character id -> the newest news id they've caught up on.
var told: Dictionary = {}
## Character id -> the everyday line they said last, so it isn't said twice running.
var said: Dictionary = {}


func _ready() -> void:
	add_to_group("persist")
	QuestLog.quest_completed.connect(func(quest: QuestData) -> void:
		add(quest.giver, QUEST_POINTS)
		# they've just heard all about it
		hear_news(quest.giver))
	# (every autoload exists by now, though the later ones aren't ready yet)
	QuestLog.ticked.connect(func(route_id: String) -> void: note_news("climb", route_words(route_id)))
	Rescues.rescued.connect(func(call: Dictionary) -> void:
		note_news("rescue", str(call.get("who", "")))
		hear_news(Rescues.LEAD))
	Achievements.landed.connect(_on_landed)
	FieldLog.logged.connect(func(id: String) -> void:
		if id in SIGHTINGS:
			note_news("sighting", with_article(str(FieldLog.get_animal(id).get("name", id)))))


func start_new_game() -> void:
	points = {}
	talked = {}
	gifted = {}
	scenes = {}
	saved_for_you = {}
	news = []
	news_count = 0
	told = {}
	said = {}
	changed.emit()


## A running count of days, for "once a day" and "once a week".
static func today() -> int:
	return (GameClock.year - 1) * 4 * GameClock.DAYS_PER_SEASON + GameClock.season * GameClock.DAYS_PER_SEASON + GameClock.day


func hearts(character_id: String) -> int:
	return mini(int(points.get(character_id, 0)) / POINTS_PER_HEART, MAX_HEARTS)


## Adds [param amount] points, sending heart_gained for each new heart.
func add(character_id: String, amount: int) -> void:
	if character_id == "" or amount <= 0:
		return
	var before := hearts(character_id)
	points[character_id] = mini(int(points.get(character_id, 0)) + amount, MAX_HEARTS * POINTS_PER_HEART)
	var after := hearts(character_id)
	changed.emit()
	for heart in range(before + 1, after + 1):
		heart_gained.emit(character_id, heart)


## The first talk of the day with someone counts.
func note_talk(character_id: String) -> void:
	if talked.get(character_id, -1) == today():
		return
	talked[character_id] = today()
	add(character_id, Festivals.talk_points(TALK_POINTS))


## True if you can give this person something today (once a week).
func can_gift(character_id: String) -> bool:
	return not gifted.has(character_id) or today() - int(gifted[character_id]) >= GIFT_EVERY


## Days until you can give this person something again (0 if you can now).
func days_until_gift(character_id: String) -> int:
	return 0 if can_gift(character_id) else GIFT_EVERY - (today() - int(gifted[character_id]))


## True if [param item_id] can be given: food and forage, not story things.
static func is_giftable(item_id: String) -> bool:
	var item := ItemDB.get_item(item_id)
	return item != null and FoodDB.is_food(item_id) and not item.resource_path.contains("/story_items/")


## "loved", "liked" (ready to eat) or "plain" (raw, or a cooking ingredient).
static func taste(character_id: String, item_id: String) -> String:
	if item_id in LOVES.get(character_id, []):
		return "loved"
	return "liked" if FoodDB.energy(item_id) > 0 else "plain"


## What you're carrying that you could give, as item ids, loved first.
func giftable_items(character_id: String) -> PackedStringArray:
	var loved := PackedStringArray()
	var rest := PackedStringArray()
	for id: String in Inventory.items:
		if Inventory.count(id) > 0 and is_giftable(id):
			if taste(character_id, id) == "loved":
				loved.append(id)
			else:
				rest.append(id)
	rest.sort()
	return loved + rest


## Gives one [param item_id] to [param character_id]: takes it from the pack,
## adds the points and returns the person's thanks (a line of dialogue), or
## "" if it couldn't be given.
func give(character_id: String, item_id: String) -> String:
	if not can_gift(character_id) or not is_giftable(item_id) or not Inventory.remove(item_id):
		return ""
	gifted[character_id] = today()
	var kind := taste(character_id, item_id)
	var lines: Array = PLAIN_LINES
	match kind:
		"loved":
			add(character_id, LOVED_POINTS)
			# in their own words, if they have some (SmallTalk)
			var own := SmallTalk.loved_line(character_id)
			lines = [own] if own != "" else LOVED_LINES
		"liked":
			add(character_id, LIKED_POINTS)
			lines = LIKED_LINES
		_:
			add(character_id, PLAIN_POINTS)
	return lines[absi(hash(character_id) + today()) % lines.size()]


# ------------------------------------------------------------------- the news

## Something you did that people might mention (SmallTalk). [param kind] is
## "climb", "rescue", "fish" or "sighting"; [param what] is how a line puts
## it: "the Nose", "Toby Lindqvist", "a 19-inch Brown Trout", "a Bobcat".
func note_news(kind: String, what: String) -> void:
	if what == "":
		return
	news_count += 1
	news.append({"id": news_count, "kind": kind, "what": what, "day": today()})
	while news.size() > NEWS_KEPT:
		news.pop_front()


## The latest news [param character_id] hasn't caught up on, of one of
## [param kinds], from the last SmallTalk.NEWS_DAYS days; or {}.
func news_for(character_id: String, kinds: Array) -> Dictionary:
	var heard := int(told.get(character_id, 0))
	for i in range(news.size() - 1, -1, -1):
		var item: Dictionary = news[i]
		if int(item.id) <= heard or today() - int(item.day) > SmallTalk.NEWS_DAYS:
			break
		if item.kind in kinds:
			return item
	return {}


## [param character_id] has caught up on everything you've done so far.
func hear_news(character_id: String) -> void:
	if character_id != "":
		told[character_id] = news_count


## A fish is news the first time you land its kind, or when it's a trophy.
func _on_landed(one: Dictionary) -> void:
	var id: String = one.get("id", "")
	var first := int(Achievements.fish.get(id, {}).get("count", 0)) == 1
	if id == "" or not (first or one.get("trophy", false)):
		return
	var fish_name := str(FieldLog.get_animal(id).get("name", id))
	note_news("fish", with_article("%d-inch %s" % [int(one.length), fish_name] if one.has("length") else fish_name))


## A route's name the way it goes in the middle of a sentence ("the Nose").
static func route_words(route_id: String) -> String:
	for route: RouteData in Guidebook.routes():
		if route.id == route_id:
			return "the " + route.display_name.substr(4) if route.display_name.begins_with("The ") else route.display_name
	return ""


## [param words] with "a" or "an" in front, as it's said ("an 18-inch").
static func with_article(words: String) -> String:
	var first := words.get_slice(" ", 0).get_slice("-", 0).to_lower()
	var vowel_sound := first.left(1) in ["a", "e", "i", "o", "u"]
	if first.is_valid_int():
		# eight, eleven, eighteen, eighty...
		vowel_sound = first.begins_with("8") or first in ["11", "18"]
	return ("an " if vowel_sound else "a ") + words


func save_data() -> Dictionary:
	return {"points": points, "talked": talked, "gifted": gifted, "scenes": scenes,
		"saved_for_you": saved_for_you, "news": news, "news_count": news_count, "told": told, "said": said}


func load_data(data: Dictionary) -> void:
	points = _ints(data.get("points", {}))
	talked = _ints(data.get("talked", {}))
	gifted = _ints(data.get("gifted", {}))
	# (saves from before heart scenes and small talk have none of these)
	scenes = _ints(data.get("scenes", {}))
	saved_for_you = _ints(data.get("saved_for_you", {}))
	news = []
	for item in data.get("news", []):
		if item is Dictionary:
			news.append({"id": int(item.get("id", 0)), "kind": str(item.get("kind", "")), "what": str(item.get("what", "")), "day": int(item.get("day", 0))})
	news_count = int(data.get("news_count", news.back().id if not news.is_empty() else 0))
	told = _ints(data.get("told", {}))
	said = {}
	var lines: Dictionary = data.get("said", {})
	for key in lines:
		said[str(key)] = str(lines[key])
	changed.emit()


## A saved dictionary of whole numbers (JSON brings them back as floats).
static func _ints(saved: Dictionary) -> Dictionary:
	var out := {}
	for key in saved:
		out[str(key)] = int(saved[key])
	return out
