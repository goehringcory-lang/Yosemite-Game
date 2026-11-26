class_name ClimberArt
extends ClimberView
## The v2 climber (thread 9): a hi-res, full-body climber seen from behind,
## animated between the poses the body system commits, with the rope from the
## belay through every clipped piece, the ghost of the move you aim at, and
## falls that drop, catch, bounce and swing.
##
## How it's drawn: the skeleton (ClimberRig) is solved every frame from the
## animated contacts (ClimberMotion) and painted with hard-edged polygons
## (ClimberPainter) into a SubViewport at a fixed density, two texels per
## world pixel at normal zoom: one window pixel each, like the old full-density
## climber. That texture is shown with nearest filtering, snapped to its texel
## grid, so the climber stays crisp pixel art however the camera moves; when
## the camera zooms in a long way the bake density steps up in whole numbers.
## The same bake, darkened and offset, is the contact shadow on the rock.
##
## It reads the session and the bus and never changes either (CONTRACTS.md);
## nothing waits on it. Plugged in by path: ClimbSystems makes it from
## scripts/climb/v2/art/climber.gd.

## Bake canvas size, metres round the hips.
const BAKE_M := Vector2(2.8, 3.0)
## Where the hips sit in the bake, as a share of its size from the top left.
const BAKE_HIP := Vector2(0.5, 0.55)
## Contact shadow: offset from the climber (world px, away from the sun) and tint.
const SHADOW_OFFSET := Vector2(2.5, 3.5)
const SHADOW_TINT := Color(0.05, 0.05, 0.12, 0.32)
const MAX_DENSITY := 4

var motion := ClimberMotion.new()
var rig := ClimberRig.new()
var painter := ClimberPainter.new()
## Texels per world pixel now.
var density := 2

var _bake: SubViewport
var _canvas: _Canvas
var _sprite := Sprite2D.new()
var _shadow := Sprite2D.new()
var _ghost_bake: SubViewport
var _ghost_canvas: _Canvas
var _ghost_sprite := Sprite2D.new()
var _ghost_rig: ClimberRig
var _ghost_painter := ClimberPainter.new()
var _ghost_move: V2Move
## The previewed move's strain signs from effort (tremble, fail...), its
## crux tells (hip_x-1, foot_2, hand_rh...) and the ghost limbs marked wrong.
var _ghost_signs := {}
var _ghost_tells := PackedStringArray()
var _ghost_warn := {}
var _fx := _Fx.new()
var _pose_key := 0
var _last_move: V2Move
var _held_item := ""
## The rope's whip after a catch (1 at rest; springs back after going taut).
var _rope_k := 1.0
var _rope_v := 0.0
var _caught_seen := -1.0
## True to keep the style set on [member painter] (the look sheet) instead of
## following the player's look.
var style_locked := false


## A canvas inside a bake: paints the rig it's given.
class _Canvas extends Node2D:
	var painter: ClimberPainter
	var rig: ClimberRig

	func _draw() -> void:
		if painter and rig and not rig.joint.is_empty():
			painter.paint(self, rig)


## Chalk puffs, grit and dust, in world pixels, in front of the climber.
class _Fx extends Node2D:
	var puffs: Array[Dictionary] = []
	var time := 0.0

	func add(pos: Vector2, kind: String, size: float) -> void:
		puffs.append({"pos": pos, "kind": kind, "size": size, "t0": time})
		if puffs.size() > 40:
			puffs.pop_front()

	func step(delta: float) -> void:
		time += delta
		var keep: Array[Dictionary] = []
		for p in puffs:
			if time - float(p.t0) < (1.2 if p.kind == "dust" else 0.7):
				keep.append(p)
		puffs = keep
		queue_redraw()

	func _draw() -> void:
		for p in puffs:
			var age := time - float(p.t0)
			var pos: Vector2 = p.pos
			var size: float = p.size
			match str(p.kind):
				"chalk":
					var s := age / 0.7
					for i in 5:
						var a := float(i) * 1.26 + size
						var off := Vector2(cos(a), sin(a) - 0.6) * (2.0 + 7.0 * s) * size
						draw_circle(pos + off + Vector2(0, -3.0 * s), (1.0 + 2.2 * s) * size, Color(0.96, 0.94, 0.88, 0.55 * (1.0 - s)))
				"grit":
					for i in 3:
						var x := (float(i) - 1.0) * 2.0
						draw_rect(Rect2(pos + Vector2(x, 2.0 + age * age * 90.0 * (1.0 + 0.3 * i)), Vector2(1, 1)), Color(0.35, 0.32, 0.3, 1.0 - age / 0.7))
				"dust":
					var s := age / 1.2
					for i in 7:
						var a := float(i) * 0.9
						draw_circle(pos + Vector2(cos(a) * (4.0 + 14.0 * s), sin(a) * 3.0 + 10.0 * s), 1.5 + 4.0 * s, Color(0.78, 0.74, 0.66, 0.4 * (1.0 - s)))
						draw_rect(Rect2(pos + Vector2((float(i) - 3.0) * 3.0, age * age * 200.0 + float(i)), Vector2(1, 1)), Color(0.3, 0.28, 0.27, 1.0 - s))


