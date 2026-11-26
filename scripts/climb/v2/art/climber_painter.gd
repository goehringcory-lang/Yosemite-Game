class_name ClimberPainter
extends RefCounted
## Draws a solved ClimberRig onto a CanvasItem (the climber's bake canvas),
## seen from behind as the camera sees a climber on the wall: hard-edged cel
## shading (an outline, a shade, the base, a light, a highlight) lit from the
## upper left like the rest of the game, in the player's own look
## (ClimberStyle). Polygons have no anti-aliasing, so at the bake's fixed
## density every edge lands on whole texels like painted pixel art.
##
## Painted back to front: the far arm and leg (when turned side-on), the
## torso with shirt, harness, rack and chalk bag, the near leg and arm, hair
## that hangs on the back, then the head. Hands are small and plain (the back
## of the hand on the hold, its shape set by the hold); there are no
## close-ups of fingers gripping.

const L = preload("res://scripts/climb/v2/art/climber_style.gd")
## The light comes from the upper left (texel space: y down).
const LIGHT_DIR := Vector2(-0.6, -0.8)

## Texels per metre and where the rig's hips land on the canvas.
var k := 120.0
var origin := Vector2.ZERO
## The rig's hips (wall metres): every point is placed relative to them.
var hip := Vector2.ZERO
## Outline width, texels.
var ol := 1.0
## Single-tone silhouette for the ghost (white fill, dark outline).
var ghost := false
var style: ClimberStyle

## Per-drawing extras, set by the climber view before [method paint]:
## lh/rh/lf/rf -> what the limb is doing (V2Limb kind).
var kinds := {}
## lh/rh/lf/rf -> the hold kind under it (V2Hold.KINDS) or &"".
var holds := {}
## lh/rh -> chalk on the fingers, 0..1.
var chalk := {&"lh": 0.6, &"rh": 0.6}
## What hangs on the harness: cams (Array of Color), draws, nuts, slings.
var rack := {"cams": [], "draws": 0, "nuts": 0, "slings": 0}
## Dangling things swing by this (metres; secondary motion from the hips).
var swing := Vector2.ZERO
## A dark sweat patch on the back, 0..1.
var sweat := 0.0
## The forearms flush a little with pump, 0..1.
var flush := 0.0
## Ghost only: limbs drawn as wrong (the crux wants the other hand).
var warn := {}
## The color of a piece in the gear hand (placing), or transparent.
var held_piece := Color(0, 0, 0, 0)

var _c: CanvasItem
var _r: ClimberRig
## What the ghost fills with (white, or red on a limb marked wrong).
var _ghost_fill := Color.WHITE


## Texel position of wall point [param p].
func t(p: Vector2) -> Vector2:
	return origin + Vector2(p.x - hip.x, hip.y - p.y) * k


## Metres to texels, never thinner than one texel.
func m(v: float) -> float:
	return maxf(v * k, 1.0)


func paint(canvas: CanvasItem, rig: ClimberRig) -> void:
	_c = canvas
	_r = rig
	if style == null:
		style = ClimberStyle.current()
	var far_side := signf(rig.twist) if absf(rig.twist) > 0.3 else 0.0
	var far_arm: StringName = &"rh" if far_side > 0 else &"lh"
	var far_leg: StringName = &"rf" if far_side > 0 else &"lf"
	if far_side != 0.0:
		_arm(far_arm, true)
		_leg(far_leg, true)
		_leg(&"lf" if far_leg == &"rf" else &"rf", false, true)
	else:
		_leg(&"lf", false)
		_leg(&"rf", false)
	_torso()
	if far_side != 0.0:
		_arm(&"lh" if far_arm == &"rh" else &"rh", false)
	else:
		_arm(&"lh", false)
		_arm(&"rh", false)
	_head()
	_c = null
	_r = null


# ---------------------------------------------------------------- primitives

## A tapered capsule from a (radius ra) to b (radius rb), in texels.
func _caps(a: Vector2, b: Vector2, ra: float, rb: float, col: Color) -> void:
	var d := b - a
	var len := d.length()
	if len < 0.5:
		_c.draw_circle(a, maxf(ra, rb), col)
		return
	var n := Vector2(-d.y, d.x) / len
	_c.draw_colored_polygon(PackedVector2Array([a + n * ra, b + n * rb, b - n * rb, a - n * ra]), col)
	_c.draw_circle(a, ra, col)
	_c.draw_circle(b, rb, col)


## A round limb segment, shaded: outline, shade, base toward the light, a
## light strip and (on thick parts) a highlight.
func _limb_seg(a: Vector2, b: Vector2, ra: float, rb: float, ramp: PackedColorArray, outline := true) -> void:
	if outline:
		_caps(a, b, ra + ol, rb + ol, ramp[L.OUTLINE])
	if ghost:
		_caps(a, b, ra, rb, _ghost_fill)
		return
	_caps(a, b, ra, rb, ramp[L.SHADE])
	var d := b - a
	var n := Vector2(-d.y, d.x).normalized() if d.length() > 0.1 else Vector2(-1, 0)
	if n.dot(LIGHT_DIR) < 0.0:
		n = -n
	_caps(a + n * ra * 0.22, b + n * rb * 0.22, ra * 0.74, rb * 0.74, ramp[L.BASE])
	if ra >= 3.0:
		_caps(a + n * ra * 0.55, b + n * rb * 0.55, ra * 0.26, rb * 0.26, ramp[L.LIGHT])
	if ra >= 5.0:
		_c.draw_circle(a + n * ra * 0.6 + (b - a) * 0.25, 1.0, ramp[L.HI])


