extends Node
## Tracks every quest's progress and runs conversations with quest givers.
##
## Conversations are returned as an Array of lines, each a Dictionary with
## "speaker" (a display name, or "" for a narrator line) and "text". The NPC
## hands them to a DialogueBox. Keeping the logic here makes it testable.
##
## To add a quest: create a QuestData resource in res://data/quests/ and add
## it to QUESTS below. To add a person: a CharacterData in res://data/characters/,
## added to CHARACTERS.

signal changed
signal quest_started(quest: QuestData)
signal quest_completed(quest: QuestData)
## Sent on a first ascent of a route.
signal ticked(route_id: String)

const QUESTS: Array[QuestData] = [
	preload("res://data/quests/leonard_belay.tres"),
	preload("res://data/quests/tabuce_acorns.tres"),
	preload("res://data/quests/tabuce_chuckah.tres"),
	# The full storyline (see STORY.md, "Quest chains")
	preload("res://data/quests/clark_register.tres"),
	preload("res://data/quests/shop_guidebook.tres"),
	preload("res://data/quests/shop_outfit.tres"),
	preload("res://data/quests/partner_apron.tres"),
	preload("res://data/quests/lamon_orchard.tres"),
	preload("res://data/quests/tenaya_ahwahnee.tres"),
	preload("res://data/quests/degnan_bread.tres"),
	preload("res://data/quests/curry_starter.tres"),
	preload("res://data/quests/mccauley_firefall.tres"),
	preload("res://data/quests/enid_leave_some.tres"),
	preload("res://data/quests/hodges_patrol.tres"),
	preload("res://data/quests/ansel_monolith.tres"),
	preload("res://data/quests/eichorn_apron.tres"),
	preload("res://data/quests/eichorn_spires.tres"),
	preload("res://data/quests/anderson_half_dome.tres"),
	preload("res://data/quests/robbins_clean.tres"),
	preload("res://data/quests/lucy_basket.tres"),
	preload("res://data/quests/salathe_steel.tres"),
	preload("res://data/quests/johnson_astroman.tres"),
	preload("res://data/quests/robbins_roof.tres"),
	preload("res://data/quests/harding_summit.tres"),
	preload("res://data/quests/muir_cathedral.tres"),
	preload("res://data/quests/bethel_trade.tres"),
	preload("res://data/quests/muir_glacier.tres"),
	preload("res://data/quests/lebrado_villages.tres"),
	# More side stories, one or two per chapter
	preload("res://data/quests/wren_apron.tres"),
	preload("res://data/quests/lamon_winter.tres"),
	preload("res://data/quests/robbins_eyebolt.tres"),
	preload("res://data/quests/anderson_summit.tres"),
	preload("res://data/quests/bestor_arches.tres"),
	preload("res://data/quests/johnson_solo.tres"),
	preload("res://data/quests/ansel_high_country.tres"),
	preload("res://data/quests/clark_last_page.tres"),
	# Side stories for the seasons, the hours, and the hubs past the Valley.
	# They go last so each giver's earlier quests are offered first.
	preload("res://data/quests/clark_big_trees.tres"),
	preload("res://data/quests/enid_dawn_chorus.tres"),
	preload("res://data/quests/hodges_bear_season.tres"),
	preload("res://data/quests/degnan_snowbound.tres"),
	preload("res://data/quests/muir_soda_springs.tres"),
	preload("res://data/quests/ahwahnee_chef_larder.tres"),
	preload("res://data/quests/wren_slackline.tres"),
	preload("res://data/quests/wren_lightning.tres"),
	preload("res://data/quests/greg_first_rod.tres"),
	# The first night out, and Half Dome from the back (Backcountry).
	preload("res://data/quests/hodges_first_night.tres"),
	preload("res://data/quests/anderson_cables.tres"),
	preload("res://data/quests/ansel_diving_board.tres"),
	# The press book (QuestData.press_line): plants for the naturalists and
	# rangers, beside the tick list. See Herbarium.
	preload("res://data/quests/enid_press.tres"),
	preload("res://data/quests/hodges_herbarium.tres"),
	preload("res://data/quests/hodges_canyon.tres"),
	preload("res://data/quests/clark_grove_sprigs.tres"),
	preload("res://data/quests/enid_rim.tres"),
	preload("res://data/quests/muir_cassiope.tres"),
	preload("res://data/quests/enid_full_press.tres"),
	# Search and rescue from Camp 4 (Rescues). After the press book, so
	# Hodges offers her press quests before this one.
	preload("res://data/quests/hodges_rescue_team.tres"),
	preload("res://data/quests/jo_first_call.tres"),
	# The finale: it needs the last page written and the press book full.
	preload("res://data/quests/lost_guardian.tres"),
	# The Guardian's Year (QuestData.guardian_line): after the finale, one arc
	# of stewardship a season, each leaving the map changed. See Stewardship.
	preload("res://data/quests/anderson_mist_steps.tres"),
	preload("res://data/quests/enid_cooks_meadow.tres"),
	preload("res://data/quests/clark_grove_fire.tres"),
	preload("res://data/quests/hodges_bear_boxes.tres"),
	preload("res://data/quests/clark_guardian_year.tres"),
]

