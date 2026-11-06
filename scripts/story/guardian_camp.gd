extends Node
## The Guardian's camp (autoload "Camp"): your tent at the Lamon Homestead,
## pitched in the missing Guardian's empty spot, and everything that turns it
## into a home as the story goes on.
##
## - Camp things (PIECES). Some quests give something for your camp instead
##   of food: Lamon's apple-box chest, Jennie Curry's canvas tent, Hodges's
##   lantern, Salathé's pot crane. Each stands at the homestead from the day
##   you finish its quest, drawn by CampPiece, and says who gave it.
## - Keepsakes (KEEPSAKES). Every main-line quest leaves one small thing on
##   the plank shelf by your tent: Wren's tick card, Salathé's piton, a
##   pebble off the Lyell ice.
## - Things that follow what you did: the gear rack shows your rack, the
##   summit cairn gets a stone for every summit (Achievements.summits), the
##   fish board holds your biggest catch, and the framed sheets count your
##   press book.
## - The camp chest: put things from your pack away and take them out again.
##   It has room for CHEST_SPACES kinds of thing, more with the bear box.
##   Food keeps spoiling in there at the same rate as in your pack.
## - After the cave, a sign: the Guardian's camp.
##
## What you have is worked out from the quests you've finished (and the
## summits and fish you've logged), so an old save gets its camp the moment
## it loads. Only the chest's contents are saved here.

signal changed

const REGION := "lamon_homestead"

## Every camp thing: id, name, the quest that brings it ("" = see [member
## has]), who gives it (a character id), where it stands at the homestead
## (feet), what the reward line calls it ("got"), and what you read when you
## look at it ("text").
const PIECES: Array[Dictionary] = [
	{"id": "chest", "name": "Apple-box chest", "quest": "lamon_orchard", "from": "james_lamon", "pos": Vector2(374, 266),
		"got": "an apple-box chest for your camp, to keep things in",
		"text": "A pine apple box with a lid and a hasp, from James Lamon's barn. Things you put away here stay at camp, so they're out of your pack. Food keeps spoiling at the usual rate."},
	{"id": "camp_chair", "name": "Camp stool", "quest": "partner_apron", "from": "wren_alvarez", "pos": Vector2(384, 424),
		"got": "Wren's old camp stool, for your fire",
		"text": "A canvas camp stool with one leg splinted with tape. Wren says it's been to the top of more routes than she has."},
	{"id": "gear_rack", "name": "Gear rack", "quest": "leonard_belay", "from": "dick_leonard", "pos": Vector2(226, 266),
		"got": "a peg rack for your rope and gear, from the Rock Climbing Section",
		"text": "Two pegs and a crossbar, lashed the Sierra Club way. Your rope hangs here when you're home, and whatever rack you've got."},
	{"id": "lantern", "name": "Ranger's lantern", "quest": "hodges_patrol", "from": "clare_hodges", "pos": Vector2(352, 334),
		"got": "a ranger's lantern on a post, for your camp",
		"text": "A kerosene lantern from the ranger station, on an oak post. Hodges says a camp with a light in it looks lived in, and bears agree."},
	{"id": "wall_tent", "name": "Canvas tent", "quest": "curry_starter", "from": "jennie_curry", "pos": Vector2(304, 256),
		"got": "a Camp Curry canvas tent on a wooden floor, in place of your little one",
		"text": "Camp Curry's kind of tent: white canvas walls on a plank floor, a cot, and room to stand up. Jennie Curry says the Guardian's spot deserved better than a pup tent."},
	{"id": "print", "name": "Half Dome print", "quest": "ansel_monolith", "from": "ansel_adams", "pos": Vector2(500, 266),
		"got": "a print of Half Dome from Ansel Adams, for your camp",
		"text": "Monolith, the Face of Half Dome, from 1927, on a little easel by your shelf. In the margin, in pencil: \"For the camp under the oaks.\""},
	{"id": "hammock", "name": "Webbing hammock", "quest": "wren_apron", "from": "wren_alvarez", "pos": Vector2(560, 334),
		"got": "a hammock woven out of old climbing webbing",
		"text": "Retired tubular webbing, woven into a hammock on an A-frame of lodgepole. Too worn to trust on a wall; perfect for an afternoon."},
	{"id": "bird_bath", "name": "Bird bath", "quest": "enid_dawn_chorus", "from": "enid_michael", "pos": Vector2(190, 214),
		"got": "a granite bird bath for your camp",
		"text": "A hollow in a slab of granite, kept full. Enid Michael says a bird bath is a field guide that comes to you."},
	{"id": "woodpile", "name": "Woodpile", "quest": "lamon_winter", "from": "james_lamon", "pos": Vector2(328, 456),
		"got": "a winter's woodpile, split and stacked",
		"text": "Oak and cedar rounds, split and stacked bark up the way Lamon likes them. Enough for a winter, if you're careful."},
	{"id": "pot_crane", "name": "Pot crane", "quest": "salathe_steel", "from": "john_salathe", "pos": Vector2(420, 403),
		"got": "a pot crane for your campfire, forged by John Salathé",
		"text": "A three-legged iron crane over your fire, with a hook that swings out. Salathé forged it from the same steel as his pitons. It will outlast you."},
	{"id": "dutch_oven", "name": "Dutch oven", "quest": "ahwahnee_chef_larder", "from": "ahwahnee_chef", "pos": Vector2(450, 414),
		"got": "a cast-iron Dutch oven from the Ahwahnee kitchen",
		"text": "Black cast iron with a rim on the lid for coals. The Ahwahnee's chef swears it bakes better over a campfire than anything in the hotel."},
	{"id": "bear_box", "name": "Bear box", "quest": "hodges_bear_season", "from": "clare_hodges", "pos": Vector2(250, 330),
		"got": "a steel bear box for your camp (your chest holds %d more kinds of thing)",
		"text": "A steel food locker with a two-handed latch. Your food stays at camp in here, and the bears walk on by."},
	{"id": "fish_board", "name": "Fish board", "quest": "greg_first_rod", "from": "greg", "pos": Vector2(660, 362),
		"got": "a board to mount your best fish on",
		"text": "A plank on a post with a chalk outline on it. Greg says you trace your best fish, then let it go."},
	{"id": "press_frames", "name": "Framed sheets", "quest": "enid_full_press", "from": "enid_michael", "pos": Vector2(560, 480),
		"got": "frames for your best press-book sheets, on a line by your tent",
		"text": "Your best sheets from the press, framed under glass and hung on a line between two posts to air."},
	{"id": "keepsake_shelf", "name": "Keepsake shelf", "quest": "partner_apron", "from": "james_lamon", "pos": Vector2(440, 252),
		"got": "",
		"text": "A plank on two rounds of oak, by the tent. It holds the things people give you along the way."},
	{"id": "summit_cairn", "name": "Summit cairn", "quest": "", "from": "", "pos": Vector2(680, 432),
		"got": "",
		"text": "A little cairn of stones by your camp, one for every summit you've stood on."},
	{"id": "guardian_sign", "name": "The Guardian's camp", "quest": "lost_guardian", "from": "galen_clark", "pos": Vector2(204, 300),
		"got": "a sign at your camp",
		"text": "A board carved by many hands, and not very well: THE GUARDIAN'S CAMP. Somebody has added a smaller line underneath: \"Knock. They're usually out.\""},
]