func _poly(points: PackedVector2Array, col: Color) -> void:
	if points.size() < 3:
		return
	if Geometry2D.triangulate_polygon(points).is_empty():
		# Folded over itself (an extreme twist): its hull is close enough.
		points = Geometry2D.convex_hull(points)
		points.remove_at(points.size() - 1)
		if points.size() < 3 or Geometry2D.triangulate_polygon(points).is_empty():
			return
	_c.draw_colored_polygon(points, col)


## [param poly] with an outline round it.
func _outlined(poly: PackedVector2Array, ramp: PackedColorArray) -> void:
	for grown in Geometry2D.offset_polygon(poly, ol, Geometry2D.JOIN_ROUND):
		_poly(grown, ramp[L.OUTLINE])
	_poly(poly, _ghost_fill if ghost else ramp[L.BASE])


## Fills the part of [param poly] on one side of the line through [param at]
## along [param along] (the side [param toward] points to).
func _side(poly: PackedVector2Array, at: Vector2, along: Vector2, toward: Vector2, col: Color) -> void:
	var a := along.normalized() * 400.0
	var out := toward.normalized() * 400.0
	var half := PackedVector2Array([at - a, at + a, at + a + out, at - a + out])
	for part in Geometry2D.intersect_polygons(poly, half):
		_poly(part, col)


func _clip(poly: PackedVector2Array, shape: PackedVector2Array, col: Color) -> void:
	for part in Geometry2D.intersect_polygons(poly, shape):
		_poly(part, col)


# ---------------------------------------------------------------- torso

func _torso() -> void:
	var r := _r
	var s := style
	var up := r.up
	var across := Vector2(up.y, -up.x)
	var tw := 1.0 - 0.3 * absf(r.twist)
	var sl := r.shoulder_l
	var sr := r.shoulder_r
	var waist := r.hip + up * 0.14
	var w_half := 0.13 * tw
	var shirt := PackedVector2Array([
		t(sl + up * 0.02 - across * 0.03), t(sl + up * 0.055 + across * 0.04),
		t(r.neck - up * 0.01 - across * 0.05), t(r.neck - up * 0.01 + across * 0.05),
		t(sr + up * 0.055 - across * 0.04), t(sr + up * 0.02 + across * 0.03),
		t(sr - up * 0.12 + across * 0.01), t(waist + across * (w_half + 0.01)),
		t(r.hip + up * 0.06 + across * w_half), t(r.hip + up * 0.06 - across * w_half),
		t(waist - across * (w_half + 0.01)), t(sl - up * 0.12 - across * 0.01),
	])
	var seat_top := r.hip + up * 0.09
	var seat := PackedVector2Array([
		t(seat_top - across * (w_half + 0.005)), t(seat_top + across * (w_half + 0.005)),
		t(r.pelvis_r + Vector2(0.045, -0.02)), t(r.pelvis_r + Vector2(0.02, -0.11)),
		t((r.pelvis_l + r.pelvis_r) * 0.5 + Vector2(0, -0.12)),
		t(r.pelvis_l + Vector2(-0.02, -0.11)), t(r.pelvis_l + Vector2(-0.045, -0.02)),
	])
	var seat_ramp := s.pants
	if s.bottom_style == "skirt":
		seat = PackedVector2Array([
			t(seat_top - across * (w_half + 0.005)), t(seat_top + across * (w_half + 0.005)),
			t(r.pelvis_r + Vector2(0.1, -0.2)), t((r.pelvis_l + r.pelvis_r) * 0.5 + Vector2(0, -0.23)),
			t(r.pelvis_l + Vector2(-0.1, -0.2)),
		])
	_outlined(seat, seat_ramp)
	if not ghost:
		_side(seat, t(r.hip), t(r.hip + up) - t(r.hip), t(r.hip + across) - t(r.hip), _shadow(0.3))
		_c.draw_line(t(seat_top), t((r.pelvis_l + r.pelvis_r) * 0.5 + Vector2(0, -0.1)), seat_ramp[L.SHADE], ol)
	_outlined(shirt, s.shirt)
	if ghost:
		return
	var mid := t(r.chest)
	var t_up := t(r.chest + up) - mid
	var t_across := t(r.chest + across) - mid
	_shirt_pattern(shirt, t_up, t_across)
	# Form shading: the side away from the light, a lit strip on the near
	# side, the spine, the shoulder blades and the folds under the arms.
	_side(shirt, mid + t_across * (0.06 + 0.04 * r.twist), t_up, t_across, _shadow(0.32))
	_side(shirt, mid - t_across * 0.12, t_up, -t_across, _light(0.18))
	var spine_top := t(r.neck - up * 0.05)
	_c.draw_line(spine_top, t(waist), _shadow(0.3), ol)
	# Shoulder blades: a soft crease under each.
	for side in [-1.0, 1.0]:
		var b0 := t(r.chest - up * 0.06 + across * side * 0.05 * tw)
		var b1 := t(r.chest - up * 0.16 + across * side * 0.11 * tw)
		_c.draw_line(b0, b1, _shadow(0.18 if side < 0 else 0.26), ol)
	_c.draw_line(t(sl - up * 0.1 + across * 0.015), t(sl - up * 0.22 + across * 0.04), _shadow(0.25), ol)
	_c.draw_line(t(sr - up * 0.1 - across * 0.015), t(sr - up * 0.22 - across * 0.04), _shadow(0.35), ol)
	if sweat > 0.05:
		_c.draw_circle(t(r.chest - up * 0.1), m(0.05 + 0.05 * sweat), Color(0.05, 0.05, 0.12, 0.22 * sweat))
	# The collar.
	_c.draw_line(t(r.neck - up * 0.012 - across * 0.06), t(r.neck - up * 0.012 + across * 0.06), s.shirt[L.HI], ol * 1.5)
	_harness(across, up, w_half)