const CHARACTERS: Array[CharacterData] = [
	preload("res://data/characters/dick_leonard.tres"),
	preload("res://data/characters/maggie_howard.tres"),
	preload("res://data/characters/galen_clark.tres"),
	preload("res://data/characters/james_lamon.tres"),
	preload("res://data/characters/tenaya.tres"),
	preload("res://data/characters/bridget_degnan.tres"),
	preload("res://data/characters/jules_eichorn.tres"),
	preload("res://data/characters/bestor_robinson.tres"),
	preload("res://data/characters/jennie_curry.tres"),
	preload("res://data/characters/james_mccauley.tres"),
	preload("res://data/characters/enid_michael.tres"),
	preload("res://data/characters/clare_hodges.tres"),
	preload("res://data/characters/ansel_adams.tres"),
	preload("res://data/characters/lucy_telles.tres"),
	preload("res://data/characters/maria_lebrado.tres"),
	preload("res://data/characters/george_anderson.tres"),
	preload("res://data/characters/royal_robbins.tres"),
	preload("res://data/characters/john_salathe.tres"),
	preload("res://data/characters/warren_harding.tres"),
	preload("res://data/characters/beverly_johnson.tres"),
	preload("res://data/characters/john_muir.tres"),
	preload("res://data/characters/carrie_bethel.tres"),
]

## Invented staff (CharacterData.staff): the Mountain Shop's two, the
## Ahwahnee's head chef, Greg, Curry Village's fishing guide, and Jo
## Tolliver, who runs the Camp 4 rescue site (Rescues). They give
## quests (and Wren partners on climbs, and Greg trades flies), but
## they aren't in the Register's cast above. The clerk's id is the shop's
## talk_target, so talking at the counter reaches them.
const STAFF: Array[CharacterData] = [
	preload("res://data/characters/staff/mountain_shop_clerk.tres"),
	preload("res://data/characters/staff/wren_alvarez.tres"),
	preload("res://data/characters/staff/ahwahnee_chef.tres"),
	preload("res://data/characters/staff/greg.tres"),
	preload("res://data/characters/staff/jo_tolliver.tres"),
]

## What the player can write on the Register's last page, after The Last Page.
## "choice" is the menu option, "entry" what goes in the book, "reply" Clark's
## answer.
const LAST_PAGE_QUEST := "clark_last_page"
## The finale, which Clark offers once the last page is written and the press
## book is full (see GuardianMirror for how it ends).
const FINALE_QUEST := "lost_guardian"
## Set when the player looks in the mirror in the Guardian's cave.
const GUARDIAN_FOUND := "guardian_found"
const FINAL_ENTRIES: Array[Dictionary] = [
	{"choice": "Write down every voice you heard",
		"entry": "Many people looked after this valley, and they didn't all agree. I wrote down what they told me.",
		"reply": "Many hands, and not one of them mine alone. Good."},
	{"choice": "Write a thank-you",
		"entry": "Thank you to everyone who shared a story, and to everyone who chose not to.",
		"reply": "Saying thanks is a fine way to end a book. Most of mine forgot to."},
	{"choice": "List the climbs, route by route",
		"entry": "Firefall Slab to the Lyell Glacier. Every pitch was somebody's gift: a rope, a rack, a meal, a story.",
		"reply": "A tick list. Ha. Muir would call it a hymn."},
	{"choice": "Leave it blank",
		"entry": "",
		"reply": "Another blank page. Some things are better kept than written."},
]

