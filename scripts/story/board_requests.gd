extends Node
## The notes pinned on the Camp 4 bulletin board (autoload "BoardRequests"),
## like Stardew Valley's Help Wanted board: each morning a note or two goes
## up from someone you know, asking for a few things from the woods. Read
## the board to take them; they go in your Quests, and you hand the things
## over by talking to whoever wrote the note. Each one pays in trail food
## and a little friendship.
##
## Only people you've talked with post (Friendship.points), so the board
## grows as you get to know the Valley, and a note only asks for forage that
## grows in the season it goes up. The notes are short and in each person's
## voice, from what their stories say; the Native cast don't post until their
## lines have had the tribal review.

signal changed

## Most notes you can carry at once.
const MAX_OPEN := 3
## Most new notes pinned up in a morning.
const PER_DAY := 2
## Days a note stays good after it goes up (the day itself and the next two).
const LASTS := 3
## Friendship points for a note done (a fifth of a heart).
const POINTS := 20

## Every note that can go up: who wrote it, what and how many they want, the
## seasons (GameClock.Season) it can go up in, what it says, the thanks, and
## what you're given. A note for something that grows in only one hub names
## it ("hub"), and goes up only once you can travel there.
const NOTES := [
	{"id": "degnan_strawberries", "giver": "bridget_degnan", "item": "wild_strawberry", "count": 3, "seasons": [0, 1],
		"text": "Wanted: wild strawberries for the morning tarts. Bring them to Degnan's.",
		"thanks": "Oh, they're perfect! The tarts will be gone by ten.", "reward": {"pilot_bread": 2}},
	{"id": "degnan_elderberries", "giver": "bridget_degnan", "item": "blue_elderberries", "count": 4, "seasons": [1],
		"text": "Blue elderberries wanted for sauce. Ripe ones only, mind.",
		"thanks": "Lovely and dusty blue. That's a good batch of sauce.", "reward": {"cheddar_wedge": 1}},
	{"id": "curry_greens", "giver": "jennie_curry", "item": "miners_lettuce", "count": 3, "seasons": [0],
		"text": "Camp Curry kitchen needs miner's lettuce for the supper salad. Fresh, please.",
		"thanks": "Fresh as the morning. The guests will never know how lucky they are.", "reward": {"dried_apples": 2}},
	{"id": "curry_rose_hips", "giver": "jennie_curry", "item": "wood_rose_hips", "count": 4, "seasons": [2, 3],
		"text": "Rose hips wanted for winter tea at the Pavilion.",
		"thanks": "These will see us through the cold months. Thank you.", "reward": {"chocolate_bar": 1}},
	{"id": "enid_onions", "giver": "enid_michael", "item": "sierra_onion", "count": 2, "seasons": [0],
		"text": "Two Sierra onions for the garden's study bed. Take only where there are many.",
		"thanks": "Good. You left the rest of the patch, I hope? Then thank you.", "reward": {"trail_mix": 1}},
	{"id": "enid_yampah", "giver": "enid_michael", "item": "yampah", "count": 2, "seasons": [1, 2],
		"text": "Yampah wanted, roots and all, to show the garden visitors. Look in the meadows.",
		"thanks": "That's yampah, sure enough. The carrot family has some dangerous cousins, and you picked the right one.", "reward": {"dried_apricots": 1}},
	{"id": "muir_tea", "giver": "john_muir", "item": "yerba_buena", "count": 3, "seasons": [0, 1],
		"text": "A few sprigs of yerba buena for a pot of tea, if any wanderer finds it by the river. J.M.",
		"thanks": "Ah, that smell! The whole river in a cup. You've earned a share of my crusts.", "reward": {"dry_crusts": 2}},
	{"id": "clark_morels", "giver": "galen_clark", "item": "morel_mushroom", "count": 2, "seasons": [0],
		"text": "Morels wanted for supper. They come up under the black oaks after the spring rains.",
		"thanks": "Just like the ones I found my first spring here. Thank you, friend.", "reward": {"beef_jerky": 1}},
	{"id": "clark_boletes", "giver": "galen_clark", "item": "king_bolete", "count": 2, "seasons": [2],
		"text": "Two king boletes for the stove. Check the conifer woods.",
		"thanks": "Fine and firm. These will fry up well.", "reward": {"beef_jerky": 1}},
	{"id": "lamon_blackberries", "giver": "james_lamon", "item": "california_blackberry", "count": 4, "seasons": [1],
		"text": "Native blackberries wanted at the homestead, for a pie to go with the apples.",
		"thanks": "A blackberry and apple pie. Now that's a Yosemite supper.", "reward": {"dried_apples": 3}},
	{"id": "chef_chanterelles", "giver": "ahwahnee_chef", "item": "chanterelle", "count": 3, "seasons": [2, 3],
		"text": "The Ahwahnee kitchen will take any golden chanterelles you find. Ask for Lucien.",
		"thanks": "Magnifique. These go in the cream sauce tonight.", "reward": {"chocolate_bar": 2}},
	{"id": "chef_toyon", "giver": "ahwahnee_chef", "item": "toyon_berries", "count": 4, "seasons": [2, 3],
		"text": "Toyon berries wanted for a winter garnish. Red ones only.",
		"thanks": "Red as the holly at Bracebridge. Very good.", "reward": {"cheddar_wedge": 1}},
	{"id": "wren_raspberries", "giver": "wren_alvarez", "item": "whitebark_raspberry", "count": 3, "seasons": [1],
		"text": "Rest day snack wanted! Raspberries, any kind. Will share. -Wren",
		"thanks": "Yes! Okay, half for you, half for me. That's the deal.", "reward": {"trail_mix": 2}},
	{"id": "marty_manzanita", "giver": "mountain_shop", "item": "manzanita_berries", "count": 4, "seasons": [1],
		"text": "Mountain Shop will trade for manzanita berries. Ask at the counter.",
		"thanks": "Good, the trail mix was getting low on anything that isn't a peanut.", "reward": {"trail_mix": 2}},
	{"id": "salathe_greens", "giver": "john_salathe", "item": "miners_lettuce", "count": 4, "seasons": [0],
		"text": "Wild greens wanted. A man cannot live on pitons alone. -J.S., Camp 4",
		"thanks": "Good greens. My doctor said eat what grows. I listened.", "reward": {"cheddar_wedge": 1}},
	{"id": "robbins_bilberries", "giver": "royal_robbins", "item": "sierra_bilberry", "count": 3, "seasons": [1, 2], "hub": "tuolumne_meadows",
		"text": "Bilberries from the high country, for a long day on the wall. -R.R.",
		"thanks": "These will ride in the haul bag. Thank you.", "reward": {"dried_apricots": 2}},
	{"id": "hodges_gooseberries", "giver": "clare_hodges", "item": "sierra_gooseberry", "count": 3, "seasons": [1],
		"text": "Ranger station: gooseberries wanted for jam. Mind the spines.",
		"thanks": "Not a scratch on you? You're better at this than I am.", "reward": {"pilot_bread": 2}},
	{"id": "degnan_plums", "giver": "bridget_degnan", "item": "sierra_plum", "count": 4, "seasons": [1],
		"text": "Wild plums wanted for jam. The thorny thickets under the oaks have them in summer.",
		"thanks": "Tart as anything. With enough sugar they'll be lovely on toast.", "reward": {"pilot_bread": 2}},
	{"id": "curry_hazelnuts", "giver": "jennie_curry", "item": "hazelnut", "count": 4, "seasons": [2],
		"text": "Hazelnuts wanted for the Pavilion's holiday cakes. Try the thickets in the shady woods.",
		"thanks": "Every one sound. The cakes will be the talk of the camp.", "reward": {"chocolate_bar": 1}},
	{"id": "clark_hedgehogs", "giver": "galen_clark", "item": "hedgehog_mushroom", "count": 2, "seasons": [3],
		"text": "Hedgehog mushrooms wanted for supper. Little teeth under the cap, in the pine woods after the snow.",
		"thanks": "Teeth and all. Fried in a little fat, that's a winter supper fit for anyone.", "reward": {"beef_jerky": 1}},
	{"id": "muir_pine_nuts", "giver": "john_muir", "item": "whitebark_pine_nuts", "count": 3, "seasons": [2], "hub": "tuolumne_meadows",
		"text": "Whitebark pine nuts from timberline, if the nutcrackers have spared any. J.M.",
		"thanks": "Mountain bread! I have lived a week on less, and been the happier for it.", "reward": {"dry_crusts": 2}},
]

