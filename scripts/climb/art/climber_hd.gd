class_name ClimberHD
extends RefCounted
## The climber on the wall, painted at the screen's full density: every
## pixel here is one screen pixel, twice the detail of the rest of the
## climbing screen's painters (which work on the 480 x 270 grid and are
## doubled by ClimbHiRes). ClimbSprites.climber hands each wall pose here and
## reports the picture at its old size, so it lands where it always did.
##
## The pose is the same Dictionary ClimbSprites builds (hand and foot targets
## as offsets from the torso on the 480 grid), plus how each limb is on the
## rock (see HoldShape):
##
## - "gr" / "gl": the right and left hand's shape ("jug", "crimp",
##   "hand_jam", ...). A hand with none hangs relaxed.
## - "ftr" / "ftl": the right and left foot's technique ("edge", "smear",
##   "toe_jam", "step").
##
## Hands and shoes are small pixel sprites (HANDS, FEET below), drawn for the
## right side and mirrored for the left, seen from behind as the camera sees
## them: the back of the hand, the heel of the shoe. A jam hides the hand in
## a crack with only the taped back of it showing; a crimp's knuckles tent up;
## a smear shows the sole.

const P := preload("res://scripts/climb/art/climb_paint.gd")
const K := 2.0
const SIZE := Vector2i(112, 128)
const ORIGIN := Vector2(56, 76)

const SHOULDER_L := Vector2(-11, -12)
const SHOULDER_R := Vector2(11, -12)
const HIP_L := Vector2(-5, 14)
const HIP_R := Vector2(5, 14)
const UPPER_ARM := 16.0
const FOREARM := 18.0
const THIGH := 17.0
const SHIN := 17.0

const TAPE := Color("f5eee0")
const TAPE_SHADE := Color("bdb8ae")
const CHALK := Color("f5eee0")
const CRACK := Color("1c1a22")
const CRACK_LIP := Color("6a6a70")
const GLOVE := Color("3a3540")

## Hand sprites for the right hand, fingers up, back of the hand to the
## camera, the wrist at the bottom middle. Thumbs are on the left (toward the
## body). Letters: s skin, l lit, d shade, k knuckle highlight, o deep shade,
## t tape, T tape shade, c crack, C crack lip, . clear.
const HANDS := {
	"jug": [
		".oooooooo.",
		".kkkkkkkk.",
		".sdsdsdsd.",
		".sssssssso",
		"lssssssssd",
		"lsssssssd.",
		".lsssssd..",
		"..lsssd...",
		"...lsd....",
	],
	"edge": [
		".k.k.k.k..",
		".ssssssss.",
		".sdsdsdsd.",
		".ssssssssd",
		".lsssssssd",
		"llsssssd..",
		".lssssd...",
		"..lsssd...",
		"...lsd....",
	],
	"crimp": [
		"..k.k.k.k.",
		".kskskskd.",
		".sdsdsdsd.",
		"lllsssssd.",
		"ldlssssd..",
		".lssssd...",
		"..lsssd...",
		"...lsd....",
	],
	"pinch": [
		"ll...ssss.",
		"ls...ssssd",
		"ls...sdsdd",
		"ls...ssssd",
		".ls..sssd.",
		".lsssssd..",
		"..lsssd...",
		"...lsd....",
	],
	"sidepull": [
		"...sssk...",
		"..ssssdk..",
		"..lsssdk..",
		"..lsssdk..",
		"..lsssdk..",
		"..lssssd..",
		"...lssd...",
		"...lsd....",
	],
	"undercling": [
		"cccccccccc",
		".s.s.s.s..",
		".ssssssss.",
		".sdsdsdsd.",
		".lssssssd.",
		"..lsssssd.",
		"...lsssd..",
		"...lsd....",
	],
	"palm": [
		".s.s.s.s..",
		".s.s.s.s..",
		".sssssssd.",
		"lsssssssd.",
		"lssssssssd",
		".lsssssd..",
		"..lsssd...",
		"...lsd....",
	],
	"finger_jam": [
		"....cC....",
		"...kcCk...",
		"...scCs...",
		"..lscCsd..",
		"..ttttttd.",
		".lttttttd.",
		"..lssssd..",
		"...lsd....",
	],
	"hand_jam": [
		"..ccccc...",
		".Ccccccc..",
		".CtTtTtc..",
		".Cttttttc.",
		".lltttttd.",
		"..lttttd..",
		"..lsssd...",
		"...lsd....",
	],
	"fist_jam": [
		"cccccccccc",
		"Cc......cc",
		"Cckkkkkkcc",
		"Cctttttdcc",
		"Ccttttttdc",
		".lttttttd.",
		"..lttttd..",
		"...lsd....",
	],
	"open": [
		"..ssss..",
		".lssssd.",
		".lsssssd",
		".lsssssd",
		"..lsssd.",
		"...ssd..",
	],
}

