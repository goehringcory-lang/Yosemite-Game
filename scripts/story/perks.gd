extends Node
## Perks: small skills and know-how the valley teaches you as you play.
##
## A perk is earned from people (finishing their story) or from experience
## (foraging, cooking, crux moves, days in the valley, ticks). Each one gives
## a gentle, permanent bonus. Nothing is bought or chosen: you learn it by
## doing it.
##
## Other systems ask for a perk's effect with [method bonus] (0 until it's
## earned), so each hook is a single line at its call site:
##   Player speed        player.gd             muirs_stride
##   Daily forage        forage_spawner.gd     enids_eye
##   Mortar and basin    recipes.gd            tabuces_patience (recipe_minutes)
##   Food shelf life     food_db.gd            lamons_cellar
##   Eating on the wall  climb_state.gd eat()  trail_cook
##   Belay ledge rest    climb_state.gd        leonards_belay
##   Crux green zone     climb_state.gd        steady_breath
##   Minutes per move    climb_state.gd move() light_rack
##   Slab moves          climb_state.gd move_cost() slackliners_feet
##   Carrying someone    rescues.gd speed_factor() long_carry
##
## Experience that no other system keeps a count of (wild forage picked up,
## mornings, perfect cruxes, slackline crossings) is counted here with
## [method note], and best scores (the slackline's) with [method record].
##
## To add a perk: add an entry to PERKS, give its "unlock" a type that
## [method progress] understands, and read its bonus where it applies.

signal unlocked(perk: Dictionary)
signal changed

## Every perk. "unlock" is how it's earned:
##   {"quest": id}                 finish that quest
##   {"stat": name, "count": n}    reach n of a counted stat (see progress())
## "amount" is what bonus() returns once it's earned. "review" marks Native
## content that hasn't been through tribal review yet (see STORY.md).
const PERKS: Array[Dictionary] = [
	{"id": "muirs_stride", "name": "Muir's Stride", "amount": 0.08,
		"unlock": {"stat": "mornings", "count": 14},
		"how": "Wake up in the valley 14 mornings.",
		"effect": "You walk a little faster.",
		"flavor": "In 1868 John Muir walked from San Francisco to Yosemite, across the Central Valley in spring flowers. He walked nearly everywhere after that."},
	{"id": "enids_eye", "name": "Enid's Eye", "amount": 1,
		"unlock": {"stat": "forage", "count": 25},
		"how": "Pick up 25 wild plants and berries.",
		"effect": "One more wild find turns up each morning, wherever you are.",
		"flavor": "Enid Michael, a ranger-naturalist from 1921, kept a wildflower garden by the Valley museum and wrote hundreds of nature notes on what grew where."},
	{"id": "tabuces_patience", "name": "Tabuce's Patience", "amount": 0.25,
		"unlock": {"stat": "acorn_meals", "count": 3},
		"how": "Cook acorn mush or acorn cakes 3 times.",
		"effect": "Grinding at the mortar and leaching at the basin take a quarter less time.",
		"flavor": "Tabuce (Maggie Howard) showed visitors at the Yosemite Museum how acorns were pounded, leached and cooked, through the 1930s."},
	{"id": "lamons_cellar", "name": "Lamon's Cellar", "amount": 1,
		"unlock": {"quest": "lamon_winter"},
		"how": "Help James Lamon lay food by for the winter.",
		"effect": "Food you pick up keeps one more day in your pack.",
		"flavor": "James Lamon stayed the winters in the Valley from the early 1860s, fed by his garden and orchard. Apples keep."},
	{"id": "trail_cook", "name": "Trail Cook", "amount": 2,
		"unlock": {"stat": "cooked", "count": 12},
		"how": "Cook or prepare 12 dishes at a campfire, mortar or basin.",
		"effect": "Food you eat at a belay ledge gives 2 more energy.",
		"flavor": "Camp 4 climbers in the 1960s lived on whatever they could cook cheaply. A good camp cook got invited on the big walls."},
	{"id": "leonards_belay", "name": "Leonard's Belay", "amount": 3,
		"unlock": {"quest": "leonard_belay"},
		"how": "Learn to belay from Dick Leonard.",
		"effect": "You rest 3 stamina more at every belay ledge.",
		"flavor": "Dick Leonard and the Sierra Club's Rock Climbing Section worked out the dynamic belay in the 1930s: let the rope run a little, and the catch is gentle."},
	{"id": "steady_breath", "name": "Steady Breath", "amount": 0.03,
		"unlock": {"stat": "perfect_cruxes", "count": 5},
		"how": "Climb 5 crux moves perfectly.",
		"effect": "The green zone of a crux is a little wider.",
		"flavor": "On a hard move, breathe out. Climbers say a crux goes better when you stop holding your breath."},
	{"id": "light_rack", "name": "Light Rack", "amount": 1,
		"unlock": {"stat": "ticks", "count": 6},
		"how": "Tick 6 routes in the guidebook.",
		"effect": "Each move on the wall takes 5 minutes instead of 6.",
		"flavor": "Clean climbing in the 1970s swapped heavy steel pitons for a few nuts and hexes. A lighter rack climbs faster."},
	{"id": "slackliners_feet", "name": "Slackliner's Feet", "amount": 1,
		"unlock": {"stat": "slackline_crossings", "count": 5},
		"how": "Walk a Camp 4 slackline end to end 5 times.",
		"effect": "Moves on a friction slab cost 1 less stamina.",
		"flavor": "Camp 4 climbers took up slacklining on rest days in the early 1980s. Walking webbing trains the quiet, trusting feet a slab asks for."},
	{"id": "long_carry", "name": "Long Carry", "amount": 0.2,
		"unlock": {"stat": "rescues", "count": 5},
		"how": "Answer 5 rescue calls from the Camp 4 rescue site.",
		"effect": "You walk faster while carrying someone out.",
		"flavor": "Since the 1970s, climbers camped at the Camp 4 rescue site have helped the park's search and rescue team, hauling litters down trails and lowering people off the walls."},
]