func _shirt_pattern(shirt: PackedVector2Array, t_up: Vector2, t_across: Vector2) -> void:
	var s := style
	var r := _r
	var c2 := s.shirt2[L.BASE]
	var mid := t(r.chest - r.up * 0.2)
	var u := t_up.normalized()
	var a := t_across.normalized()
	match s.top_style:
		"stripes":
			for i in range(-5, 5):
				var y := mid + u * (i * m(0.06))
				_clip(shirt, PackedVector2Array([y - a * 200, y + a * 200, y + a * 200 + u * m(0.022), y - a * 200 + u * m(0.022)]), c2)
		"plaid":
			for i in range(-5, 5):
				var y := mid + u * (i * m(0.07))
				_clip(shirt, PackedVector2Array([y - a * 200, y + a * 200, y + a * 200 + u * m(0.018), y - a * 200 + u * m(0.018)]), Color(c2, 0.75))
				var x := mid + a * (i * m(0.07))
				_clip(shirt, PackedVector2Array([x - u * 200, x + u * 200, x + u * 200 + a * m(0.018), x - u * 200 + a * m(0.018)]), Color(c2, 0.6))
		"sweater":
			var hem := t(r.hip + r.up * 0.08)
			_clip(shirt, PackedVector2Array([hem - a * 200, hem + a * 200, hem + a * 200 - u * m(0.05), hem - a * 200 - u * m(0.05)]), s.shirt[L.SHADE])
			for i in range(-4, 5):
				var x := hem + a * (i * m(0.03))
				_c.draw_line(x, x - u * m(0.045), s.shirt[L.OUTLINE].lerp(s.shirt[L.SHADE], 0.5), ol)
		"vest":
			var back := PackedVector2Array([
				t(r.shoulder_l - r.up * 0.04 + Vector2(r.up.y, -r.up.x) * 0.05), t(r.neck - r.up * 0.03),
				t(r.shoulder_r - r.up * 0.04 - Vector2(r.up.y, -r.up.x) * 0.05),
				t(r.hip + r.up * 0.1 + Vector2(r.up.y, -r.up.x) * 0.13), t(r.hip + r.up * 0.1 - Vector2(r.up.y, -r.up.x) * 0.13)])
			_clip(shirt, back, c2)
		"jacket":
			var yoke := t(r.chest - r.up * 0.03)
			_clip(shirt, PackedVector2Array([yoke - a * 200, yoke + a * 200, yoke + a * 200 - u * m(0.012), yoke - a * 200 - u * m(0.012)]), s.shirt[L.OUTLINE])
			var hem := t(r.hip + r.up * 0.12)
			_clip(shirt, PackedVector2Array([hem - a * 200, hem + a * 200, hem + a * 200 - u * m(0.04), hem - a * 200 - u * m(0.04)]), s.shirt[L.SHADE])
		"suspenders":
			for side in [-1.0, 1.0]:
				var top := t(r.chest + Vector2(r.up.y, -r.up.x) * side * 0.07)
				var bottom := t(r.hip + r.up * 0.1 + Vector2(r.up.y, -r.up.x) * side * 0.05)
				var cross := t(r.chest - r.up * 0.18)
				_c.draw_line(top, cross, c2, m(0.022))
				_c.draw_line(cross, bottom, c2, m(0.022))