## Shoe sprites for the right foot, heel to the camera, the bottom middle at
## the foot target. R shoe, L shoe lit, D shoe shade, b rubber, B scuffed
## rubber, w logo, c crack, . clear.
const FEET := {
	"edge": [
		"...LRRRR...",
		"..LRRRRRD..",
		".LRRRwRRRD.",
		".LRRRRRRRD.",
		".RRRRRRRRD.",
		".bbbbbbbbb.",
		"..BbbbbbB..",
	],
	"smear": [
		"...LRRRR...",
		"..LRRRRRD..",
		".LRRRwRRRD.",
		".RRRRRRRRD.",
		".bbbbbbbbbb",
		".BBBBBBBBBb",
		"..BBBBBBBb.",
		"...bbbbbb..",
	],
	"toe_jam": [
		"......c......",
		"....LRcRRRR..",
		"..LLRRcRRRRD.",
		".LRRRRcRRRRRD",
		".bbbbbcbbbbbb",
		"......c......",
	],
	"step": [
		"...LRRRR...",
		"..LRRRRRD..",
		".LRRRwRRRRD",
		".RRRRRRRRRD",
		".RRRRRRRRRD",
		"bbbbbbbbbbb",
	],
}


## The climber in [param pose] wearing [param kit], at full density.
static func paint(pose: Dictionary, kit: Dictionary, flags: Dictionary) -> Image:
	var im := P.make(SIZE.x, SIZE.y)
	var lean := float(pose.get("lean", 0)) * K
	var torso := ORIGIN + Vector2(lean, 0)
	var tilt := float(pose.get("tilt", 0))
	var snow: bool = flags.get("snow", false)
	var harness_on: bool = int(kit.get("harness", 0)) > 0 or flags.get("always_harness", false)
	var shoes := _shoe_colors(int(kit.get("climbing_shoes", 0)) > 0)
	var crampons: bool = int(kit.get("crampons", 0)) > 0 and snow
	var axe: bool = int(kit.get("ice_axe", 0)) > 0 and snow
	# Legs, behind everything.
	for side in [-1, 1]:
		var key := "fr" if side > 0 else "fl"
		var hip: Vector2 = torso + (HIP_R if side > 0 else HIP_L)
		var foot: Vector2 = ORIGIN + _at(pose.get(key, Vector2(side * 5, 18))) + Vector2(lean * 0.3, 0)
		var joints := _limb_out(hip, foot, THIGH, SHIN, float(side))
		var tech: String = pose.get("ftr" if side > 0 else "ftl", "step" if pose.get("gr", "") == "" else "edge")
		if crampons:
			tech = "step"
		_leg(im, hip, joints, tech, side > 0, shoes, crampons, harness_on)
	var body := _body_layer(kit, flags, harness_on)
	var at := Vector2i(roundi(torso.x) - LAYER_C.x, roundi(torso.y) - LAYER_C.y)
	im.blend_rect(body, Rect2i(Vector2i.ZERO, body.get_size()), at)
	for side in [-1, 1]:
		var key := "hr" if side > 0 else "hl"
		var shoulder: Vector2 = torso + (SHOULDER_R if side > 0 else SHOULDER_L)
		var hand: Vector2 = ORIGIN + _at(pose.get(key, Vector2(side * 6, -12))) + Vector2(lean * 0.4, 0)
		var joints := _limb_out(shoulder, hand, UPPER_ARM, FOREARM, float(side))
		var shape: String = pose.get("gr" if side > 0 else "gl", "")
		if axe and side > 0:
			shape = "tool"
		_arm(im, shoulder, joints, shape, side > 0, pose.get("chalk", false))
	# The head last: the camera is behind you and your hands are on the
	# rock, so a raised arm passes behind the hat.
	var head := _head_layer()
	var hc := torso + Vector2(lean * 0.25, -25 + tilt * 0.6)
	im.blend_rect(head, Rect2i(Vector2i.ZERO, head.get_size()), Vector2i(roundi(hc.x) - HEAD_C.x, roundi(hc.y) - HEAD_C.y))
	_outline(im)
	return im


