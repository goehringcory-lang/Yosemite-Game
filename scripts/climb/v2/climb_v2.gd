class_name ClimbV2
extends RefCounted
## Climbing v2: the switch that picks it over the old climbing screen, and the
## numbers every v2 system shares (scale, body size, rope).
##
## v2 is built beside the old climbing (ClimbState, ClimbMinigame) and only
## runs when it is switched on, for all routes or route by route:
##   - the environment: VALLEY_CLIMB_V2=1 (every route) or
##     VALLEY_CLIMB_V2=swan_slab,nutcracker (those routes);
##   - the project setting valley/climb_v2 (the same values);
##   - or, from code and tests, ClimbV2.force (true / false; null = ask the
##     two above).
## See scripts/climb/v2/CONTRACTS.md for how the v2 pieces fit together.

## Bumped when a contract changes in a way other threads must know about.
const CONTRACT_VERSION := 2

## Wall space is in metres: x to the right, y UP, (0, 0) at the pitch's lower
## belay. Views turn it into screen pixels with [method to_screen].
const PX_PER_M := 60.0
## The climber, shared by reach (body), rope pulls (rope) and the drawn
## skeleton (art), so they always agree.
const HEIGHT_M := 1.75
## Hip to shoulder, and shoulder to fingertips at full stretch.
const TORSO_M := 0.55
const ARM_M := 0.72
## Hip to sole with the leg straight.
const LEG_M := 0.9
## One pull of rope: an arm-length, from the tie-in to as high as you reach.
const ARM_PULL_M := 0.7
## The rope you lead on (Gear's "70 m rope").
const ROPE_M := 70.0

## null asks the environment and project setting; true or false overrides.
static var force: Variant = null


## True if v2 runs for every route, or for any route at all when
## [param route_id] is given and listed.
static func enabled_for(route_id: String) -> bool:
	if force != null:
		return bool(force)
	var value := _setting()
	if value == "" or value == "0" or value == "false":
		return false
	if value == "1" or value == "true" or value == "all":
		return true
	return route_id in value.split(",", false)


## True if v2 is on for every route.
static func enabled() -> bool:
	if force != null:
		return bool(force)
	return _setting() in ["1", "true", "all"]


static func _setting() -> String:
	var env := OS.get_environment("VALLEY_CLIMB_V2").strip_edges().to_lower()
	if env != "":
		return env.replace(" ", "")
	return str(ProjectSettings.get_setting("valley/climb_v2", "")).strip_edges().to_lower().replace(" ", "")


## A wall position (metres, y up) as a point on the climbing canvas, for a
## camera centred on [param focus] with [param zoom] (1 = PX_PER_M).
static func to_screen(wall_pos: Vector2, focus: Vector2, screen_size: Vector2, zoom := 1.0) -> Vector2:
	var d := (wall_pos - focus) * PX_PER_M * zoom
	return screen_size * 0.5 + Vector2(d.x, -d.y)


## The inverse of [method to_screen].
static func to_wall(screen_pos: Vector2, focus: Vector2, screen_size: Vector2, zoom := 1.0) -> Vector2:
	var d := (screen_pos - screen_size * 0.5) / (PX_PER_M * zoom)
	return focus + Vector2(d.x, -d.y)