func bind(p_session: ClimbSession) -> void:
	session = p_session
	var bus := session.bus
	bus.pitch_started.connect(_on_pitch_started)
	bus.move_committed.connect(_on_move_committed)
	bus.aim_changed.connect(_on_aim_changed)
	bus.hip_changed.connect(_on_hip_changed)
	bus.hand_swapped.connect(_on_hand_swapped)
	bus.effort_changed.connect(_on_effort_changed)
	bus.rested.connect(_on_rested)
	bus.food_eaten.connect(_on_food_eaten)
	bus.rope_pulled.connect(_on_rope_pulled)
	bus.clipped.connect(_on_clipped)
	bus.piece_offered.connect(_on_piece_offered)
	bus.piece_placed.connect(_on_piece_placed)
	bus.fall_started.connect(_on_fall_started)
	bus.crux_sent.connect(_on_crux_sent)


func _ready() -> void:
	if not style_locked or painter.style == null:
		painter.style = ClimberStyle.current()
	_ghost_painter.style = painter.style
	_ghost_painter.ghost = true
	_bake = _make_bake()
	_canvas = _Canvas.new()
	_canvas.painter = painter
	_canvas.rig = rig
	_bake.add_child(_canvas)
	_ghost_bake = _make_bake()
	_ghost_canvas = _Canvas.new()
	_ghost_canvas.painter = _ghost_painter
	_ghost_bake.add_child(_ghost_canvas)
	for s: Sprite2D in [_shadow, _ghost_sprite, _sprite]:
		s.centered = false
		s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		add_child(s)
	_sprite.name = "Body"
	_shadow.name = "Shadow"
	_ghost_sprite.name = "Ghost"
	_sprite.texture = _bake.get_texture()
	_shadow.texture = _bake.get_texture()
	_shadow.modulate = SHADOW_TINT
	_ghost_sprite.texture = _ghost_bake.get_texture()
	_ghost_sprite.material = _ghost_material()
	_ghost_sprite.visible = false
	_fx.name = "Fx"
	add_child(_fx)
	_resize_bakes()
	if session and session.pose:
		motion.snap(session.pose)
		_pose_key = _key(session.pose)


func _make_bake() -> SubViewport:
	var vp := SubViewport.new()
	vp.transparent_bg = true
	vp.disable_3d = true
	vp.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	return vp


func _resize_bakes() -> void:
	var k := ClimbV2.PX_PER_M * density
	var size := Vector2i(ceili(BAKE_M.x * k), ceili(BAKE_M.y * k))
	for vp: SubViewport in [_bake, _ghost_bake]:
		if vp and vp.size != size:
			vp.size = size
	painter.k = k
	_ghost_painter.k = k
	painter.ol = maxf(1.0, density * 0.5)
	_ghost_painter.ol = painter.ol
	for s: Sprite2D in [_sprite, _shadow, _ghost_sprite]:
		s.scale = Vector2.ONE / density


## The bake's anchor: the texel the hips land on.
func _anchor() -> Vector2:
	return (BAKE_M * BAKE_HIP * ClimbV2.PX_PER_M * density).floor()