## The harness from behind: the waist belt with its buckle, gear loops with
## the rack hanging off them, the chalk bag on the back.
func _harness(across: Vector2, up: Vector2, w_half: float) -> void:
	var r := _r
	var s := style
	var belt_y := r.hip + up * 0.085
	var hw := w_half + 0.015
	var belt := PackedVector2Array([t(belt_y - across * hw + up * 0.025), t(belt_y + across * hw + up * 0.025),
		t(belt_y + across * hw - up * 0.025), t(belt_y - across * hw - up * 0.025)])
	_outlined(belt, s.harness)
	_side(belt, t(belt_y), t(belt_y + across) - t(belt_y), t(belt_y + up) - t(belt_y), s.harness[L.LIGHT])
	_c.draw_line(t(belt_y - across * hw - up * 0.022), t(belt_y + across * hw - up * 0.022), s.harness[L.SHADE], ol)
	# Rear elastics down to the leg loops.
	for side in [-1.0, 1.0]:
		_c.draw_line(t(belt_y + across * side * 0.05 - up * 0.02), t(r.hip + across * side * 0.075 - up * 0.09), s.harness[L.SHADE], m(0.014))
	var sw := swing
	# Draws on the right gear loops, cams on the left (a right-hander's rack).
	var draws: int = mini(int(rack.get("draws", 0)), 8)
	for i in draws:
		var at := belt_y + across * (hw + 0.005 + (i % 4) * 0.012) * (1.0 if i < 4 else 0.82) - up * 0.03
		var hang := Vector2(0.004 * (i % 3), -0.1) + sw * (0.6 + 0.1 * (i % 3))
		_draw_quickdraw(t(at), t(at + hang), i)
	var cams: Array = rack.get("cams", [])
	for i in mini(cams.size(), 8):
		var at := belt_y - across * (hw + 0.005 + (i % 4) * 0.014) * (1.0 if i < 4 else 0.8) - up * 0.03
		var hang := Vector2(-0.004 * (i % 2), -0.085 - 0.012 * (i % 3)) + sw * (0.7 + 0.1 * (i % 2))
		_draw_cam(t(at), t(at + hang), cams[i])
	if int(rack.get("nuts", 0)) > 0:
		var at := belt_y - across * (hw - 0.03) - up * 0.035
		var hang := Vector2(0, -0.08) + sw * 0.6
		_c.draw_line(t(at), t(at + hang * 0.5), s.steel[L.LIGHT], m(0.008))
		for j in mini(int(rack.nuts), 5):
			var p := t(at + hang * (0.55 + j * 0.1) + Vector2((j % 2) * 0.012 - 0.006, 0))
			_c.draw_rect(Rect2(p - Vector2(m(0.012), m(0.008)), Vector2(m(0.024), m(0.016))), Color("d8a63b") if j % 2 == 0 else Color("b0925f"))
	if int(rack.get("slings", 0)) > 0:
		var at := belt_y + across * (hw - 0.04) - up * 0.03
		_c.draw_line(t(at), t(at + Vector2(0, -0.14) + sw), Color("4a8fb8"), m(0.012))
		_c.draw_line(t(at + Vector2(0.01, 0)), t(at + Vector2(0.012, -0.13) + sw), Color("2f6c90"), m(0.01))
	# The chalk bag on the small of the back, on its belt.
	var bag_top := belt_y - up * 0.03 + sw * 0.25
	var bag := bag_top - up * 0.08 + sw * 0.5
	var bw := 0.045
	var bag_poly := PackedVector2Array([t(bag_top - across * bw), t(bag_top + across * bw),
		t(bag + across * (bw + 0.004)), t(bag - across * bw * 0.2 - up * 0.012), t(bag - across * (bw + 0.004))])
	_outlined(bag_poly, s.chalk_bag)
	_side(bag_poly, t(bag_top), t(bag) - t(bag_top), t(bag_top + across) - t(bag_top), s.chalk_bag[L.SHADE])
	_c.draw_line(t(bag_top - across * (bw + 0.006)), t(bag_top + across * (bw + 0.006)), s.tape[L.BASE], m(0.016))
	_c.draw_circle(t(bag_top + across * 0.03 - up * 0.02), 1.0, s.tape[L.LIGHT])
	# The back buckle.
	_c.draw_rect(Rect2(t(belt_y) - Vector2(m(0.017), m(0.017)), Vector2(m(0.034), m(0.034))), s.steel[L.BASE])
	_c.draw_rect(Rect2(t(belt_y) - Vector2(m(0.009), m(0.009)), Vector2(m(0.018), m(0.018))), s.harness[L.SHADE])


func _draw_quickdraw(a: Vector2, b: Vector2, i: int) -> void:
	var s := style
	var mid := a.lerp(b, 0.42)
	var low := a.lerp(b, 0.7)
	_c.draw_line(a, mid, s.steel[L.OUTLINE], m(0.016))
	_c.draw_line(a, mid, s.steel[L.LIGHT], m(0.008))
	var sling := Color("6f5aa6") if i % 2 == 0 else Color("f7a64a")
	_c.draw_line(mid, low, sling, m(0.016))
	_c.draw_line(low, b, s.steel[L.OUTLINE], m(0.016))
	_c.draw_line(low, b, s.steel[L.BASE], m(0.008))


func _draw_cam(a: Vector2, b: Vector2, col: Color) -> void:
	var s := style
	_c.draw_line(a, a.lerp(b, 0.3), s.steel[L.OUTLINE], m(0.014))
	_c.draw_line(a.lerp(b, 0.3), a.lerp(b, 0.7), col.darkened(0.15), m(0.014))
	var head := b
	_c.draw_circle(head, m(0.022), col.darkened(0.45))
	_c.draw_circle(head, m(0.017), col)
	_c.draw_circle(head + Vector2(-1, -1), m(0.007), col.lightened(0.45))


