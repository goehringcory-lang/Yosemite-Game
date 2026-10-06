class_name ClimbSprites
extends RefCounted
## The climber, the belayer and the hardware, painted in code at the game's
## pixel scale (a person is about 40 px tall, like the farmers in the games
## this art takes after): warm colors, a dark brown outline, light from the
## upper left. Figures are posed with two-bone limbs, so any hand or foot
## target gives a clean pose; frames are cached by pose.
##
## The climber shows what you own: red climbing shoes, a chalk bag, a harness
## with a rack of cams and quickdraws, a belay device, aiders, a rolled
## portaledge, an ice axe and crampons.

const P := preload("res://scripts/climb/art/climb_paint.gd")
const SIZE := Vector2i(48, 56)
## Where the torso's center sits in a figure image.
const ORIGIN := Vector2(24, 30)

const SKIN := Color("f0c088")
const SKIN_SHADE := Color("d09a62")
const HAT := Color("8a5a2a")
const SHIRT := Color("6a8a4a")
const PANTS := Color("3a4466")
const HARNESS := Color("f0b030")
const CAM_COLORS := [Color("d8452e"), Color("e8a030"), Color("3a78c8"), Color("7a4ab0"), Color("3a9a58")]

static var _cache: Dictionary = {}


## Shoulder and hip positions relative to the torso center.
const SHOULDER_L := Vector2(-5, -6)
const SHOULDER_R := Vector2(5, -6)
const HIP_L := Vector2(-2.5, 7)
const HIP_R := Vector2(2.5, 7)
const ARM := 14.5
const LEG := 15.5


## The default stance: right hand high, left hand low, left foot high.
static func stance(step: int) -> Dictionary:
	var a := (step % 2) == 0
	return {
		"hr": Vector2(9, -20) if a else Vector2(9, -9),
		"hl": Vector2(-9, -9) if a else Vector2(-9, -20),
		"fr": Vector2(7, 17) if a else Vector2(7, 22),
		"fl": Vector2(-7, 22) if a else Vector2(-7, 17),
		"lean": 0,
	}


static func climber(pose: Dictionary, kit: Dictionary, flags := {}) -> Texture2D:
	var key := "c|%s|%s|%s" % [_pose_key(pose), _kit_key(kit), str(flags)]
	if _cache.has(key):
		return _cache[key]
	var im := _paint_climber(pose, kit, flags)
	var tex := ImageTexture.create_from_image(im)
	_cache[key] = tex
	return tex


static func _pose_key(pose: Dictionary) -> String:
	var parts: Array[String] = []
	for k in ["hr", "hl", "fr", "fl"]:
		var v: Vector2 = pose.get(k, Vector2.ZERO)
		parts.append("%d,%d" % [roundi(v.x), roundi(v.y)])
	parts.append(str(roundi(pose.get("lean", 0))))
	parts.append(str(pose.get("mode", "wall")))
	parts.append(str(pose.get("chalk", false)))
	parts.append(str(roundi(pose.get("tilt", 0))))
	return "|".join(parts)


static func _kit_key(kit: Dictionary) -> String:
	var parts: Array[String] = []
	for k in ["climbing_shoes", "chalk_bag", "harness", "cam", "quickdraw", "belay_device", "aiders", "portaledge", "ice_axe", "crampons", "rope"]:
		parts.append("%s%d" % [k.substr(0, 3), mini(int(kit.get(k, 0)), 5)])
	return "".join(parts)


## Two-bone limb: the middle joint for a limb from [param a] reaching toward
## [param t], bending toward [param side] (+1 or -1). Returns [elbow, hand].
static func _limb(a: Vector2, t: Vector2, l1: float, l2: float, side: float) -> Array[Vector2]:
	var d := t - a
	var dist := d.length()
	if dist < 0.01:
		return [a, a]
	dist = clampf(dist, 1.0, l1 + l2 - 0.5)
	var dir := d.normalized()
	var x := (l1 * l1 - l2 * l2 + dist * dist) / (2.0 * dist)
	var h := sqrt(maxf(l1 * l1 - x * x, 0.0))
	var perp := Vector2(-dir.y, dir.x) * side
	return [a + dir * x + perp * h, a + dir * dist]


