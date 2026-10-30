class_name GuardianMirror
extends StaticBody2D
## The looking-glass at the back of the Guardian's cave, where the story
## ends. The press's old sheets were labeled "Collected for the Guardian of
## Yosemite"; the last one holds this mirror. Look in it during The Lost
## Guardian and everyone in the Register is standing behind you, and every
## sighting of the missing Guardian (GuardianSearch) turns out to be yours.
##
## Nothing here is magic (STORY.md): it's a mirror someone hung on a rock,
## and people who walked up the talus after you.

const NPC_SCENE := preload("res://scenes/story/npc.tscn")
## What the player sees, before turning round.
const LOOKING := [
	"A tin box sits open on a ledge of rock, in the light that comes down a chimney in the roof. In it is the last sheet from the press. Its label reads: \"The Guardian of Yosemite.\"",
	"There's no plant on it, and no outline of one. Where the specimen should be the sheet is cut away, and behind it, hung on the rock, is a small looking-glass.",
	"You lean in to read the collector's line. Your own face looks back at you, with pine needles in your hair and the press under your arm.",
	"Collected for the Guardian of Yosemite. Every label, the whole time.",
	"The speck on the Apron at sunrise. The climber who left no scratch on Nutcracker. The figure in Ansel Adams's negative, the headlamp on the Nose, the climber on the Lyell ice. Every sighting, the whole time.",
	"Sand shifts behind you. You turn around.",
	"They're all here. Everyone with a page in the Register is standing in the sand of the cave floor, as if they'd been walking up the talus behind you the whole way.",
]
## What they say, in order: [character id, line]. An empty id is the narrator.
const GATHERING := [
	["galen_clark", "It was you. It was you all along."],
	["james_lamon", "Pitched your tent in the Guardian's spot the very first night. I ought to have said something."],
	["enid_michael", "I gave you a press full of empty sheets, and you filled every one. Nobody else was ever going to."],
	["clare_hodges", "I looked for a name in the files. It couldn't have been there. You hadn't done the walking yet."],
	["dick_leonard", "You held the rope for every one of us, one way or another. That's a guardian's work too."],
	["royal_robbins", "And you left the rock the way you found it."],
	["warren_harding", "Mostly."],
	["beverly_johnson", "I told you. Look for the work, not the person."],
	["ansel_adams", "I'll print that negative again tonight. I think I'll be able to make out the face."],
	["bridget_degnan", "You never once came by without carrying something for somebody."],
	["jennie_curry", "I'll give that empty tent to somebody who needs one. The Guardian has a camp."],
	["john_muir", "The mountains did notice. I'm nearly sure of it now."],
	["wren_alvarez", "First tick to last. I knew on Firefall Slab."],
	["ahwahnee_chef", "Somebody had better feed all these people. Come by the kitchen after, all of you."],
	["greg", "Two clean stops, every time. I could tell from your first back cast."],
	["jo_tolliver", "Everybody gets found. I told you. Even the Guardian."],
	["", "[Placeholder pending tribal review: what Tenaya, Tabuce, Lucy Telles, Maria Lebrado and Carrie Bethel say here, and whether they are part of this scene.]"],
	["galen_clark", "Every one of us kept this valley for a while, and every one of us was afraid there'd be nobody after. We were all looking for the Guardian, and the whole time you were the one doing the looking."],
	["galen_clark", "You had to do all of it to find this out. The quests were never a test. They were the work, and the work is what a Guardian is."],
]
## Where the crowd stands: four rows across the cave, with the way to the
## mirror left open down the middle.
const COLUMNS := [120, 200, 280, 360, 600, 680, 760, 840]
const ROWS := [300, 356, 412, 468]

var _busy := false


func get_prompt() -> String:
	return "Look in the looking-glass"


func interact(player: Player) -> void:
	if _busy:
		return
	if QuestLog.is_completed(QuestLog.FINALE_QUEST):
		get_tree().call_group("hud", "show_info", "The Guardian of Yosemite", "The looking-glass, the tin box, and the last sheet. It's still you.")
		return
	if not QuestLog.active.has(QuestLog.FINALE_QUEST):
		get_tree().call_group("hud", "show_message", "A small looking-glass, hung on the rock over a tin box.")
		return
	_busy = true
	player.can_act = false
	var box := DialogueBox.open(player)
	await box.say(narrate(LOOKING.slice(0, LOOKING.size() - 1)))
	gather()
	player.facing = Vector2i.DOWN
	player.interaction_area.position = Vector2(player.facing) * 24.0
	await box.say(narrate(LOOKING.slice(LOOKING.size() - 1)))
	await box.say(gathering_lines())
	await box.say(QuestLog.find_guardian())
	await box.say(closing_lines())
	box.close()
	player.can_act = true
	_busy = false


## Narrator lines for a DialogueBox.
static func narrate(texts: Array) -> Array[Dictionary]:
	var lines: Array[Dictionary] = []
	for text: String in texts:
		lines.append({"speaker": "", "text": text})
	return lines


## GATHERING as lines for a DialogueBox, each under its speaker's name.
static func gathering_lines() -> Array[Dictionary]:
	var lines: Array[Dictionary] = []
	for entry: Array in GATHERING:
		var character := QuestLog.get_character(entry[0])
		lines.append({"speaker": character.display_name if character else "", "text": entry[1]})
	return lines


## The game's last words.
static func closing_lines() -> Array[Dictionary]:
	return narrate([
		"Outside, the light is going gold on the Royal Arches. Somebody has brought bread. Somebody has brought a rope, out of habit.",
		"The end of Valley Days. Your tick list holds %d of %d routes and your press book %d of %d plants. The valley is still open, and it has a Guardian." % [
			Guidebook.ticked_count(), Guidebook.routes().size(), Herbarium.count(), Herbarium.total()],
	])


## Stands everyone in the Register (and the invented staff) in the cave
## behind the player, facing the mirror. Safe to call again.
func gather() -> void:
	var entities := get_parent()
	if not get_tree().get_nodes_in_group("guardian_crowd").is_empty():
		return
	var cast: Array[CharacterData] = QuestLog.CHARACTERS + QuestLog.STAFF
	for i in cast.size():
		var npc: NPC = NPC_SCENE.instantiate()
		npc.name = "Crowd_" + cast[i].id
		npc.character = cast[i]
		npc.stands_still = true
		npc.facing = Vector2i.UP
		npc.position = entities.to_local(global_position) + Vector2(COLUMNS[i % COLUMNS.size()] - 480, ROWS[(i / COLUMNS.size()) % ROWS.size()] - 192)
		npc.add_to_group("guardian_crowd")
		npc.modulate.a = 0.0
		entities.add_child(npc)
		npc.create_tween().tween_property(npc, "modulate:a", 1.0, 0.8)
