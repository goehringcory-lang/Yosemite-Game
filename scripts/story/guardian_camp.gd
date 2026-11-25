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
## - The cabin (CABIN). James Lamon's old log cabin stands on the spot, empty
##   and leaky when you arrive. Keepers fix it up and furnish it as you
##   finish their quests: a patched roof and a rope bed, a porch, a stone
##   hearth and chimney, glass windows, a lean-to kitchen, a loft. Cabin
##   draws it outside, CabinRoom inside (the guardian_cabin region).
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
		"text": "Two pegs and a crossbar, lashed the Sierra Club way. Your gear bag only holds so much: hang up what today's climb doesn't need, and pack what it does."},
	{"id": "lantern", "name": "Ranger's lantern", "quest": "hodges_patrol", "from": "clare_hodges", "pos": Vector2(352, 334),
		"got": "a ranger's lantern on a post, for your camp",
		"text": "A kerosene lantern from the ranger station, on an oak post. Hodges says a camp with a light in it looks lived in, and bears agree."},
	{"id": "wall_tent", "name": "Canvas tent", "quest": "curry_starter", "from": "jennie_curry", "pos": Vector2(304, 256),
		"got": "a Camp Curry canvas tent on a wooden floor, in place of your little one",
		"text": "Camp Curry's kind of tent: white canvas walls on a plank floor, a cot, and room to stand up. Jennie Curry says the Guardian's spot deserved better than a pup tent."},
	{"id": "print", "name": "Half Dome print", "quest": "ansel_monolith", "from": "ansel_adams", "pos": Vector2(500, 266),
		"got": "a print of Half Dome from Ansel Adams, for your camp",
		"text": "Monolith, the Face of Half Dome, from 1927, on a little easel by your shelf. In the margin, in pencil: \"For the camp under the oaks.\""},
	{"id": "hill_study", "name": "Thomas Hill oil study", "quest": "hill_last_canvas", "from": "thomas_hill", "pos": Vector2(536, 266),
		"got": "a framed oil study of Bridalveil and El Capitan from Thomas Hill (+25% friendship from gifts)",
		"text": "A warm miniature oil study painted by Thomas Hill at Wawona: clearing storm clouds and gold light down Bridalveil's spray. Gifts you share across the park earn 25% more friendship."},
	{"id": "hammock", "name": "Webbing hammock", "quest": "wren_apron", "from": "wren_alvarez", "pos": Vector2(560, 334),
		"got": "a hammock woven out of old climbing webbing",
		"text": "Retired tubular webbing, woven into a hammock on an A-frame of lodgepole. Too worn to trust on a wall; perfect for an afternoon."},
	{"id": "chalk_peg", "name": "Two chalk bags", "quest": "wren_long_way", "from": "wren_alvarez", "pos": Vector2(606, 404),
		"got": "a peg by your fire with Wren's old chalk bag on it, and a hook for yours",
		"text": "A peg on an oak post with two hooks. One holds Wren's old teal chalk bag, worn white at the rim. The other is for yours. She says it lives here now, since she's over most Sundays anyway."},
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
	{"id": "field_table", "name": "Pressed-flower field table", "quest": "enid_spring_moonbow", "from": "enid_michael", "pos": Vector2(540, 266),
		"got": "a pressed-flower field table for your camp (food in your chest ages half as fast)",
		"text": "A shaded cedar sorting table with a spare plant press and spring specimens laid out to dry. Keeping your camp stores cool and sorted cuts spoilage in your camp chest in half."},
	{"id": "string_lights", "name": "Camp Curry string lights", "quest": "curry_summer_firefall", "from": "jennie_curry", "pos": Vector2(440, 344),
		"got": "a strand of Camp Curry string lights for your camp (+3 stamina at every climbing rest)",
		"text": "Warm glass bulbs strung between two lodgepole posts, just like the dining lawn at Camp Curry. A bright, restful camp leaves you fresher on the rock: every belay ledge and rest stance restores 3 extra stamina."},
	{"id": "workbench", "name": "Trail-crew workbench", "quest": "lamon_fall_meadow", "from": "james_lamon", "pos": Vector2(180, 366),
		"got": "a trail-crew workbench for your camp (+15% barter value with climbers and outfitters)",
		"text": "Seasoned Lamon oak planks bolted into a heavy camp bench, with a vise and neatly coiled cord from Wren. Climbers and outfitters pay 15% more for whatever you bring to trade."},
	{"id": "hearth_kettle", "name": "Ahwahnee hearth kettle", "quest": "ansel_winter_horsetail", "from": "ansel_adams", "pos": Vector2(474, 404),
		"got": "a copper hearth kettle for your campfire (pour a free mug of spiced wassail each morning)",
		"text": "A hammered copper kettle from the Ahwahnee kitchen, kept simmering on the coals of your fire. Step up once a day to pour a hot mug of Bracebridge Spiced Wassail for the trail."},
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