## Note ids on the board, waiting to be read.
var posted: PackedStringArray = []
## Note id -> the day (Friendship.today()) it went up, for notes you've taken.
var taken: Dictionary = {}
## The last day notes went up.
var posted_day := -1
## How many notes you've seen through.
var done := 0


func _ready() -> void:
	add_to_group("persist")
	GameClock.day_started.connect(_expire.unbind(3))


func start_new_game() -> void:
	posted = []
	taken = {}
	posted_day = -1
	done = 0
	changed.emit()


func get_note(id: String) -> Dictionary:
	for note: Dictionary in NOTES:
		if note.id == id:
			return note
	return {}


## Pins up the morning's notes, once a day: up to PER_DAY, from people you
## know, for things in season, never one you're already carrying. Notes
## you've let run out come down first.
func refresh() -> void:
	_expire()
	var today := Friendship.today()
	if posted_day == today:
		return
	posted_day = today
	posted = []
	var room := mini(PER_DAY, MAX_OPEN - taken.size())
	var choices: Array[Dictionary] = []
	for note: Dictionary in NOTES:
		if GameClock.season in note.seasons and not taken.has(note.id) and int(Friendship.points.get(note.giver, 0)) > 0 \
				and (not note.has("hub") or Park.is_hub_unlocked(note.hub)):
			choices.append(note)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("board:%d" % today)
	var givers: Array[String] = []
	while room > 0 and not choices.is_empty():
		var pick: Dictionary = choices.pop_at(rng.randi() % choices.size())
		# one note a day from each person
		if pick.giver in givers:
			continue
		givers.append(pick.giver)
		posted.append(pick.id)
		room -= 1
	changed.emit()


