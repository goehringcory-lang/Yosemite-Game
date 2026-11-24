class_name Backpacking
extends RefCounted
## Camping anywhere with a backpacking pack, and Leave No Trace.
##
## After The First Night Out, Ranger Hodges sends you to Marty at the
## Mountain Shop to be fitted for a backpacking pack (quest
## "hodges_pack_setup"). While the pack is in your gear bag (not left on the
## rack at camp) you wear it: your walking sheet shows it (PlayerLook), and
## from 6 PM until you'd pass out, facing open ground outdoors, the action
## button says "Make camp" (CampSpot, the player's fallback target after
## the fly rod). You sleep where you stand and wake up there, and the game
## saves there (World.camp_out).
##
## Making camp, the game checks the spot against Leave No Trace
## (problems()), and the confirm box tells you what's wrong before you
## commit:
##   "food"    everything you carry to eat must fit in the bear canister
##   "water"   at least 100 feet (WATER_REACH) from a river, lake or creek
##   "trail"   not on a trail or road, or right beside one (TRAIL_REACH)
##   "meadow"  on durable ground: not on a meadow (they take years to heal)
##   "fire"    a fire only in a fire ring that's already there (FIRE_REACH)
## A clean night is a quiet morning (your food spends it in the canister,
## Backcountry.night_out) and counts for Hodges (CLEAN_CAMP). Break any rule
## and you wake up beside a wilderness ranger (RANGER), who tells you what
## you did wrong, takes all your food, and fines you goods worth FINE_EACH
## per problem (FINE_CAP at most; what you can't pay is let go as a warning).

const PACK := "backpacking_pack"
const QUEST := "hodges_pack_setup"
## Kept in QuestLog.unlocks: a night camped anywhere, leaving no trace.
const CLEAN_CAMP := "lnt_camp"
## The wilderness ranger who finds a bad camp in the morning.
const RANGER := "Ranger Pruitt"
const RANGER_DATA := "res://data/characters/rangers/wilderness_ranger.tres"
## Evening: from this hour you can make camp (until you'd pass out).
const CAMP_FROM := 18
const CAMP_TO := 2
## 100 feet at the game's scale (Wayfinding.METERS_PER_PIXEL), in pixels.
const WATER_REACH := 66.0
## On a trail or road, or within this many pixels of one.
const TRAIL_REACH := 20.0
## An existing fire ring (a campfire) within this many pixels.
const FIRE_REACH := 96.0
## Not this close to the edge of an area (the view runs on into the next).
const EDGE_MARGIN := 48.0
## The fine, in goods worth this much food energy a problem, and its cap.
const FINE_EACH := 10
const FINE_CAP := 40
const PROBLEMS := ["food", "water", "trail", "meadow", "fire"]

const Terrain := preload("res://scripts/world/terrain.gd")
const WATER := [Terrain.RIVER, Terrain.LAKE, Terrain.CREEK, Terrain.FALLS]
const TRAILS := [Terrain.TRAIL, Terrain.ROAD, Terrain.PAVED, Terrain.PARKING, Terrain.BRIDGE]
const MEADOWS := [Terrain.MEADOW, Terrain.WET_MEADOW]

## What the confirm box warns of, before you sleep.
const WARNINGS := {
	"food": "Not all your food fits in a bear canister.",
	"water": "You're within a hundred feet of water.",
	"trail": "You're on the trail, or right beside it.",
	"meadow": "You're on the meadow, not on durable ground.",
	"fire": "There's no fire ring here.",
}
## What the ranger says about each problem, in the morning.
const LESSONS := {
	"food": "Your food wasn't all in a bear canister. A bear that gets one meal from a camp comes back for more, and a bear that keeps coming back ends up having to be put down. Everything with a smell goes in the canister, every night.",
	"water": "You slept right by the water. Camp at least a hundred feet back: the plants on a bank hold the bank together, and the animals need to come down to drink without walking through your kitchen.",
	"trail": "You pitched on the trail. Camp a hundred feet off it, out of sight if you can, so the next people through get the wilderness and not your tent.",
	"meadow": "You camped on the meadow. A tent and boots can kill the grass under them, and up here a meadow takes years to heal. Camp on durable ground: rock, sand, or the duff under the trees.",
	"fire": "You built a new fire ring. Fires go only in a ring that's already there, small, and dead out, cold to the touch, before you sleep. Better yet, a stove.",
}
const LNT := "Leave No Trace: plan ahead, camp on durable ground, pack out what you pack in, leave what you find, keep fires small and in a ring, respect wildlife, and be kind to whoever comes after you."