# ---------------------------------------------------------------- limbs

func _arm(l: StringName, far: bool) -> void:
	_ghost_fill = Color(1, 0, 0) if warn.get(l, false) else Color.WHITE
	_arm_body(l, far)
	_ghost_fill = Color.WHITE


func _arm_body(l: StringName, far: bool) -> void:
	var r := _r
	var s := style
	var root: Vector2 = r.shoulder_l if l == &"lh" else r.shoulder_r
	var elbow: Vector2 = r.joint[l]
	var hand: Vector2 = r.tip[l]
	var shirt := ClimberStyle.far(s.shirt) if far else s.shirt
	var skin := ClimberStyle.far(s.skin) if far else s.skin
	if flush > 0.05 and not ghost:
		skin = skin.duplicate()
		for i in skin.size():
			skin[i] = skin[i].lerp(Color("c8504a"), 0.12 * flush)
	var a := t(root)
	var e := t(elbow)
	var h := t(hand)
	var fore := (hand - elbow)
	var wrist := hand - fore.normalized() * 0.07 if fore.length() > 0.08 else elbow.lerp(hand, 0.5)
	var sleeve_long := s.top_style in ["sweater", "jacket"]
	# The forearm swells below the elbow and tapers to the wrist.
	var swell := t(elbow.lerp(wrist, 0.3))
	if sleeve_long:
		var cuff := elbow.lerp(wrist, 0.62)
		_limb_seg(swell, t(wrist), m(0.037), m(0.025), skin)
		_limb_seg(a, e, m(0.045), m(0.038), shirt)
		_limb_seg(e, t(cuff), m(0.04), m(0.035), shirt)
	else:
		_limb_seg(swell, t(wrist), m(0.037), m(0.025), skin)
		_limb_seg(e, swell, m(0.033), m(0.037), skin)
		_limb_seg(a, e, m(0.045), m(0.039), shirt)
		if not ghost:
			# The deltoid rounds the top of the arm.
			_c.draw_circle(a + (e - a).normalized() * m(0.03), m(0.047), shirt[L.BASE])
			_c.draw_circle(a + (e - a).normalized() * m(0.03) + LIGHT_DIR * m(0.015), m(0.02), shirt[L.LIGHT])
		if not ghost:
			# The pushed-up sleeve at the elbow.
			_c.draw_circle(e, m(0.04), shirt[L.SHADE])
			_c.draw_circle(e + (LIGHT_DIR * 1.2), m(0.026), shirt[L.LIGHT])
	if s.top_style == "vest" and not ghost:
		_c.draw_circle(a, m(0.048), s.shirt2[L.BASE] if not far else s.shirt2[L.SHADE])
	_hand(l, t(wrist), h, skin, far)


func _hand(l: StringName, wrist: Vector2, at: Vector2, skin: PackedColorArray, far: bool) -> void:
	var kind: StringName = kinds.get(l, &"hold")
	var hold: StringName = holds.get(l, &"")
	var dir := (at - wrist).normalized() if at.distance_to(wrist) > 0.5 else Vector2.UP
	var side := Vector2(-dir.y, dir.x)
	var len := m(0.085)
	var wide := m(0.075)
	if hold == &"sloper":
		wide = m(0.088)
		len = m(0.07)
	elif hold == &"pocket":
		wide = m(0.05)
	elif hold == &"jam":
		wide = m(0.058)
	if kind == &"chalk":
		# Fingers in the bag: the wrist disappears into it.
		_c.draw_circle(wrist, m(0.03), skin[L.OUTLINE])
		_c.draw_circle(wrist, m(0.026), skin[L.SHADE])
		return
	var base := at - dir * len
	var palm := PackedVector2Array([
		base + side * wide * 0.4, base + dir * len * 0.55 + side * wide * 0.5,
		at + side * wide * 0.38, at - side * wide * 0.38,
		base + dir * len * 0.55 - side * wide * 0.5, base - side * wide * 0.4])
	var main := skin
	if hold == &"jam" and kind == &"hold":
		main = style.tape
	_outlined(palm, main)
	if ghost:
		return
	_side(palm, base, dir, -side if side.dot(LIGHT_DIR) > 0 else side, main[L.SHADE])
	if kind == &"hold" or kind == &"smear":
		# Knuckles: a lit ridge across the back of the hand; tented high on a crimp.
		var ridge := base + dir * len * (0.72 if hold == &"crimp" else 0.62)
		_c.draw_line(ridge - side * wide * 0.4, ridge + side * wide * 0.4, main[L.LIGHT], ol)
		if hold == &"crimp" or hold == &"edge":
			for i in 4:
				_c.draw_circle(ridge + side * wide * (-0.3 + i * 0.2), 1.0, main[L.HI])
		if hold == &"pinch" or hold == &"sidepull" or hold == &"gaston":
			# The thumb wraps the side.
			var thumb_side := -side if l == &"rh" else side
			_caps(base + dir * len * 0.3 + thumb_side * wide * 0.48, at + thumb_side * wide * 0.5 - dir * len * 0.2, m(0.014) + ol, m(0.012) + ol, main[L.OUTLINE])
			_caps(base + dir * len * 0.3 + thumb_side * wide * 0.48, at + thumb_side * wide * 0.5 - dir * len * 0.2, m(0.014), m(0.012), main[L.BASE])
		var dust: float = chalk.get(l, 0.0)
		if dust > 0.1 and hold != &"jam":
			for i in 5:
				if float(i) / 5.0 < dust:
					_c.draw_circle(at - dir * 1.0 + side * wide * (-0.32 + i * 0.16), 1.0, style.tape[L.LIGHT])
	elif kind == &"rope":
		_c.draw_line(at - side * wide * 0.7, at + side * wide * 0.7, style.rope[L.OUTLINE], m(0.02))
		_c.draw_line(at - side * wide * 0.7, at + side * wide * 0.7, style.rope[L.BASE], m(0.012))
	elif kind == &"gear" and held_piece.a > 0.0:
		_c.draw_circle(at + dir * m(0.02), m(0.026), held_piece.darkened(0.45))
		_c.draw_circle(at + dir * m(0.02), m(0.02), held_piece)
	elif kind == &"food":
		_c.draw_rect(Rect2(at + dir * m(0.01) - Vector2(m(0.03), m(0.015)), Vector2(m(0.06), m(0.03))), Color("d9772a"))