## The torso with its harness and gear, painted once for each kit and look
## and stamped on every pose (it doesn't change shape when you move).
const LAYER_SIZE := Vector2i(48, 72)
const LAYER_C := Vector2i(24, 22)
const HEAD_SIZE := Vector2i(30, 30)
const HEAD_C := Vector2i(15, 16)
static var _layers := {}


static func _look_key() -> String:
	return "%s%s%s%s%s%s" % [ClimbSprites.SKIN.to_html(), ClimbSprites.SHIRT.to_html(), ClimbSprites.PANTS.to_html(),
		ClimbSprites.HAIR.to_html(), ClimbSprites.HAT.to_html(), ClimbSprites.HAT_KIND]


static func _body_layer(kit: Dictionary, flags: Dictionary, harness_on: bool) -> Image:
	var key := "b|%s|%s|%s|%s|%s|%s" % [_look_key(), ClimbSprites._kit_key(kit), harness_on,
		flags.get("portaledge", false), flags.get("aiders", false), flags.get("rope_coil", false)]
	if _layers.has(key):
		return _layers[key]
	if _layers.size() > 64:
		_layers.clear()
	var im := P.make(LAYER_SIZE.x, LAYER_SIZE.y)
	var torso := Vector2(LAYER_C)
	_torso(im, torso, harness_on)
	if flags.get("portaledge", false):
		_portaledge(im, torso)
	if int(kit.get("chalk_bag", 0)) > 0:
		_chalk_bag(im, torso)
	_rack(im, torso, int(kit.get("cam", 0)), int(kit.get("quickdraw", 0)))
	if int(kit.get("belay_device", 0)) > 0 and harness_on:
		P.rect(im, roundi(torso.x) + 2, roundi(torso.y) + 14, 5, 6, ClimbSprites.STEEL)
		P.rect(im, roundi(torso.x) + 2, roundi(torso.y) + 14, 2, 2, ClimbSprites.STEEL_LIT)
		P.rect(im, roundi(torso.x) + 5, roundi(torso.y) + 17, 2, 3, ClimbSprites.STEEL_DARK)
	if int(kit.get("rope", 0)) > 0 and flags.get("rope_coil", false):
		for i in 3:
			P.line(im, torso + Vector2(-12, -12 + i * 4), torso + Vector2(12, -10 + i * 4), ClimbSprites.ROPE_C.darkened(0.15 * (i % 2)), 2)
	if int(kit.get("aiders", 0)) > 0 and flags.get("aiders", false):
		_aiders(im, torso)
	_layers[key] = im
	return im


static func _head_layer() -> Image:
	var key := "h|" + _look_key()
	if _layers.has(key):
		return _layers[key]
	var im := P.make(HEAD_SIZE.x, HEAD_SIZE.y)
	_head(im, Vector2(HEAD_C), 0.0)
	_layers[key] = im
	return im


## ClimbSprites._outline, over just the part of the picture that's painted.
static func _outline(im: Image) -> void:
	var used := im.get_used_rect().grow(1).intersection(Rect2i(Vector2i.ZERO, im.get_size()))
	var part := im.get_region(used)
	ClimbSprites._outline(part)
	im.blit_rect(part, Rect2i(Vector2i.ZERO, part.get_size()), used.position)


