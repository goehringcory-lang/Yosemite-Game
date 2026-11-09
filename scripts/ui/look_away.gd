class_name LookAway
extends CanvasLayer
## Pauses the game when its window stops being the one in front (you switched
## to another program, or the laptop lid closed), so the day's clock, a climb
## or a fish on the line don't run on without you. Out walking, that opens
## the pause menu; in the middle of anything else (a climb, a conversation,
## the slackline) the whole game holds still under a "Paused" card until you
## press something. The "Pause when away" setting turns it off. World adds
## one.
##
##   look_away.away()        # what losing the window does
##   look_away.is_holding()  # true while the Paused card is up

const TITLE := "Paused"
const NOTE := "Press any key or button to carry on."

var _card: PanelContainer
var _holding := false
## The window is in front again, so the next press carries on. A click that
## brings the window back doesn't count as that press.
var _back := true


func _ready() -> void:
	layer = 40
	add_to_group("look_away")
	process_mode = Node.PROCESS_MODE_ALWAYS
	UiScale.layer(self)
	_card = PanelContainer.new()
	_card.visible = false
	add_child(_card)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 4)
	_card.add_child(column)
	var title := Label.new()
	title.text = TITLE
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", PauseMenu.HEADING)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title)
	var note := Label.new()
	note.text = NOTE
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(note)


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_FOCUS_OUT:
			away()
		NOTIFICATION_APPLICATION_FOCUS_IN:
			_back = true


func is_holding() -> bool:
	return _holding


## The window lost focus: pause, whichever way fits what's on screen.
func away() -> void:
	Settings.ensure_loaded()
	if not Settings.pause_away or not is_inside_tree():
		return
	Rumble.stop()
	_back = false
	if _holding or get_tree().paused:
		return
	var pause := get_tree().get_first_node_in_group("pause_menu") as PauseMenu
	if pause and pause.is_open():
		return # already paused
	var world := get_tree().get_first_node_in_group("world")
	var player: Player = world.player if world else null
	if pause and player and player.can_act:
		pause.open()
		return
	_holding = true
	get_tree().paused = true
	_card.visible = true
	_card.reset_size()
	_card.position = ((UiScale.SCREEN - _card.size) / 2.0).round()


## Carries on from the Paused card.
func carry_on() -> void:
	if not _holding:
		return
	_holding = false
	_card.visible = false
	get_tree().paused = false


func _input(event: InputEvent) -> void:
	if not _holding:
		return
	get_viewport().set_input_as_handled() # nothing reaches the game under the card
	if not _back:
		return
	if (event is InputEventKey or event is InputEventJoypadButton or event is InputEventMouseButton) and event.is_pressed() and not event.is_echo():
		carry_on()


func _exit_tree() -> void:
	if _holding:
		get_tree().paused = false