## What every main-line quest leaves on the keepsake shelf: name, a few
## words, and how it's drawn on the shelf ("look").
const KEEPSAKES: Array[Dictionary] = [
	{"quest": "partner_apron", "name": "Wren's tick card", "look": "card", "text": "Firefall Slab, 5.5, with the date and Wren's initials as witness."},
	{"quest": "leonard_belay", "name": "A whipped rope end", "look": "coil", "text": "The end of an old hemp rope, whipped with waxed thread. Dick Leonard says every climber should own one rope they never trust again."},
	{"quest": "eichorn_apron", "name": "A Glacier Point postcard", "look": "postcard", "text": "From the top of the Apron, addressed to your camp. Jennie Curry posted it for you."},
	{"quest": "robbins_clean", "name": "A hex nut", "look": "nut", "text": "An aluminum hex on a sling, from Royal Robbins. No hammer needed."},
	{"quest": "eichorn_spires", "name": "A copied summit register", "look": "page", "text": "Jules Eichorn's copy of the 1934 summit register from Higher Cathedral Spire, with your name added at the bottom."},
	{"quest": "salathe_steel", "name": "A hand-forged piton", "look": "piton", "text": "Salathé's hard steel, still blue from the forge. He says the old soft ones bent like hairpins."},
	{"quest": "johnson_astroman", "name": "A roll of tape", "look": "tape", "text": "Half a roll of finger tape from Beverly Johnson. Astroman's cracks ate the other half."},
	{"quest": "robbins_roof", "name": "A chalky handprint", "look": "hand", "text": "A card with a white handprint on it, from the lip of Separate Reality."},
	{"quest": "harding_summit", "name": "A bent bolt hanger", "look": "hanger", "text": "From the Nose, retired after years of hauling. Warren Harding says it's a souvenir. Royal Robbins says it's evidence."},
	{"quest": "muir_cathedral", "name": "A whitebark pine cone", "look": "cone", "text": "From under the trees below Cathedral Peak, where John Muir says he went to church."},
	{"quest": "muir_glacier", "name": "A glacier-polished pebble", "look": "pebble", "text": "Ground smooth under the Lyell ice. Muir says it's older than anything else on your shelf, and he's right."},
	{"quest": "clark_last_page", "name": "A pencil stub", "look": "pencil", "text": "The pencil you wrote the Register's last page with, sharpened down to a stub."},
	{"quest": "lost_guardian", "name": "The tin box", "look": "tin", "text": "The tin box from the cave under the Royal Arches. It's empty now. Everything that was in it was you."},
]