func _ghost_material() -> ShaderMaterial:
	var sh := Shader.new()
	sh.code = """
shader_type canvas_item;
uniform vec4 tint : source_color = vec4(0.95, 0.92, 0.82, 0.6);
void fragment() {
	vec4 c = texture(TEXTURE, UV);
	// A checker of every other window pixel: reads as see-through pixel art.
	vec2 g = floor(FRAGCOORD.xy);
	float keep = mod(g.x + g.y, 2.0);
	float edge = step(c.r, 0.5);
	// Red fill marks a limb the crux says is wrong.
	float wrong = step(0.5, c.r) * step(c.g, 0.5);
	vec3 col = mix(tint.rgb, tint.rgb * 0.35, edge);
	col = mix(col, vec3(1.0, 0.25, 0.2), wrong);
	COLOR = vec4(col, c.a * max(tint.a, wrong * 0.8) * max(keep, max(edge, wrong)));
}
"""
	var mat := ShaderMaterial.new()
	mat.shader = sh
	return mat


# ---------------------------------------------------------------- the contract

func show_pose(pose: V2Pose) -> void:
	if pose == null:
		return
	var key := _key(pose)
	if key != _pose_key:
		_pose_key = key
		motion.retarget(pose, null)


func show_ghost(move: V2Move) -> void:
	_ghost_move = move if move and move.to else null
	if _ghost_move:
		_ghost_signs = {}
		if session.sys and session.sys.effort and session.sys.effort.session and session.sys.effort.has_method("ghost_signs"):
			_ghost_signs = session.sys.effort.ghost_signs(_ghost_move)
		_ghost_tells = crux_tells(_ghost_move)
		_ghost_warn = {}
		for tell: String in _ghost_tells:
			if tell.begins_with("hand_"):
				_ghost_warn[StringName(tell.trim_prefix("hand_"))] = true
		_ghost_rig = ghost_rig(_ghost_move, motion.time)
		_ghost_canvas.rig = _ghost_rig
		_ghost_canvas.queue_redraw()
		var mat := _ghost_sprite.material as ShaderMaterial
		var strain := clampf(maxf(_ghost_move.strain, float(_ghost_signs.get("tremble", 0.0))), 0.0, 1.0)
		var tint := Color(0.95, 0.92, 0.82, 0.62).lerp(Color(1.0, 0.62, 0.25, 0.7), strain)
		if not _ghost_move.valid or _ghost_signs.get("fail", false):
			tint = Color(1.0, 0.32, 0.28, 0.6)
		mat.set_shader_parameter("tint", tint)
	_ghost_sprite.visible = _ghost_move != null and not motion.falling()


func show_fall(fall: V2Fall) -> void:
	_start_fall(fall)


## The effort system draws its strain signs on the climber through us, so
## its stand-in overlay stands down (PR #206's handshake).
func draws_effort_signs() -> bool:
	return true


## The effort system's strain signs (session.notes.effort.signs), or {}.
func effort_signs() -> Dictionary:
	if session == null:
		return {}
	var n: Variant = session.notes.get(&"effort", session.notes.get("effort", null))
	if n is Dictionary:
		var signs: Variant = (n as Dictionary).get("signs", null)
		if signs is Dictionary:
			return signs
	return {}


## What a crux says is wrong with [param move] before you commit it, from
## its "crux_miss:<tell>" tags: hip_x-1 / hip_x1 (hips square, the body would
## barn-door that way), hip_y-1 (hips too high), hip_y1 (should stand up),
## foot_1 / foot_2 (a foot would skate), hand_lh / hand_rh (the wrong hand).
static func crux_tells(move: V2Move) -> PackedStringArray:
	var out := PackedStringArray()
	for tag in move.tags:
		if tag.begins_with("crux_miss:"):
			for part in tag.trim_prefix("crux_miss:").split(",", false):
				out.append(part.strip_edges())
	return out


