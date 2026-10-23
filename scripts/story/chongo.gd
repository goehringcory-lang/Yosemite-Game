class_name Chongo
extends NPC
## Chongo, a Camp 4 boulderer who wrote a physics book and will sell you a
## copy. He's never in the same place twice: each day he's out at one of
## HAUNTS in the morning and another in the afternoon, almost always by one of
## its boulders (sometimes just at a named spot), working a problem. Not in
## the Register and gives no quests. The book costs a snack (BOOK_PRICE food
## energy, paid like any trade; see Barter); once you own it he teaches you a
## little of what's in it each time you find him.
##
## World calls visit() each time the player enters a region, which puts him
## there or takes him away. Meeting him and buying the book are kept with the
## heard story beats (QuestLog.heard_beats), so they're saved with the game.

const SCENE := preload("res://scenes/story/chongo.tscn")
const MET := "chongo:met"
const SOLD := "chongo:sold"
const SPEAKER := "Chongo"
const BOOK := "chongo_book"
## Food energy the book costs: about a chocolate bar.
const BOOK_PRICE := 20
## Where he turns up: outdoor areas with boulders. Camp 4 is home turf, so the
## Village is in twice.
const HAUNTS := [
	"yosemite_village", "yosemite_village", "curry_village", "happy_isles", "mirror_lake",
	"tenaya_creek", "leidig_meadow", "el_capitan_meadow", "bridalveil_fall", "four_mile_trailhead",
	"housekeeping_camp", "upper_pines", "ahwahnee_trail", "ahwahnee_meadow", "the_ahwahnee",
	"tunnel_view", "glacier_point", "el_portal", "wawona", "tuolumne_meadows",
]
## His hours: out from OUT_HOUR, moving on to the afternoon's haunt at
## MOVE_HOUR, gone at HOME_HOUR.
const OUT_HOUR := 8
const MOVE_HOUR := 13
const HOME_HOUR := 19
## Chance he's at a named spot in the region instead of a boulder.
const OFF_ROCK_CHANCE := 0.15
## How far in front of a boulder's base he stands.
const STAND_OFF := Vector2(0, 26)

## What's in the book, a page per visit once you own it.
const LESSONS := [
	["Chapter 2: glacial erratics. A glacier picks up a rock the size of a cabin, carries it for miles, melts, and just... leaves it. No note. Half the boulders in this Valley are lost luggage."],
	["Chapter 3: friction. Rubber on granite, the coefficient's around one. That means if the rock's tilted less than forty-five degrees, your shoe sticks. Steeper than that, you're relying on vibes."],
	["Chapter 5: exfoliation. Granite cooled deep underground, under huge pressure. Bring it up to the surface and it relaxes, peels off in sheets like an onion. That's how Half Dome got its curve. Rock yoga."],
	["Chapter 6: center of mass. Keep your hips over your feet and the rock does the work. Lean out and gravity sends you a bill. I wrote it as an equation. It's mostly a drawing of a guy falling."],
	["Chapter 7: potential energy. A boulder up on the talus has stored energy: mass, times gravity, times height. Rockfall is just a boulder spending its savings all at once. That's why you don't camp under the cliff."],
	["Chapter 8: frost wedging. Water gets in a crack, freezes, expands about nine percent. Do that every winter night for a few thousand years and you can split a mountain. Ice is the strongest climber in the park."],
	["Chapter 10: crash pads. Land on a pad and you stop over a longer time, so the force is smaller. Same fall, less ouch. Impulse! Newton was a boulderer, he just didn't know it."],
	["Chapter 11: why chalk works. Sweat makes a slippery film between skin and rock. Magnesium carbonate soaks it up. Dry skin, more friction. That chapter is short. I was out of chalk when I wrote it."],
	["Chapter 12: deep time. This granite cooled about a hundred million years ago. You and me are a rounding error. That's not sad. It means nobody's watching you fall off the warmup."],
]

## The boulder (or spot) he's at, kept so he faces it.
var rock: Node2D


