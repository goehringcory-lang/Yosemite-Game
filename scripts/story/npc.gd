class_name NPC
extends CharacterBody2D
## A person the player can talk to. What they say comes from QuestLog, based
## on their quests and the player's progress. Visitors just chat.
##
## Place NPCs in a story overlay (scenes/story/content/<region>.tscn). Set
## [member spot] to a marker name so they follow the map if it's regenerated,
## and [member wander_radius] to let them stroll around it.

const FRAME_TIME := 0.18
## Sheet rows, matching the player's sheet.
const ROWS := {Vector2i.DOWN: 0, Vector2i.UP: 1, Vector2i.LEFT: 2, Vector2i.RIGHT: 3}

@export var character: CharacterData
## Named spot in the region (a Marker2D in Markers or the generated Spawns) to
## start at. Empty keeps the position set in the scene.
@export var spot: String
## Offset from [member spot], so several people can share one.
@export var offset := Vector2.ZERO
## How far they stroll from where they start. 0 = stays put.
@export var wander_radius := 0.0
@export var walk_speed := 16.0

var facing := Vector2i.DOWN
var _home := Vector2.ZERO
var _target := Vector2.ZERO
var _wait := 0.0
var _walk_time := 0.0
var _stuck_time := 0.0
var _talking := false
var _sprite: Sprite2D
var _rng := RandomNumberGenerator.new()
## The "!" or "?" over their head.
var quest_marker: QuestMarker
## Visitors keep hours (see is_out): out of doors by day, home at night.
var _out := true
var _routine_check := 0.0

## Visitors head home between these hours (each at their own time) and come
## back out in the morning; on a rainy day about half of them stay in.
const HOME_FROM := 20.0
const HOME_SPREAD := 2.0
const OUT_FROM := 7.0


func _ready() -> void:
	if spot != "":
		var region := _find_region()
		var marker: Marker2D = region.get_spawn(spot) if region else null
		if marker:
			global_position = marker.global_position + offset
		else:
			push_warning("%s: no spot named '%s'" % [name, spot])
	_home = global_position
	_target = _home
	_rng.seed = hash(name)
	_wait = _rng.randf_range(0.5, 3.0)
	# Wanderers bump into the map (layer 1) and the player (layer 2).
	collision_mask = 3 if wander_radius > 0.0 else 0
	if character and character.sprite_sheet:
		_sprite = Sprite2D.new()
		_sprite.texture = character.sprite_sheet
		_sprite.hframes = 3
		_sprite.vframes = 4
		_sprite.offset = Vector2(0, -11)
		add_child(_sprite)
	_update_frame(false)
	queue_redraw()
	if character and not character.visitor:
		quest_marker = QuestMarker.new(character.id)
		add_child(quest_marker)


func _process(delta: float) -> void:
	_routine_check -= delta
	if _routine_check > 0.0 or character == null or not character.visitor:
		return
	_routine_check = 0.5
	var out := is_out()
	if out != _out and not _talking:
		_set_out(out)


## True when this visitor is about: from OUT_FROM until their own hour
## between HOME_FROM and HOME_FROM + HOME_SPREAD, and not kept in by rain.
func is_out() -> bool:
	if character == null or not character.visitor:
		return true
	var hour := GameClock.minutes / 60.0
	var home_at := HOME_FROM + float(absi(hash(name)) % 100) / 100.0 * HOME_SPREAD
	if hour >= home_at or hour < OUT_FROM:
		return false
	return not (Weather.today().rain > 0.4 and absi(hash(name + "rain")) % 2 == 0)


## Fades them away (home for the night) or back.
func _set_out(out: bool) -> void:
	_out = out
	var hitbox := get_node_or_null("Hitbox") as Area2D
	if hitbox:
		hitbox.set_deferred("monitorable", out)
	set_deferred("collision_layer", 1 if out else 0)
	if out:
		visible = true
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 1.0 if out else 0.0, 0.8)
	if not out:
		tween.tween_callback(func() -> void: visible = _out)


func _find_region() -> Region:
	var node := get_parent()
	while node and not node is Region:
		node = node.get_parent()
	return node


