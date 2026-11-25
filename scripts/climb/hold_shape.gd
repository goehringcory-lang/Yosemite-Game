class_name HoldShape
extends RefCounted
## What a hold is to the hand and the foot that use it: a hold's grip (jug,
## edge, crimp) says how hard it is, its shape says how you take it. A jug is
## wrapped, a crimp is pulled on with the knuckles tented, an edge on a flake
## is a sidepull, a crack takes a finger, hand or fist jam, a slab is pressed
## with a flat palm and smeared with the feet.
##
## ClimbState tags every hold of a pitch with "shape" and "foot" when it
## builds it ([method tag]). The climber is painted with the hand shape of
## the hold each hand is on (ClimberHD), the grip close-up shows it big
## (ClimbGripView), and anything that plays on how a hold is taken (the
## controls, the skill game) can read the same tags.
##
## Tagging uses no random numbers, so it never changes the holds a seed makes.

## Every hand shape, in the order the close-up sheet shows them.
const HANDS := ["jug", "edge", "crimp", "pinch", "sidepull", "gaston", "undercling", "palm",
	"finger_jam", "hand_jam", "fist_jam", "tool"]
## Every foot technique.
const FEET := ["edge", "smear", "toe_jam", "step"]

## The word the close-up shows under each shape.
const LABELS := {
	"jug": "Jug", "edge": "Edge", "crimp": "Crimp", "pinch": "Pinch", "sidepull": "Sidepull",
	"gaston": "Gaston", "undercling": "Undercling", "palm": "Palm press", "finger_jam": "Finger jam",
	"hand_jam": "Hand jam", "fist_jam": "Fist jam", "tool": "Tool placement",
}
const FOOT_LABELS := {"edge": "Edging", "smear": "Smear", "toe_jam": "Toe jam", "step": "Step"}

## Hand shapes that go into a crack.
const JAMS := ["finger_jam", "hand_jam", "fist_jam"]


## Tags every hold in [param holds] (row -> {column -> hold}) for a pitch of
## [param style].
static func tag(holds: Dictionary, style: String) -> void:
	for r: int in holds:
		for c: int in holds[r]:
			var hold: Dictionary = holds[r][c]
			hold["shape"] = of(hold, style, r, c)
			hold["foot"] = foot_of(hold, style, r, c)


## The hand shape for [param hold] at ([param r], [param c]) on a pitch of
## [param style]. An authored hold's own "shape" wins.
static func of(hold: Dictionary, style: String, r: int, c: int) -> String:
	if hold.has("shape") and HANDS.has(hold.shape):
		return hold.shape
	var grip: String = hold.get("grip", "step")
	var kind: String = hold.get("kind", "")
	if kind == "ice":
		return "tool"
	if kind == "snow" or grip == "step":
		return "jug"
	var roll := _roll(r, c)
	var name := str(hold.get("name", "")).to_lower()
	if name.contains("sidepull"):
		return "sidepull"
	if name.contains("undercling"):
		return "undercling"
	if name.contains("pinch"):
		return "pinch"
	if hold.get("crack", false) and (style in ["crack", "chimney", "roof"] or roll < 0.5):
		match grip:
			"crimp":
				return "finger_jam"
			"jug":
				return "hand_jam"
			_:
				return "fist_jam" if roll < 0.3 else "hand_jam"
	match style:
		"flake":
			match grip:
				"edge":
					return "sidepull"
				"crimp":
					return "gaston" if roll < 0.4 else "crimp"
				"jug":
					return "undercling" if roll < 0.3 else "jug"
		"knobs":
			if grip == "edge":
				return "pinch"
		"dike":
			if grip == "edge":
				return "pinch" if roll < 0.45 else "edge"
		"slab":
			if grip == "edge":
				return "palm" if roll < 0.4 else "edge"
		"roof":
			if grip == "edge":
				return "undercling" if roll < 0.35 else "edge"
		_:
			if grip == "edge":
				if roll < 0.2:
					return "sidepull"
				if roll < 0.32:
					return "pinch"
	return grip if grip in ["jug", "edge", "crimp"] else "jug"


## The foot technique on [param hold]'s row: smears on slab and on blank
## rock, toes twisted into a crack, edges on anything with an edge.
static func foot_of(hold: Dictionary, style: String, r: int, c: int) -> String:
	if hold.has("foot") and FEET.has(hold.foot):
		return hold.foot
	var grip: String = hold.get("grip", "step")
	if hold.get("kind", "") in ["ice", "snow"] or grip == "step":
		return "step"
	match style:
		"slab":
			return "edge" if grip == "jug" else "smear"
		"dike":
			return "edge" if hold.get("dike", false) else "smear"
		"crack", "roof":
			if hold.get("crack", false):
				return "toe_jam"
		"knobs":
			return "edge"
		"flake":
			return "smear" if _roll(r + 7, c) < 0.5 else "edge"
	return "smear" if grip == "crimp" and _roll(r + 3, c) < 0.4 else "edge"


static func label(shape: String) -> String:
	return LABELS.get(shape, shape.capitalize())


static func foot_label(foot: String) -> String:
	return FOOT_LABELS.get(foot, foot.capitalize())


static func is_jam(shape: String) -> bool:
	return JAMS.has(shape)


## A stable 0..1 for a hold's place on the pitch.
static func _roll(r: int, c: int) -> float:
	var h := (r * 73856093) ^ (c * 19349663) ^ 0x5bd1e995
	h = (h ^ (h >> 13)) * 1274126177
	return float((h >> 8) & 0xffff) / 65535.0
