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

const QUESTS: Array[QuestData] = [
	preload("res://data/quests/leonard_belay.tres"),
	preload("res://data/quests/tabuce_acorns.tres"),
	preload("res://data/quests/tabuce_chuckah.tres"),
	# The full storyline (see STORY.md, "Quest chains")
	preload("res://data/quests/clark_register.tres"),
	preload("res://data/quests/lamon_orchard.tres"),
	preload("res://data/quests/tenaya_ahwahnee.tres"),
	preload("res://data/quests/degnan_bread.tres"),
	preload("res://data/quests/curry_starter.tres"),
	preload("res://data/quests/mccauley_firefall.tres"),
	preload("res://data/quests/enid_leave_some.tres"),
	preload("res://data/quests/hodges_patrol.tres"),
	preload("res://data/quests/ansel_monolith.tres"),
	preload("res://data/quests/eichorn_spires.tres"),
	preload("res://data/quests/anderson_half_dome.tres"),
	preload("res://data/quests/robbins_clean.tres"),
	preload("res://data/quests/lucy_basket.tres"),
	preload("res://data/quests/salathe_steel.tres"),
	preload("res://data/quests/harding_nose.tres"),
	preload("res://data/quests/johnson_solo.tres"),
	preload("res://data/quests/harding_summit.tres"),
	preload("res://data/quests/muir_cathedral.tres"),
	preload("res://data/quests/bethel_trade.tres"),
	preload("res://data/quests/muir_glacier.tres"),
	preload("res://data/quests/lebrado_villages.tres"),
	preload("res://data/quests/clark_last_page.tres"),
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

## Quest id -> index of the current step. Missing = not started.
var active: Dictionary = {}
var completed: Array[String] = []
var climbed: Array[String] = []
var unlocks: Array[String] = []

var _quests_by_id: Dictionary = {}
var _characters_by_id: Dictionary = {}


func _ready() -> void:
	add_to_group("persist")
	for quest: QuestData in QUESTS:
		_quests_by_id[quest.id] = quest
	for character: CharacterData in CHARACTERS:
		_characters_by_id[character.id] = character


func start_new_game() -> void:
	active = {}
	completed = []
	climbed = []
	unlocks = []
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


func record_climb(route_id: String) -> void:
	if not has_climbed(route_id):
		climbed.append(route_id)
		changed.emit()


## The next quest this person would offer, or null.
func available_from(character_id: String) -> QuestData:
	for quest: QuestData in QUESTS:
		if quest.giver != character_id or active.has(quest.id) or is_completed(quest.id):
			continue
		if Array(quest.requires).all(is_completed):
			return quest
	return null


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
	push_error("Unknown quest step type: %s" % step.get("type", ""))
	return false


## One line per active quest, for the quest list: "Title: objective".
func objectives() -> PackedStringArray:
	var result := PackedStringArray()
	for quest: QuestData in QUESTS:
		if active.has(quest.id):
			result.append("%s: %s" % [quest.title, current_step(quest).get("objective", "")])
	return result


## Runs a conversation with [param character_id], updating quests along the
## way, and returns the lines to show.
func talk_to(character_id: String) -> Array[Dictionary]:
	var character := get_character(character_id)
	var speaker := character.display_name if character else character_id
	var lines: Array[Dictionary] = []

	# Someone else's quest sent the player here.
	for quest: QuestData in QUESTS:
		var step := current_step(quest)
		if step.get("type") == "talk" and step.get("target") == character_id:
			_add_lines(lines, speaker, step.get("done", []))
			_advance(quest, lines)

	# This person's own quest, in progress.
	for quest: QuestData in QUESTS:
		if quest.giver != character_id or not active.has(quest.id):
			continue
		var progressed := false
		while active.has(quest.id):
			var step := current_step(quest)
			if step.get("type") == "talk" or not is_step_done(step):
				break
			if step.get("type") == "have" and step.get("consume", false):
				Inventory.remove(step.item, int(step.get("count", 1)))
			_add_lines(lines, speaker, step.get("done", []))
			_advance(quest, lines)
			progressed = true
		if not progressed and active.has(quest.id):
			_add_lines(lines, speaker, [current_step(quest).get("reminder", "")])
		return lines

	# A new quest from this person.
	var offer := available_from(character_id)
	if offer:
		_add_lines(lines, speaker, offer.intro)
		active[offer.id] = 0
		lines.append({"speaker": "", "text": "New quest: %s. %s" % [offer.title, current_step(offer).get("objective", "")]})
		quest_started.emit(offer)
		changed.emit()
		return lines

	if lines.is_empty() and character:
		_add_lines(lines, speaker, character.idle_lines)
	return lines


func _advance(quest: QuestData, lines: Array[Dictionary]) -> void:
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
	lines.append({"speaker": "", "text": _give_rewards(quest)})
	quest_completed.emit(quest)
	changed.emit()


## Hands out the rewards and returns a "Quest complete" line describing them.
func _give_rewards(quest: QuestData) -> String:
	var got := PackedStringArray()
	for id: String in quest.reward_gear:
		var amount := int(quest.reward_gear[id])
		Gear.add(id, amount)
		var name := Gear.get_gear(id).display_name
		got.append(name if amount == 1 else "%d %ss" % [amount, name])
	for id: String in quest.reward_items:
		var amount := int(quest.reward_items[id])
		Inventory.add(id, amount)
		var item := ItemDB.get_item(id)
		got.append("%d %s" % [amount, item.display_name if item else id])
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
	return {"active": active, "completed": completed, "climbed": climbed, "unlocks": unlocks}


func load_data(data: Dictionary) -> void:
	active = {}
	var saved: Dictionary = data.get("active", {})
	for id in saved:
		active[str(id)] = int(saved[id])
	completed.assign(data.get("completed", []))
	climbed.assign(data.get("climbed", []))
	unlocks.assign(data.get("unlocks", []))
	changed.emit()