## What Galen Clark says as he hands the finished Register back.
const EPILOGUE := [
	"When the State gave me this job, I thought a guardian was a man who stood at the gate and kept count. I was wrong about that, as about a good many things.",
	"Keep the book with you. And when you read it, start at the front.",
]

## The line after the last page: the Register is done, the mystery isn't.
const AFTER_EPILOGUE := "The Guardian's Register is finished, with your page at the back. But the valley's Guardian is still missing, and the press book's old labels still say \"Collected for the Guardian of Yosemite.\""

## What Galen Clark says once the Register is finished.
const AFTER_LAST_PAGE := [
	"The book's yours now. I read it some evenings, the parts that aren't mine especially.",
	"The valley keeps going. So should you: there's always someone new on the trail with a story.",
]

## What he says once the lost Guardian is found.
const AFTER_FINALE := [
	"Guardian. It suits you better than it ever suited me.",
	"The valley keeps going. So should you: there's work in every season, and someone in each one who could use your hands.",
]
## The Guardian's Year ends with Clark's quest of that name.
const GUARDIAN_YEAR_QUEST := "clark_guardian_year"

## Quest id -> index of the current step. Missing = not started.
var active: Dictionary = {}
var completed: Array[String] = []
var climbed: Array[String] = []
var unlocks: Array[String] = []
## Index into FINAL_ENTRIES once the player has written the last page, or -1.
var final_entry := -1
## Story beats already heard, as "<character id>:<quest id>" (see
## CharacterData.story_beats).
var heard_beats: Array[String] = []

var _quests_by_id: Dictionary = {}
var _characters_by_id: Dictionary = {}


func _ready() -> void:
	add_to_group("persist")
	for quest: QuestData in QUESTS:
		_quests_by_id[quest.id] = quest
	for character: CharacterData in CHARACTERS + STAFF:
		_characters_by_id[character.id] = character


func start_new_game() -> void:
	active = {}
	completed = []
	climbed = []
	unlocks = []
	final_entry = -1
	heard_beats = []
	changed.emit()


func get_quest(id: String) -> QuestData:
	return _quests_by_id.get(id)


func get_character(id: String) -> CharacterData:
	return _characters_by_id.get(id)


func is_completed(quest_id: String) -> bool:
	return quest_id in completed


func is_unlocked(ability: String) -> bool:
	return ability in unlocks


func has_climbed(route_id: String) -> bool:
	return route_id in climbed


## Ticks a route in the guidebook. Returns true the first time.
func record_climb(route_id: String) -> bool:
	if has_climbed(route_id):
		return false
	climbed.append(route_id)
	changed.emit()
	ticked.emit(route_id)
	return true


## What to tell the player right after a first ascent: the tick, and which
## quests that climb finished (their givers hand over the reward when you
## talk to them).
func tick_report(route_id: String) -> Array[Dictionary]:
	var lines: Array[Dictionary] = []
	var route_name := route_id.capitalize()
	for route in Guidebook.routes():
		if route.id == route_id:
			route_name = route.display_name
	var grade := ""
	var hardest := Guidebook.hardest_tick()
	for route in Guidebook.routes():
		if route.id == route_id:
			grade = " (%s)" % (Guidebook.yds_label(route.grade) if Guidebook.yds(route.grade) > 0.0 else route.grade)
			if hardest == route and Guidebook.yds(route.grade) > 0.0:
				grade += ", your hardest grade yet,"
	lines.append({"speaker": "", "text": "Ticked! %s%s goes in your tick list (%d of %d routes in the guidebook)." % [
		route_name, grade, Guidebook.ticked_count(), Guidebook.routes().size()]})
	for quest: QuestData in QUESTS:
		var step := current_step(quest)
		if step.get("type") == "climbed" and step.route == route_id and quest.steps.back() == step:
			var giver := get_character(quest.giver)
			lines.append({"speaker": "", "text": "%s is waiting to hear about it. Tell %s how it went to finish \"%s\"." % [
				giver.display_name if giver else quest.giver, giver.display_name if giver else "them", quest.title]})
	return lines