static func _paint_climber(pose: Dictionary, kit: Dictionary, flags: Dictionary) -> Image:
	var im := P.make(SIZE.x, SIZE.y)
	var o := ORIGIN
	var lean: float = pose.get("lean", 0)
	var mode: String = pose.get("mode", "wall")
	var torso := o + Vector2(lean, 0)
	var shoes_red := int(kit.get("climbing_shoes", 0)) > 0
	var shoe_col := Color("d8502e") if shoes_red else Color("8a5a32")
	var shoe_dark := Color("8a2a1c") if shoes_red else Color("5a3a1e")
	var sole := Color("2a2a30") if shoes_red else Color("3a2a1e")
	var crampons: bool = int(kit.get("crampons", 0)) > 0 and flags.get("snow", false)
	var axe: bool = int(kit.get("ice_axe", 0)) > 0 and flags.get("snow", false)
	# Legs first (they're behind the harness).
	var hl: Vector2 = torso + HIP_L
	var hr: Vector2 = torso + HIP_R
	var fl: Vector2 = o + pose.get("fl", Vector2(-5, 20)) + Vector2(lean * 0.3, 0)
	var fr: Vector2 = o + pose.get("fr", Vector2(5, 16)) + Vector2(lean * 0.3, 0)
	var leg_l := _limb(hl, fl, LEG * 0.5, LEG * 0.5, -1.0)
	var leg_r := _limb(hr, fr, LEG * 0.5, LEG * 0.5, 1.0)
	_draw_leg(im, hl, leg_l, PANTS, shoe_col, shoe_dark, sole, crampons)
	_draw_leg(im, hr, leg_r, PANTS, shoe_col, shoe_dark, sole, crampons)
	# Torso.
	var tx := roundi(torso.x)
	var ty := roundi(torso.y)
	P.rect(im, tx - 5, ty - 7, 10, 13, SHIRT)
	P.rect(im, tx - 6, ty - 6, 12, 5, SHIRT)
	P.rect(im, tx - 5, ty - 7, 2, 12, SHIRT.lightened(0.22))
	P.rect(im, tx - 6, ty - 6, 2, 4, SHIRT.lightened(0.22))
	P.rect(im, tx + 3, ty - 6, 2, 11, SHIRT.darkened(0.2))
	P.rect(im, tx + 4, ty - 6, 2, 4, SHIRT.darkened(0.2))
	P.vline(im, tx, ty - 6, 9, SHIRT.darkened(0.14))
	P.hline(im, tx - 5, ty + 5, 10, SHIRT.darkened(0.22))
	# Pants seat and harness.
	P.rect(im, tx - 5, ty + 5, 10, 3, PANTS)
	P.rect(im, tx - 5, ty + 5, 2, 3, PANTS.lightened(0.18))
	P.rect(im, tx - 6, ty + 3, 12, 3, HARNESS)
	P.hline(im, tx - 6, ty + 3, 12, HARNESS.lightened(0.35))
	P.hline(im, tx - 6, ty + 5, 12, HARNESS.darkened(0.3))
	P.rect(im, tx - 5, ty + 6, 3, 4, HARNESS.darkened(0.12))
	P.rect(im, tx + 2, ty + 6, 3, 4, HARNESS.darkened(0.12))
	if int(kit.get("harness", 0)) == 0 and not flags.get("always_harness", false):
		# Without a harness you're just in a belt: dull brown.
		P.rect(im, tx - 6, ty + 3, 12, 3, Color("7a5a3a"))
		P.hline(im, tx - 6, ty + 3, 12, Color("a07a50"))
	# Chalk bag, on the small of the back.
	if int(kit.get("chalk_bag", 0)) > 0:
		P.rect(im, tx - 2, ty - 1, 5, 6, Color("2f6ab8"))
		P.rect(im, tx - 2, ty - 1, 2, 6, Color("4a8ae0"))
		P.rect(im, tx - 2, ty - 2, 5, 2, Color("f4f0e6"))
		P.px(im, tx - 2, ty + 2, Color("f4f0e6"))
		P.hline(im, tx - 2, ty + 4, 5, Color("1f4a88"))
	# Rolled portaledge (a big wall's bedroll) across the shoulders.
	if flags.get("portaledge", false):
		P.rect(im, tx - 7, ty - 8, 14, 3, Color("e88a30"))
		P.hline(im, tx - 7, ty - 8, 14, Color("f8b060"))
		P.hline(im, tx - 7, ty - 6, 14, Color("a85a1c"))
		P.rect(im, tx - 8, ty - 8, 2, 3, Color("6a6e78"))
		P.rect(im, tx + 6, ty - 8, 2, 3, Color("6a6e78"))
	# The rack: cams on the left hip, quickdraws on the right.
	var cams := int(kit.get("cam", 0))
	for i in mini(cams, 5):
		var c: Color = CAM_COLORS[i % CAM_COLORS.size()]
		var x := tx - 8 + (i % 3) * 2
		var y := ty + 5 + (i / 3) * 3 + (i % 3)
		P.rect(im, x, y, 2, 3, c)
		P.px(im, x, y, c.lightened(0.4))
		P.px(im, x, y + 3, Color("c8ccd4"))
	var draws := int(kit.get("quickdraw", 0))
	for i in mini(draws, 4):
		var x := tx + 6 + (i % 2) * 2
		var y := ty + 4 + (i / 2) * 3
		P.rect(im, x, y, 1, 3, Color("c8ccd4"))
		P.rect(im, x + 1, y + 1, 1, 2, Color("3a78c8"))
	if int(kit.get("belay_device", 0)) > 0:
		P.rect(im, tx - 1, ty + 7, 3, 3, Color("c8ccd4"))
		P.px(im, tx, ty + 8, Color("505868"))
	if int(kit.get("aiders", 0)) > 0 and flags.get("aiders", false):
		for i in 3:
			P.rect(im, tx + 5 + i, ty + 6, 1, 8 + i * 2, Color("3a78c8"))
			for k in 3:
				P.hline(im, tx + 5 + i, ty + 8 + k * 3, 1, Color("f4f0e6"))
	# Arms.
	var sl: Vector2 = torso + SHOULDER_L
	var sr: Vector2 = torso + SHOULDER_R
	var tl: Vector2 = o + pose.get("hl", Vector2(-6, -9)) + Vector2(lean * 0.4, 0)
	var tr: Vector2 = o + pose.get("hr", Vector2(6, -19)) + Vector2(lean * 0.4, 0)
	var arm_l := _limb(sl, tl, ARM * 0.5, ARM * 0.5, 1.0)
	var arm_r := _limb(sr, tr, ARM * 0.5, ARM * 0.5, -1.0)
	var chalk: bool = pose.get("chalk", false)
	_draw_arm(im, sl, arm_l, SHIRT, chalk)
	_draw_arm(im, sr, arm_r, SHIRT, chalk)
	if axe:
		_draw_axe(im, arm_r[1])
	# Head and hat, from behind.
	var hx := roundi(torso.x) + roundi(lean * 0.5)
	var hy := ty - 14 + roundi(float(pose.get("tilt", 0)) * 0.3)
	P.rect(im, hx - 2, hy + 4, 4, 3, SKIN_SHADE)
	P.shaded_ellipse(im, hx, hy, 4.5, 4.5, Color("6a4428"), Color("8a5e3a"), Color("4a2e1a"))
	P.rect(im, hx - 4, hy + 1, 8, 3, Color("6a4428"))
	P.px(im, hx - 4, hy + 4, SKIN)
	P.px(im, hx + 3, hy + 4, SKIN_SHADE)
	P.ellipse(im, hx, hy - 2, 7.0, 2.2, HAT.darkened(0.12))
	P.ellipse(im, hx, hy - 3, 6.0, 1.6, HAT)
	P.shaded_ellipse(im, hx, hy - 4, 3.6, 3.0, HAT, HAT.lightened(0.28), HAT.darkened(0.2))
	P.hline(im, hx - 4, hy - 2, 8, Color("c8a050"))
	P.outline(im)
	return im