static func _at(v: Vector2) -> Vector2:
	return v * K


static func _shoe_colors(climbing: bool) -> Dictionary:
	if climbing:
		return {"R": Color("b3362b"), "L": Color("d9574a"), "D": Color("7c2420"), "b": Color("2b2a30"),
			"B": Color("5a5860"), "w": Color("f7a64a")}
	return {"R": Color("92693d"), "L": Color("b08752"), "D": Color("6b4829"), "b": Color("47301f"),
		"B": Color("6b4829"), "w": Color("d8a63b")}


## Two-bone reach (ClimbSprites._limb) with the joint bent away from the body.
static func _limb_out(a: Vector2, t: Vector2, l1: float, l2: float, out: float) -> Array[Vector2]:
	var p1 := ClimbSprites._limb(a, t, l1, l2, 1.0)
	var p2 := ClimbSprites._limb(a, t, l1, l2, -1.0)
	return p1 if (p1[0].x - p2[0].x) * out > 0.0 else p2


## A limb segment, round and lit from the upper left: a dark contour, the
## base tone, a lit strip on the upper-left side and a 1 px highlight.
static func _seg(im: Image, a: Vector2, b: Vector2, w0: int, w1: int, base: Color, contour := true) -> void:
	var d := (b - a)
	if d.length() < 0.01:
		d = Vector2.DOWN
	var n := Vector2(-d.y, d.x).normalized()
	if n.dot(Vector2(-1, -1)) < 0.0:
		n = -n
	var steps := maxi(int(d.length()), 1)
	for i in steps + 1:
		var t := float(i) / steps
		var p := a.lerp(b, t)
		var w := roundi(lerpf(w0, w1, t))
		if contour:
			_dot(im, p, w + 2, base.darkened(0.55))
	for i in steps + 1:
		var t := float(i) / steps
		var p := a.lerp(b, t)
		var w := roundi(lerpf(w0, w1, t))
		_dot(im, p, w, base.darkened(0.2))
		_dot(im, p + n * (w * 0.2), maxi(w - 2, 1), base)
		if w >= 4:
			_dot(im, p + n * (w * 0.38), 1, base.lightened(0.22))


## A filled round dot [param w] pixels across.
static func _dot(im: Image, p: Vector2, w: int, col: Color) -> void:
	if w <= 1:
		P.px(im, roundi(p.x), roundi(p.y), col)
		return
	if w <= 2:
		P.rect(im, roundi(p.x - 0.5), roundi(p.y - 0.5), 2, 2, col)
		return
	# A rounded square from two native fills: fast enough to stamp every
	# pixel along a limb.
	var x0 := roundi(p.x - w * 0.5)
	var y0 := roundi(p.y - w * 0.5)
	P.rect(im, x0 + 1, y0, w - 2, w, col)
	P.rect(im, x0, y0 + 1, w, w - 2, col)


# ---------------------------------------------------------------- body