func _leg(l: StringName, far: bool, near_after_far := false) -> void:
	var r := _r
	var s := style
	var root: Vector2 = r.pelvis_l if l == &"lf" else r.pelvis_r
	var knee: Vector2 = r.joint[l]
	var foot: Vector2 = r.tip[l]
	var pants := ClimberStyle.far(s.pants) if far else s.pants
	var shin_ramp := pants
	if s.bottom_style == "knickers":
		shin_ramp = ClimberStyle.far(s.tape) if far else s.tape
	elif s.bottom_style == "skirt":
		pants = ClimberStyle.far(ClimberStyle.ramp(s.pants[L.SHADE])) if far else ClimberStyle.ramp(s.pants[L.SHADE])
		shin_ramp = pants
	var shin := foot - knee
	var ankle := foot - shin.normalized() * 0.06 if shin.length() > 0.08 else knee.lerp(foot, 0.6)
	# The calf swells high on the shin.
	var calf := t(knee.lerp(ankle, 0.3))
	_limb_seg(calf, t(ankle), m(0.058), m(0.038), shin_ramp)
	_limb_seg(t(knee), calf, m(0.054), m(0.058), shin_ramp)
	_limb_seg(t(root), t(knee), m(0.072), m(0.058), pants)
	if s.bottom_style == "knickers" and not ghost:
		_c.draw_circle(t(knee.lerp(ankle, 0.12)), m(0.056), pants[L.SHADE])
	if not ghost:
		# The leg loop round the top of the thigh, and the crease behind the knee.
		var loop := root.lerp(knee, 0.22)
		var d := (knee - root).normalized()
		var n := Vector2(-d.y, d.x)
		_c.draw_line(t(loop + n * 0.07), t(loop - n * 0.07 - d * 0.02), s.harness[L.OUTLINE], m(0.028))
		_c.draw_line(t(loop + n * 0.068), t(loop - n * 0.068 - d * 0.02), s.harness[L.BASE], m(0.018))
		_c.draw_circle(t(knee), 1.5, pants[L.OUTLINE].lerp(pants[L.SHADE], 0.5))
	_shoe(l, t(ankle), t(foot), far)


func _shoe(l: StringName, ankle: Vector2, at: Vector2, far: bool) -> void:
	var s := style
	var kind: StringName = kinds.get(l, &"hold")
	var upper := ClimberStyle.far(s.shoe) if far else s.shoe
	var rub := s.rubber
	var side_on := absf(_r.twist) > 0.5 or kind == &"free"
	var dir := (at - ankle).normalized() if at.distance_to(ankle) > 0.5 else Vector2.DOWN
	if side_on:
		# In profile: heel at the ankle, the toe pointing the way you face.
		var toe_x := signf(_r.twist) if _r.twist != 0.0 else (-1.0 if l == &"lf" else 1.0)
		var toe := at + Vector2(toe_x * m(0.11), m(0.01))
		var heel := at + Vector2(-toe_x * m(0.035), -m(0.02))
		var shape := PackedVector2Array([heel + Vector2(0, -m(0.045)), ankle + Vector2(toe_x * m(0.03), 0),
			toe + Vector2(0, -m(0.025)), toe + Vector2(toe_x * m(0.012), m(0.006)), heel + Vector2(0, m(0.018))])
		_outlined(shape, upper)
		if not ghost:
			_c.draw_line(heel + Vector2(0, m(0.016)), toe + Vector2(0, m(0.004)), rub[L.BASE], m(0.016))
			_c.draw_line(ankle + Vector2(toe_x * m(0.02), m(0.01)), toe + Vector2(-toe_x * m(0.03), -m(0.02)), upper[L.LIGHT], ol)
		return
	# From behind: the heel cup, rubber round the bottom, a pull tab.
	var w := m(0.042)
	var h := m(0.055)
	var c := at - dir * h * 0.35
	var cup := PackedVector2Array([c + Vector2(-w, -h * 0.5), c + Vector2(w, -h * 0.5), c + Vector2(w * 1.05, h * 0.35),
		c + Vector2(w * 0.6, h * 0.62), c + Vector2(-w * 0.6, h * 0.62), c + Vector2(-w * 1.05, h * 0.35)])
	_outlined(cup, upper)
	if ghost:
		return
	var sole_h := h * (0.42 if kind == &"smear" else 0.3)
	_clip(cup, PackedVector2Array([c + Vector2(-w * 2, h * 0.62 - sole_h), c + Vector2(w * 2, h * 0.62 - sole_h),
		c + Vector2(w * 2, h), c + Vector2(-w * 2, h)]), rub[L.BASE])
	_side(cup, c, Vector2.DOWN, Vector2.RIGHT, Color(upper[L.SHADE], 0.8))
	_c.draw_rect(Rect2(c + Vector2(-1, -h * 0.5 - m(0.012)), Vector2(2, m(0.018))), Color("2b2a30"))