static func _draw_leg(im: Image, hip: Vector2, joints: Array[Vector2], pants: Color, shoe: Color, shoe_dark: Color, sole: Color, crampons: bool) -> void:
	var knee := joints[0]
	var foot := joints[1]
	P.line(im, hip, knee, pants.darkened(0.15), 4)
	P.line(im, knee, foot, pants.darkened(0.15), 3)
	P.line(im, hip + Vector2(-1, 0), knee + Vector2(-1, 0), pants, 3)
	P.line(im, knee + Vector2(-1, 0), foot + Vector2(-1, 0), pants.lightened(0.1), 2)
	# Shoe: toe pointing at the rock (up on a smear), sole on the bottom.
	var fx := roundi(foot.x)
	var fy := roundi(foot.y)
	P.rect(im, fx - 3, fy - 1, 6, 4, shoe)
	P.rect(im, fx - 3, fy - 1, 6, 1, shoe.lightened(0.3))
	P.rect(im, fx - 3, fy + 2, 6, 1, shoe_dark)
	P.rect(im, fx - 3, fy + 3, 6, 1, sole)
	if crampons:
		for i in 3:
			P.px(im, fx - 3 + i * 2, fy + 4, Color("c8ccd4"))
			P.px(im, fx - 3 + i * 2, fy + 5, Color("7a808e"))