static func _torso(im: Image, t: Vector2, harness_on: bool) -> void:
	var s: Color = ClimbSprites.SHIRT
	var pants: Color = ClimbSprites.PANTS
	var tx := roundi(t.x)
	var ty := roundi(t.y)
	# The back, row by row: wide at the shoulders, narrower at the waist.
	for y in range(-15, 11):
		var half := 12 if y < -10 else (11 if y < -4 else (10 if y < 2 else 9))
		if y == -15:
			half = 9
		elif y == -14:
			half = 11
		for x in range(-half, half):
			var u := (x + 0.5) / float(half)
			var col := s
			if u < -0.62:
				col = s.lightened(0.22)
			elif u > 0.55:
				col = s.darkened(0.24)
			elif u > 0.2:
				col = s.darkened(0.08)
			P.px(im, tx + x, ty + y, col)
	# Spine, shoulder blades, collar and the fold under each arm.
	P.vline(im, tx, ty - 11, 18, s.darkened(0.16))
	P.ellipse(im, tx - 6, ty - 8, 4.0, 3.0, s.lightened(0.12))
	P.ellipse(im, tx + 6, ty - 8, 4.0, 3.0, s.darkened(0.02))
	P.hline(im, tx - 6, ty - 8, 3, s.lightened(0.28))
	P.hline(im, tx - 8, ty - 15, 16, s.lightened(0.32))
	P.line(im, Vector2(tx - 10, ty - 6), Vector2(tx - 7, ty + 1), s.darkened(0.1))
	P.line(im, Vector2(tx + 9, ty - 6), Vector2(tx + 6, ty + 1), s.darkened(0.3))
	P.line(im, Vector2(tx - 3, ty + 4), Vector2(tx + 4, ty + 6), s.darkened(0.12))
	# Pants seat.
	for y in range(11, 20):
		var half := 9 if y < 17 else 8
		for x in range(-half, half):
			var col := pants
			if x < -half + 3:
				col = pants.lightened(0.16)
			elif x > half - 4:
				col = pants.darkened(0.22)
			P.px(im, tx + x, ty + y, col)
	P.vline(im, tx, ty + 12, 8, pants.darkened(0.3))
	P.line(im, Vector2(tx - 6, ty + 17), Vector2(tx - 2, ty + 19), pants.darkened(0.15))
	P.line(im, Vector2(tx + 5, ty + 17), Vector2(tx + 2, ty + 19), pants.darkened(0.3))
	# Waist belt (the harness, or a plain belt).
	var belt := ClimbSprites.HARNESS if harness_on else Color("86694b")
	P.rect(im, tx - 10, ty + 7, 20, 5, belt)
	P.hline(im, tx - 10, ty + 7, 20, belt.lightened(0.35))
	P.hline(im, tx - 10, ty + 11, 20, belt.darkened(0.32))
	P.rect(im, tx + 6, ty + 8, 4, 3, belt.darkened(0.15))
	if harness_on:
		# Back buckle, the rear elastics to the leg loops and the gear loops.
		P.rect(im, tx - 2, ty + 7, 5, 5, ClimbSprites.STEEL)
		P.rect(im, tx - 1, ty + 8, 3, 3, belt.darkened(0.2))
		P.px(im, tx - 2, ty + 7, ClimbSprites.STEEL_LIT)
		P.line(im, Vector2(tx - 5, ty + 12), Vector2(tx - 6, ty + 19), ClimbSprites.HARNESS.darkened(0.12), 2)
		P.line(im, Vector2(tx + 5, ty + 12), Vector2(tx + 6, ty + 19), ClimbSprites.HARNESS.darkened(0.3), 2)
		for gx in [-12, -9, 8, 11]:
			P.rect(im, tx + gx, ty + 12, 2, 2, Color("47464d"))
	else:
		P.rect(im, tx - 1, ty + 8, 3, 3, Color("d8a63b"))


static func _chalk_bag(im: Image, t: Vector2) -> void:
	var tx := roundi(t.x)
	var ty := roundi(t.y)
	var blue := Color("6f5aa6")
	P.rect(im, tx - 3, ty + 1, 7, 8, blue)
	P.rect(im, tx - 3, ty + 1, 2, 8, blue.lightened(0.18))
	P.rect(im, tx + 2, ty + 2, 2, 7, blue.darkened(0.3))
	P.hline(im, tx - 3, ty + 8, 7, blue.darkened(0.35))
	# Rolled fleece rim, the drawstring toggle and a dusting of chalk.
	P.rect(im, tx - 4, ty - 1, 9, 2, CHALK)
	P.hline(im, tx - 4, ty, 9, TAPE_SHADE)
	P.rect(im, tx + 4, ty + 3, 1, 2, Color("f7a64a"))
	for p in [Vector2i(-1, 3), Vector2i(1, 5), Vector2i(-2, 6)]:
		P.px(im, tx + p.x, ty + p.y, CHALK)


