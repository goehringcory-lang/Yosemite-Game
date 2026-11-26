class_name ClimbSystems
extends RefCounted
## Finds each v2 system by a fixed path, so no thread edits this file to plug
## its system in: thread N writes its real system at the path below and the
## registry picks it up; until then (and whenever a test pins it) the
## permanent stub in contracts/stubs/ runs. The script at a path must extend
## that system's interface.

const ROOT := "res://scripts/climb/v2/"
## System -> [real path (owning thread's folder), stub path].
const SYSTEMS := {
	&"wall": ["wall/wall.gd", "contracts/stubs/wall_source_stub.gd"],
	&"body": ["body/body.gd", "contracts/stubs/body_stub.gd"],
	&"cruxes": ["cruxes/cruxes.gd", "contracts/stubs/crux_stub.gd"],
	&"effort": ["effort/effort.gd", "contracts/stubs/effort_stub.gd"],
	&"rope": ["rope/rope.gd", "contracts/stubs/rope_stub.gd"],
	&"gear": ["gear/gear.gd", "contracts/stubs/gear_stub.gd"],
	&"falls": ["falls/falls.gd", "contracts/stubs/falls_stub.gd"],
}
## Views: the climber (thread 9) and the look (thread 10).
const VIEWS := {
	&"climber": ["art/climber.gd", "contracts/stubs/climber_view_stub.gd"],
	&"look": ["look/look.gd", "contracts/stubs/look_stub.gd"],
}

## Name -> "stub" (always the stub) or "real" (fail loudly if missing).
## Tests pin the systems they don't own to their stubs, so another thread's
## merge can't change their results.
static var pins := {}


## The script path in use for [param name].
static func path_for(name: StringName) -> String:
	var entry: Array = SYSTEMS.get(name, VIEWS.get(name, []))
	if entry.is_empty():
		return ""
	var pin: String = pins.get(name, "")
	if pin != "stub" and (pin == "real" or ResourceLoader.exists(ROOT + entry[0])):
		return ROOT + entry[0]
	return ROOT + entry[1]


## True if [param name] runs its owning thread's real system.
static func is_real(name: StringName) -> bool:
	return not path_for(name).contains("/stubs/")


static func make(name: StringName) -> Object:
	var script: Script = load(path_for(name))
	return script.new() if script else null


## Pins every system and view to its stub except those in [param keep].
static func pin_stubs_except(keep: Array = []) -> void:
	pins.clear()
	for name: StringName in SYSTEMS.keys() + VIEWS.keys():
		if not name in keep:
			pins[name] = "stub"


## Makes every system for [param session] and attaches it.
static func build(session: ClimbSession) -> void:
	var s := session.sys
	s.wall = make(&"wall")
	s.body = make(&"body")
	s.cruxes = make(&"cruxes")
	s.effort = make(&"effort")
	s.rope = make(&"rope")
	s.gear = make(&"gear")
	s.falls = make(&"falls")
	for system in s.all():
		system.attach(session)