func has_guidebook() -> bool:
	return is_unlocked(Guidebook.ABILITY)


## The current step of the main storyline: {"quest", "objective"}, or {}.
func main_objective() -> Dictionary:
	for quest: QuestData in QUESTS:
		if quest.main_line and active.has(quest.id):
			return {"quest": quest, "objective": objective_text(quest)}
	# Between quests: point at the next person on the main line.
	for quest: QuestData in QUESTS:
		if not quest.main_line or is_completed(quest.id):
			continue
		if quest.id == FINALE_QUEST and final_entry < 0:
			continue # write the last page first
		var unmet := Array(quest.requires).filter(func(r: String) -> bool: return not is_completed(r))
		if not unmet.is_empty() and unmet.all(func(r: String) -> bool: return not get_quest(r).main_line):
			var titles := PackedStringArray()
			for r: String in unmet:
				# Name the quest the player can act on now, not one that is
				# itself waiting on another (Maria Lebrado waits on Tenaya).
				var side := _first_open(get_quest(r))
				var side_giver := get_character(side.giver)
				var title := "%s from %s" % [side.title, side_giver.display_name if side_giver else side.giver]
				if side.id == "tabuce_acorns" and not active.has(side.id) and GameClock.season != GameClock.Season.FALL:
					title += " (the oaks drop acorns in fall)"
				titles.append(title)
			if quest.id == LAST_PAGE_QUEST:
				return {"quest": quest, "objective": "Before the last page, hear everyone out: %s" % ", ".join(titles)}
			if quest.id == FINALE_QUEST:
				return {"quest": quest, "objective": "One Guardian is still missing. Fill the press book: %s" % ", ".join(titles)}
			var next_giver := get_character(quest.giver)
			return {"quest": quest, "objective": "Before %s will take you on, finish %s" % [
				next_giver.display_name if next_giver else quest.giver, ", ".join(titles)]}
		if unmet.is_empty():
			var objective := "Talk to %s" % _who_and_where(quest.giver)
			# Muir waits up in Tuolumne, and the Tioga Road shuts for winter.
			if quest.id == "muir_cathedral" and not Park.is_open("tioga_road"):
				objective += ". The Tioga Road is closed for winter. It reopens in early summer."
			return {"quest": quest, "objective": objective}
	return {}


## The press book's next step, shown beside the main story: {"quest",
## "objective"}, or {} before the press and once the book's quests are done.
func press_objective() -> Dictionary:
	for quest: QuestData in QUESTS:
		if quest.press_line and active.has(quest.id):
			return {"quest": quest, "objective": objective_text(quest)}
	for quest: QuestData in QUESTS:
		if not quest.press_line or is_completed(quest.id):
			continue
		var unmet := Array(quest.requires).filter(func(r: String) -> bool: return not is_completed(r))
		if unmet.is_empty():
			return {"quest": quest, "objective": "Talk to %s" % _who_and_where(quest.giver)}
		# Waiting on the tick list (a road or a mentor further up the ladder).
		if unmet.all(func(r: String) -> bool: return not get_quest(r).press_line):
			var gate := _first_open(get_quest(unmet[0]))
			return {"quest": quest, "objective": "%s has plants to ask for once you've finished %s" % [
				_who_and_where(quest.giver), gate.title]}
	return {}


## The Guardian's Year's next step, once the lost Guardian is found:
## {"quest", "objective"}, or {} before the finale and once the year's done.
## Between arcs it names the next season's work and who has it.
func guardian_objective() -> Dictionary:
	if not is_completed(FINALE_QUEST):
		return {}
	for quest: QuestData in QUESTS:
		if quest.guardian_line and active.has(quest.id):
			return {"quest": quest, "objective": objective_text(quest)}
	var next: QuestData = null
	var wait := 99
	for quest: QuestData in QUESTS:
		if not quest.guardian_line or is_completed(quest.id) or not Array(quest.requires).all(is_completed):
			continue
		var seasons := _seasons_until(quest)
		if seasons < wait:
			next = quest
			wait = seasons
	if next == null:
		return {}
	if wait == 0:
		return {"quest": next, "objective": "Talk to %s" % _who_and_where(next.giver)}
	var season: String = GameClock.SEASON_NAMES[(GameClock.season + wait) % 4]
	return {"quest": next, "objective": "Come %s, %s has work for you" % [season.to_lower(), _who_and_where(next.giver)]}