## The cabin's additions: id, name, the quest that brings it, who gives it
## (a character id), where it shows ("outside" on the cabin, "inside" in
## the room, or "both"), the reward line ("got") and what you read when you
## look at it ("text"). Inside things stand at "pos" in the room. Like
## PIECES, what you have is worked out from the quests you've finished, so
## nothing extra is saved and an old save gets its cabin when it loads.
const CABIN: Array[Dictionary] = [
	{"id": "roof_patch", "name": "Patched roof", "quest": "lamon_orchard", "from": "james_lamon", "where": "outside",
		"got": "a patched roof on Lamon's old cabin",
		"text": "Lamon's old roof, the holes stopped with a wagon sheet and battens. It won't win prizes. It keeps the rain off the bed."},
	{"id": "rope_bed", "name": "Rope bed", "quest": "lamon_orchard", "from": "james_lamon", "where": "inside", "pos": Vector2(72, 250),
		"got": "his old rope bed, so you can sleep inside",
		"text": "A pine frame strung with rope, a tick stuffed with meadow hay, and a wool blanket. Lamon slept on it his first winter in the valley, in 1859."},
	{"id": "table", "name": "Plank table", "quest": "degnan_bread", "from": "bridget_degnan", "where": "inside", "pos": Vector2(296, 250),
		"got": "a plank table and a bread box from the Degnans' kitchen",
		"text": "A scrubbed plank table with a bench, and a tin bread box that is never quite empty. Bridget Degnan says a house without a table is only a shelter."},
	{"id": "window_box", "name": "Window box", "quest": "enid_press", "from": "enid_michael", "where": "outside",
		"got": "a window box of wildflowers for your cabin",
		"text": "A cedar box under the front window, planted with shooting stars, monkeyflower and a little lupine. Enid Michael says to let them go to seed."},
	{"id": "valley_map", "name": "Valley map", "quest": "matthes_reading_ice", "from": "francois_matthes", "where": "inside", "pos": Vector2(186, 100),
		"got": "a survey map of the valley for your cabin wall",
		"text": "Matthes's own survey sheet of Yosemite Valley, every contour inked by hand, with the old glaciers' reach pencilled in blue."},
	{"id": "bookshelf", "name": "Bookshelf", "quest": "shop_guidebook", "from": "mountain_shop", "where": "inside", "pos": Vector2(64, 108),
		"got": "a bookshelf for your cabin, with a few field guides on it",
		"text": "Three planks on brackets, holding field guides, a tide of maps, and your climbing guidebook, its corners already soft."},
	{"id": "porch_chair", "name": "Porch chair", "quest": "clark_big_trees", "from": "galen_clark", "where": "outside",
		"got": "a cedar porch chair, for sitting out the evenings",
		"text": "A chair of incense cedar with a seat of woven rawhide. Galen Clark says he did his best thinking sitting still."},
	{"id": "porch", "name": "Front porch", "quest": "anderson_half_dome", "from": "george_anderson", "where": "outside",
		"got": "a front porch on your cabin, with a forged iron latch on the door",
		"text": "A plank porch across the front of the cabin, its posts drilled and pinned the way George Anderson drilled his way up Half Dome. The door latch is his iron too."},
	{"id": "hearth", "name": "Stone hearth", "quest": "mccauley_firefall", "from": "james_mccauley", "where": "both", "pos": Vector2(256, 104),
		"got": "a stone hearth and chimney for your cabin",
		"text": "A granite hearth and a chimney of river stones, laid up by James McCauley, who knew a thing or two about fire. It draws well. It keeps the cabin warm all night."},
	{"id": "glass_windows", "name": "Glass windows", "quest": "hodges_first_night", "from": "clare_hodges", "where": "both",
		"got": "real glass windows for your cabin, in place of the shutters",
		"text": "Two six-pane windows, packed in from the ranger station in a crate of straw. Ranger Hodges says a lit window is the best trail sign there is."},
	{"id": "shake_roof", "name": "Shake roof", "quest": "lamon_winter", "from": "james_lamon", "where": "outside",
		"got": "a new roof of split sugar-pine shakes, and the logs chinked tight for winter",
		"text": "Sugar pine shakes, split by hand and laid in even rows, and every gap in the walls chinked with clay and moss. The wagon sheet is retired."},
	{"id": "kitchen", "name": "Lean-to kitchen", "quest": "degnan_snowbound", "from": "bridget_degnan", "where": "both", "pos": Vector2(592, 112),
		"got": "a lean-to kitchen on your cabin, with the Degnans' old cookstove",
		"text": "A lean-to on the east wall with a cast-iron cookstove, a dry sink and a shelf of crocks. Bridget Degnan says the snowbound winter taught her where a kitchen should be: indoors."},
	{"id": "loft", "name": "Sleeping loft", "quest": "harding_summit", "from": "warren_harding", "where": "both", "pos": Vector2(452, 124),
		"got": "a sleeping loft and ladder, and a window up under the roof",
		"text": "A loft over the back of the cabin, up a ladder Warren Harding built with what he swears were leftover bolts. Up there you can see the stars through the roof window."},
	{"id": "writing_desk", "name": "Writing desk", "quest": "muir_cathedral", "from": "john_muir", "where": "inside", "pos": Vector2(436, 250),
		"got": "a writing desk by the window, from John Muir",
		"text": "A slant-top desk with an inkwell and a stack of notebooks. Muir says to write things down while they're still alive in you."},
	{"id": "mailbox", "name": "Mailbox", "quest": "kochakji_general_delivery", "from": "michael_kochakji", "where": "outside",
		"got": "a mailbox for your cabin, on a post by the path",
		"text": "A tin mailbox on a cedar post, with a red flag. Michael Kochakji painted GENERAL DELIVERY on it, then crossed it out and painted your name."},
	{"id": "prints", "name": "Framed prints", "quest": "ansel_portfolio", "from": "ansel_adams", "where": "inside", "pos": Vector2(322, 100),
		"got": "two framed prints from Ansel Adams's portfolio, for your cabin wall",
		"text": "Two silver prints in plain frames: Half Dome in winter, and an oak at dawn by your own camp. On the back of one, in pencil: \"For the cabin.\""},
	{"id": "register_stand", "name": "Register stand", "quest": "clark_guardian_year", "from": "galen_clark", "where": "both", "pos": Vector2(170, 324),
		"got": "a stand for the Register by your door, and a nameplate over it",
		"text": "An oak stand by the door with the Register open on it, and over the door outside a carved board: THE GUARDIAN. Galen Clark says the job comes with a desk now."},
]

