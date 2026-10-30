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
@export var walk_speed := 32.0
## For someone who moves house during the story (CharacterData.early_home):
## which of their two homes this node stands at. They're only here while
## they live here.
@export_enum("Always", "Early home", "Later home") var stays := 0
## Only here while a quest is on one step, as "quest_id:step index" (the
## chef waiting under the carved oak while you walk out to meet him).
@export var only_on_step := ""
## Away while a quest is on one step, as "quest_id:step index" (the chef's
## out of his kitchen then).
@export var away_on_step := ""
## Never strolls, whatever the hour (the crowd in the Guardian's cave).
@export var stands_still := false
## A day, as Stardew Valley's villagers keep one: stops like "9:00 plaza",
## each a time and a spot in this region, in order. They walk to each stop
## by the open ground (WalkGrid) when its time comes and stroll about it
## until the next. The first stop is home: a visitor comes out of it in the
## morning and walks back to it to go in at night; someone with quests stays
## out, standing at it overnight, and should be back at [member spot]
## through the middle of the day so the Journal's "where to find them" holds.
## Empty keeps them about [member spot] all day.
@export var timetable: PackedStringArray
## Someone who trades as well as talks (Greg, with his flies): after what
## they have to say, their offers come up, as a Vendor's do. Only while
## there's something on offer.
@export var shop: ShopData

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
## The timetable as [minutes, spot] pairs, and the stop they're keeping.
var _stops: Array = []
var _stop := -1
## The turning points still to walk through on the way to a stop.
var _route := PackedVector2Array()
var _heading_home := false
## Walking pace between stops (tests speed it up).
var travel_speed := TRAVEL_SPEED
## Life while standing about (see _idle_life): the emote last shown in this
## conversation, the day a friend was last greeted, a breath, a glance about.
var _last_emote := ""
var _greeted_day := -1
var _breath := 0.0
var _glance := 0.0
var _glance_back := Vector2i.ZERO
var _doze := 0.0
var _base_offset_y := 0.0

## Visitors head home between these hours (each at their own time) and come
## back out in the morning; on a rainy day about half of them stay in.
const HOME_FROM := 20.0
const HOME_SPREAD := 2.0
const OUT_FROM := 7.0
## People with quests keep a day of their own close to their spot, so you can
## always find them: at their post first thing, strolling about it through
## the middle of the day (up to STROLL px), staying nearer in the evening, and
## standing at it again overnight.
const STROLL := 72.0
## How fast people walk between stops (pixels a second): a purposeful walk,
## quicker than a stroll, slower than the player.
const TRAVEL_SPEED := 56.0
## A friend (this many hearts or more) waves when you walk up, once a day,
## from within GREET_REACH px.
const GREET_HEARTS := 1
const GREET_REACH := 88.0
## Standing about: a breath every BREATH seconds (the sprite rises 2 px), and
## a look round every GLANCE_MIN to GLANCE_MAX seconds for GLANCE_HOLD.
const BREATH := 0.9
const GLANCE_MIN := 5.0
const GLANCE_MAX := 11.0
const GLANCE_HOLD := 1.4
## People with quests doze on their feet late at night: "Zzz" every DOZE s.
const DOZE := 6.0


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
	_stops = parse_timetable(timetable)
	if not _stops.is_empty():
		# Start the day where the timetable has them now.
		_stop = stop_index(GameClock.minutes)
		# (not snapped to the walk grid yet: the map's bodies may not be in
		# the physics space until the next frame)
		var at: Variant = _spot_position(_stops[_stop][1] if is_out() else _stops[0][1], false)
		if at != null:
			global_position = at
			_home = at
			_target = at
	# Wanderers (and quest givers, who stroll by day) bump into the map
	# (layer 1) and the player (layer 2).
	collision_mask = 3 if wander_radius > 0.0 or not _stops.is_empty() or (character and not character.visitor) else 0
	if character and character.sprite_sheet:
		_sprite = Sprite2D.new()
		_sprite.texture = character.sprite_sheet
		_sprite.hframes = 3
		_sprite.vframes = 4
		_sprite.offset = Vector2(0, -22)
		_base_offset_y = _sprite.offset.y
		add_child(_sprite)
	_update_frame(false)
	queue_redraw()
	# The crowd in the Guardian's cave came to see you, not to hand out errands.
	if character and not character.visitor and not stands_still:
		quest_marker = QuestMarker.new(character.id)
		add_child(quest_marker)
	if _comes_and_goes():
		QuestLog.changed.connect(_refresh_stay)
		_refresh_stay()
	add_to_group("talkers")
	_glance = _rng.randf_range(GLANCE_MIN, GLANCE_MAX)
	_doze = _rng.randf_range(0.0, DOZE)