## Seasons until [param quest] is offered: 0 if it is now, or 99 if never.
func _seasons_until(quest: QuestData) -> int:
	for wait in 4:
		if quest.is_offered_in((GameClock.season + wait) % 4):
			return wait
	return 99


## "Enid Michael (Museum garden)": a person and where they are now.
func _who_and_where(character_id: String) -> String:
	var character := get_character(character_id)
	if character == null:
		return character_id
	var home := character.home_now(is_completed)
	return "%s (%s)" % [character.display_name, home] if home != "" else character.display_name


## The first quest in [param quest]'s chain of requirements that the player
## hasn't finished, which is the one they can start or are already doing.
func _first_open(quest: QuestData) -> QuestData:
	for r: String in quest.requires:
		if not is_completed(r):
			return _first_open(get_quest(r))
	return quest


## True once The Last Page is done and the player hasn't written their entry.
func final_entry_pending() -> bool:
	return is_completed(LAST_PAGE_QUEST) and final_entry < 0


## Writes the player's last page (an index into FINAL_ENTRIES) and returns
## the epilogue lines. The game carries on afterwards: the season turns.
func write_final_entry(index: int) -> Array[Dictionary]:
	var lines: Array[Dictionary] = []
	if not final_entry_pending() or index < 0 or index >= FINAL_ENTRIES.size():
		return lines
	final_entry = index
	var choice: Dictionary = FINAL_ENTRIES[index]
	var clark := get_character("galen_clark")
	if choice.entry != "":
		lines.append({"speaker": "", "text": "You write: \"%s\"" % choice.entry})
	else:
		lines.append({"speaker": "", "text": "You close the book and leave the last page blank."})
	var clark_name := clark.display_name if clark else "Galen Clark"
	lines.append({"speaker": clark_name, "text": choice.reply})
	# Clark leafs back through what the player gathered.
	var pages := RegisterPages.written()
	var hands := {}
	for page: Dictionary in pages:
		hands[page.by] = true
	var leafing := "Clark turns back through the book: %d pages, in %d hands." % [pages.size(), hands.size()]
	if not pages.is_empty() and pages[0].by == "Tenaya":
		leafing += " Tenaya's page is still at the front, where Clark put it."
	lines.append({"speaker": "", "text": leafing})
	_add_lines(lines, clark_name, EPILOGUE)
	lines.append({"speaker": "", "text": "The season turns. Looking after the valley doesn't end, and it was never one person's job."})
	lines.append({"speaker": "", "text": AFTER_EPILOGUE})
	changed.emit()
	return lines


## Called when the player looks in the mirror in the Guardian's cave: marks
## the Guardian found and finishes the finale there and then, with Clark
## speaking (he's standing behind you). Returns his lines, the Register page
## and the reward; [] unless the finale is under way.
func find_guardian() -> Array[Dictionary]:
	var lines: Array[Dictionary] = []
	var quest := get_quest(FINALE_QUEST)
	if not active.has(FINALE_QUEST) or current_step(quest).get("ability") != GUARDIAN_FOUND:
		return lines
	if not is_unlocked(GUARDIAN_FOUND):
		unlocks.append(GUARDIAN_FOUND)
	var clark := get_character(quest.giver)
	_add_lines(lines, clark.display_name if clark else quest.giver, current_step(quest).get("done", []))
	_advance(quest, lines)
	return lines


## The next quest this person would offer, or null.
func available_from(character_id: String) -> QuestData:
	for quest: QuestData in QUESTS:
		if quest.giver != character_id or active.has(quest.id) or is_completed(quest.id):
			continue
		if quest.id == FINALE_QUEST and final_entry < 0:
			continue # Clark hands you the last page to write first
		if Array(quest.requires).all(is_completed) and quest.is_offered_in(GameClock.season):
			return quest
	return null