## How many kinds of thing the camp chest holds, and how many more once the
## bear box is in.
const CHEST_SPACES := 10
const BEAR_BOX_SPACES := 6
## Extra stamina restored on belay ledges and rest stances once Camp Curry string lights are hung.
const STRING_LIGHTS_REST := 3

## The camp chest: item id -> count.
var chest: Dictionary = {}
## Food in the chest: item id -> days left for each unit, oldest first (as
## in Larder.batches).
var chest_batches: Dictionary = {}
## What spoiled in the chest last night ("" if nothing), for the morning.
var last_spoiled := ""
## Day (Friendship.today()) the Ahwahnee hearth kettle was last poured.
var kettle_day := -1
## Toggles each night while field_table is present so chest food ages every other night.
var _field_table_skip := false


func _ready() -> void:
	add_to_group("persist")
	GameClock.day_started.connect(_age_food.unbind(3))
	QuestLog.quest_completed.connect(func(_q: QuestData) -> void: changed.emit())


func start_new_game() -> void:
	chest = {}
	chest_batches = {}
	last_spoiled = ""
	kettle_day = -1
	_field_table_skip = false
	changed.emit()


func get_piece(id: String) -> Dictionary:
	for piece: Dictionary in PIECES:
		if piece.id == id:
			return piece
	for part: Dictionary in CABIN:
		if part.id == id:
			return part
	return {}


