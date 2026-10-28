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

## Character id -> points (0 to MAX_HEARTS * POINTS_PER_HEART).
var points: Dictionary = {}
## Character id -> the day (Friendship.today()) you last talked or gave.
var talked: Dictionary = {}
var gifted: Dictionary = {}


func _ready() -> void:
	add_to_group("persist")
	QuestLog.quest_completed.connect(func(quest: QuestData) -> void: add(quest.giver, QUEST_POINTS))


func start_new_game() -> void:
	points = {}
	talked = {}
	gifted = {}
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
			lines = LOVED_LINES
		"liked":
			add(character_id, LIKED_POINTS)
			lines = LIKED_LINES
		_:
			add(character_id, PLAIN_POINTS)
	return lines[(hash(character_id) + today()) % lines.size()]


func save_data() -> Dictionary:
	return {"points": points, "talked": talked, "gifted": gifted}


func load_data(data: Dictionary) -> void:
	points = {}
	talked = {}
	gifted = {}
	for key in data.get("points", {}):
		points[str(key)] = int(data.points[key])
	for key in data.get("talked", {}):
		talked[str(key)] = int(data.talked[key])
	for key in data.get("gifted", {}):
		gifted[str(key)] = int(data.gifted[key])
	changed.emit()