static func _draw_arm(im: Image, shoulder: Vector2, joints: Array[Vector2], sleeve: Color, chalk: bool) -> void:
	var elbow := joints[0]
	var hand := joints[1]
	# Short sleeve to the elbow, skin forearm.
	P.line(im, shoulder, elbow, sleeve.darkened(0.12), 4)
	P.line(im, shoulder + Vector2(-1, 0), elbow + Vector2(-1, 0), sleeve.lightened(0.05), 3)
	P.line(im, elbow, hand, SKIN_SHADE, 3)
	P.line(im, elbow + Vector2(-1, 0), hand + Vector2(-1, 0), SKIN, 2)
	var hx := roundi(hand.x)
	var hy := roundi(hand.y)
	P.rect(im, hx - 2, hy - 2, 4, 3, SKIN)
	P.px(im, hx - 2, hy - 2, SKIN.lightened(0.2))
	if chalk:
		P.rect(im, hx - 2, hy - 2, 4, 2, Color("f4f0e6"))


static func _draw_axe(im: Image, hand: Vector2) -> void:
	var hx := roundi(hand.x)
	var hy := roundi(hand.y)
	P.vline(im, hx, hy - 6, 14, Color("9a6a3a"))
	P.vline(im, hx + 1, hy - 6, 14, Color("6a4a2a"))
	P.rect(im, hx - 4, hy - 8, 9, 2, Color("c8ccd4"))
	P.rect(im, hx - 5, hy - 7, 2, 3, Color("7a808e"))
	P.rect(im, hx + 4, hy - 7, 2, 2, Color("7a808e"))


# ---------------------------------------------------------------- belayer

## A person standing, seen from three-quarters behind, holding a rope.
## [param look] comes from ClimbProfiles.BELAYERS. [param mode]: "belay"
## (standing, rope in both hands), "sit" (seated at an anchor, rope to the
## hip) or "cheer" (arms up).
static func belayer(look: Dictionary, mode := "belay", frame := 0) -> Texture2D:
	var key := "b|%s|%s|%d" % [str(look.get("id", "")), mode, frame]
	if _cache.has(key):
		return _cache[key]
	var im := _paint_belayer(look, mode, frame)
	var tex := ImageTexture.create_from_image(im)
	_cache[key] = tex
	return tex