## Takes down the notes you've carried past their last day.
func _expire() -> void:
	var before := taken.size()
	for id: String in taken.keys():
		if Friendship.today() - int(taken[id]) >= LASTS:
			taken.erase(id)
	if taken.size() != before:
		changed.emit()


## Reading the board: what it says, and the notes you take down. Returns
## the text the sign shows.
func read() -> String:
	refresh()
	if posted.is_empty():
		if taken.size() >= MAX_OPEN:
			return "You're carrying all the notes you can. See them through, and check back."
		if not _knows_anyone():
			return "Notes for partners and rides, mostly. Get to know people around the Valley and some of the notes will be for you."
		return "Nothing new pinned up today. Check back tomorrow morning."
	var lines := PackedStringArray()
	for id: String in posted:
		var note := get_note(id)
		lines.append("\"%s\"\n(%s, %s)" % [note.text, _want_text(note), _who(note.giver)])
		taken[id] = posted_day
	posted = []
	changed.emit()
	return "%s\n\nYou take the note%s down. They're in your Quests (Q)." % ["\n\n".join(lines), "" if lines.size() == 1 else "s"]


## The notes you're carrying, as {note, have, days_left}, oldest first.
func open_notes() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for id: String in taken:
		var note := get_note(id)
		if note.is_empty():
			continue
		out.append({"note": note, "have": mini(Inventory.count(note.item), int(note.count)),
			"days_left": LASTS - (Friendship.today() - int(taken[id]))})
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.days_left < b.days_left)
	return out


## What a note asks for in the Quests tab: "Bring 3 Wild Strawberries to
## Bridget Degnan (Degnan's Bakery, Yosemite Village). 2 of 3."
func objective(entry: Dictionary) -> String:
	var note: Dictionary = entry.note
	var character := QuestLog.get_character(note.giver)
	var home := character.home_now(QuestLog.is_completed) if character else ""
	var left := "today is the last day" if entry.days_left <= 1 else "%d days left" % entry.days_left
	return "Bring %s to %s%s. You have %d of %d; %s." % [_want_text(note), _who(note.giver),
		" (%s)" % home if home != "" else "", entry.have, note.count, left]


## Hands over everything [param character_id] asked for that you're
## carrying, and returns their thanks and what they gave as dialogue lines
## (empty if there was nothing to hand over).
func deliver(character_id: String) -> Array[Dictionary]:
	var lines: Array[Dictionary] = []
	for id: String in taken.keys():
		var note := get_note(id)
		if note.is_empty() or note.giver != character_id or Inventory.count(note.item) < int(note.count):
			continue
		Inventory.remove(note.item, int(note.count))
		taken.erase(id)
		done += 1
		var got := PackedStringArray()
		for item_id: String in note.reward:
			var amount := int(note.reward[item_id])
			Inventory.add(item_id, amount)
			var item := ItemDB.get_item(item_id)
			got.append(ItemDB.count_name(amount, item.display_name if item else item_id))
		lines.append({"speaker": _who(character_id), "text": note.thanks, "mood": "happy"})
		lines.append({"speaker": "", "text": "Board note done. Received %s." % ", ".join(got)})
		Friendship.add(character_id, POINTS)
	if not lines.is_empty():
		changed.emit()
	return lines


func _want_text(note: Dictionary) -> String:
	var item := ItemDB.get_item(note.item)
	return ItemDB.count_name(int(note.count), item.display_name if item else note.item)


func _who(character_id: String) -> String:
	var character := QuestLog.get_character(character_id)
	return character.display_name if character else character_id


func _knows_anyone() -> bool:
	for note: Dictionary in NOTES:
		if int(Friendship.points.get(note.giver, 0)) > 0:
			return true
	return false


func save_data() -> Dictionary:
	return {"posted": posted, "taken": taken, "posted_day": posted_day, "done": done}


func load_data(data: Dictionary) -> void:
	posted = PackedStringArray(data.get("posted", []))
	taken = {}
	for key in data.get("taken", {}):
		taken[str(key)] = int(data.taken[key])
	posted_day = int(data.get("posted_day", -1))
	done = int(data.get("done", 0))
	changed.emit()
