class_name LookSound
extends RefCounted
## The climb's sounds (thread 10), all worked out from bus events: the rock
## under each hand by the kind of hold, the rope coming up hand over hand,
## clips, cams and nuts, a piece popping, the air of a fall and the rope's
## catch, chalk on a rest, food, cruxes, the top. Breathing comes in as the
## forearms pump and quickens with them. The wind and the valley's beds are
## Sound's "climb" mode, which reads ClimbLookLive.exposure().
##
## Mix rules: the same sound never plays twice inside SOUND_GAP, a sound
## with takes never repeats its last take, pitches wander a little, and a
## fall ducks the breathing for a moment. [member played] keeps what played
## (for tests); [member mute] stops the actual playing (headless tests).

const T := preload("res://scripts/climb/v2/look/look_tuning.gd")
## Sounds with numbered takes (name_1 ...).
const TAKES := {"climb_move": 3, "climb2_breath": 3}
## Hold kind -> [sound, pitch, dB]: small edges tick higher, slopers lower,
## jugs and horns get a slap, jams a scrunch.
const TOUCH := {
	&"jug": ["climb2_slap", 1.0, -2.0], &"horn": ["climb2_slap", 0.95, -3.0],
	&"edge": ["climb_move", 1.05, 0.0], &"crimp": ["climb_move", 1.18, -2.0],
	&"sloper": ["climb_move", 0.85, -1.0], &"pinch": ["climb_move", 0.95, -1.0],
	&"pocket": ["climb_move", 1.1, -2.0], &"jam": ["climb2_jam", 1.0, 0.0],
	&"stance": ["climb_move", 0.8, 0.0],
}

var played: Array[String] = []
var mute := false
## 0..1, how pumped (from effort_changed).
var pump := 0.0

var _last_at := {}
var _last_take := {}
var _time := 0.0
var _breath_wait := 1.0
var _duck := 0.0
var _gust_wait := 6.0


## Starts listening to [param bus].
func listen(bus: ClimbEvents, session: ClimbSession) -> void:
	bus.move_committed.connect(func(m: V2Move) -> void: _touch(session, m))
	bus.rope_pulled.connect(func(arms: int, needed: int) -> void:
		play("climb2_rope_pull", -2.0, 0.9 + 0.2 * clampf(float(arms) / maxf(needed, 1), 0.0, 1.0)))
	bus.clipped.connect(func(_id: String, back: bool) -> void:
		play("climb_clip", -3.0 if back else 0.0, 0.85 if back else 1.0))
	bus.piece_offered.connect(func(_item: String, _reading: Dictionary) -> void: play("climb2_cam_trigger", -4.0))
	bus.piece_placed.connect(func(id: String) -> void: _placed(session, id))
	bus.piece_popped.connect(func(_id: String) -> void: play("climb2_pop"))
	bus.fall_started.connect(func(_f: V2Fall) -> void:
		play("climb2_whoosh")
		_duck = T.DUCK_TIME)
	bus.fall_caught.connect(func(f: V2Fall) -> void:
		play("climb2_catch")
		if f.drop_m > 4.0:
			play("slack_twang", -6.0, 0.8))
	bus.rested.connect(func(_kind: StringName) -> void: play("climb_chalk"))
	bus.food_eaten.connect(func(_id: String, _gas: float) -> void: play("climb_eat"))
	bus.crux_entered.connect(func(_id: String) -> void: play("climb_crux", -8.0))
	bus.crux_sent.connect(func(_id: String, clean: bool) -> void:
		if clean:
			play("climb2_sent", -4.0))
	bus.pitch_finished.connect(func(_p: int) -> void: play("climb_clip", -2.0, 0.9))
	bus.climb_finished.connect(func(r: V2Result) -> void:
		if r.success:
			play("climb_topout"))
	bus.effort_changed.connect(func(e: V2Effort) -> void: pump = e.pump)


## Plays [param id] (a take of it, if it has takes) unless it just played.
func play(id: String, volume_db := 0.0, pitch := 1.0) -> bool:
	if _time - float(_last_at.get(id, -99.0)) < T.SOUND_GAP:
		return false
	_last_at[id] = _time
	var name := id
	var takes: int = TAKES.get(id, 0)
	if takes > 0:
		var last: int = _last_take.get(id, 0)
		# Any take but the last one.
		var take := randi_range(1, takes - 1) if last > 0 else randi_range(1, takes)
		if last > 0 and take >= last:
			take += 1
		_last_take[id] = take
		name = "%s_%d" % [id, take]
	played.append(name)
	if not mute:
		var sound := _sound()
		if sound:
			sound.play(name, volume_db, 0.06, pitch)
	return true


## Each frame: breathing with the pump, gusts with the wind and the height.
func step(delta: float, wind: float, exposure: float) -> void:
	_time += delta
	_duck = maxf(_duck - delta, 0.0)
	if pump >= T.BREATH_FROM:
		_breath_wait -= delta
		if _breath_wait <= 0.0:
			var hard := (pump - T.BREATH_FROM) / (1.0 - T.BREATH_FROM)
			play("climb2_breath", lerpf(-12.0, -3.0, hard) + (T.DUCK_DB if _duck > 0.0 else 0.0), lerpf(0.95, 1.1, hard))
			_breath_wait = lerpf(2.6, 1.0, hard) * randf_range(0.9, 1.1)
	else:
		_breath_wait = minf(_breath_wait, 0.6)
	var gusty := clampf(wind * 0.7 + exposure * 0.4, 0.0, 1.0)
	if gusty > 0.15:
		_gust_wait -= delta
		if _gust_wait <= 0.0:
			play("slack_gust", lerpf(-16.0, -6.0, gusty), randf_range(0.85, 1.1))
			_gust_wait = lerpf(18.0, 6.0, gusty) * randf_range(0.7, 1.3)


func _touch(session: ClimbSession, m: V2Move) -> void:
	var hold := session.wall.hold(m.hold_id) if session.wall else null
	var kind: StringName = hold.kind if hold else &"edge"
	var touch: Array = TOUCH.get(kind, TOUCH[&"edge"])
	var pitch: float = touch[1]
	if hold and kind == &"jug" and hold.size < 0.8:
		touch = TOUCH[&"edge"]
		pitch = 0.95
	play(touch[0], touch[2], pitch)


func _placed(session: ClimbSession, id: String) -> void:
	var piece := session.piece(id)
	var kind: StringName = piece.kind if piece else &"cam"
	match kind:
		&"nut":
			play("climb2_nut")
		&"pin":
			play("climb_pin")
		&"sling":
			play("climb_chalk", -4.0, 0.7)
		_:
			play("climb_cam")


func _sound() -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	return tree.root.get_node_or_null("/root/Sound") if tree else null