## How many kinds of thing the camp chest holds, and how many more once the
## bear box is in.
const CHEST_SPACES := 10
const BEAR_BOX_SPACES := 6

## The camp chest: item id -> count.
var chest: Dictionary = {}
## Food in the chest: item id -> days left for each unit, oldest first (as
## in Larder.batches).
var chest_batches: Dictionary = {}
## What spoiled in the chest last night ("" if nothing), for the morning.
var last_spoiled := ""


func _ready() -> void:
	add_to_group("persist")
	GameClock.day_started.connect(_age_food.unbind(3))
	QuestLog.quest_completed.connect(func(_q: QuestData) -> void: changed.emit())


func start_new_game() -> void:
	chest = {}
	chest_batches = {}
	last_spoiled = ""
	changed.emit()


func get_piece(id: String) -> Dictionary:
	for piece: Dictionary in PIECES:
		if piece.id == id:
			return piece
	return {}


## Whether the camp has [param id] yet.
func has(id: String) -> bool:
	var piece := get_piece(id)
	if piece.is_empty():
		return false
	if id == "summit_cairn":
		return Achievements.summit_count() > 0
	return QuestLog.is_completed(piece.quest)


## The camp things you have, in PIECES order.
func pieces() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for piece: Dictionary in PIECES:
		if has(piece.id):
			out.append(piece)
	return out


## The keepsakes on your shelf so far.
func keepsakes() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for keepsake: Dictionary in KEEPSAKES:
		if QuestLog.is_completed(keepsake.quest):
			out.append(keepsake)
	return out


## The line a finished quest adds to its rewards ("For your camp: ..."), or
## "" if it brings nothing for the camp.
func reward_line(quest_id: String) -> String:
	var parts := PackedStringArray()
	for piece: Dictionary in PIECES:
		if piece.quest == quest_id and piece.got != "":
			parts.append(piece.got % BEAR_BOX_SPACES if piece.got.contains("%d") else piece.got)
	for keepsake: Dictionary in KEEPSAKES:
		if keepsake.quest == quest_id:
			parts.append("%s for your keepsake shelf" % keepsake.name.to_lower())
	if parts.is_empty():
		return ""
	return "For your camp: %s." % "; ".join(parts)


## Who gave [param piece], as a display name ("" for things nobody gave).
func giver_name(piece: Dictionary) -> String:
	if piece.from == "":
		return ""
	var who := QuestLog.get_character(piece.from)
	return who.display_name if who else piece.from


## What you read when you look at a camp thing: its text, plus what it's
## showing now (your best fish, your summits, your press book, your rack).
func describe(id: String) -> String:
	var piece := get_piece(id)
	var text: String = piece.get("text", "")
	match id:
		"keepsake_shelf":
			var names := PackedStringArray()
			for keepsake: Dictionary in keepsakes():
				names.append(keepsake.name)
			if not names.is_empty():
				text += " On it: %s." % ", ".join(names)
		"summit_cairn":
			var tops := PackedStringArray()
			for summit: Dictionary in Achievements.SUMMITS:
				if Achievements.on_summit(summit.id):
					tops.append(summit.name)
			text += " %s." % ", ".join(tops)
		"fish_board":
			var best := biggest_fish()
			if best.is_empty():
				text += " It's still empty."
			else:
				text += " Traced on it now: a %d-inch %s." % [best.inches, best.name]
		"press_frames":
			text += " %d of %d plants in your press book." % [Herbarium.count(), Herbarium.total()]
		"gear_rack":
			var rack := PackedStringArray()
			for gear_id in ["rope", "cam", "quickdraw", "ice_axe"]:
				if Gear.count(gear_id) > 0:
					var gear := Gear.get_gear(gear_id)
					rack.append(ItemDB.count_name(Gear.count(gear_id), gear.display_name) if Gear.count(gear_id) > 1 else gear.display_name)
			if not rack.is_empty():
				text += " On it: %s." % ", ".join(rack)
		"chest":
			text += " %d of %d spaces used." % [chest.size(), chest_spaces()]
	var who := giver_name(piece)
	if who != "":
		text += "\nFrom %s." % who
	return text


