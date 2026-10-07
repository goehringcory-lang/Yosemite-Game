class_name InfoSign
extends StaticBody2D
## An interpretive sign. Interact to read it.
##
## A sign can carry an extra paragraph that only shows when the time, season,
## moon or story is right. Leave the [code]extra_*[/code] fields alone and it
## behaves like a plain sign. Every condition that is set must hold.

@export var title := ""
@export_multiline var text := ""

@export_group("Extra text")
## Added after [member text] while the conditions below hold. Empty means none.
@export_multiline var extra_text := ""
## Hours of the day, from (included) to (excluded). It wraps past midnight, so
## (21, 2) is 9 PM until 2 AM. (-1, -1) means any time.
@export var extra_hours := Vector2i(-1, -1)
## A GameClock.Season, or -1 for any season.
@export var extra_season := -1
## Only on a full-moon night (GameClock.is_full_moon).
@export var extra_full_moon := false
## A quest id: only once the player has finished it.
@export var extra_after_quest := ""
## Optional extra test that returns a bool, for conditions the fields above
## can't say (set from code).
var extra_when := Callable()


func get_prompt() -> String:
	return "Read: %s" % title


func interact(_player: Player) -> void:
	get_tree().call_group("hud", "show_info", title, current_text())


## True while the extra paragraph is showing.
func extra_active() -> bool:
	if extra_text == "":
		return false
	if extra_hours.x >= 0 and not GameClock.hour_in_range(extra_hours.x, extra_hours.y):
		return false
	if extra_season >= 0 and GameClock.season != extra_season:
		return false
	if extra_full_moon and not GameClock.is_full_moon():
		return false
	if extra_after_quest != "" and not QuestLog.is_completed(extra_after_quest):
		return false
	if extra_when.is_valid() and not extra_when.call():
		return false
	return true


## What the sign says right now.
func current_text() -> String:
	if extra_active():
		return "%s\n\n%s" % [text, extra_text]
	return text