## A line of a conversation was just shown (DialogueBox.say). If it's theirs,
## they show how it feels over their head: "!" when surprised, a note when
## glad, a drop when it's hard to say (Emote.for_line), never the same one
## twice running.
func on_line(speaker: String, text: String, mood: String) -> void:
	if not _talking or character == null or speaker != character.display_name:
		return
	var kind := Emote.for_line(text, mood)
	if kind != "" and kind != _last_emote:
		Emote.pop(self, kind)
		_last_emote = kind


## Standing about, people aren't statues: they breathe, glance round now and
## then, wave to a friend walking up (once a day), and doze late at night.
func _idle_life(delta: float) -> void:
	if _sprite == null or not visible or _talking:
		return
	var standing := velocity == Vector2.ZERO and _route.is_empty()
	_breath += delta
	_sprite.offset.y = _base_offset_y - (2.0 if standing and int(_breath / BREATH) % 2 == 1 else 0.0)
	if not standing:
		_glance_back = Vector2i.ZERO
		return
	if _greet_friend():
		return
	_glance -= delta
	if _glance <= 0.0:
		if _glance_back != Vector2i.ZERO:
			facing = _glance_back
			_glance_back = Vector2i.ZERO
			_glance = _rng.randf_range(GLANCE_MIN, GLANCE_MAX)
		else:
			_glance_back = facing
			var turns: Array[Vector2i] = [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.DOWN]
			turns.erase(facing)
			facing = turns[_rng.randi() % turns.size()]
			_glance = GLANCE_HOLD
		_update_frame(false)
	if character and not character.visitor and not stands_still and is_dozing_hour():
		_doze -= delta
		if _doze <= 0.0:
			_doze = DOZE
			Emote.pop(self, "sleep")


## True late at night, when people with quests nod off at their spot.
static func is_dozing_hour() -> bool:
	var hour := GameClock.minutes / 60.0
	return hour >= 23.0 or hour < 5.0


## A friend walking up gets a wave, once a day: they turn to you and a note
## pops up. True if they waved just now.
func _greet_friend() -> bool:
	if character == null or character.visitor or stands_still or is_dozing_hour():
		return false
	var today := Friendship.today()
	if _greeted_day == today or Friendship.hearts(character.id) < GREET_HEARTS:
		return false
	var world := get_tree().get_first_node_in_group("world")
	var player: Node2D = world.player if world and "player" in world else null
	if player == null or player.global_position.distance_to(global_position) > GREET_REACH:
		return false
	_greeted_day = today
	_face(player.global_position - global_position)
	_update_frame(false)
	Emote.pop(self, "heart" if Friendship.hearts(character.id) >= 3 else "glad")
	return true


## True if the story moves them about (see [member stays], [member only_on_step]
## and [member away_on_step]).
func _comes_and_goes() -> bool:
	return stays != 0 or only_on_step != "" or away_on_step != ""


## True while this node is where the person is now (see [member stays],
## [member only_on_step] and [member away_on_step]).
func is_here() -> bool:
	if character == null:
		return true
	if only_on_step != "" and not _on_step(only_on_step):
		return false
	if away_on_step != "" and _on_step(away_on_step):
		return false
	if stays == 0:
		return true
	return character.at_early_home(QuestLog.is_completed) == (stays == 1)