## The ghost's skeleton at [param time]: the previewed pose, acting out what
## a crux says is wrong with it (shown on the body, not as a meter).
func ghost_rig(move: V2Move, time: float) -> ClimberRig:
	var r := ClimberRig.new()
	var pose := move.to
	r.hip = pose.hip
	r.ends = ClimberRig.settle_free(pose, ClimberMotion._pose_ends(pose))
	r.twist = float(pose.facing)
	for l in V2Pose.LIMBS:
		r.bend[l] = r.bend_wanted(l, pose.tags)
	r.look = pose.hip + Vector2(0, 1.6)
	for tell in _ghost_tells:
		match tell:
			"hip_x-1", "hip_x1":
				# The barn door: the body swings open off its hands.
				var dir := -1.0 if tell == "hip_x-1" else 1.0
				var open := (0.5 + 0.5 * sin(time * 5.0)) * 0.14
				r.hip += Vector2(dir * open, -open * 0.3)
				r.twist = dir
				for f: StringName in [&"lf", &"rf"]:
					r.ends[f] = (r.ends[f] as Vector2) + Vector2(dir * open * 1.6, open * 0.4)
			"hip_y-1":
				r.hip += Vector2(0, 0.05 + 0.02 * sin(time * 4.0))
			"hip_y1":
				r.hip += Vector2(0, -0.07 + 0.02 * sin(time * 4.0))
			"foot_1", "foot_2":
				var f: StringName = &"lf" if tell == "foot_1" else &"rf"
				r.ends[f] = (r.ends[f] as Vector2) + Vector2(sin(time * 40.0) * 0.03 - 0.02 * fmod(time * 2.0, 1.0), -0.04 * fmod(time * 2.0, 1.0))
	r.solve()
	return r


## Matches the wall's light (night, a headlamp) if the look can tell us.
func _light() -> void:
	var look: Node = get_parent().get_node_or_null("Look") if get_parent() else null
	if look and look.has_method("light_at"):
		var c: Variant = look.light_at(rig.hip + Vector2(0, 0.5))
		if c is Color:
			modulate = c


# ---------------------------------------------------------------- frames

func _process(delta: float) -> void:
	if session == null or session.pose == null:
		return
	# The session is the truth: any pose change (a hand off to clip, a hip
	# shift, a settle) the screen didn't pass on is picked up here.
	show_pose(session.pose)
	_step(delta)


## One frame of animation and drawing (tests call it directly).
func _step(delta: float) -> void:
	var want := clampi(roundi(2.0 * _zoom()), 1, MAX_DENSITY)
	if want != density:
		density = want
		_resize_bakes()
	if session.effort:
		motion.pump = session.effort.pump
		motion.gas = session.effort.gas / maxf(session.effort.gas_cap, 0.01)
	motion.signs = effort_signs()
	_light()
	motion.update_bends(session.pose.tags)
	motion.step(delta)
	motion.apply(rig)
	_paint_extras()
	_place(_sprite, rig.hip)
	_place(_shadow, rig.hip)
	_shadow.position += SHADOW_OFFSET
	_canvas.queue_redraw()
	if _ghost_move and _ghost_rig:
		_ghost_rig = ghost_rig(_ghost_move, motion.time)
		_ghost_canvas.rig = _ghost_rig
		var tremble := clampf(maxf(_ghost_move.strain, float(_ghost_signs.get("tremble", 0.0))), 0.0, 1.0)
		var shake := Vector2(sin(motion.time * 83.0), cos(motion.time * 71.0)) * 1.3 * tremble
		_place(_ghost_sprite, _ghost_rig.hip)
		_ghost_sprite.position += shake
		_ghost_painter.hip = _ghost_rig.hip
		_ghost_painter.kinds = _kinds_of(_ghost_move.to)
		_ghost_painter.holds = _holds_of(_ghost_move.to)
		_ghost_painter.warn = _ghost_warn
		_ghost_canvas.queue_redraw()
		_ghost_sprite.visible = not motion.falling()
	for f: Dictionary in motion.fx:
		_fx.add(px(f.pos), str(f.kind), float(f.size))
		if f.has("limb") and f.kind == "chalk":
			motion.chalk[f.limb] = maxf(float(motion.chalk.get(f.limb, 0.7)) - 0.12, 0.0)
	motion.fx.clear()
	_fx.step(delta)
	if motion.caught_at != _caught_seen and motion.caught_at >= 0.0:
		_caught_seen = motion.caught_at
		_rope_k = 0.0
		_rope_v = -3.0
	_rope_v += ((1.0 - _rope_k) * 300.0 - _rope_v * 6.0) * delta
	_rope_k += _rope_v * delta
	queue_redraw()