## What to show over this person's head: "!" when they have a new quest for
## you or a quest has sent you to them, "?" when you can finish a quest of
## theirs by talking to them, and "" otherwise.
func marker_for(character_id: String) -> String:
	for quest: QuestData in QUESTS:
		if not active.has(quest.id):
			continue
		var step := current_step(quest)
		if step.get("type") == "talk" and step.get("target") == character_id:
			return "!"
		if quest.giver == character_id and step.get("type") != "talk" and is_step_done(step):
			return "?"
	return "!" if available_from(character_id) else ""


## A quest this person would offer if it were the right season, or null.
func waiting_for_season(character_id: String) -> QuestData:
	for quest: QuestData in QUESTS:
		if quest.giver != character_id or active.has(quest.id) or is_completed(quest.id):
			continue
		if Array(quest.requires).all(is_completed) and not quest.is_offered_in(GameClock.season):
			return quest
	return null


## What this person says about a quest of theirs that's waiting on a side
## story (QuestData.waiting_on), or "". Only once the main line has caught up,
## so nobody nags about it early.
func waiting_hint(character_id: String) -> String:
	for quest: QuestData in QUESTS:
		if quest.giver != character_id or quest.waiting_on.is_empty() or active.has(quest.id) or is_completed(quest.id):
			continue
		var main_done := Array(quest.requires).all(func(id: String) -> bool:
			return is_completed(id) or not get_quest(id).main_line)
		if not main_done:
			continue
		for id: String in quest.waiting_on:
			if not is_completed(id):
				return quest.waiting_on[id]
	return ""


func current_step(quest: QuestData) -> Dictionary:
	if not active.has(quest.id):
		return {}
	return quest.steps[active[quest.id]]


func is_step_done(step: Dictionary) -> bool:
	match step.get("type", ""):
		"have":
			return Inventory.count(step.item) >= int(step.get("count", 1))
		"have_food":
			return FoodDB.carried_energy() >= int(step.energy)
		"pay":
			return Barter.can_afford(int(step.energy))
		"chuckah":
			return Granary.chuckahs_built >= int(step.get("count", 1))
		"stored":
			return Granary.acorns >= int(step.count)
		"made":
			return Recipes.times_made.get(step.recipe, 0) >= int(step.get("count", 1))
		"climbed":
			return has_climbed(step.route)
		"talk":
			return false # only finished by talking to the target
		"return":
			return true # finished as soon as you talk to the giver again
		"time":
			return GameClock.hour_in_range(int(step.from), int(step.to))
		"pressed":
			return Herbarium.has_all(step.get("plants", [])) and Herbarium.count(step.get("hub", "")) >= int(step.get("count", 0))
		"unlocked":
			return is_unlocked(step.ability)
		"work":
			return Stewardship.count(step.task) >= int(step.get("count", 1))
	push_error("Unknown quest step type: %s" % step.get("type", ""))
	return false


## One line per active quest, for the quest list: "Title: objective".
func objectives() -> PackedStringArray:
	var result := PackedStringArray()
	for quest: QuestData in QUESTS:
		if active.has(quest.id):
			result.append("%s%s: %s" % ["* " if quest.main_line or quest.press_line else "", quest.title, objective_text(quest)])
	return result


## The quest's current objective. A climb that's already ticked says who to
## tell, since the quest finishes when you report it.
func objective_text(quest: QuestData) -> String:
	var step := current_step(quest)
	if step.get("type") == "climbed" and is_step_done(step):
		var giver := get_character(quest.giver)
		return "Ticked! Tell %s" % (giver.display_name if giver else quest.giver)
	if step.get("type") == "pressed":
		return step.get("objective", "") + _pressed_progress(step)
	if step.get("type") == "work":
		# a run of work steps goes on to the next one without a talk between
		var work := Stewardship.next_work_step(quest)
		if work.is_empty():
			var giver := get_character(quest.giver)
			return "All done. Tell %s" % (giver.display_name if giver else quest.giver)
		return "%s (%d of %d done)" % [work.get("objective", ""), Stewardship.count(work.task), int(work.get("count", 1))]
	return step.get("objective", "")


