class_name Traveler
extends NPC
## One of the Travelers, walking their day (see Travelers.PLANS). Travelers
## says which part of the day they're on (a segment: a stop, or the walk
## across one area) and where the clock has them; this walks there along the
## measured way, hurrying a little when behind (stopped to talk, or waiting
## for you to get out of the road), and at a stop stands about like anyone
## else. Talk to them and they say where they're off to, or what they're
## doing there.

## How much quicker than Travelers.WALK_SPEED they go to catch up, and how
## far behind the clock (in pixels) before they do.
const CATCH_UP := 1.6
const BEHIND := 40.0
## Someone standing this close in the road ahead holds them up, for a moment.
const BLOCK_REACH := 24.0
const BLOCK_WAIT := 1.2
## How fast they step over to where they stand at a stop.
const STEP_SPEED := 30.0
const FADE := 0.6
const FACES := {"up": Vector2i.UP, "down": Vector2i.DOWN, "left": Vector2i.LEFT, "right": Vector2i.RIGHT}

## Their id in Travelers.PLANS.
var plan_id := ""
## The day they're walking (Travelers.today) and the segment of it they're on.
var day: Array = []
var segment: Dictionary = {}
## The way they're walking now, in their region's pixels, how long it is,
## how far along it they are and how far the clock would have them.
var _points := PackedVector2Array()
var _length := 0.0
var _along := 0.0
var _want := 0.0
## The clock has moved on past this segment: finish it, quickly.
var _hurry := false
var _held := 0.0
## Where they stand at a stop.
var _stand := Vector2.ZERO
var _said := ""
var _leaving := false


func _ready() -> void:
	super._ready()
	# They keep to the measured way, so nothing needs to stop them; walking,
	# you can walk through them (standing, they're in the way like anyone).
	collision_mask = 0
	collision_layer = 0
	if _sprite:
		# a child is drawn smaller, feet on the ground
		_sprite.scale = Vector2.ONE * float(Travelers.PLANS.get(plan_id, {}).get("scale", 1.0))
		LitSprites.attach_sprite(_sprite)


## Their own day, not NPC's hours or timetable: just standing about.
func _process(delta: float) -> void:
	_idle_life(delta)


## The region they're in now, as its id.
func region_id() -> String:
	var region := _find_region()
	return region.region_id if region else ""


## True while you're talking with them.
func busy() -> bool:
	return _talking


## Put straight into [param seg], [param f] of the way along it (a walk),
## fading in: coming out in the morning, or met in an area you just came to.
func arrive(seg: Dictionary, f: float, now: float) -> void:
	start(seg, false)
	if seg.kind == "walk":
		_along = f * _length
		_want = _along
		var at: Array = Travelers.point_along(_points, _along)
		_place(at[0])
		if at[1] != Vector2.ZERO:
			_face(at[1])
	else:
		_place(_stand)
		_face_stop()
	aim(seg.n, now)
	_update_frame(false)
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, FADE)


## Begins [param seg]: from wherever they are now, or with [param from_here]
## false, from its own start (just put there).
func start(seg: Dictionary, from_here := true) -> void:
	segment = seg
	_hurry = false
	_held = 0.0
	var region := _find_region()
	var here := region.to_local(global_position) if region else position
	if seg.kind == "walk":
		_points = Travelers.route(seg.region, seg.a, seg.b)
		# from where they are onto the way (over a seam they've come from
		# the last area's edge, a step or two short of this one's start)
		if _points.is_empty() or (from_here and _points[0].distance_to(here) > 2.0):
			_points.insert(0, here)
		_length = Travelers.length_of(_points)
		_along = 0.0
		_want = 0.0
		set_deferred("collision_layer", 0)
	else:
		_stand = Travelers.spot_point(seg.region, seg.point)
		if _stand == Vector2.INF:
			var marker: Marker2D = region.get_spawn(seg.spot) if region else null
			_stand = region.to_local(marker.global_position) if marker else here
		set_deferred("collision_layer", 1)


## Where the clock has them: segment [param target_n] of their day, at
## [param now]. Behind it, they finish this one first.
func aim(target_n: int, now: float) -> void:
	_hurry = target_n > segment.n
	if segment.kind == "walk" and not _hurry:
		_want = Travelers.progress(segment, now) * _length


## True once this segment is done with: walked to its end, or a stop the
## clock has moved on from.
func finished() -> bool:
	if _talking:
		return false
	if segment.kind == "walk":
		return _along >= _length - 0.5
	return _hurry


