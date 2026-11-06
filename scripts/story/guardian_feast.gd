class_name GuardianFeast
extends Node2D
## After the looking-glass: everyone walks you home from the cave, and
## there's a supper round the fire at your camp (the Ahwahnee's chef brings
## the kitchen). You can talk to each of them once, and the sign goes up:
## the Guardian's camp. When you're ready, sleep in your tent: the credits
## roll, and in the morning the Guardian's Year begins.
##
## It's waiting from the moment the finale is done until you've slept
## through it (QuestLog.unlocks FEAST_DONE), so quitting halfway just means
## the supper is still going when you come back to camp.
##
## Who comes: the people with a line below. Native characters' words wait on
## tribal review (STORY.md), and so does whether they're part of a scene the
## game invented, so the feast doesn't put them in it.

const FEAST_DONE := "guardian_feast"
## The supper starts this hour (24h), if you come out of the cave earlier.
const EVENING := 18
const NAME := "GuardianFeast"

## Each guest's one line at the supper: [character id, line].
const LINES := [
	["galen_clark", "Sit down, Guardian. No, there. That's your fire. I'll take the stump."],
	["james_lamon", "First night you pitched here I nearly told you whose spot it was. Glad I didn't. You'd have moved."],
	["jennie_curry", "There. The Guardian has a camp. David would have put a sign up the first day, and spelled it wrong."],
	["ahwahnee_chef", "Bread, a roast, and a pudding in your own Dutch oven, if you've got one. Don't tell the hotel."],
	["enid_michael", "Look at that bird bath. You'll have a junco in it at dawn, and a field guide's worth of company by summer."],
	["clare_hodges", "I've closed the Guardian file. One name in it. It took me a while to look at who was standing in my office."],
	["dick_leonard", "We tied in on Swan Slab, and look at you now. Pass the bread down, would you? Belayer's privilege."],
	["jules_eichorn", "I've been wanting to ask: when you topped out on the Spire, did you sign the register? Good. Then it's official."],
	["bestor_robinson", "The Section's going to want you on the practice days. As an instructor, this time."],
	["royal_robbins", "I won't ask how many pitons you placed. I'll just assume none."],
	["warren_harding", "Somebody find me a glass. A Guardian's camp ought to have a toast in it, and I volunteer."],
	["john_salathe", "That pot crane will outlast all of us. Good steel. Good fire. Good."],
	["beverly_johnson", "You did most of it alone. That's not the same as doing it by yourself. You figured that out."],
	["george_anderson", "I drilled my way up Half Dome to see the top. You walked the whole park to see the people. Better climb."],
	["james_mccauley", "No Firefall tonight, I'm afraid. Just this one. It'll do."],
	["ansel_adams", "I printed that negative again. You can make out the face now. I'll bring it round."],
	["bridget_degnan", "I brought the first loaves. Somebody had to, and it was always going to be me."],
	["john_muir", "The mountains are glad of you. I'm nearly sure of it. I'm quite sure of it, in fact."],
	["wren_alvarez", "First tick to last. I'm still calling you Guardian on belay, and you can't stop me."],
	["mountain_shop", "Marty here. I've already put a sign in the shop window: Outfitters to the Guardian. You don't mind."],
	["greg", "Your fish board's coming along. Next season we'll fill it."],
	["jo_tolliver", "Everybody gets found. The Guardian too. Eat something, you look like you walked the whole park."],
	["mateo_reyes", "I brought the first-aid kit to a supper. Old habit. Pass me a roll."],
]
## The ring of guests round the campfire (offsets from the fire).
const SEATS := [
	Vector2(-64, -40), Vector2(-20, -60), Vector2(28, -58), Vector2(70, -36), Vector2(84, 6), Vector2(70, 46),
	Vector2(30, 66), Vector2(-14, 70), Vector2(-60, 54), Vector2(-88, 14), Vector2(-112, -32), Vector2(-68, -84),
	Vector2(-14, -100), Vector2(44, -96), Vector2(102, -70), Vector2(128, -18), Vector2(126, 40), Vector2(96, 92),
	Vector2(40, 108), Vector2(-24, 112), Vector2(-86, 98), Vector2(-130, 60), Vector2(-150, 4),
]
const FIRE := Vector2(420, 400)
const HOME_REGION := "lamon_homestead"