## True while the quest in [param quest_step] ("quest_id:step index") is on that step.
static func _on_step(quest_step: String) -> bool:
	var parts := quest_step.split(":")
	return parts.size() == 2 and QuestLog.active.get(parts[0], -1) == int(parts[1])


## Shows or hides them as they move between their two homes. Never in the
## middle of a conversation: they finish talking first.
func _refresh_stay() -> void:
	if _talking:
		return
	var here := is_here()
	visible = here
	set_deferred("collision_layer", 1 if here else 0)
	var hitbox := get_node_or_null("Hitbox") as Area2D
	if hitbox:
		hitbox.set_deferred("monitorable", here)


func _process(delta: float) -> void:
	_idle_life(delta)
	_routine_check -= delta
	# Visitors keep hours; people with quests keep a timetable if they have
	# one (always out: they stand at their first stop overnight).
	if _routine_check > 0.0 or character == null or (not character.visitor and _stops.is_empty()):
		return
	_routine_check = 0.5
	var out := is_out()
	if _stops.is_empty():
		if out != _out and not _talking:
			_set_out(out)
		return
	if _talking:
		return
	if not out and _out and not _heading_home:
		# home time: walk back to the first stop, then go in (see _arrive)
		_heading_home = true
		_go_to(_stops[0][1])
	elif out and not _out:
		# morning: out of the door at home
		_heading_home = false
		var home: Variant = _spot_position(_stops[0][1])
		if home != null:
			global_position = home
		_stop = -1
		_set_out(true)
	if out and not _heading_home:
		var now := stop_index(GameClock.minutes)
		if now != _stop:
			_stop = now
			_go_to(_stops[now][1])


## [param lines] ("9:00 plaza", "13:30 pool_side") as [minutes, spot] pairs
## in time order. Lines that don't read are skipped with a warning.
static func parse_timetable(lines: PackedStringArray) -> Array:
	var stops := []
	for line in lines:
		var parts := line.strip_edges().split(" ", false)
		var clock := parts[0].split(":") if parts.size() == 2 else PackedStringArray()
		if clock.size() != 2 or not clock[0].is_valid_int() or not clock[1].is_valid_int():
			push_warning("timetable: can't read '%s'" % line)
			continue
		stops.append([int(clock[0]) * 60 + int(clock[1]), parts[1]])
	stops.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	return stops


## Which stop of the timetable holds at [param minutes] past midnight: the
## last one begun, or home (the first) before the day's first stop.
func stop_index(minutes: int) -> int:
	var index := 0
	for i in _stops.size():
		if _stops[i][0] <= minutes:
			index = i
	return index


## Where this person stands at [param spot_name]: the marker, moved a little
## their own way so people sharing a stop don't stand in one another, onto
## open ground. Null if the region has no such spot.
func _spot_position(spot_name: String, snap := true) -> Variant:
	var region := _find_region()
	var marker: Marker2D = region.get_spawn(spot_name) if region else null
	if marker == null:
		push_warning("%s: no spot named '%s'" % [name, spot_name])
		return null
	var nudge := Vector2.from_angle(float(absi(hash(name + spot_name)) % 628) / 100.0) * 20.0
	# at their own spot they stand just where the scene puts them
	if spot_name == spot:
		nudge = offset
	var at := marker.global_position + nudge
	if snap:
		at = WalkGrid.of(region).nearest_open(at)
	return at


## Sets off for [param spot_name] by the open ground.
func _go_to(spot_name: String) -> void:
	var at: Variant = _spot_position(spot_name)
	if at == null:
		return
	_home = at
	_target = at
	_route = WalkGrid.of(_find_region()).route(global_position, at)
	if _route.is_empty():
		_route = PackedVector2Array([at])
	_stuck_time = 0.0
	_wait = 0.0