static func _rack(im: Image, t: Vector2, cams: int, draws: int) -> void:
	var tx := roundi(t.x)
	var ty := roundi(t.y)
	# Cams on the left gear loops: colored lobes, a trigger bar, a sling.
	for i in mini(cams, 6):
		var c: Color = ClimbSprites.CAM_COLORS[i % ClimbSprites.CAM_COLORS.size()]
		var x := tx - 17 + (i % 2) * 5
		var y := ty + 13 + (i / 2) * 5 + (i % 2) * 2
		P.vline(im, x + 2, y - 2, 3, ClimbSprites.STEEL_DARK)
		P.rect(im, x, y, 5, 3, c)
		P.hline(im, x, y, 5, c.lightened(0.5))
		P.px(im, x + 2, y + 1, c.darkened(0.4))
		P.hline(im, x, y + 3, 5, ClimbSprites.STEEL)
		P.vline(im, x + 2, y + 4, 2, c.darkened(0.2))
	# Quickdraws on the right: a biner, the dogbone, a biner.
	for i in mini(draws, 6):
		var x := tx + 12 + (i % 3) * 3
		var y := ty + 12 + (i / 3) * 6
		var sling := Color("6f5aa6") if i % 2 == 0 else Color("f7a64a")
		P.rect(im, x, y, 2, 3, ClimbSprites.STEEL)
		P.px(im, x, y, ClimbSprites.STEEL_LIT)
		P.rect(im, x, y + 3, 2, 3, sling)
		P.rect(im, x, y + 6, 2, 3, ClimbSprites.STEEL_DARK)
		P.px(im, x, y + 6, ClimbSprites.STEEL)


static func _aiders(im: Image, t: Vector2) -> void:
	var tx := roundi(t.x)
	var ty := roundi(t.y)
	for i in 2:
		var x := tx + 9 + i * 4
		var h := 24 + i * 6
		P.vline(im, x, ty + 10, h, Color("6f5aa6"))
		P.vline(im, x + 1, ty + 10, h, Color("4d3f7a"))
		for k in 5:
			P.hline(im, x - 1, ty + 15 + k * 5, 4, Color("f5eee0"))
		P.rect(im, x, ty + 9, 2, 2, ClimbSprites.STEEL)


static func _portaledge(im: Image, t: Vector2) -> void:
	var tx := roundi(t.x)
	var ty := roundi(t.y)
	P.rect(im, tx - 14, ty - 17, 28, 11, Color("a84a1c"))
	P.rect(im, tx - 14, ty - 17, 28, 7, Color("d9772a"))
	P.hline(im, tx - 14, ty - 17, 28, Color("f7a64a"))
	P.rect(im, tx - 18, ty - 11, 4, 5, ClimbSprites.STEEL)
	P.px(im, tx - 18, ty - 11, ClimbSprites.STEEL_LIT)
	P.rect(im, tx + 14, ty - 11, 4, 5, ClimbSprites.STEEL_DARK)
	P.vline(im, tx - 6, ty - 13, 9, Color("47301f"))
	P.vline(im, tx + 5, ty - 13, 9, Color("47301f"))


static func _leg(im: Image, hip: Vector2, joints: Array[Vector2], tech: String, right: bool, shoes: Dictionary, crampons: bool, harness_on: bool) -> void:
	var pants: Color = ClimbSprites.PANTS
	var knee := joints[0]
	var foot := joints[1]
	var ankle := foot + Vector2(0, -4)
	_seg(im, hip, knee, 9, 8, pants)
	_seg(im, knee, ankle, 7, 5, pants)
	# A crease behind the knee.
	P.px(im, roundi(knee.x), roundi(knee.y), pants.darkened(0.35))
	if harness_on:
		var mid := hip.lerp(knee, 0.32)
		P.line(im, mid + Vector2(-4, -1), mid + Vector2(4, 1), ClimbSprites.HARNESS.darkened(0.1), 2)
		P.px(im, roundi(mid.x) - 4, roundi(mid.y) - 1, ClimbSprites.HARNESS.lightened(0.3))
	# Rolled cuff, then the shoe.
	P.rect(im, roundi(ankle.x) - 3, roundi(ankle.y) - 1, 7, 2, pants.lightened(0.26))
	var sprite: Array = FEET.get(tech, FEET.edge)
	var cols := shoes.duplicate()
	cols["c"] = CRACK
	_stamp(im, sprite, foot + Vector2(0, 3), not right, cols)
	if crampons:
		for i in 4:
			P.px(im, roundi(foot.x) - 4 + i * 3, roundi(foot.y) + 3, ClimbSprites.STEEL)
			P.px(im, roundi(foot.x) - 4 + i * 3, roundi(foot.y) + 4, ClimbSprites.STEEL_DARK)


