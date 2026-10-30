class_name HalfDomeCables
extends RegionDoor
## The cables up the back of Half Dome. One of these stands at the foot of
## the cables (going up) and one at the top (coming down). The one at the
## foot draws the whole line: two steel cables on their posts up the granite
## to [member top], with a board across the rock at each pair of posts. In
## winter the posts are pulled and the cables lie flat on the rock.
##
## Going up is the CablesMinigame, and needs the wilderness permit, the
## cables up (Park.SEASONAL "half_dome_cables") and dry rock. Coming down is
## a walk, open all year: Snake Dike climbers come down this way too.
## It's a RegionDoor to the other end (target_region, target_spawn, minutes),
## so the tests and the world see the two halves of Half Dome as joined.

## true at the foot of the cables, false at the top.
@export var up := true
## Where the cables reach, from here (the foot's line only).
@export var top := Vector2(0, -400)

const MINIGAME := preload("res://scripts/world/cables_minigame.gd")
const CABLE := Color("c8ccd4")
const CABLE_SHADE := Color("6e737c")
const POST := Color("4a4e56")
const BOARD := Color("8a6a44")
const OUTLINE := Color("2a1f1a")
## Pairs of posts up the line, as drawn.
const POSTS := 12


func _ready() -> void:
	queue_redraw()


func get_prompt() -> String:
	return "Go up the cables" if up else "Go down the cables"


## Why you can't go up now, or "" if you can.
static func closed_reason() -> String:
	if not Park.is_open("half_dome_cables"):
		return Park.SEASONAL["half_dome_cables"].why
	if float(Weather.today().get("rain", 0.0)) > 0.0:
		return "Rain on the granite. Under the cables the rock is polished like glass by a century of boots, and wet it's like ice. Nobody goes up in the rain: come back on a dry day."
	if not Backcountry.has_permit():
		return "A ranger's sign at the foot of the cables: Half Dome hikers need a permit. Ranger Hodges writes wilderness permits at the ranger station in Yosemite Village."
	return ""


func interact(player: Player) -> void:
	if not up:
		_go(player, "You edge down the cables backwards, board by board, to the shoulder.")
		return
	var why := closed_reason()
	if why != "":
		DialogueBox.say_to(player, [{"speaker": "", "text": why}])
		return
	if GameClock.is_too_late_for(minutes * 2):
		DialogueBox.say_to(player, [{"speaker": "", "text": "Too late in the day to start up the cables: you'd be coming down them in the dark."}])
		return
	var crowd := CablesMinigame.crowd_for(GameClock.minutes / 60.0, GameClock.season)
	player.can_act = false
	var box := DialogueBox.open(player)
	var choice := await box.choose("The cables: 400 feet of steel up the back of the Dome, at about 45 degrees. %s." % CablesMinigame.CROWDS[crowd].note, ["Go up", "Not yet"])
	box.close()
	if choice != 0:
		player.can_act = true
		return
	var tree := player.get_tree()
	var was_paused := GameClock.paused
	GameClock.paused = true
	var game: CablesMinigame = MINIGAME.new()
	tree.root.add_child(game)
	game.start(crowd)
	var made_it: bool = await game.finished
	var outcome := game.outcome
	var reached := game.board
	game.queue_free()
	GameClock.paused = was_paused
	player.can_act = true
	if made_it:
		Backcountry.mark(Backcountry.CABLES)
		_go(player, "")
	elif outcome == "backed_down":
		GameClock.advance_minutes(20)
		DialogueBox.say_to(player, [{"speaker": "", "text": "Your arms gave out %d boards up. You backed down to the foot of the cables to rest. Try again when you've got your breath back." % reached}])


func _go(player: Player, message: String) -> void:
	var tree := player.get_tree()
	var world := tree.get_first_node_in_group("world")
	if world == null:
		return
	await world.go_to_region(target_region, target_spawn, minutes)
	if message != "":
		tree.call_group("hud", "show_message", message)


## The cables up the rock (drawn from the foot only), or the top posts.
func _draw() -> void:
	if not up:
		_post(Vector2(-16, 0))
		_post(Vector2(16, 0))
		return
	var standing := Park.is_open("half_dome_cables")
	var left_foot := Vector2(-16, 0)
	var right_foot := Vector2(16, 0)
	if standing:
		for i in POSTS + 1:
			var t := float(i) / POSTS
			var l := left_foot.lerp(top + left_foot, t)
			var r := right_foot.lerp(top + right_foot, t)
			draw_rect(Rect2(l.x - 1, l.y - 1, r.x - l.x + 2, 4), OUTLINE)
			draw_rect(Rect2(l.x, l.y, r.x - l.x, 2), BOARD)
			_post(l)
			_post(r)
	var lift := Vector2(0, -12) if standing else Vector2.ZERO
	for side in [left_foot, right_foot]:
		draw_line(side + lift, side + top + lift, OUTLINE, 3.0)
		draw_line(side + lift, side + top + lift, CABLE, 1.0)
	if not standing:
		for side in [left_foot, right_foot]:
			draw_line(side + Vector2(1, 1), side + top + Vector2(1, 1), CABLE_SHADE, 1.0)


func _post(at: Vector2) -> void:
	draw_rect(Rect2(at.x - 2, at.y - 14, 4, 15), OUTLINE)
	draw_rect(Rect2(at.x - 1, at.y - 13, 2, 13), POST)
	draw_rect(Rect2(at.x - 1, at.y - 13, 1, 13), CABLE)
