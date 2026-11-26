class_name ClimbSystem
extends RefCounted
## Base of every v2 system (wall, body, cruxes, effort, rope, gear, falls).
## A system owns some session fields (CONTRACTS.md) and is the only thing that
## writes them. It talks to others only through session data, the other
## systems' pure queries (session.sys.<name>), and the bus.
##
## Queries (anything named like a question, or preview/price/risk) must be
## pure: no session changes and no random draws, because previews run on
## every aim change and the bot searches with them. Draw randomness only in
## mutators, from session.rng_for(id()).

var session: ClimbSession


## The system's name: wall, body, cruxes, effort, rope, gear or falls.
func id() -> StringName:
	return &""


func attach(p_session: ClimbSession) -> void:
	session = p_session


## Called when a pitch starts, after the wall is built and the pose set.
func pitch_started() -> void:
	pass


## Phase controllers this system supplies: phase name -> ClimbPhase.
## See ClimbDirector.PHASES for which system supplies which.
func phases() -> Dictionary:
	return {}


## A HUD or overlay node for the screen to mount (in a slot named after
## [method id]), or null. Overlays read the session and listen to the bus.
func make_overlay() -> Node:
	return null