static func _arm(im: Image, shoulder: Vector2, joints: Array[Vector2], shape: String, right: bool, chalk: bool) -> void:
	var shirt: Color = ClimbSprites.SHIRT
	var elbow := joints[0]
	var hand := joints[1]
	var d := (hand - elbow).normalized() if hand.distance_to(elbow) > 0.1 else Vector2.UP
	# The wrist sits a little short of the hand target: the hand sprite covers
	# the rest, reaching the hold.
	var upright := shape != "" and shape != "tool" and d.y < 0.35
	var wrist := hand + Vector2(0, 3) if upright else hand - d * 2.0
	_seg(im, shoulder, elbow, 8, 7, shirt)
	# Forearm: thick under the elbow, thin at the wrist.
	_seg(im, elbow, wrist, 6, 4, ClimbSprites.SKIN)
	# Pushed-up sleeve at the elbow.
	P.ellipse(im, elbow.x, elbow.y, 3.5, 2.5, shirt.darkened(0.1))
	P.hline(im, roundi(elbow.x) - 3, roundi(elbow.y) - 2, 5, shirt.lightened(0.25))
	if shape == "tool":
		_axe(im, hand)
		return
	var key := shape if upright and HANDS.has(shape) else "open"
	var sprite: Array = HANDS[key]
	if key == "open":
		_stamp(im, sprite, hand + Vector2(0, 3), not right, _skin(chalk))
		return
	# A gaston is a sidepull turned the other way.
	var mirror := not right
	if shape == "gaston":
		sprite = HANDS.sidepull
		mirror = right
	_stamp(im, sprite, hand + Vector2(0, 4), mirror, _skin(chalk))
	if chalk:
		_chalk_fingers(im, sprite, hand + Vector2(0, 4), mirror)


static func _skin(chalk: bool) -> Dictionary:
	var s: Color = ClimbSprites.SKIN
	var shade: Color = ClimbSprites.SKIN_SHADE
	return {
		"s": s, "l": s.lightened(0.14), "d": shade, "o": shade.darkened(0.3),
		"k": CHALK.lerp(s, 0.45) if chalk else s.lightened(0.28),
		"t": TAPE, "T": TAPE_SHADE, "c": CRACK, "C": CRACK_LIP,
	}


## Chalk on the fingertips: the top two rows of skin go white here and there.
static func _chalk_fingers(im: Image, sprite: Array, base: Vector2, mirror: bool) -> void:
	var w: int = str(sprite[0]).length()
	var h := sprite.size()
	var x0 := roundi(base.x) - w / 2
	var y0 := roundi(base.y) - h
	for y in mini(2, h):
		var row: String = sprite[y]
		for x in w:
			if row[x] in ["s", "d"] and (x + y) % 2 == 0:
				var sx := (w - 1 - x) if mirror else x
				P.px(im, x0 + sx, y0 + y, CHALK)


## Stamps a letter sprite with its bottom middle at [param base].
static func _stamp(im: Image, sprite: Array, base: Vector2, mirror: bool, colors: Dictionary) -> void:
	var w: int = str(sprite[0]).length()
	var h := sprite.size()
	var x0 := roundi(base.x) - w / 2
	var y0 := roundi(base.y) - h
	for y in h:
		var row: String = sprite[y]
		for x in w:
			var ch := row[x] if x < row.length() else "."
			if ch == "." or not colors.has(ch):
				continue
			var sx := (w - 1 - x) if mirror else x
			P.px(im, x0 + sx, y0 + y, colors[ch])