## Puts Chongo in [param region] if this is where he is now, at the same
## boulder each time you come back this half of the day, or takes him away.
static func visit(region: Region) -> void:
	var here := region.region_id == where_now()
	var key := _shift_key() + region.region_id
	var npc := region.entities.get_node_or_null("Chongo") as Chongo
	if npc and (not here or npc.get_meta("shift", "") != key):
		npc.get_parent().remove_child(npc)
		npc.queue_free()
		npc = null
	if not here or npc:
		return
	# The walk grid reads the physics space, which only sees the region's
	# bodies once it has been through a physics frame.
	await region.get_tree().physics_frame
	if not region.is_inside_tree() or region.entities.has_node("Chongo") or region.region_id != where_now():
		return
	var spot := pick_spot(region, key)
	if spot.is_empty():
		return
	npc = SCENE.instantiate()
	npc.name = "Chongo"
	npc.position = region.entities.to_local(spot.at)
	npc.rock = spot.rock
	npc.set_meta("shift", key)
	region.entities.add_child(npc)
	npc._face(spot.rock.global_position - spot.at)
	npc._update_frame(false)


## The region he's out in now, or "" outside his hours.
static func where_now() -> String:
	var hour := GameClock.minutes / 60
	if hour < OUT_HOUR or hour >= HOME_HOUR:
		return ""
	return haunt(_today(), hour >= MOVE_HOUR)


## Where he spends the morning (or [param afternoon]) of [param day]. The
## afternoon is always somewhere other than the morning.
static func haunt(day: String, afternoon: bool) -> String:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("chongo@" + day)
	var morning: String = HAUNTS[rng.randi() % HAUNTS.size()]
	if not afternoon:
		return morning
	var later: String = morning
	while later == morning:
		later = HAUNTS[rng.randi() % HAUNTS.size()]
	return later


## Where to stand in [param region] this shift ({"at", "rock"}): in front of
## one of its boulders, or now and then at a named spot. The same for a given
## [param key], so he's where you left him. Empty if there's nowhere.
static func pick_spot(region: Region, key: String) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(key)
	var grid := WalkGrid.of(region)
	var rocks := boulders(region)
	var places: Array = region.get_places().filter(func(p: Place) -> bool: return p.radius > 0.0)
	if not rocks.is_empty() and (places.is_empty() or rng.randf() >= OFF_ROCK_CHANCE):
		for attempt in 8:
			var boulder: Node2D = rocks[rng.randi() % rocks.size()]
			var side := Vector2(rng.randf_range(-16.0, 16.0), 0.0)
			var at := grid.nearest_open(boulder.global_position + STAND_OFF + side, 4)
			if grid.is_open(at) and at.distance_to(boulder.global_position) < 80.0:
				return {"at": at, "rock": boulder}
	if places.is_empty():
		return {}
	var place: Place = places[rng.randi() % places.size()]
	var at := grid.nearest_open(place.global_position)
	return {"at": at, "rock": place} if grid.is_open(at) else {}


## The region's solid boulders and rocks, found once and kept on the region.
static func boulders(region: Region) -> Array:
	if region.has_meta("chongo_boulders"):
		return region.get_meta("chongo_boulders")
	var found := []
	for body: StaticBody2D in region.find_children("*", "StaticBody2D", true, false):
		if body.collision_layer & 1 == 0:
			continue
		var sprite := body.get_node_or_null("Sprite") as Sprite2D
		if sprite == null or sprite.texture == null:
			continue
		var file := sprite.texture.resource_path.get_file()
		if file.begins_with("rock_") or "boulder" in file:
			found.append(body)
	region.set_meta("chongo_boulders", found)
	return found


static func has_met() -> bool:
	return MET in QuestLog.heard_beats


static func has_sold() -> bool:
	return SOLD in QuestLog.heard_beats


static func _today() -> String:
	return "%d-%d-%d" % [GameClock.year, GameClock.season, GameClock.day]


static func _shift_key() -> String:
	return "%s:%s:" % [_today(), "pm" if GameClock.minutes / 60 >= MOVE_HOUR else "am"]