const NPC_SCENE := preload("res://scenes/story/npc.tscn")

## Guests talked to at this supper (not saved: the supper is one evening).
var talked: Dictionary = {}


## True from the end of the finale until you've slept the supper off.
static func is_pending() -> bool:
	return QuestLog.is_completed(QuestLog.FINALE_QUEST) and not QuestLog.is_unlocked(FEAST_DONE)


## The supper at the homestead, if one is laid on there (null otherwise).
static func at(tree: SceneTree) -> GuardianFeast:
	for node in tree.get_nodes_in_group("guardian_feast"):
		if node.is_inside_tree() and node.is_visible_in_tree() and is_pending():
			return node
	return null


func _ready() -> void:
	name = NAME
	add_to_group("guardian_feast")
	QuestLog.changed.connect(_refresh)
	_refresh()


func _refresh() -> void:
	var pending := is_pending()
	var guests: Array = get_tree().get_nodes_in_group("feast_guest") if is_inside_tree() else []
	if pending and guests.is_empty():
		_seat_guests()
	elif not pending and not guests.is_empty():
		for guest in guests:
			guest.queue_free()


## Seats everyone with a line round the campfire, facing it.
func _seat_guests() -> void:
	var entities := get_parent()
	if entities == null:
		return
	var seat := 0
	for entry: Array in LINES:
		var character := QuestLog.get_character(entry[0])
		if character == null or character.needs_tribal_review or seat >= SEATS.size():
			continue
		var npc: NPC = NPC_SCENE.instantiate()
		npc.name = "Guest_" + character.id
		npc.character = character
		npc.stands_still = true
		var at: Vector2 = FIRE + SEATS[seat]
		npc.position = at
		var toward := FIRE - at
		npc.facing = Vector2i(signi(int(toward.x)), 0) if absf(toward.x) > absf(toward.y) else Vector2i(0, signi(int(toward.y)))
		npc.say_instead = PackedStringArray([entry[1]])
		npc.add_to_group("feast_guest")
		npc.talked_to.connect(func() -> void: talked[character.id] = true)
		entities.add_child.call_deferred(npc)
		seat += 1


## The lines for [param id] at the supper ("" if they aren't at it).
static func line_for(id: String) -> String:
	for entry: Array in LINES:
		if entry[0] == id:
			return entry[1]
	return ""


## What you hear when you walk in, and what the HUD says.
static func arrival_lines() -> Array[Dictionary]:
	return GuardianMirror.narrate([
		"Everyone walks you home: down the talus, across the meadow in the last light, to your camp under the oaks.",
		"Somebody has lit your fire. The Ahwahnee's chef has brought the kitchen. There's a new sign by your tent, carved by a lot of people and not very well: THE GUARDIAN'S CAMP.",
	])


const HINT := "Talk to everyone round the fire. When you're ready, sleep in your tent."


## Ends the supper: the game's last words, the credits, and the guests go
## home. The tent then puts you to bed as usual.
func finish() -> void:
	if not is_pending():
		return
	var world := get_tree().get_first_node_in_group("world")
	var player: Player = world.player if world else null
	var headless := DisplayServer.get_name() == "headless"
	if player and not headless:
		player.can_act = false
		var box := DialogueBox.open(player)
		await box.say(GuardianMirror.closing_lines())
		box.close()
	if not QuestLog.is_unlocked(FEAST_DONE):
		QuestLog.unlocks.append(FEAST_DONE)
	if not headless:
		await EndCredits.roll(get_tree()).finished
	QuestLog.changed.emit()
	if player:
		player.can_act = true