static func _paint_belayer(look: Dictionary, mode: String, frame: int) -> Image:
	var im := P.make(40, 48)
	var skin := Color(look.get("skin", "e0ac7e"))
	var skin_shade := skin.darkened(0.18)
	var hair := Color(look.get("hair", "5a3a22"))
	var top := Color(look.get("top", "8a4a6a"))
	var bottom := Color(look.get("bottom", "4a4a58"))
	var hat: String = look.get("hat", "")
	var hat_kind: String = look.get("hat_kind", "cap")
	var cx := 20
	var base := 40 if mode != "sit" else 42
	var bob := 0
	if frame == 1:
		bob = 1
	if mode == "sit":
		# Seated: legs forward (toward the viewer's left), body upright.
		P.rect(im, cx - 9, base - 5, 12, 4, bottom)
		P.rect(im, cx - 12, base - 6, 4, 6, Color("5a3a24"))
		P.rect(im, cx - 12, base - 2, 5, 2, Color("2a2a30"))
		P.rect(im, cx - 4, base - 16, 10, 12, top)
	else:
		# Legs, braced wide.
		P.rect(im, cx - 5, base - 14, 4, 13, bottom)
		P.rect(im, cx + 1, base - 14, 4, 13, bottom.darkened(0.12))
		P.rect(im, cx - 5, base - 14, 1, 13, bottom.lightened(0.15))
		P.rect(im, cx - 6, base - 2, 5, 3, Color("5a3a24"))
		P.rect(im, cx + 1, base - 2, 5, 3, Color("4a2e1c"))
		P.rect(im, cx - 6, base + 1, 5, 1, Color("2a2a30"))
		P.rect(im, cx + 1, base + 1, 5, 1, Color("2a2a30"))
		P.rect(im, cx - 6, base - 26 + bob, 12, 14, top)
	var ty := (base - 26 + bob) if mode != "sit" else (base - 16)
	var tw := 12 if mode != "sit" else 10
	var tx := (cx - 6) if mode != "sit" else (cx - 4)
	P.rect(im, tx, ty, 2, 13, top.lightened(0.2))
	P.rect(im, tx + tw - 3, ty + 1, 3, 12, top.darkened(0.2))
	P.hline(im, tx, ty + 12, tw, top.darkened(0.25))
	if look.get("apron", "") != "":
		P.rect(im, tx + 1, ty + 5, tw - 2, 9, Color(look.apron))
	if look.get("pack", "") != "":
		P.rect(im, tx - 2, ty + 1, 4, 10, Color(look.pack))
		P.rect(im, tx - 2, ty + 1, 1, 10, Color(look.pack).lightened(0.2))
	# Harness belt.
	P.rect(im, tx - 1, ty + 10, tw + 2, 3, Color("f0b030"))
	P.hline(im, tx - 1, ty + 10, tw + 2, Color("f8d070"))
	P.rect(im, tx + tw / 2 - 1, ty + 12, 3, 3, Color("c8ccd4"))
	# Head.
	var hy := ty - 6
	var hx := tx + tw / 2
	P.rect(im, hx - 2, hy + 4, 5, 3, skin_shade)
	if look.get("long", false):
		P.rect(im, hx - 5, hy - 1, 10, 12, hair)
		P.rect(im, hx - 5, hy - 1, 2, 12, hair.lightened(0.15))
	P.shaded_ellipse(im, hx, hy, 5, 5, skin, skin.lightened(0.12), skin_shade)
	# Hair covers the back of the head; face in three-quarter to the left.
	if look.get("bald", false):
		P.rect(im, hx + 1, hy - 3, 4, 7, hair)
		P.rect(im, hx - 5, hy - 1, 2, 4, hair)
	else:
		P.shaded_ellipse(im, hx + 1, hy - 1, 4.8, 4.2, hair, hair.lightened(0.18), hair.darkened(0.2))
	if look.has("beard"):
		var bc := Color(look.beard)
		P.rect(im, hx - 4, hy + 2, 5, 4 if look.get("long_beard", false) else 3, bc)
		if look.get("long_beard", false):
			P.rect(im, hx - 3, hy + 6, 4, 4, bc.darkened(0.1))
	P.px(im, hx - 3, hy, Color("2a1f1a"))
	if look.get("glasses", false):
		P.hline(im, hx - 4, hy, 3, Color("2a1f1a"))
	# Hats.
	if hat != "":
		var hc := Color(hat)
		match hat_kind:
			"headband":
				P.rect(im, hx - 5, hy - 3, 10, 2, hc)
			"bandana":
				P.rect(im, hx - 5, hy - 3, 10, 3, hc)
				P.rect(im, hx + 4, hy - 1, 3, 4, hc.darkened(0.12))
			"fedora":
				P.ellipse(im, hx, hy - 3, 8.0, 2.4, hc.darkened(0.1))
				P.shaded_ellipse(im, hx, hy - 5, 4.6, 3.6, hc, hc.lightened(0.2), hc.darkened(0.2))
				P.hline(im, hx - 4, hy - 3, 8, Color("2a2a30"))
			_:
				P.shaded_ellipse(im, hx, hy - 3, 5.6, 3.2, hc, hc.lightened(0.2), hc.darkened(0.2))
				P.rect(im, hx - 7, hy - 2, 5, 1, hc.darkened(0.2))
	# Arms, rope held at the hips; a little pay-out motion on frame 1.
	var shoulder_y := ty + 2
	var hand_y := ty + 10 - (1 if frame == 1 else 0)
	P.line(im, Vector2(tx + 1, shoulder_y), Vector2(tx - 3, hand_y - 2), top.darkened(0.1), 3)
	P.line(im, Vector2(tx - 3, hand_y - 2), Vector2(tx - 5, hand_y - 8), skin_shade, 3)
	P.line(im, Vector2(tx + tw - 1, shoulder_y), Vector2(tx + tw + 3, hand_y), top.darkened(0.2), 3)
	P.line(im, Vector2(tx + tw + 3, hand_y), Vector2(tx + tw + 2, hand_y + 4), skin_shade, 3)
	if mode == "cheer":
		P.rect(im, tx - 6, shoulder_y - 12, 3, 12, top)
		P.rect(im, tx - 6, shoulder_y - 15, 3, 3, skin)
		P.rect(im, tx + tw + 3, shoulder_y - 12, 3, 12, top.darkened(0.1))
		P.rect(im, tx + tw + 3, shoulder_y - 15, 3, 3, skin)
	P.outline(im)
	return im