## True while you wear the backpacking pack (it's in your gear bag).
static func worn() -> bool:
	return Gear.carried(PACK) > 0


## Whether "Make camp" is offered to [param player] right now: the pack on,
## outdoors (not at home, which has its own tent), in the evening.
static func can_offer(player: Player) -> bool:
	if not worn() or not player.can_act:
		return false
	var region := _region(player)
	if region == null or region.indoors or region.region_id == Park.HOME_REGION:
		return false
	return GameClock.hour_in_range(CAMP_FROM, CAMP_TO)


## Why you can't camp at [param at] at all, or "" if you can.
static func refusal(region: Region, at: Vector2) -> String:
	if GameClock.season == GameClock.Season.WINTER:
		return "The ground's frozen and the snow's deep. Not a night to sleep out in a tent: better to go home to camp."
	var ground := region.get_ground()
	if ground == null:
		return "There's nowhere to pitch a tent here."
	if not region.get_bounds().grow(-EDGE_MARGIN).has_point(ground.to_local(at)):
		return "You're right at the edge of the map here. Walk on a little before you pitch the tent."
	if type_at(ground, at) in WATER:
		return "You can't pitch a tent in the water."
	return ""


## The Leave No Trace problems with camping at [param at] in [param region]
## (ids from PROBLEMS), with [param fire] if you'd light a fire.
static func problems(region: Region, at: Vector2, fire := false) -> Array[String]:
	var out: Array[String] = []
	if not food_stored():
		out.append("food")
	var ground := region.get_ground()
	if ground:
		if near_type(ground, at, WATER, WATER_REACH):
			out.append("water")
		if near_type(ground, at, TRAILS, TRAIL_REACH):
			out.append("trail")
		if type_at(ground, at) in MEADOWS:
			out.append("meadow")
	if fire and not has_fire_ring(region, at):
		out.append("fire")
	return out


## True if everything you carry to eat fits in a bear canister you carry.
static func food_stored() -> bool:
	var units := 0
	for id in FoodDB.edible_in_inventory():
		units += Inventory.count(id)
	if units == 0:
		return true
	return Backcountry.has_canister() and units <= Backcountry.canister_capacity()


## The terrain type (Terrain's enum) of the ground at [param at], or -1.
static func type_at(ground: TileMapLayer, at: Vector2) -> int:
	return _cell_type(ground, ground.local_to_map(ground.to_local(at)))


static func _cell_type(ground: TileMapLayer, cell: Vector2i) -> int:
	var source := ground.get_cell_source_id(cell)
	if source < 0:
		return -1
	var coords := ground.get_cell_atlas_coords(cell)
	if source == ForageSpawner.SOURCE_TERRAIN:
		return coords.y
	if coords == ForageSpawner.WATER_TILE:
		return Terrain.RIVER
	return -1


## True if any ground of [param types] lies within [param reach] pixels of
## [param at].
static func near_type(ground: TileMapLayer, at: Vector2, types: Array, reach: float) -> bool:
	var tile := Vector2(ground.tile_set.tile_size) * ground.global_scale
	var center := ground.local_to_map(ground.to_local(at))
	var cells := Vector2i(ceili(reach / maxf(tile.x, 1.0)), ceili(reach / maxf(tile.y, 1.0)))
	for y in range(-cells.y, cells.y + 1):
		for x in range(-cells.x, cells.x + 1):
			var cell := center + Vector2i(x, y)
			if not _cell_type(ground, cell) in types:
				continue
			var there := ground.to_global(ground.map_to_local(cell))
			# the nearest point of that cell to you
			var half := tile / 2.0
			var nearest := Vector2(clampf(at.x, there.x - half.x, there.x + half.x), clampf(at.y, there.y - half.y, there.y + half.y))
			if nearest.distance_to(at) <= reach:
				return true
	return false