## Placeholder figure in the character's color when there's no sprite sheet.
func _draw() -> void:
	GroundShadow.draw_under(self)
	if _sprite:
		return
	var color := character.color if character else Color.GRAY
	draw_rect(Rect2(-4, -14, 8, 11), color)
	draw_circle(Vector2(0, -17), 3.5, Color(0.8, 0.62, 0.48))
	draw_rect(Rect2(-4, -3, 3, 3), color.darkened(0.4))
	draw_rect(Rect2(1, -3, 3, 3), color.darkened(0.4))


func _physics_process(delta: float) -> void:
	if wander_radius <= 0.0 or _talking:
		return
	if _wait > 0.0:
		_wait -= delta
		if _wait <= 0.0:
			_target = _home + Vector2.from_angle(_rng.randf() * TAU) * _rng.randf_range(0.3, 1.0) * wander_radius
			_stuck_time = 0.0
		return
	var to_target := _target - global_position
	if to_target.length() < 2.0 or _stuck_time > 1.0:
		velocity = Vector2.ZERO
		_wait = _rng.randf_range(1.5, 5.0)
		_update_frame(false)
		return
	velocity = to_target.normalized() * walk_speed
	var before := global_position
	move_and_slide()
	if global_position.distance_to(before) < walk_speed * delta * 0.25:
		_stuck_time += delta
	_face(to_target)
	_walk_time += delta
	_update_frame(true)


func _face(direction: Vector2) -> void:
	if absf(direction.x) > absf(direction.y):
		facing = Vector2i.RIGHT if direction.x > 0 else Vector2i.LEFT
	else:
		facing = Vector2i.DOWN if direction.y > 0 else Vector2i.UP


func _update_frame(walking: bool) -> void:
	if not _sprite:
		return
	var column := 0
	if walking:
		column = 1 + int(_walk_time / FRAME_TIME) % 2
	_sprite.frame = ROWS[facing] * 3 + column


func interact(player: Player) -> void:
	_talking = true
	velocity = Vector2.ZERO
	_face(player.global_position - global_position)
	_update_frame(false)
	_hop()
	if quest_marker:
		quest_marker.hidden_while_talking = true
		quest_marker.refresh()
	if character and not character.visitor:
		Friendship.note_talk(character.id)
	if character and character.visitor:
		var line := character.idle_lines[_rng.randi() % character.idle_lines.size()] if not character.idle_lines.is_empty() else ""
		await DialogueBox.say_to(player, [{"speaker": character.display_name, "text": line}])
	else:
		await DialogueBox.say_to(player, QuestLog.talk_to(character.id))
		if QuestLog.final_entry_pending() and character.id == "galen_clark":
			await _write_last_page(player)
	_talking = false
	if quest_marker:
		quest_marker.hidden_while_talking = false
		quest_marker.refresh()


## True if this person keeps friendship hearts (visitors just pass through).
func can_receive_gift() -> bool:
	return character != null and not character.visitor and GiftGiving.possible(character.id)


func receive_gift(player: Player) -> void:
	if character == null or character.visitor or _talking:
		return
	_talking = true
	velocity = Vector2.ZERO
	_face(player.global_position - global_position)
	_update_frame(false)
	_hop()
	await GiftGiving.offer(player, character.id, character.display_name, self)
	_talking = false


## A small hop of greeting when you start talking to them.
func _hop() -> void:
	var target: Node2D = _sprite if _sprite else self
	if target == self:
		return
	var tween := create_tween()
	tween.tween_property(_sprite, "position:y", -3.0, 0.07).set_ease(Tween.EASE_OUT)
	tween.tween_property(_sprite, "position:y", 0.0, 0.1).set_ease(Tween.EASE_IN)


## After The Last Page, Clark hands you the Register to write your own entry.
func _write_last_page(player: Player) -> void:
	player.can_act = false
	var box := DialogueBox.open(player)
	var options := PackedStringArray()
	for entry: Dictionary in QuestLog.FINAL_ENTRIES:
		options.append(entry.choice)
	var pick := await box.choose("What do you write on the last page?", options)
	if pick >= 0:
		await box.say(QuestLog.write_final_entry(pick))
	box.close()
	player.can_act = true