# ---------------------------------------------------------------- head

func _head() -> void:
	var r := _r
	var s := style
	var hc := t(r.head)
	var rad := m(ClimberRig.HEAD_R)
	var up := t(r.head + r.up) - hc
	up = up.normalized()
	var across := Vector2(-up.y, up.x)
	var yaw := r.head_yaw
	var pitch := r.head_pitch
	# Neck in the collar.
	var neck_top := hc - up * rad * 0.2
	_limb_seg(t(r.neck - r.up * 0.02), neck_top, m(0.04), m(0.042), s.skin)
	if ghost:
		_c.draw_circle(hc, rad + ol, s.hair[L.OUTLINE])
		_c.draw_circle(hc, rad, Color.WHITE)
		return
	# Hair hanging down the back goes under the head.
	if s.hair_style in ["long", "braid"]:
		var tail_top := hc + up * rad * -0.2
		var tail_end := tail_top - up * m(0.2 if s.hair_style == "long" else 0.26) + Vector2(swing.x, -swing.y) * k * 0.8
		var tw := m(0.08 if s.hair_style == "long" else 0.032)
		_caps(tail_top, tail_end, tw + ol, tw * 0.7 + ol, s.hair[L.OUTLINE])
		_caps(tail_top, tail_end, tw, tw * 0.7, s.hair[L.SHADE])
		_caps(tail_top + across * 1.0, tail_end + across * 1.0, tw * 0.6, tw * 0.4, s.hair[L.BASE])
		if s.hair_style == "braid":
			for i in 4:
				var p := tail_top.lerp(tail_end, 0.2 + i * 0.2)
				_c.draw_line(p - across * tw, p + across * tw, s.hair[L.OUTLINE], ol)
	# The face, a sliver of it, when the head turns: cheek, nose tip, beard.
	var face_side := signf(yaw)
	var turn := absf(yaw)
	if turn > 0.2:
		var cheek := hc + across * face_side * rad * 0.78 - up * rad * 0.12
		_c.draw_circle(cheek, rad * 0.42 + ol, s.skin[L.OUTLINE])
		_c.draw_circle(cheek, rad * 0.42, s.skin[L.BASE])
		var nose := hc + across * face_side * rad * (0.9 + 0.25 * turn) - up * rad * (0.05 + 0.1 * pitch)
		_c.draw_circle(nose, m(0.016) + ol, s.skin[L.OUTLINE])
		_c.draw_circle(nose, m(0.016), s.skin[L.LIGHT])
		if s.beard != "none":
			var chin := cheek - up * rad * 0.38
			_c.draw_circle(chin, rad * (0.36 if s.beard in ["short", "long"] else 0.22), s.hair[L.SHADE])
	# The back of the head: ears, the hair and its style.
	for side in [-1.0, 1.0]:
		var ear: Vector2 = hc + across * side * rad * (0.96 - 0.25 * absf(yaw) * (1.0 if side == face_side else -0.6)) - up * rad * 0.05
		_c.draw_circle(ear, m(0.022) + ol, s.skin[L.OUTLINE])
		_c.draw_circle(ear, m(0.022), s.skin[L.SHADE] if side > 0 else s.skin[L.BASE])
	var hair_c := hc - across * yaw * rad * 0.12
	if s.hair_style == "bald":
		_c.draw_circle(hair_c, rad + ol, s.skin[L.OUTLINE])
		_c.draw_circle(hair_c, rad, s.skin[L.BASE])
		_c.draw_circle(hair_c + LIGHT_DIR * rad * 0.35, rad * 0.4, s.skin[L.LIGHT])
	else:
		var hr := rad * (1.12 if s.hair_style == "wild" else 1.0)
		_c.draw_circle(hair_c, hr + ol, s.hair[L.OUTLINE])
		_c.draw_circle(hair_c, hr, s.hair[L.SHADE])
		_c.draw_circle(hair_c + LIGHT_DIR * hr * 0.18, hr * 0.8, s.hair[L.BASE])
		_c.draw_circle(hair_c + LIGHT_DIR * hr * 0.5, hr * 0.28, s.hair[L.LIGHT])
		# Strands at the nape.
		for i in 5:
			var x := hair_c + across * rad * (-0.6 + i * 0.3) - up * rad * 0.55
			_c.draw_line(x, x - up * rad * 0.35, s.hair[L.OUTLINE].lerp(s.hair[L.SHADE], 0.4), ol)
		if s.hair_style == "bun":
			var bun := hair_c + up * rad * 0.65
			_c.draw_circle(bun, rad * 0.42 + ol, s.hair[L.OUTLINE])
			_c.draw_circle(bun, rad * 0.42, s.hair[L.BASE])
		elif s.hair_style == "wild":
			for i in 6:
				var ang := -2.6 + i * 0.6
				var tuft := hair_c + (across * cos(ang) + up * sin(ang) * -1.0) * hr * 1.02
				_c.draw_circle(tuft, rad * 0.2, s.hair[L.BASE])
	if s.glasses and turn > 0.15:
		var temple := hc + across * face_side * rad * 0.95
		_c.draw_line(temple - across * face_side * rad * 0.5, temple + across * face_side * rad * 0.1, Color("2b2a30"), ol)
	_hat(hc, rad, up, across, yaw, pitch)