## Over a seam: moves into [param region] where they stand, and walks on
## into [param seg] there, gliding on as if nothing changed.
func hand_over(region: Region, seg: Dictionary) -> void:
	var at := global_position
	var was := position
	get_parent().remove_child(self)
	region.entities.add_child(self)
	global_position = at
	var smooth := get_node_or_null("SmoothMotion") as SmoothMotion
	if smooth:
		smooth.shift(position - was)
	start(seg)


## Done for the day: they fade away (home, or into their tent).
func go_in() -> void:
	_leaving = true
	velocity = Vector2.ZERO
	_update_frame(false)
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, FADE)
	tween.tween_callback(queue_free)


func _physics_process(delta: float) -> void:
	if _talking or _leaving or segment.is_empty():
		velocity = Vector2.ZERO
		return
	if segment.kind == "walk":
		_walk(delta)
	else:
		_stand_about(delta)


func _walk(delta: float) -> void:
	var goal := _length if _hurry else _want
	var ahead := goal - _along
	if ahead <= 0.5 or _blocked(delta):
		_halt()
		return
	var speed := Travelers.WALK_SPEED * (CATCH_UP if _hurry or ahead > BEHIND else 1.0)
	_along = minf(_along + minf(ahead, speed * delta), _length)
	var at: Array = Travelers.point_along(_points, _along)
	_move_to(at[0], delta)
	if at[1] != Vector2.ZERO:
		_face(at[1])
	_walk_time += delta
	_update_frame(true)


func _stand_about(delta: float) -> void:
	var region := _find_region()
	var here := region.to_local(global_position) if region else position
	var to_stand := _stand - here
	if to_stand.length() < 1.0:
		if velocity != Vector2.ZERO:
			_halt()
			_face_stop()
		return
	_move_to(here + to_stand.limit_length(STEP_SPEED * delta), delta)
	_face(to_stand)
	_walk_time += delta
	_update_frame(true)


## Steps to [param local] (their region's pixels) this tick, by the body so
## their feet kick up dust as they go.
func _move_to(local: Vector2, delta: float) -> void:
	var region := _find_region()
	var target := region.to_global(local) if region else local
	velocity = (target - global_position) / maxf(delta, 0.0001)
	move_and_slide()
	global_position = target


func _halt() -> void:
	if velocity != Vector2.ZERO:
		velocity = Vector2.ZERO
		_update_frame(false)


## True while someone (you) stands in the road just ahead: they wait a
## moment, then go on by.
func _blocked(delta: float) -> bool:
	var world := get_tree().get_first_node_in_group("world")
	var player: Node2D = world.player if world and "player" in world else null
	if player == null:
		return false
	var ahead: Array = Travelers.point_along(_points, minf(_along + 14.0, _length))
	var region := _find_region()
	var spot: Vector2 = region.to_global(ahead[0]) if region else ahead[0]
	if player.global_position.distance_to(spot) > BLOCK_REACH:
		_held = 0.0
		return false
	_held += delta
	return _held < BLOCK_WAIT


func _place(local: Vector2) -> void:
	var region := _find_region()
	global_position = region.to_global(local) if region else local


func _face_stop() -> void:
	var plan: Dictionary = Travelers.PLANS.get(plan_id, {})
	if plan.is_empty() or segment.is_empty() or segment.kind != "stop":
		return
	var stop: Dictionary = plan.stops[segment.stop]
	if stop.has("face"):
		facing = FACES.get(stop.face, facing)
		_update_frame(false)


## What they say: where they're off to, or what they're doing here.
func line_now() -> String:
	var lines: Array = Travelers.lines_for(plan_id, segment)
	if lines.is_empty():
		lines = Array(character.idle_lines) if character else []
	if lines.is_empty():
		return ""
	var pick: String = lines[_rng.randi() % lines.size()]
	if pick == _said and lines.size() > 1:
		pick = lines[(lines.find(pick) + 1) % lines.size()]
	_said = pick
	return pick


func interact(player: Player) -> void:
	_talking = true
	_last_emote = ""
	velocity = Vector2.ZERO
	_face(player.global_position - global_position)
	_update_frame(false)
	_hop()
	await DialogueBox.say_to(player, [{"speaker": character.display_name if character else "", "text": line_now()}])
	_talking = false
	_held = 0.0
	talked_to.emit()