func _zoom() -> float:
	var x := get_global_transform_with_canvas().get_scale().x if is_inside_tree() else 1.0
	return absf(x) if x != 0.0 else 1.0


## Places a bake's sprite so its hips land on [param hip], the bake's texels
## lined up with the world's 1/density grid (no shimmer as it moves).
func _place(sprite: Sprite2D, at_hip: Vector2) -> void:
	var q := px(at_hip) * density
	var base := q.floor()
	var anchor := _anchor()
	if sprite == _sprite:
		painter.origin = anchor + (q - base)
		painter.hip = at_hip
	elif sprite == _ghost_sprite:
		_ghost_painter.origin = anchor + (q - base)
	sprite.position = (base - anchor) / density


func _paint_extras() -> void:
	var pose := session.pose
	painter.kinds = _kinds_of(motion.target if motion.target else pose)
	painter.holds = _holds_of(motion.target if motion.target else pose)
	painter.chalk = motion.chalk
	painter.swing = motion.swing()
	var signs := motion.signs
	painter.sweat = float(signs.get("sweat", clampf(1.0 - motion.gas, 0.0, 1.0) * 0.8 + clampf(motion.pump - 0.6, 0.0, 0.4)))
	var band := str(signs.get("band", ""))
	painter.flush = {"fresh": 0.0, "working": 0.25, "pumped": 0.7, "boxed": 1.0}.get(band, clampf((motion.pump - 0.4) / 0.6, 0.0, 1.0))
	painter.rack = _rack()
	painter.held_piece = _item_color(_held_item) if _held_item != "" else Color(0, 0, 0, 0)
	if painter.style.version != PlayerLook.version and not style_locked:
		painter.style = ClimberStyle.current()
		_ghost_painter.style = painter.style


func _kinds_of(pose: V2Pose) -> Dictionary:
	var out := {}
	for l in V2Pose.LIMBS:
		out[l] = (pose.limb(l) as V2Limb).kind
	return out


func _holds_of(pose: V2Pose) -> Dictionary:
	var out := {}
	for l in V2Pose.LIMBS:
		var limb: V2Limb = pose.limb(l)
		var h := session.wall.hold(limb.id) if session.wall and limb.kind == &"hold" else null
		out[l] = h.kind if h else &""
	return out


func _rack() -> Dictionary:
	var out := {"cams": [], "draws": 0, "nuts": 0, "slings": 0}
	if session.rack == null:
		return out
	for it: Dictionary in session.rack.items:
		var n := int(it.get("count", 0))
		match str(it.get("kind", "")):
			"cam":
				for i in n:
					(out.cams as Array).append(_item_color(str(it.id)))
			"draw":
				out.draws += n
			"nut", "offset":
				out.nuts += n
			"sling":
				out.slings += n
	return out


## A rack item's color: its own, else the Camalot color for its width.
func _item_color(item_id: String) -> Color:
	var it: Dictionary = session.rack.item(item_id) if session.rack else {}
	var c: Variant = it.get("color", null)
	if c is Color:
		return c
	if c is String and str(c) != "":
		return Color(str(c))
	const CAMALOT := ["3a6fc0", "8d8f94", "6f5aa6", "4f9a3a", "c8382e", "dcaa2c", "2f6cc0", "a0a2a8"]
	return Color(CAMALOT[clampi(int(it.get("width_min", 4)), 0, 7)])


static func _key(pose: V2Pose) -> int:
	return hash(pose.to_dict())


# ---------------------------------------------------------------- rope and shadow

func _draw() -> void:
	if session == null or session.wall == null or rig.tip.is_empty():
		return
	_draw_rope()