func _hat(hc: Vector2, rad: float, up: Vector2, across: Vector2, yaw: float, pitch: float) -> void:
	var s := style
	var h := s.hat
	var tilt := up * rad * 0.12 * pitch
	match s.hat_kind:
		"none":
			return
		"headband":
			var y := hc + up * rad * 0.22 + tilt
			_c.draw_line(y - across * rad * 1.02, y + across * rad * 1.02, h[L.OUTLINE], m(0.04))
			_c.draw_line(y - across * rad * 0.98, y + across * rad * 0.98, h[L.BASE], m(0.028))
		"cap", "beanie":
			var top := hc + up * rad * 0.3 + tilt
			var crown := PackedVector2Array()
			for i in 13:
				var a := PI * i / 12.0
				crown.append(top + across * cos(a) * rad * 1.05 + up * sin(a) * rad * 0.95)
			crown.append(top - across * rad * 1.05 - up * rad * 0.2)
			crown.append(top + across * rad * 1.05 - up * rad * 0.2)
			_outlined(crown, h)
			_side(crown, top, up, across, h[L.SHADE])
			_c.draw_circle(top + up * rad * 0.45 - across * rad * 0.35, rad * 0.22, h[L.LIGHT])
			if s.hat_kind == "beanie":
				_c.draw_line(top - across * rad * 1.05 - up * rad * 0.12, top + across * rad * 1.05 - up * rad * 0.12, h[L.SHADE], m(0.03))
				_c.draw_circle(top + up * rad * 0.98, rad * 0.2, h[L.LIGHT])
			else:
				# The cap's bill sticks out the way you look.
				var bill := top + across * signf(yaw) * rad * (0.6 + 0.6 * absf(yaw)) + up * rad * 0.05
				if absf(yaw) > 0.25:
					_c.draw_line(top + across * signf(yaw) * rad * 0.8, bill + across * signf(yaw) * rad * 0.5, h[L.OUTLINE], m(0.03))
					_c.draw_line(top + across * signf(yaw) * rad * 0.8, bill + across * signf(yaw) * rad * 0.45, h[L.SHADE], m(0.018))
		_:
			# Brimmed hats: wide, ranger, fedora. The brim's an ellipse seen
			# from behind and a little above, tipping with the head.
			var brim_c := hc + up * rad * 0.15 + tilt
			var bw := rad * (1.75 if s.hat_kind == "wide" else 1.5)
			var bh := rad * (0.42 - 0.15 * pitch)
			var brim := PackedVector2Array()
			for i in 24:
				var a := TAU * i / 24.0
				brim.append(brim_c + across * cos(a) * bw + up * sin(a) * bh + across * yaw * rad * 0.1)
			_outlined(brim, ClimberStyle.ramp(h[L.SHADE]))
			_side(brim, brim_c, across, up, h[L.BASE])
			var crown_c := brim_c + up * rad * 0.45
			var cw := rad * (0.95 if s.hat_kind != "fedora" else 0.9)
			var crown := PackedVector2Array([
				brim_c - across * cw, brim_c + across * cw,
				crown_c + across * cw * 0.92 + up * rad * 0.3, crown_c + across * cw * 0.5 + up * rad * (0.55 if s.hat_kind != "campaign" else 0.85),
				crown_c - across * cw * 0.5 + up * rad * (0.55 if s.hat_kind != "campaign" else 0.85), crown_c - across * cw * 0.92 + up * rad * 0.3])
			_outlined(crown, h)
			_side(crown, crown_c, up, across, h[L.SHADE])
			_side(crown, crown_c - across * cw * 0.5, up, -across, h[L.LIGHT])
			# The band.
			_c.draw_line(brim_c - across * cw + up * rad * 0.12, brim_c + across * cw + up * rad * 0.12, Color("3a2a20"), m(0.025))


func _shadow(a: float) -> Color:
	return Color(0.08, 0.09, 0.2, a)


func _light(a: float) -> Color:
	return Color(1.0, 0.95, 0.8, a)