## " (2 of 3 pressed)" for a press-book step, or " Show <giver>" once it's done.
func _pressed_progress(step: Dictionary) -> String:
	if is_step_done(step):
		return " (all pressed)"
	var parts := PackedStringArray()
	var plants: Array = step.get("plants", [])
	if not plants.is_empty():
		var missing := PackedStringArray()
		for id: String in plants:
			if not Herbarium.has(id):
				missing.append(Herbarium.get_plant(id).get("name", id))
		if not missing.is_empty():
			parts.append("still to find: %s" % ", ".join(missing))
	var need := int(step.get("count", 0))
	var got := Herbarium.count(step.get("hub", ""))
	if need > 0 and got < need:
		parts.append("%d of %d pressed" % [got, need])
	return " (%s)" % "; ".join(parts) if not parts.is_empty() else ""


## Runs a conversation with [param character_id], updating quests along the
## way, and returns the lines to show.
func talk_to(character_id: String, speaker_name := "") -> Array[Dictionary]:
	var character := get_character(character_id)
	var speaker := speaker_name if speaker_name != "" else (character.display_name if character else character_id)
	var lines: Array[Dictionary] = []

	# Someone else's quest sent the player here.
	for quest: QuestData in QUESTS:
		var step := current_step(quest)
		if step.get("type") == "talk" and step.get("target") == character_id:
			_add_lines(lines, speaker, step.get("done", []))
			_advance(quest, lines)

	# This person's own quests, in progress. Someone can carry a side story
	# and a main-line quest at the same time.
	var had_own := false
	var finished_now := false
	for quest: QuestData in QUESTS:
		if quest.giver != character_id or not active.has(quest.id):
			continue
		# A press-book quest takes days of walking, so it doesn't hold up
		# the giver's other stories.
		had_own = had_own or not quest.press_line
		var progressed := false
		while active.has(quest.id):
			var step := current_step(quest)
			if step.get("type") == "talk" or not is_step_done(step):
				break
			if step.get("type") == "have" and step.get("consume", false):
				Inventory.remove(step.item, int(step.get("count", 1)))
			if step.get("type") == "pay":
				var paid := Barter.pay(int(step.energy))
				lines.append({"speaker": "", "text": "You hand over %s." % Barter.describe(paid)})
			_add_lines(lines, speaker, step.get("done", []))
			_advance(quest, lines)
			progressed = true
		finished_now = finished_now or not active.has(quest.id)
		if not progressed and active.has(quest.id):
			_add_lines(lines, speaker, [current_step(quest).get("reminder", "")])

	# A new quest from this person, next time you talk. A side story in
	# progress never holds up the main line, but otherwise one at a time.
	var offer := available_from(character_id)
	if finished_now or (had_own and not (offer and (offer.main_line or offer.press_line))):
		return lines
	if offer:
		_add_lines(lines, speaker, offer.intro)
		active[offer.id] = 0
		for ability: String in offer.start_unlocks:
			if not is_unlocked(ability):
				unlocks.append(ability)
				var got := "Received the %s." % ability.replace("_", " ")
				if ability == Herbarium.ABILITY:
					got += " The press book is in your journal (P). Walk up to a plant to press a sprig."
				lines.append({"speaker": "", "text": got})
		lines.append({"speaker": "", "text": "New quest: %s. %s" % [offer.title, current_step(offer).get("objective", "")]})
		quest_started.emit(offer)
		changed.emit()
		return lines

	# A quest that's ready but for the season: say when to come back.
	var seasonal: QuestData = waiting_for_season(character_id) if lines.is_empty() else null
	# After the last page, Clark talks about the book you wrote, not the job.
	if lines.is_empty() and character_id == "galen_clark" and final_entry >= 0:
		_add_lines(lines, speaker, AFTER_FINALE if is_completed(FINALE_QUEST) else AFTER_LAST_PAGE)
	elif seasonal and not seasonal.out_of_season.is_empty():
		_add_lines(lines, speaker, seasonal.out_of_season)
	elif lines.is_empty() and character:
		# News of the main line first, once; then their usual lines.
		var beat := character.latest_beat(is_completed)
		if not beat.is_empty() and not beat.key in heard_beats:
			heard_beats.append(beat.key)
			_add_lines(lines, speaker, beat.lines)
			return lines
		# A quest held up by a side story: say who to go and see.
		var waiting := waiting_hint(character_id)
		if waiting != "":
			_add_lines(lines, speaker, [waiting])
			return lines
		_add_lines(lines, speaker, character.idle_lines_for(character.rare_after_quest == "" or is_completed(character.rare_after_quest)))
	return lines


