class_name MenuInput
extends RefCounted
## Input helpers shared by the menus.


## True when [param event] is a fresh press of [param action] ("move_up",
## "ui_down", ...). A key or button press counts once, but a held analog stick
## sends a motion event every frame it is past the deadzone, so a joypad axis
## only counts on the frame it crosses it. Without this one flick of the stick
## moves a menu cursor many steps.
static func pressed(event: InputEvent, action: StringName) -> bool:
	if not event.is_action_pressed(action):
		return false
	return not event is InputEventJoypadMotion or Input.is_action_just_pressed(action)