# ---------------------------------------------------------------- hardware

## Small gear pictures for the wall: a cam in its crack, a quickdraw on a bolt
## (or an old piton), an anchor bolt, at their natural sizes.
static func hardware(kind: String, color_index := 0) -> Texture2D:
	var key := "h|%s|%d" % [kind, color_index]
	if _cache.has(key):
		return _cache[key]
	var im := P.make(12, 20)
	match kind:
		"cam":
			var c: Color = CAM_COLORS[color_index % CAM_COLORS.size()]
			P.rect(im, 3, 1, 6, 5, Color("c8ccd4"))
			P.rect(im, 4, 2, 4, 3, c)
			P.rect(im, 3, 1, 6, 1, Color("f4f6fa"))
			P.rect(im, 5, 6, 2, 6, Color("d89a24"))
			P.rect(im, 5, 6, 1, 6, Color("f0c050"))
			P.rect(im, 4, 12, 4, 3, Color("c8ccd4"))
			P.rect(im, 5, 13, 2, 1, Color("505868"))
		"draw":
			P.rect(im, 4, 0, 4, 3, Color("c8ccd4"))
			P.rect(im, 5, 1, 2, 1, Color("505868"))
			P.rect(im, 4, 3, 4, 8, Color("3a78c8"))
			P.rect(im, 4, 3, 1, 8, Color("5a98e8"))
			P.rect(im, 7, 3, 1, 8, Color("24488a"))
			P.rect(im, 4, 11, 4, 4, Color("c8ccd4"))
			P.rect(im, 5, 12, 2, 2, Color("505868"))
		"pin_draw":
			P.rect(im, 1, 0, 8, 3, Color("8a5a2a"))
			P.rect(im, 2, 0, 6, 1, Color("c47a3a"))
			P.rect(im, 4, 3, 4, 8, Color("3a78c8"))
			P.rect(im, 4, 3, 1, 8, Color("5a98e8"))
			P.rect(im, 4, 11, 4, 4, Color("c8ccd4"))
			P.rect(im, 5, 12, 2, 2, Color("505868"))
	P.outline(im)
	var tex := ImageTexture.create_from_image(im)
	_cache[key] = tex
	return tex