## The cabin's additions you have, in CABIN order. [param where] keeps only
## those that show "inside" or "outside" ("both" counts for either).
func cabin_parts(where := "") -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for part: Dictionary in CABIN:
		if (where == "" or part.where == where or part.where == "both") and QuestLog.is_completed(part.quest):
			out.append(part)
	return out


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
	var cabin := PackedStringArray()
	for part: Dictionary in CABIN:
		if part.quest == quest_id:
			cabin.append(part.got)
	var out := PackedStringArray()
	if not parts.is_empty():
		out.append("For your camp: %s." % "; ".join(parts))
	if not cabin.is_empty():
		out.append("For your cabin: %s." % "; ".join(cabin))
	return " ".join(out)


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
			for gear: GearData in Gear.GEAR:
				var n := 0 if gear.generic else Gear.cached_count(gear.id)
				if n > 0:
					rack.append(ItemDB.count_name(n, gear.display_name) if n > 1 else gear.display_name)
			text += " Your gear bag: %d of %d room used." % [Gear.bag_used(), Gear.bag_room()]
			if not rack.is_empty():
				text += " Hanging here: %s." % ", ".join(rack)
		"chest":
			text += " %d of %d spaces used." % [chest.size(), chest_spaces()]
		"hearth_kettle":
			text += " Fresh pot simmering." if can_pour_kettle() else " You already poured today's mug; more will simmer tomorrow."
	var who := giver_name(piece)
	if who != "":
		text += "\nFrom %s." % who
	return text


## True while the Ahwahnee hearth kettle has a fresh mug ready to pour today.
func can_pour_kettle() -> bool:
	return has("hearth_kettle") and kettle_day != Friendship.today()


## Pours one free mug of Bracebridge Spiced Wassail from the hearth kettle,
## once per day. Returns true if poured.
func pour_kettle() -> bool:
	if not can_pour_kettle():
		return false
	kettle_day = Friendship.today()
	Inventory.add("bracebridge_wassail", 1)
	changed.emit()
	return true


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
## With Enid's pressed-flower field table, food in the chest ages every other night.
func _age_food() -> void:
	last_spoiled = ""
	if has("field_table"):
		_field_table_skip = not _field_table_skip
		if _field_table_skip:
			return
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
	if region.get("region_id") == Cabin.ROOM_REGION and not region.entities.has_node("CabinRoom"):
		CabinRoom.furnish(region)
		return
	if region.get("region_id") != REGION or region.entities.has_node(CampPiece.node_name("chest")):
		return
	Cabin.build(region)
	for piece: Dictionary in PIECES:
		region.entities.add_child(CampPiece.make(piece))
	# the supper after the finale, laid on here while it's waiting
	region.entities.add_child(GuardianFeast.new())


func save_data() -> Dictionary:
	return {"chest": chest, "batches": chest_batches, "kettle_day": kettle_day, "field_table_skip": _field_table_skip}


func load_data(data: Dictionary) -> void:
	chest = {}
	chest_batches = {}
	kettle_day = int(data.get("kettle_day", -1))
	_field_table_skip = bool(data.get("field_table_skip", false))
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
