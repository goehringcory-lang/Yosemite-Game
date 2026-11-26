class_name ClimbSystemSet
extends RefCounted
## The seven v2 systems of a climb, typed by their interfaces, so a system
## can ask another a question: session.sys.effort.price(move).
## Filled by ClimbSystems.build.

var wall: WallSource
var body: BodySystem
var cruxes: CruxSystem
var effort: EffortSystem
var rope: RopeSystem
var gear: GearSystem
var falls: FallSystem


func all() -> Array[ClimbSystem]:
	var out: Array[ClimbSystem] = []
	for s: ClimbSystem in [wall, body, cruxes, effort, rope, gear, falls]:
		if s:
			out.append(s)
	return out