static func _axe(im: Image, hand: Vector2) -> void:
	var hx := roundi(hand.x)
	var hy := roundi(hand.y)
	P.rect(im, hx - 1, hy - 12, 2, 30, Color("92693d"))
	P.rect(im, hx + 1, hy - 12, 1, 30, Color("6b4829"))
	P.rect(im, hx - 8, hy - 16, 20, 3, ClimbSprites.STEEL)
	P.hline(im, hx - 8, hy - 16, 20, ClimbSprites.STEEL_LIT)
	P.rect(im, hx - 10, hy - 14, 3, 5, ClimbSprites.STEEL_DARK)
	P.rect(im, hx + 10, hy - 14, 3, 3, ClimbSprites.STEEL_DARK)
	P.rect(im, hx - 1, hy + 16, 3, 3, ClimbSprites.STEEL)
	# A gloved fist round the shaft, and the leash.
	P.rect(im, hx - 3, hy - 3, 7, 6, GLOVE)
	P.hline(im, hx - 3, hy - 3, 7, GLOVE.lightened(0.3))
	P.rect(im, hx - 3, hy + 3, 2, 2, Color("f7a64a"))


## The head from behind: neck, hair, ears and the hat you chose.
static func _head(im: Image, c: Vector2, tilt: float) -> void:
	var hair: Color = ClimbSprites.HAIR
	var skin: Color = ClimbSprites.SKIN
	var shade: Color = ClimbSprites.SKIN_SHADE
	var hat: Color = ClimbSprites.HAT
	var hx := roundi(c.x)
	var hy := roundi(c.y)
	# Neck, in the shirt collar.
	P.rect(im, hx - 4, hy + 7, 8, 6, shade)
	P.rect(im, hx - 4, hy + 7, 2, 6, skin)
	P.hline(im, hx - 3, hy + 11, 6, shade.darkened(0.2))
	# Hair: round crown, lit upper left, longer at the nape.
	P.shaded_ellipse(im, hx, hy, 8.5, 9.0, hair, hair.lightened(0.2), hair.darkened(0.25))
	P.rect(im, hx - 7, hy + 2, 14, 6, hair)
	P.rect(im, hx - 7, hy + 2, 3, 6, hair.lightened(0.16))
	P.rect(im, hx + 4, hy + 4, 3, 4, hair.darkened(0.25))
	for i in 4:
		P.vline(im, hx - 5 + i * 3, hy + 5, 3, hair.darkened(0.18))
	# Ears.
	P.rect(im, hx - 10, hy + 1, 2, 4, skin)
	P.px(im, hx - 10, hy + 4, shade)
	P.rect(im, hx + 8, hy + 1, 2, 4, shade)
	match ClimbSprites.HAT_KIND:
		"none":
			return
		"dome":
			P.shaded_ellipse(im, hx, hy - 3, 9.2, 7.0, hat, hat.lightened(0.28), hat.darkened(0.25))
			P.rect(im, hx - 9, hy, 18, 3, hat.darkened(0.12))
			P.hline(im, hx - 9, hy, 18, hat.lightened(0.15))
			P.hline(im, hx - 9, hy + 2, 18, hat.darkened(0.32))
		_:
			# Brim, crown, band.
			P.ellipse(im, hx, hy - 3, 13.0, 4.4, hat.darkened(0.25))
			P.ellipse(im, hx - 0.5, hy - 5, 11.6, 3.4, hat)
			P.hline(im, hx - 10, hy - 6, 8, hat.lightened(0.2))
			P.shaded_ellipse(im, hx, hy - 9, 7.6, 6.2, hat, hat.lightened(0.3), hat.darkened(0.22))
			P.rect(im, hx - 7, hy - 7, 15, 2, Color("d8a63b"))
			P.hline(im, hx + 2, hy - 7, 6, Color("ad7a22"))
			P.hline(im, hx - 9, hy - 2, 18, hat.darkened(0.45))