## Your biggest fish so far: {"name", "inches"}, or {} before the first.
func biggest_fish() -> Dictionary:
	var best := {}
	for id: String in Achievements.fish:
		var inches := int(Achievements.fish[id].get("biggest", 0))
		if inches > int(best.get("inches", 0)):
			var fish_name: String = FieldLog.get_animal(id).get("name", id.replace("_", " "))
			best = {"name": fish_name.to_lower(), "inches": inches}
	return best


# ------------------------------------------------------------------ the chest

## How many kinds of thing the chest holds now.
func chest_spaces() -> int:
	return CHEST_SPACES + (BEAR_BOX_SPACES if has("bear_box") else 0)


func chest_count(id: String) -> int:
	return int(chest.get(id, 0))


## True if [param id] can go in the chest: it's already there, or there's a
## free space.
func has_room_for(id: String) -> bool:
	return chest.has(id) or chest.size() < chest_spaces()


## Moves [param amount] of an item from your pack into the chest. Food takes
## its days left along with it. Returns how many went in.
func put_away(id: String, amount: int) -> int:
	amount = mini(amount, Inventory.count(id))
	if amount <= 0 or not has_room_for(id):
		return 0
	# the oldest leave the pack first (Larder works the same way)
	var days: Array = Larder.batches.get(id, []).slice(0, amount)
	Inventory.remove(id, amount)
	chest[id] = chest_count(id) + amount
	if not days.is_empty():
		var list: Array = chest_batches.get(id, [])
		list.append_array(days)
		list.sort()
		chest_batches[id] = list
	changed.emit()
	return amount


## Moves [param amount] of an item from the chest back into your pack, food
## as fresh as it was when it went in. Returns how many came out.
func take_out(id: String, amount: int) -> int:
	amount = mini(amount, chest_count(id))
	if amount <= 0:
		return 0
	chest[id] = chest_count(id) - amount
	if chest[id] <= 0:
		chest.erase(id)
	var days: Array = []
	var list: Array = chest_batches.get(id, [])
	if not list.is_empty():
		days = list.slice(0, amount)
		list = list.slice(amount)
		if list.is_empty():
			chest_batches.erase(id)
		else:
			chest_batches[id] = list
	Inventory.add(id, amount)
	if not days.is_empty():
		Larder.receive(id, days)
	changed.emit()
	return amount


## Ages the food in the chest a day, like Larder does for your pack.
func _age_food() -> void:
	last_spoiled = ""
	var spoiled := {}
	for id: String in chest_batches.keys():
		var list: Array = chest_batches[id]
		for i in list.size():
			list[i] -= 1
		while not list.is_empty() and list[0] <= 0:
			list.pop_front()
			spoiled[id] = spoiled.get(id, 0) + 1
		if list.is_empty():
			chest_batches.erase(id)
	if spoiled.is_empty():
		return
	var names := PackedStringArray()
	for id: String in spoiled:
		chest[id] = chest_count(id) - int(spoiled[id])
		if chest[id] <= 0:
			chest.erase(id)
		var item := ItemDB.get_item(id)
		names.append(ItemDB.count_name(spoiled[id], item.display_name if item else id))
	last_spoiled = "Spoiled in your camp chest: %s." % ", ".join(names)
	changed.emit()


# ------------------------------------------------------------------ the map

## Puts the camp things at the homestead (StoryContent.attach calls this for
## every region). Each one shows itself once you have it.
func dress(region: Node) -> void:
	if region.get("region_id") != REGION or region.entities.has_node(CampPiece.node_name("chest")):
		return
	for piece: Dictionary in PIECES:
		region.entities.add_child(CampPiece.make(piece))
	# the supper after the finale, laid on here while it's waiting
	region.entities.add_child(GuardianFeast.new())


func save_data() -> Dictionary:
	return {"chest": chest, "batches": chest_batches}


func load_data(data: Dictionary) -> void:
	chest = {}
	chest_batches = {}
	var saved: Dictionary = data.get("chest", {})
	for id in saved:
		if ItemDB.get_item(str(id)) and int(saved[id]) > 0:
			chest[str(id)] = int(saved[id])
	var batches: Dictionary = data.get("batches", {})
	for id in batches:
		if chest.has(str(id)):
			var list: Array = []
			for days in batches[id]:
				list.append(int(days))
			chest_batches[str(id)] = list
	changed.emit()
