class_name ClimbInput
extends RefCounted
## The verbs of the v2 climbing screen and the input actions that make them.
## The screen turns input events into verbs and hands them to the director;
## phases and bots speak in verbs only. Keys are the project's input map
## (project.godot), so the Controls page can rebind them.

const VERBS := {
	&"aim_up": &"move_up", &"aim_down": &"move_down", &"aim_left": &"move_left", &"aim_right": &"move_right",
	## Take the move / clip / offer and place / get back on.
	&"commit": &"use_tool",
	## Held: the arrows shift the hips instead of aiming.
	&"body": &"run",
	## The other hand moves next.
	&"swap": &"climb_swap",
	## Pull up an arm-length of rope (starts clipping the nearest piece).
	&"rope": &"climb_rope",
	## Open the rack at a crack.
	&"rack": &"climb_rack",
	## Shake out on a jug, stance or kneebar.
	&"rest": &"climb_rest",
	&"eat": &"interact",
	## Back out of clipping or placing; twice on the wall to retreat.
	&"cancel": &"ui_cancel",
}


## The verbs [param event] presses or releases: [[verb, pressed], ...].
static func verbs_for(event: InputEvent) -> Array:
	var out := []
	if event is InputEventKey and (event as InputEventKey).echo:
		return out
	for verb: StringName in VERBS:
		var action: StringName = VERBS[verb]
		if not InputMap.has_action(action):
			continue
		if event.is_action_pressed(action):
			out.append([verb, true])
		elif event.is_action_released(action):
			out.append([verb, false])
	return out