func _advance(quest: QuestData, lines: Array[Dictionary]) -> void:
	var finished: Dictionary = quest.steps[active[quest.id]]
	var gift := _give_step_rewards(finished)
	if gift != "":
		lines.append({"speaker": "", "text": gift})
	var next: int = active[quest.id] + 1
	if next < quest.steps.size():
		active[quest.id] = next
		lines.append({"speaker": "", "text": "Next: %s" % quest.steps[next].get("objective", "")})
		changed.emit()
		return
	active.erase(quest.id)
	completed.append(quest.id)
	var giver := get_character(quest.giver)
	_add_lines(lines, giver.display_name if giver else quest.giver, quest.outro)
	# The story goes in the Register, with its note on what's history.
	lines.append_array(RegisterPages.on_completed(quest.id))
	lines.append({"speaker": "", "text": _give_rewards(quest)})
	quest_completed.emit(quest)
	changed.emit()


## Gifts a step hands over when it's done ("unlock", "gear", "items").
## Returns a line describing them, or "".
func _give_step_rewards(step: Dictionary) -> String:
	var got := PackedStringArray()
	var ability: String = step.get("unlock", "")
	if ability != "" and not is_unlocked(ability):
		unlocks.append(ability)
		got.append("the %s" % ability.replace("_", " "))
	var gear: Dictionary = step.get("gear", {})
	for id: String in gear:
		var amount := int(gear[id])
		Gear.add(id, amount)
		var gear_name := Gear.get_gear(id).display_name
		got.append(gear_name if amount == 1 else ItemDB.count_name(amount, gear_name))
	var items: Dictionary = step.get("items", {})
	for id: String in items:
		Inventory.add(id, int(items[id]))
		var item := ItemDB.get_item(id)
		got.append(ItemDB.count_name(int(items[id]), item.display_name if item else id))
	return "Received %s." % ", ".join(got) if not got.is_empty() else ""


## Hands out the rewards and returns a "Quest complete" line describing them.
func _give_rewards(quest: QuestData) -> String:
	var got := PackedStringArray()
	for id: String in quest.reward_gear:
		var amount := int(quest.reward_gear[id])
		Gear.add(id, amount)
		var name := Gear.get_gear(id).display_name
		got.append(name if amount == 1 else ItemDB.count_name(amount, name))
	for id: String in quest.reward_items:
		var amount := int(quest.reward_items[id])
		Inventory.add(id, amount)
		var item := ItemDB.get_item(id)
		got.append(ItemDB.count_name(amount, item.display_name if item else id))
	for id: String in quest.reward_recipes:
		Recipes.learn(id)
		got.append("recipe: %s" % Recipes.get_recipe(id).display_name)
	for ability: String in quest.reward_unlocks:
		if not is_unlocked(ability):
			unlocks.append(ability)
		# "hub:<id>" opens a locked part of the park, like a road to the high country.
		if ability.begins_with("hub:"):
			var hub_id := ability.trim_prefix("hub:")
			Park.unlock_hub(hub_id)
			got.append("the way to %s" % Park.get_hub(hub_id).display_name)
	var text := "Quest complete: %s!" % quest.title
	if not got.is_empty():
		text += " Received %s." % ", ".join(got)
	return text


func _add_lines(lines: Array[Dictionary], speaker: String, texts) -> void:
	for text: String in texts:
		if text != "":
			lines.append({"speaker": speaker, "text": text})


func save_data() -> Dictionary:
	return {"active": active, "completed": completed, "climbed": climbed, "unlocks": unlocks, "final_entry": final_entry, "heard_beats": heard_beats}


func load_data(data: Dictionary) -> void:
	active = {}
	var saved: Dictionary = data.get("active", {})
	for id in saved:
		active[str(id)] = int(saved[id])
	completed.assign(data.get("completed", []))
	climbed.assign(data.get("climbed", []))
	unlocks.assign(data.get("unlocks", []))
	final_entry = int(data.get("final_entry", -1))
	heard_beats.assign(data.get("heard_beats", []))
	changed.emit()