## The rope from the belay, through every clipped piece's draw, to the knot at
## the harness; while pulling rope to clip, through the pulling hand with the
## bight hanging below it. Sag comes from the slack out (V2Rope.slack_m); after
## a catch it snaps taut and whips back.
func _draw_rope() -> void:
	var pts: Array[Vector2] = [session.wall.start]
	var extra: Array[float] = []
	for id in session.rope.clipped:
		var p := session.piece(id)
		if p == null or p.popped:
			continue
		pts.append(p.pos - Vector2(0, p.sling_m))
		extra.append(0.025 if extra.is_empty() else 0.012)
	var tie := rig.hip + Vector2(0, 0.1)
	var rope_hand := _rope_hand()
	var slack := maxf(session.rope.slack_m, 0.0)
	if rope_hand != &"":
		pts.append(rig.tip[rope_hand])
		extra.append(0.03)
		pts.append(tie)
		extra.append(maxf(slack, 0.12))
	else:
		pts.append(tie)
		extra.append(slack + 0.06)
	var line := PackedVector2Array()
	for i in pts.size() - 1:
		var seg := _sag(pts[i], pts[i + 1], extra[i] * maxf(_rope_k, 0.0), i == pts.size() - 2)
		if i > 0:
			seg.remove_at(0)
		line.append_array(seg)
	var c := painter.style.rope if painter.style else ClimberStyle.ramp(ClimbSprites.ROPE_C)
	draw_polyline(line, c[ClimberStyle.OUTLINE], 2.2)
	draw_polyline(line, c[ClimberStyle.BASE], 1.2)


func _rope_hand() -> StringName:
	for hand: StringName in [&"lh", &"rh"]:
		if motion.kinds.get(hand, &"") == &"rope":
			return hand
	return &""


## A rope segment from [param a] to [param b] (metres) with [param extra]
## metres more rope than the straight line, hanging under gravity (a parabola
## close enough to a catenary), as world pixels.
func _sag(a: Vector2, b: Vector2, extra: float, last: bool) -> PackedVector2Array:
	var d := b - a
	var length := d.length()
	var out := PackedVector2Array()
	var n := clampi(int(length / 0.12), 2, 48)
	var depth := sqrt(3.0 * maxf(length, 0.05) * maxf(extra, 0.0) / 8.0)
	depth = minf(depth, 4.0)
	var dir := d / length if length > 0.001 else Vector2.DOWN
	var perp := Vector2(1, 0) if absf(dir.y) > 0.7 else Vector2(-dir.y, dir.x)
	var side := absf(dir.y) * 0.55
	var sway := sin(motion.time * 1.1 + a.x) * 0.012 * (1.0 if last else 0.4)
	for i in n + 1:
		var t := float(i) / n
		var bow := 4.0 * t * (1.0 - t)
		var p := a.lerp(b, t) + Vector2(0, -depth * bow) + perp * (depth * side + sway) * bow
		out.append(px(p))
	return out


# ---------------------------------------------------------------- events

func _on_pitch_started(_pitch: int) -> void:
	if session.pose:
		motion.snap(session.pose)
		_pose_key = _key(session.pose)


func _on_move_committed(move: V2Move) -> void:
	_last_move = move
	_pose_key = _key(session.pose)
	motion.retarget(session.pose, move)
	if move.hold_id != "":
		var h := session.wall.hold(move.hold_id)
		if h:
			motion.look_goal = h.pos + Vector2(0, 0.6)


func _on_aim_changed(hold_id: String) -> void:
	var h := session.wall.hold(hold_id) if hold_id != "" and session.wall else null
	motion.look_goal = h.pos if h else motion.hip + Vector2(0, 1.6)


func _on_hip_changed(hip: Vector2) -> void:
	motion.lean_goal = ((hip - session.pose.hip) * 0.35).limit_length(0.12)


func _on_hand_swapped(hand: StringName) -> void:
	var l: V2Limb = session.pose.limb(hand)
	motion.look_goal = l.pos + Vector2(0, 0.5)


func _on_effort_changed(effort: V2Effort) -> void:
	motion.pump = effort.pump
	motion.gas = effort.gas / maxf(effort.gas_cap, 0.01)


