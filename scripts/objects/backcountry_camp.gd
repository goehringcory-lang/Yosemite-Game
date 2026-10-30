class_name BackcountryCamp
extends StaticBody2D
## A tent site in a backcountry camp. With a wilderness permit your tent is
## pitched here, and you can sleep in it instead of going home: you wake up
## in camp and the game saves here (World.sleep). Your bear canister sits a
## little way off, and whatever doesn't fit in it is left for the bears
## (Backcountry.night_out). Without a permit it's a cleared spot you can't
## use yet.

## The spot (a Marker2D in the region) you wake up on.
@export var wake_spot := "camp"

const STONE := Color("8a8478")
const STONE_DARK := Color("4e4a44")
const OUTLINE := Color("2a1f1a")


func _ready() -> void:
	Inventory.changed.connect(_refresh)
	Gear.changed.connect(_refresh)
	_refresh()


func _refresh() -> void:
	$Sprite.visible = Backcountry.has_permit()
	queue_redraw()


func get_prompt() -> String:
	return "Sleep: Backcountry camp" if Backcountry.has_permit() else "Look at the tent site"


func interact(player: Player) -> void:
	if not Backcountry.has_permit():
		DialogueBox.say_to(player, [{"speaker": "", "text": "A flat spot of sand, cleared for a tent, with a ring of stones. To camp out here you need a wilderness permit. The rangers write them at the ranger station in Yosemite Village."}])
		return
	player.can_act = false
	var box := DialogueBox.open(player)
	var note := "Your tent, pitched in Little Yosemite Valley. Sleep out here tonight? You'll wake up in camp."
	if Backcountry.has_canister():
		note += " Your food goes in the bear canister (it holds %d things to eat)." % Backcountry.CANISTER_HOLDS
	var choice := await box.choose(note, ["Sleep", "Not yet"])
	box.close()
	player.can_act = true
	if choice == 0:
		get_tree().call_group("world", "sleep", false, wake_spot)


## Before the tent's up, a ring of stones on the sand; once you have your
## canister, it stands off to one side, away from the tent as it should be.
func _draw() -> void:
	if not Backcountry.has_permit():
		for i in 9:
			var a := TAU * i / 9.0
			var at := Vector2(cos(a) * 26.0, sin(a) * 9.0 - 10.0)
			draw_rect(Rect2(at - Vector2(3, 2), Vector2(6, 4)), OUTLINE)
			draw_rect(Rect2(at - Vector2(2, 2), Vector2(4, 3)), STONE)
			draw_rect(Rect2(at + Vector2(-2, 0), Vector2(4, 1)), STONE_DARK)
		return
	if Backcountry.has_canister():
		var c := Vector2(64, -2)
		draw_rect(Rect2(c.x - 7, c.y - 20, 14, 21), OUTLINE)
		draw_rect(Rect2(c.x - 6, c.y - 15, 12, 15), Color("3e424a"))
		draw_rect(Rect2(c.x - 6, c.y - 15, 3, 15), Color("6e737c"))
		draw_rect(Rect2(c.x - 6, c.y - 8, 12, 1), Color("24272d"))
		draw_rect(Rect2(c.x - 6, c.y - 19, 12, 4), Color("1e2026"))
		draw_rect(Rect2(c.x - 3, c.y - 18, 2, 1), Color("b8bcc4"))
		draw_rect(Rect2(c.x + 2, c.y - 18, 2, 1), Color("b8bcc4"))
