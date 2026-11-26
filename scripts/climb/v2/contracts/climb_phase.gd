class_name ClimbPhase
extends RefCounted
## One phase of the climbing screen (climb, clip, place, fall, belay,
## special...). The director owns the table of phases and hands input verbs
## (ClimbInput) to the current one. A phase asks the director to change
## phase with [method ClimbDirector.go]; it changes game state only through
## its own system or the director's intents.

var director: ClimbDirector
var name: StringName = &""


func enter(p_director: ClimbDirector, _args := {}) -> void:
	director = p_director


func exit() -> void:
	pass


## The session changed under the phase (a move went in, a rest, food):
## re-read it.
func refresh() -> void:
	pass


## A verb (ClimbInput) was pressed ([param pressed] true) or released.
## Return true if it was used.
func handle(_verb: StringName, _pressed: bool) -> bool:
	return false


## Presentation-only time step (animation). Game state never waits on it.
func step(_delta: float) -> void:
	pass


## A short line for the HUD: what the keys do right now.
func hint() -> String:
	return ""