## The end of a walk: at a stop they stroll about it; at home time they go in.
func _arrive() -> void:
	velocity = Vector2.ZERO
	_update_frame(false)
	_wait = _rng.randf_range(1.0, 4.0)
	if _heading_home:
		_set_out(false)


## True while walking between stops.
func is_travelling() -> bool:
	return not _route.is_empty()


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
	draw_rect(Rect2(-8, -28, 16, 22), color)
	draw_circle(Vector2(0, -34), 7.0, Color(0.8, 0.62, 0.48))
	draw_rect(Rect2(-8, -6, 6, 6), color.darkened(0.4))
	draw_rect(Rect2(2, -6, 6, 6), color.darkened(0.4))


## How far from their spot they wander now: their own wander radius, or for
## people with quests, their time of day (see STROLL).
func roam_radius() -> float:
	if stands_still:
		return 0.0
	if character == null or character.visitor:
		return wander_radius
	var hour := GameClock.minutes / 60.0
	if hour >= 9.0 and hour < 17.0:
		return maxf(wander_radius, STROLL)
	if hour >= 17.0 and hour < 21.0:
		return maxf(wander_radius, STROLL * 0.5)
	if hour >= 21.0 or hour < 6.0:
		return 0.0
	return wander_radius


func _physics_process(delta: float) -> void:
	if _talking or not visible:
		return
	if not _route.is_empty():
		_follow_route(delta)
		return
	if _heading_home:
		return
	var radius := roam_radius()
	if radius <= 0.0:
		# standing at their spot: walk back to it first if they're out
		if global_position.distance_to(_home) <= 4.0 or _stuck_time > 1.0:
			if velocity != Vector2.ZERO:
				velocity = Vector2.ZERO
				_update_frame(false)
			return
		_target = _home
		_wait = 0.0
	if _wait > 0.0:
		_wait -= delta
		if _wait <= 0.0:
			_target = _home + Vector2.from_angle(_rng.randf() * TAU) * _rng.randf_range(0.3, 1.0) * radius
			_stuck_time = 0.0
		return
	var to_target := _target - global_position
	if to_target.length() < 4.0 or _stuck_time > 1.0:
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


## One step along the route. Someone in the way (the player, another
## person) holds them up a moment, then they find a way round.
func _follow_route(delta: float) -> void:
	var to_point := _route[0] - global_position
	if to_point.length() < 4.0:
		_route.remove_at(0)
		_stuck_time = 0.0
		if _route.is_empty():
			_arrive()
		return
	# the last bit of a step lands on the point rather than past it
	velocity = to_point.normalized() * minf(travel_speed, to_point.length() / delta)
	var before := global_position
	move_and_slide()
	if global_position.distance_to(before) < velocity.length() * delta * 0.25:
		_stuck_time += delta
		if _stuck_time > 1.5:
			_stuck_time = 0.0
			var goal := _route[_route.size() - 1]
			var again := WalkGrid.of(_find_region()).route(global_position, goal)
			# no way round: skip ahead rather than stand stuck forever
			_route = again if not again.is_empty() and again[0].distance_to(_route[0]) > 4.0 else _route.slice(1)
			if _route.is_empty():
				_arrive()
	_face(to_point)
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
	_last_emote = ""
	_glance_back = Vector2i.ZERO
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
		var lines := Festivals.talk_to(character.id)
		lines.append_array(BoardRequests.deliver(character.id))
		lines.append_array(QuestLog.talk_to(character.id))
		if shop and not Vendor.offers_open(shop).is_empty():
			player.can_act = false
			var box := DialogueBox.open(player)
			await box.say(lines)
			await Vendor.trade_menu(box, shop, character.display_name, true)
			box.close()
			player.can_act = true
		else:
			await DialogueBox.say_to(player, lines)
		if QuestLog.final_entry_pending() and character.id == "galen_clark":
			await _write_last_page(player)
	_talking = false
	if _comes_and_goes():
		_refresh_stay()
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
	tween.tween_property(_sprite, "position:y", -6.0, 0.07).set_ease(Tween.EASE_OUT)
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
