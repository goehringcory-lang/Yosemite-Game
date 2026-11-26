class_name WallSource
extends ClimbSystem
## Interface (thread 2, wall and routes): builds each pitch's V2Wall.
## Must be deterministic: the same route, pitch and seed give the same wall.


func id() -> StringName:
	return &"wall"


## How many pitches [param route] has on the v2 wall.
func pitch_count(route: RouteData) -> int:
	return maxi(1, route.pitches.size()) if route else 1


## Builds pitch [param pitch] of [param route].
func build_pitch(_route: RouteData, _pitch: int, _seed: int) -> V2Wall:
	return V2Wall.new()
