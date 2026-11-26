class_name EffortSigns
extends RefCounted
## How tired the climber looks: the effort system's state turned into named
## body signs, so art (thread 9), the look and sound (thread 10) and the
## effort overlay can show strain on the climber instead of a meter. Pure
## functions of the numbers; every value is 0..1 unless it says otherwise.
##
## Published after every change in session.notes["effort"]["signs"]:
##   band          "fresh", "working", "pumped" or "boxed" (EffortSystem.band)
##   tremble       forearm shake
##   chicken_wing  elbows lifting off the wall (deep in the pump)
##   stiff         deep pump: heavier, slower movement
##   shake_want    how much the arms want shaking out
##   rest_left     how much a shake-out here would still win back (0: spent,
##                 stop shaking and climb on)
##   breath        heavy breathing (hard work lately, or running low on gas)
##   hip_sag       hips sagging off the wall when low on gas
##   sweat         sweat (sun and effort)
##   chalk_want    reaching for the chalk bag
##   hunger        stomach growl, a glance at the pack (food would help)
##   thirst        lip-licking when the water is low
##   bonked        1 when out of gas
##   steadied      1 just after a nibble steadied the arms
## A ghost (EffortSystem.ghost_signs) adds:
##   fail          1 if this move will fail at the pump it leaves you with
##   unreliable    how unreliable small holds are at that pump

const T = preload("res://scripts/climb/v2/effort/effort_tuning.gd")


static func smooth(from: float, to: float, x: float) -> float:
	if is_equal_approx(from, to):
		return 1.0 if x >= to else 0.0
	return smoothstep(from, to, x)


static func band(pump: float) -> StringName:
	if pump >= T.BOXED:
		return &"boxed"
	if pump >= T.PUMPED:
		return &"pumped"
	if pump >= T.WORKING:
		return &"working"
	return &"fresh"


## The signs for [param effort] with the effort system's [param note]
## (deep pump, recent exertion...), [param mods] (sun) and [param rest_left]
## (EffortSystem.rest_left()).
static func make(effort: V2Effort, note: Dictionary, mods: V2Modifiers, rest_left: float, has_food: bool) -> Dictionary:
	var pump := effort.pump
	var deep := float(note.get("deep", 0.0))
	var gas_share := effort.gas / maxf(effort.gas_cap, 0.01)
	var recent := float(note.get("recent", 0.0))
	var sun := mods.sun if mods else 0.0
	var sweat := clampf(0.25 * sun + 0.5 * sun * recent * 10.0 + 0.4 * smooth(0.6, 1.0, pump), 0.0, 1.0)
	var since_chalk := float(note.get("since_chalk", 0))
	return {
		"band": String(band(pump)),
		"tremble": smooth(0.5, 0.95, pump),
		"chicken_wing": smooth(0.8, 1.0, pump),
		"stiff": smooth(0.05, 0.4, deep),
		"shake_want": smooth(0.3, 0.8, pump),
		"rest_left": clampf(rest_left / 0.3, 0.0, 1.0),
		"breath": clampf(maxf(recent * 12.0, 1.0 - gas_share - 0.2), 0.0, 1.0),
		"hip_sag": smooth(0.4, 0.1, gas_share) if gas_share < 0.4 else 0.0,
		"sweat": sweat,
		"chalk_want": clampf(sweat * since_chalk / 10.0 + 0.1 * smooth(0.5, 0.9, pump), 0.0, 1.0),
		"hunger": smooth(T.LOW_GAS, 0.1, gas_share) if has_food and gas_share < T.LOW_GAS else 0.0,
		"thirst": smooth(0.4, 0.05, effort.water) if effort.water < 0.4 else 0.0,
		"bonked": 1.0 if effort.gas <= 0.001 else 0.0,
		"steadied": 1.0 if note.get("steadied", false) else 0.0,
	}