## Out while this is his haunt; when he moves on he fades away like a visitor
## going home.
func is_out() -> bool:
	var region := _find_region()
	return region != null and region.region_id == where_now()


func interact(player: Player) -> void:
	_talking = true
	velocity = Vector2.ZERO
	_face(player.global_position - global_position)
	_update_frame(false)
	_hop()
	player.can_act = false
	if has_sold():
		await _lesson(player)
	else:
		await _pitch(player)
	player.can_act = true
	_talking = false
	if rock:
		_face(rock.global_position - global_position)
		_update_frame(false)


## The sales pitch: the long version the first time, the short one after.
func _pitch(player: Player) -> void:
	var box := DialogueBox.open(player)
	if not has_met():
		QuestLog.heard_beats.append(MET)
		await box.say(_lines([
			["Whoa, hey! Don't mind me. I'm just reading the rock.", "surprised"],
			["Name's Chongo. Camp 4, mostly. Wherever there's a good boulder, really.", "happy"],
			["You ever wonder WHY you stick to granite? Why you fall off it? Why it's even here?"],
			["I did. For about twenty years. Then I wrote it all down.", "happy"],
		]))
	else:
		await box.say(_lines([[_greeting(), "happy"]]))
	var pick := 1
	while pick == 1:
		pick = await box.choose("Want a copy of the book? Just a snack's worth. Writers gotta eat.",
			["Trade a snack for it", "What's in it?", "No thanks"], SPEAKER)
		if pick == 1:
			await box.say(_lines([
				["Gravity, friction, glaciers, chalk. The whole universe, explained from the bottom of a boulder problem.", "happy"],
				["Chapter 1 proves every boulder is a falling object. It's just falling REAL slow."],
				["The physics department at Berkeley hasn't written back yet. Which I take as a good sign."],
			]))
	if pick != 0:
		await box.say(_lines([["No worries. The universe isn't going anywhere. Me neither. Well, I'm going to a different rock. But you'll find me.", "happy"]]))
		box.close()
		return
	if not Barter.can_afford(BOOK_PRICE):
		await box.say(_lines([["Oh, man. You're running on empty. Eat something, friend. The book'll keep. Physics is pretty stable.", "sad"]]))
		box.close()
		return
	var paid := Barter.pay(BOOK_PRICE)
	QuestLog.heard_beats.append(SOLD)
	Inventory.add(BOOK)
	Sound.play("item_get")
	await box.say(_lines([
		["%s! Oh, that's perfect. Here. Signed copy. Well, they're all signed." % Barter.describe(paid), "happy"],
		["Read chapter 1 lying in the shade and chapter 9 on top of something tall. Trust the friction.", "happy"],
		["Find me again sometime. I'll walk you through the hard parts."],
	]))
	box.close()


## Once you own the book: a page of it, explained, or just hanging out.
func _lesson(player: Player) -> void:
	var box := DialogueBox.open(player)
	var pick := await box.choose(_greeting(), ["Teach me something from the book", "Just watching you climb"], SPEAKER)
	if pick == 0:
		var page: Array = LESSONS[absi(hash(_shift_key() + "lesson")) % LESSONS.size()]
		await box.say(_lines([page, ["That'll be on the test. There's no test. Life's the test.", "happy"]]))
	else:
		await box.say(_lines([[_idle_line()]]))
	box.close()


func _greeting() -> String:
	var hour := GameClock.minutes / 60.0
	if hour < 10.0:
		return "Morning! Rock's still cold. Best friction of the day. Chapter 3."
	if hour >= 17.0:
		return "Golden hour. Granite's warm. Physics gets sleepy this time of day."
	return "Hey, it's you! Small Valley. Well, big Valley. Small number of boulders I like."


func _idle_line() -> String:
	if character and not character.idle_lines.is_empty():
		return character.idle_lines[_rng.randi() % character.idle_lines.size()]
	return "..."


## [[text, mood?], ...] as dialogue lines spoken by Chongo.
func _lines(raw: Array) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for r: Array in raw:
		var line := {"speaker": SPEAKER, "text": r[0]}
		if r.size() > 1:
			line.mood = r[1]
		result.append(line)
	return result
