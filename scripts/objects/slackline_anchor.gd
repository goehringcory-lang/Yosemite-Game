class_name SlacklineAnchor
extends Node2D
## One end of Wren's slackline: TravelSlackline puts this on every tree that
## could hold it, with a hitbox at the foot of the trunk. Interact to rig the
## line to the nearest tree the right distance off, walk it, or take it down.

const MINIGAME := preload("res://scripts/slackline/slackline_minigame.gd")


func _ready() -> void:
	name = "SlacklineAnchor"
	var hitbox := Area2D.new()
	hitbox.name = "Hitbox"
	hitbox.collision_layer = 4
	hitbox.collision_mask = 0
	hitbox.monitoring = false
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(28, 20)
	shape.shape = rect
	shape.position = Vector2(0, -6)
	hitbox.add_child(shape)
	add_child(hitbox)


func tree() -> StaticBody2D:
	return get_parent() as StaticBody2D


func rig_owner() -> TravelSlackline:
	var node := get_parent()
	while node and not node is Region:
		node = node.get_parent()
	return node.get_node_or_null("TravelSlackline") as TravelSlackline if node else null


func get_prompt() -> String:
	var rig := rig_owner()
	return "Walk your slackline" if rig and rig.is_rigged_on(tree()) else "Rig your slackline"


func interact(player: Player) -> void:
	var rig := rig_owner()
	if rig == null:
		return
	player.can_act = false
	var box := DialogueBox.open(player)
	var here := TravelSlackline.kind_of(tree())
	if rig.is_rigged_on(tree()):
		var other: StaticBody2D = rig.rigged[1] if rig.rigged[0] == tree() else rig.rigged[0]
		var text := "Your slackline runs %d m from this %s to the %s, tight and humming." % [TravelSlackline.meters_between(tree(), other), here, TravelSlackline.kind_of(other)]
		var choice := await box.choose(text, ["Walk the line", "Take it down", "Leave"])
		box.close()
		if choice == 0:
			await walk(player, rig.line())
			return
		if choice == 1:
			rig.take_down()
			Sound.play("ui_back")
		player.can_act = true
		return
	var partner := rig.partner_for(tree())
	if partner == null:
		await box.say([{"speaker": "", "text": "A sturdy %s, but there's no tree the right distance off to tie the other end to. A line wants a partner %d to %d meters away, off to one side." % [here, roundi(TravelSlackline.MIN_GAP / TravelSlackline.PIXELS_PER_METER), roundi(TravelSlackline.MAX_GAP / TravelSlackline.PIXELS_PER_METER)]}])
		box.close()
		player.can_act = true
		return
	var text := "Rig your slackline from this %s to the %s, %d m off? You'll pad both trunks so the slings don't scar the bark." % [here, TravelSlackline.kind_of(partner), TravelSlackline.meters_between(tree(), partner)]
	if not rig.rigged.is_empty():
		text += " (You'll take it down where it's rigged now.)"
	var choice := await box.choose(text, ["Rig it and walk", "Just rig it", "Leave"])
	box.close()
	if choice == 0 or choice == 1:
		rig.rig(tree(), partner)
		Sound.play("slack_twang", -4.0, 0.05, 1.1)
	if choice == 0:
		await walk(player, rig.line())
		return
	player.can_act = true


## Opens the slackline screen on [param line] and waits for the player to
## leave it (time passes the same way it does at Camp 4).
func walk(player: Player, line: Dictionary) -> void:
	var was_paused := GameClock.paused
	GameClock.paused = true
	var minigame: SlacklineMinigame = MINIGAME.new()
	minigame.setup(-1, line)
	player.get_tree().root.add_child(minigame)
	await minigame.finished
	var spent := minigame.minutes()
	GameClock.paused = was_paused
	player.can_act = true
	if spent > 0:
		GameClock.advance_minutes(spent)
