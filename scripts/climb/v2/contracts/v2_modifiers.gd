class_name V2Modifiers
extends RefCounted
## Everything outside the wall that changes how a climb plays: kit, perks,
## food boosts, weather, assists and what mentors have taught you. The
## director fills it once per pitch (and after eating), so no system reads
## autoloads during play. Defaults are neutral.

var has_shoes := true
var has_chalk := true
var has_device := true
## Multipliers effort (thread 4) applies: 1 = normal.
var pump_mult := 1.0
var gas_mult := 1.0
## The rock and weather right now (WallWeather): 0..1.
var wet := 0.0
var sun := 0.0
var cold := 0.0
var wind := 0.0
## Perk id -> value (Perks.bonus), for the perks a system cares about.
var perks := {}
## What mentors have taught (information, not verbs): e.g. "lobes" (cam lobes
## read clearly), "constrictions" (nut spots glint), "kneebars", "rests".
var knowledge := PackedStringArray()
## Assists (Settings): "auto_gear" picks the right size for you, "relaxed"
## lowers costs, "simple_moves" lets body pick the hold.
var assists := PackedStringArray()
## A story route: no ground falls, at most two pieces pop.
var story := true


func knows(what: String) -> bool:
	return knowledge.has(what)


func assisted(what: String) -> bool:
	return assists.has(what)


## Reads the game for [param route]. Missing autoloads leave defaults, so
## tests run without the world.
static func from_world(route: RouteData) -> V2Modifiers:
	var m := V2Modifiers.new()
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or route == null:
		return m
	var gear := tree.root.get_node_or_null("/root/Gear")
	if gear and gear.has_method("carried"):
		m.has_shoes = int(gear.carried("climbing_shoes")) > 0
		m.has_chalk = int(gear.carried("chalk_bag")) > 0
		m.has_device = int(gear.carried("belay_device")) > 0
	if Settings.climb_moves == Settings.ClimbMoves.SIMPLE:
		m.assists.append("simple_moves")
	if Settings.timing != Settings.Timing.STANDARD:
		m.assists.append("relaxed")
	return m


func to_dict() -> Dictionary:
	return {"has_shoes": has_shoes, "has_chalk": has_chalk, "has_device": has_device,
		"pump_mult": pump_mult, "gas_mult": gas_mult, "wet": wet, "sun": sun, "cold": cold,
		"wind": wind, "perks": perks.duplicate(), "knowledge": Array(knowledge),
		"assists": Array(assists), "story": story}


static func from_dict(d: Dictionary) -> V2Modifiers:
	var m := V2Modifiers.new()
	for key in ["has_shoes", "has_chalk", "has_device", "story"]:
		m.set(key, bool(d.get(key, m.get(key))))
	for key in ["pump_mult", "gas_mult", "wet", "sun", "cold", "wind"]:
		m.set(key, float(d.get(key, m.get(key))))
	m.perks = (d.get("perks", {}) as Dictionary).duplicate()
	m.knowledge = PackedStringArray(d.get("knowledge", []))
	m.assists = PackedStringArray(d.get("assists", []))
	return m