## True if a campfire (a fire ring that's already there) is close by.
static func has_fire_ring(region: Region, at: Vector2) -> bool:
	for node in region.find_children("*", "Station", true, false):
		var station := node as Station
		if station and station.station == "campfire" and station.global_position.distance_to(at) <= FIRE_REACH:
			return true
	return false


## The confirm box's words for camping at [param at].
static func preview(region: Region, at: Vector2) -> String:
	var found := problems(region, at)
	var text := "Make camp here for the night? You'll wake up on this spot."
	if found.is_empty():
		text += " Your food goes in the bear canister. It looks like a good spot."
	else:
		var lines := PackedStringArray()
		for id in found:
			lines.append(WARNINGS[id])
		text += " But: " + " ".join(lines)
	if not has_fire_ring(region, at):
		text += " " + WARNINGS.fire
	return text


## Takes every bit of food you carry. Returns what was taken (id -> count).
static func confiscate_food() -> Dictionary:
	var taken := {}
	for id: String in Inventory.items.keys():
		if FoodDB.is_food(id) and Inventory.count(id) > 0:
			taken[id] = Inventory.count(id)
	for id: String in taken:
		Inventory.remove(id, taken[id])
	return taken


## The fine for [param count] problems, in food energy.
static func fine_for(count: int) -> int:
	return mini(FINE_EACH * count, FINE_CAP)


## The morning with a ranger beside your camp: what they say (lines for a
## DialogueBox), having taken your food and fined you. The message for the
## HUD after is in "summary".
static func ranger_morning(found: Array) -> Dictionary:
	var lines: Array[Dictionary] = []
	var say := func(text: String) -> void: lines.append({"speaker": RANGER, "text": text})
	lines.append({"speaker": "", "text": "Someone is standing over your tent in the grey light: a ranger in a flat hat, with a pack bigger than yours and a notebook open."})
	say.call("Morning. Wilderness ranger. Stay in your bag a minute, I want to talk to you about your camp.")
	for id: String in PROBLEMS:
		if id in found:
			say.call(LESSONS[id])
	var food := confiscate_food()
	if food.is_empty():
		say.call("You've no food on you, so there's none for me to take. Lucky.")
	else:
		say.call("I'm taking your food. All of it: %s. It's coming out with me, and it won't teach a bear anything on the way." % Barter.describe(food))
	var fine := fine_for(found.size())
	var can := mini(fine, Barter.purse())
	var paid := {}
	if can > 0:
		paid = Barter.pay(can)
	if paid.is_empty():
		say.call("That's a fine as well, worth %d. You've nothing on you to pay it with, so I'll write it up as a warning this time. Only this time." % fine)
	elif can < fine:
		say.call("And a fine, worth %d. I'll take %s, and write the rest up as a warning." % [fine, Barter.describe(paid)])
	else:
		say.call("And a fine, worth %d: I'll take %s." % [fine, Barter.describe(paid)])
	say.call(LNT)
	say.call("Go and see Ranger Hodges at the station if you want it all again from somebody kinder. Next time, leave the place like nobody slept here.")
	var summary := "The ranger took all your food"
	if not paid.is_empty():
		summary += " and fined you %s" % Barter.describe(paid)
	summary += ". Leave No Trace next time."
	return {"lines": lines, "summary": summary, "food": food, "paid": paid}


## The ranger standing beside you in the morning: their walking sheet on
## a sprite, facing you. Freed by the caller.
static func ranger_figure() -> Sprite2D:
	var data := load(RANGER_DATA) as CharacterData
	var sprite := Sprite2D.new()
	sprite.name = "WildernessRanger"
	sprite.offset = Vector2(0, -22)
	if data and data.sprite_sheet:
		CharacterSheet.setup(sprite, data.sprite_sheet)
		sprite.frame = CharacterSheet.frame(data.sprite_sheet, Vector2i.LEFT, CharacterSheet.Col.TALK)
	return sprite


## Marks a first (like CLEAN_CAMP). True the first time.
static func mark(ability: String) -> bool:
	return Backcountry.mark(ability)


static func _region(node: Node) -> Region:
	var world := node.get_tree().get_first_node_in_group("world") if node.is_inside_tree() else null
	return world.region if world and "region" in world else null