## How long the HUD must be free before a "New perk" message shows, so it
## doesn't cover the message that caused it (a find, a wake-up, a tick).
const TOAST_DELAY := 2.0
## Time between two queued messages.
const TOAST_GAP := 3.6

## Perk ids, in the order they were earned.
var earned: Array[String] = []
## Counts kept here: "forage", "mornings", "perfect_cruxes".
var stats: Dictionary = {}

var _by_id: Dictionary = {}
## Messages waiting for the HUD.
var _toasts: PackedStringArray = []
var _toast_wait := TOAST_DELAY


func _ready() -> void:
	add_to_group("persist")
	for perk: Dictionary in PERKS:
		_by_id[perk.id] = perk
	QuestLog.changed.connect(check)
	Recipes.made.connect(check.unbind(1))
	GameClock.day_started.connect(_on_day_started.unbind(3))


func start_new_game() -> void:
	earned = []
	stats = {}
	_toasts = []
	changed.emit()


func get_perk(id: String) -> Dictionary:
	return _by_id.get(id, {})


func has(id: String) -> bool:
	return id in earned


## The perk's effect if the player has earned it, otherwise 0.
func bonus(id: String) -> float:
	return float(get_perk(id).get("amount", 0)) if has(id) else 0.0


## How long a recipe takes, after Tabuce's Patience (mortar and basin only).
func recipe_minutes(recipe: RecipeData) -> int:
	if recipe.station in ["mortar", "leaching"]:
		return roundi(recipe.minutes * (1.0 - bonus("tabuces_patience")))
	return recipe.minutes


## Counts some experience ("forage", "perfect_cruxes"...) and checks for new perks.
func note(what: String, amount := 1) -> void:
	if amount <= 0:
		return
	stats[what] = int(stats.get(what, 0)) + amount
	check()


func stat(key: String) -> int:
	return int(stats.get(key, 0))


## Keeps the highest [param value] seen for [param what] (a best score).
## Returns true if it's a new best.
func record(what: String, value: int) -> bool:
	if value <= stat(what):
		return false
	stats[what] = value
	return true


## [have, need] toward a perk. For a quest it's [0 or 1, 1].
func progress(perk: Dictionary) -> Array[int]:
	var unlock: Dictionary = perk.unlock
	if unlock.has("quest"):
		return [1 if QuestLog.is_completed(unlock.quest) else 0, 1]
	var need := int(unlock.count)
	var have := 0
	match str(unlock.stat):
		"cooked":
			for id: String in Recipes.times_made:
				have += int(Recipes.times_made[id])
		"acorn_meals":
			have = int(Recipes.times_made.get("acorn_mush", 0)) + int(Recipes.times_made.get("acorn_cake", 0))
		"ticks":
			have = QuestLog.climbed.size()
		_:
			have = stat(unlock.stat)
	return [mini(have, need), need]


func is_ready(perk: Dictionary) -> bool:
	var p := progress(perk)
	return p[0] >= p[1]


## Earns every perk whose condition is met. [param announce] queues a HUD
## message for each (a loaded save catches up quietly).
func check(announce := true) -> void:
	var any := false
	for perk: Dictionary in PERKS:
		if has(perk.id) or not is_ready(perk):
			continue
		earned.append(perk.id)
		any = true
		if announce:
			_toasts.append("New perk: %s. %s" % [perk.name, perk.effect])
		unlocked.emit(perk)
	if any:
		changed.emit()


## Messages not shown yet (tests read this).
func pending_toasts() -> PackedStringArray:
	return _toasts


func _on_day_started() -> void:
	note("mornings")


func _process(delta: float) -> void:
	if _toasts.is_empty():
		return
	if _hud_busy():
		_toast_wait = maxf(_toast_wait, TOAST_DELAY)
		return
	_toast_wait -= delta
	if _toast_wait > 0.0:
		return
	var hud := get_tree().get_first_node_in_group("hud")
	if hud == null:
		return
	hud.show_message(_toasts[0])
	_toasts.remove_at(0)
	_toast_wait = TOAST_GAP


## True while something covers the HUD or the clock is stopped (a
## conversation, a menu, the climbing screen, a sleep fade).
func _hud_busy() -> bool:
	if GameClock.paused or not get_tree().get_nodes_in_group("dialogue_box").is_empty():
		return true
	for group: String in ["journal", "pause_menu", "park_map"]:
		var screen := get_tree().get_first_node_in_group(group)
		if screen and screen.has_method("is_open") and screen.is_open():
			return true
	return false


func save_data() -> Dictionary:
	return {"earned": earned, "stats": stats}


func load_data(data: Dictionary) -> void:
	earned = []
	for id in data.get("earned", []):
		if _by_id.has(str(id)):
			earned.append(str(id))
	stats = {}
	var saved: Dictionary = data.get("stats", {})
	for key in saved:
		stats[str(key)] = int(saved[key])
	_toasts = []
	check(false)
	changed.emit()