## Shaking out: the free arm drops and flicks; the head drops too.
func _on_rested(kind: StringName) -> void:
	if kind == &"hang" or kind == &"belay":
		return
	# The effort system says which arm it's shaking out; else the free one.
	var n: Variant = session.notes.get(&"effort", session.notes.get("effort", null))
	var hand: StringName = StringName(str((n as Dictionary).get("arm", ""))) if n is Dictionary else &""
	if not hand in [&"lh", &"rh"]:
		hand = _free_hand()
	if hand == &"":
		return
	var side := -1.0 if hand == &"lh" else 1.0
	var pts: Array = []
	for i in 9:
		pts.append(Vector2(side * (0.26 + 0.04 * (i % 2)), -0.32 - 0.05 * (i % 2)))
	motion.gesture(hand, pts, 1.4)
	motion.look_goal = motion.hip + Vector2(side * 0.3, -1.0)
	motion.chalk[hand] = 1.0


func _on_food_eaten(_food_id: String, _gas: float) -> void:
	var hand := _free_hand()
	if hand == &"":
		return
	var side := -1.0 if hand == &"lh" else 1.0
	# Into the pack pocket at the hip, up to the mouth, a few chews, back.
	motion.gesture(hand, [Vector2(side * 0.16, 0.02), Vector2(side * 0.08, 0.66), Vector2(side * 0.07, 0.64),
		Vector2(side * 0.08, 0.66), Vector2(side * 0.07, 0.64)], 1.1)


## One arm-length of rope: the hand drops to the knot, grabs and pulls up.
func _on_rope_pulled(_arms: int, _needed: int) -> void:
	var hand := _rope_hand()
	if hand == &"":
		hand = _free_hand()
	if hand == &"":
		return
	var side := -1.0 if hand == &"lh" else 1.0
	motion.gesture(hand, [Vector2(side * 0.03, 0.12), Vector2(side * 0.03, 0.1),
		Vector2(side * 0.12, 0.85), Vector2(side * 0.14, 1.12)], 0.32)
	motion.exertion = minf(motion.exertion + 0.08, 1.0)


func _on_clipped(_piece_id: String, _back: bool) -> void:
	var hand := _rope_hand()
	if hand != &"":
		# The wrist flick that snaps the gate shut.
		motion.gesture(hand, [Vector2.ZERO, Vector2(0.03, 0.03), Vector2(-0.01, -0.01), Vector2.ZERO], 0.16, &"base")


func _on_piece_offered(item_id: String, _reading: Dictionary) -> void:
	_held_item = item_id
	for hand: StringName in [&"lh", &"rh"]:
		if motion.kinds.get(hand, &"") == &"gear":
			# Feeding the piece into the crack: in, wiggle, settle.
			motion.gesture(hand, [Vector2.ZERO, Vector2(0, 0.04), Vector2(0.015, 0.02), Vector2(-0.015, 0.03), Vector2.ZERO], 0.5, &"base")


func _on_piece_placed(_piece_id: String) -> void:
	_held_item = ""
	for hand: StringName in [&"lh", &"rh"]:
		if motion.kinds.get(hand, &"") == &"gear":
			# Two sharp tugs to set it.
			motion.gesture(hand, [Vector2.ZERO, Vector2(0, -0.05), Vector2.ZERO, Vector2(0, -0.05), Vector2.ZERO], 0.4, &"base")


func _on_fall_started(fall: V2Fall) -> void:
	_start_fall(fall)


func _start_fall(fall: V2Fall) -> void:
	if fall == null:
		return
	var catcher := session.piece(fall.caught_by) if fall.caught_by != "" else null
	var at := catcher.pos if catcher else session.wall.start
	motion.start_fall(fall, at)
	_ghost_sprite.visible = false


func _on_crux_sent(_zone_id: String, clean: bool) -> void:
	# A long breath out, and a look up the pitch.
	motion.exertion = 1.0 if clean else 0.7
	motion.look_goal = motion.hip + Vector2(0, 2.5)


func _free_hand() -> StringName:
	if session.sys and session.sys.body and session.sys.body.session:
		var h: StringName = session.sys.body.free_hand()
		if h != &"":
			return h
	return session.pose.other_hand() if session.pose else &""
