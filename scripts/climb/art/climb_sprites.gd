class_name ClimbSprites
extends RefCounted
## The climber, the belayers and the hardware, painted in code at the game's
## pixel scale (a person is about 40 px tall, like the farmers in the games
## this art takes after): warm colors, a dark brown outline, light from the
## upper left. Figures are posed with two-bone limbs, so any hand or foot
## target gives a clean pose; frames are cached by pose, and doubled to the
## screen's 32px finish by ClimbHiRes.
##
## The climber shows what you own: red climbing shoes, a chalk bag, a harness
## with a rack of cams (colored by size) and quickdraws, a belay device, aiders,
## a rolled portaledge, an ice axe and crampons.
##
## POSES are Dictionaries with keys hr / hl / fr / fl (hand and foot targets,
## offsets from the torso center), lean, tilt, chalk and mode ("wall" is the
## default, "chimney" paints a face-on back-and-feet chimney climber). Use the
## factory functions: stance(step), fall_pose(), hang_pose(), cheer_pose(),
## chalk_pose(step), protect_pose(step), eat_pose(), rest_pose(), roof_pose(step),
## chimney_pose(side), stand_pose(), style_pose(style, step) (jams and laybacks)
## and mantle_pose(). Blend two poses with blend_pose().
##
## BELAYER modes: "belay" (standing, braced, device and rope; frames 0 neutral,
## 1 pay out, 2 take in), "look_up" (same, head tipped back to watch the
## leader), "sit" (relaxed, rope in the lap), "anchor" (seated and clipped to the
## anchor, belaying; frames 0/1/2 like "belay"), "spot" (a boulderer's spotter,
## no rope, both hands up), "cheer" (arms up; frame 1 hops).

const P := preload("res://scripts/climb/art/climb_paint.gd")
const SIZE := Vector2i(56, 64)
## Where the torso's center sits in a figure image.
const ORIGIN := Vector2(28, 38)
const BSIZE := Vector2i(48, 56)

const SKIN := Color("d6bd88")
const SKIN_LIT := Color("d6bd88")
const SKIN_SHADE := Color("b0925f")
const HAT := Color("7e531c")
const SHIRT := Color("5c8f3c")
const PANTS := Color("2d3050")
const HARNESS := Color("d8a63b")
const CAM_COLORS := [Color("b3362b"), Color("f7a64a"), Color("6f5aa6"), Color("6f5aa6"), Color("437f45")]
const STEEL := Color("bdb8ae")
const STEEL_LIT := Color("f5eee0")
const STEEL_DARK := Color("6a6a70")
const ROPE_C := Color("b3362b")
const ROPE_D := Color("b3362b")

static var _cache: Dictionary = {}


## Shoulder and hip positions relative to the torso center.
const SHOULDER_L := Vector2(-5.5, -6)
const SHOULDER_R := Vector2(5.5, -6)
const HIP_L := Vector2(-2.5, 7)
const HIP_R := Vector2(2.5, 7)
const ARM := 17.0
const LEG := 17.0


# ---------------------------------------------------------------- poses

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


## The stance for a pitch's style: hand jams stacked in a crack, a layback
## up a flake (hands pulling on its edge, feet pushing against the wall
## beside it), or the plain [method stance] on face climbing.
static func style_pose(style: String, step: int) -> Dictionary:
	var a := (step % 2) == 0
	match style:
		"crack":
			return {
				"hr": Vector2(2, -21) if a else Vector2(1, -10),
				"hl": Vector2(-1, -10) if a else Vector2(-2, -21),
				"fr": Vector2(3, 16) if a else Vector2(3, 22),
				"fl": Vector2(-3, 22) if a else Vector2(-3, 16),
				"lean": 0,
			}
		"flake":
			return {
				"hr": Vector2(11, -18) if a else Vector2(11, -9),
				"hl": Vector2(10, -9) if a else Vector2(10, -19),
				"fr": Vector2(12, 11) if a else Vector2(9, 15),
				"fl": Vector2(6, 17) if a else Vector2(10, 10),
				"lean": -2,
			}
	return stance(step)


## Pressing out a mantel onto a ledge: both hands down on the lip, a foot
## coming up.
static func mantle_pose() -> Dictionary:
	return {"hr": Vector2(8, -3), "hl": Vector2(-8, -3), "fr": Vector2(6, 9), "fl": Vector2(-5, 22), "lean": 0}


## Standing on a ledge, arms relaxed.
static func stand_pose() -> Dictionary:
	return {"hr": Vector2(9, 5), "hl": Vector2(-9, 5), "fr": Vector2(5, 22), "fl": Vector2(-5, 22), "lean": 0}


## Mid-fall: arms flung up and out, legs kicked out.
static func fall_pose() -> Dictionary:
	return {"hr": Vector2(12, -21), "hl": Vector2(-12, -19), "fr": Vector2(9, 21), "fl": Vector2(-8, 24), "lean": 0, "tilt": -2}


## Hanging on the rope after a fall: hands up on the rope, legs dangling.
static func hang_pose() -> Dictionary:
	return {"hr": Vector2(6, -14), "hl": Vector2(-6, -16), "fr": Vector2(5, 23), "fl": Vector2(-5, 25), "lean": 0, "tilt": 2}


## Arms up at the top.
static func cheer_pose() -> Dictionary:
	return {"hr": Vector2(12, -24), "hl": Vector2(-12, -24), "fr": Vector2(6, 22), "fl": Vector2(-6, 22), "lean": 0}


## Right hand in the chalk bag (stance feet and left hand).
static func chalk_pose(step: int) -> Dictionary:
	var p := stance(step)
	p["hr"] = Vector2(3, 6)
	p["chalk"] = true
	return p


## Right hand reaching to the rack at the hip; the left holds on.
static func protect_pose(step: int) -> Dictionary:
	var p := stance(step)
	p["hr"] = Vector2(7, 6)
	p["hl"] = Vector2(-9, -19)
	return p


## One hand up to the mouth.
static func eat_pose() -> Dictionary:
	var p := stance(1)
	p["hr"] = Vector2(3, -13)
	return p


## Resting on a good hold, one arm shaking out below.
static func rest_pose() -> Dictionary:
	var p := stance(0)
	p["hl"] = Vector2(-8, 4)
	p["fr"] = Vector2(7, 22)
	p["fl"] = Vector2(-7, 22)
	p["lean"] = -1
	return p


## Hanging under a roof: hands up, feet swung back and out.
static func roof_pose(step: int) -> Dictionary:
	var fwd := 1.0 if (step % 2) == 0 else -1.0
	return {
		"hr": Vector2(13 if fwd > 0 else 4, -24),
		"hl": Vector2(-4 if fwd > 0 else -13, -24),
		"fr": Vector2(-2, 19),
		"fl": Vector2(-11, 15),
		"lean": 2,
	}


## A chimney climber: back on one wall, feet on the other. [param side] is the
## wall the back is against, -1 left or +1 right. Walls are about 24 px apart:
## the near wall's surface is at ORIGIN.x - 6, the far wall's at ORIGIN.x + 19.
static func chimney_pose(side := -1) -> Dictionary:
	return {"mode": "chimney", "side": 1 if side >= 0 else -1, "hr": Vector2(0, 4), "hl": Vector2(0, 4), "fr": Vector2(18, 10), "fl": Vector2(18, 18), "lean": 0}


## A pose partway between two (keys that are not Vector2 take [param b]'s value).
static func blend_pose(a: Dictionary, b: Dictionary, t: float) -> Dictionary:
	var out := b.duplicate()
	for k in ["hr", "hl", "fr", "fl"]:
		var va: Vector2 = a.get(k, Vector2.ZERO)
		var vb: Vector2 = b.get(k, Vector2.ZERO)
		out[k] = va.lerp(vb, t)
	out["lean"] = lerpf(float(a.get("lean", 0)), float(b.get("lean", 0)), t)
	return out


# ---------------------------------------------------------------- climber API

static func climber(pose: Dictionary, kit: Dictionary, flags := {}) -> Texture2D:
	var key := "c|%s|%s|%s" % [_pose_key(pose), _kit_key(kit), str(flags)]
	if _cache.has(key):
		return _cache[key]
	var im: Image
	if str(pose.get("mode", "wall")) == "chimney":
		im = _paint_chimney(pose, kit, flags)
	else:
		im = _paint_climber(pose, kit, flags)
	var tex := ClimbHiRes.texture(im)
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
	parts.append(str(pose.get("side", 0)))
	return "|".join(parts)


static func _kit_key(kit: Dictionary) -> String:
	var parts: Array[String] = []
	for k in ["climbing_shoes", "chalk_bag", "harness", "cam", "quickdraw", "belay_device", "aiders", "portaledge", "ice_axe", "crampons", "rope"]:
		parts.append("%s%d" % [k.substr(0, 3), mini(int(kit.get(k, 0)), 6)])
	return "".join(parts)


## A colored outline: each dark edge takes a deep, saturated shade of the
## color it runs along. The edge on the upper-left (where the light hits the
## figure's outside) is lighter, so the outline breaks up there.
static func _outline(im: Image) -> void:
	var w := im.get_width()
	var h := im.get_height()
	var out := {}
	for y in h:
		for x in w:
			if im.get_pixel(x, y).a > 0.1:
				continue
			# The opaque neighbor this pixel borders, if any (right and below
			# count as lit-side neighbors: the outline is on our upper left).
			var src := Color(0.082, 0.078, 0.11, 0)
			var lit_side := false
			for d in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
				var n: Vector2i = Vector2i(x, y) + d
				if n.x < 0 or n.y < 0 or n.x >= w or n.y >= h:
					continue
				var c := im.get_pixel(n.x, n.y)
				if c.a > 0.5:
					src = c
					lit_side = d == Vector2i.RIGHT or d == Vector2i.DOWN
					break
			if src.a > 0.5:
				var v := src.v * (0.62 if lit_side else 0.34)
				out[Vector2i(x, y)] = Color.from_hsv(src.h, minf(src.s + 0.2, 1.0), v, 1.0)
	for p: Vector2i in out:
		im.set_pixelv(p, out[p])


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


## Like _limb, but the joint bends away from the body ([param out] is -1 for a
## limb on the left, +1 for the right).
static func _limb_out(a: Vector2, t: Vector2, l1: float, l2: float, out: float) -> Array[Vector2]:
	var p1 := _limb(a, t, l1, l2, 1.0)
	var p2 := _limb(a, t, l1, l2, -1.0)
	return p1 if (p1[0].x - p2[0].x) * out > 0.0 else p2


## A limb segment in three tones (lit upper-left, shaded lower-right), over a
## darker contour so it separates from whatever it crosses.
static func _seg(im: Image, a: Vector2, b: Vector2, w: int, base: Color, contour := true) -> void:
	if contour:
		P.line(im, a, b, base.darkened(0.55), w + 2)
	P.line(im, a, b, base.darkened(0.2), w)
	P.line(im, a + Vector2(-1, -1) * (1 if w >= 3 else 0), b + Vector2(-1, -1) * (1 if w >= 3 else 0), base, maxi(w - 1, 1))
	if w >= 3:
		P.line(im, a + Vector2(-1, -1), b + Vector2(-1, -1), base.lightened(0.18), 1)


static func _paint_climber(pose: Dictionary, kit: Dictionary, flags: Dictionary) -> Image:
	var im := P.make(SIZE.x, SIZE.y)
	var o := ORIGIN
	var lean: float = pose.get("lean", 0)
	var torso := o + Vector2(lean, 0)
	var shoes_red := int(kit.get("climbing_shoes", 0)) > 0
	var shoe_col := Color("b3362b") if shoes_red else Color("92693d")
	var shoe_dark := Color("b3362b") if shoes_red else Color("6b4829")
	var sole := Color("2b2a30") if shoes_red else Color("47301f")
	var snow: bool = flags.get("snow", false)
	var crampons: bool = int(kit.get("crampons", 0)) > 0 and snow
	var axe: bool = int(kit.get("ice_axe", 0)) > 0 and snow
	var harness_on: bool = int(kit.get("harness", 0)) > 0 or flags.get("always_harness", false)
	var tilt: float = pose.get("tilt", 0)
	var tx := roundi(torso.x)
	var ty := roundi(torso.y)
	# Portaledge roll, strapped across the back (behind everything).
	# Legs first (they're behind the harness).
	var hl: Vector2 = torso + HIP_L
	var hr: Vector2 = torso + HIP_R
	var fl: Vector2 = o + pose.get("fl", Vector2(-5, 20)) + Vector2(lean * 0.3, 0)
	var fr: Vector2 = o + pose.get("fr", Vector2(5, 16)) + Vector2(lean * 0.3, 0)
	var leg_l := _limb_out(hl, fl, LEG * 0.5, LEG * 0.5, -1.0)
	var leg_r := _limb_out(hr, fr, LEG * 0.5, LEG * 0.5, 1.0)
	_draw_leg(im, hl, leg_l, shoe_col, shoe_dark, sole, crampons, harness_on)
	_draw_leg(im, hr, leg_r, shoe_col, shoe_dark, sole, crampons, harness_on)
	# Torso: shoulders a touch wider than the waist, light from the left.
	_torso(im, tx, ty, harness_on)
	if flags.get("portaledge", false):
		_portaledge_roll(im, tx, ty)
	# Chalk bag, on the small of the back.
	if int(kit.get("chalk_bag", 0)) > 0:
		_chalk_bag(im, tx, ty)
	# The rack: cams (by size) on the left, quickdraws on the right.
	_rack(im, tx, ty, int(kit.get("cam", 0)), int(kit.get("quickdraw", 0)))
	if int(kit.get("belay_device", 0)) > 0 and harness_on:
		# The belay device hangs from a locker at the front of the belt; a bit shows.
		P.rect(im, tx + 1, ty + 7, 3, 3, STEEL)
		P.px(im, tx + 1, ty + 7, STEEL_LIT)
		P.px(im, tx + 2, ty + 8, STEEL_DARK)
		P.px(im, tx + 3, ty + 9, STEEL_DARK)
	if int(kit.get("rope", 0)) > 0 and flags.get("rope_coil", false):
		for i in 3:
			P.hline(im, tx - 6, ty - 6 + i * 2, 13, ROPE_C if i != 1 else ROPE_D)
	if int(kit.get("aiders", 0)) > 0 and flags.get("aiders", false):
		_aiders(im, tx, ty)
	# Arms.
	var sl: Vector2 = torso + SHOULDER_L
	var sr: Vector2 = torso + SHOULDER_R
	var tl: Vector2 = o + pose.get("hl", Vector2(-6, -9)) + Vector2(lean * 0.4, 0)
	var tr: Vector2 = o + pose.get("hr", Vector2(6, -19)) + Vector2(lean * 0.4, 0)
	var arm_l := _limb_out(sl, tl, ARM * 0.5, ARM * 0.5, -1.0)
	var arm_r := _limb_out(sr, tr, ARM * 0.5, ARM * 0.5, 1.0)
	var chalk: bool = pose.get("chalk", false)
	_draw_arm(im, sl, arm_l, chalk and false)
	_draw_arm(im, sr, arm_r, chalk)
	if axe:
		_draw_axe(im, arm_r[1])
	# Head and hat, from behind.
	var hx := tx + roundi(lean * 0.5)
	var hy := ty - 14 + roundi(tilt * 0.3)
	_head(im, hx, hy, tilt)
	_outline(im)
	return im


static func _portaledge_roll(im: Image, tx: int, ty: int) -> void:
	# A rolled portaledge strapped across the upper back, tubes poking out.
	P.rect(im, tx - 7, ty - 8, 14, 6, Color("a84a1c"))
	P.rect(im, tx - 7, ty - 8, 14, 4, Color("d9772a"))
	P.hline(im, tx - 7, ty - 8, 14, Color("f7a64a"))
	P.rect(im, tx + 4, ty - 4, 3, 3, Color("7e531c"))
	P.rect(im, tx - 9, ty - 5, 2, 3, STEEL)
	P.px(im, tx - 9, ty - 5, STEEL_LIT)
	P.rect(im, tx + 7, ty - 5, 2, 3, STEEL_DARK)
	P.vline(im, tx - 3, ty - 6, 5, Color("47301f"))
	P.vline(im, tx + 2, ty - 6, 5, Color("47301f"))


static func _torso(im: Image, tx: int, ty: int, harness_on: bool) -> void:
	var s := SHIRT
	# Body, then shoulders.
	P.rect(im, tx - 5, ty - 7, 10, 14, s)
	P.rect(im, tx - 6, ty - 7, 12, 5, s)
	# Light on the left side, shade on the right and under the arms.
	P.rect(im, tx - 6, ty - 7, 2, 5, s.lightened(0.25))
	P.rect(im, tx - 5, ty - 2, 2, 7, s.lightened(0.18))
	P.rect(im, tx + 3, ty - 4, 3, 2, s.darkened(0.2))
	P.rect(im, tx + 3, ty - 2, 2, 7, s.darkened(0.22))
	P.vline(im, tx, ty - 5, 9, s.darkened(0.12))
	# Shoulder yoke and collar.
	P.hline(im, tx - 5, ty - 7, 10, s.lightened(0.34))
	P.hline(im, tx - 5, ty - 3, 10, s.darkened(0.1))
	# Pants seat.
	P.rect(im, tx - 5, ty + 5, 10, 4, PANTS)
	P.rect(im, tx - 5, ty + 5, 3, 4, PANTS.lightened(0.18))
	P.rect(im, tx + 3, ty + 6, 2, 3, PANTS.darkened(0.2))
	P.vline(im, tx, ty + 6, 3, PANTS.darkened(0.25))
	# Waist belt.
	var belt := HARNESS if harness_on else Color("86694b")
	P.rect(im, tx - 6, ty + 3, 12, 3, belt)
	P.hline(im, tx - 6, ty + 3, 12, belt.lightened(0.35))
	P.hline(im, tx - 6, ty + 5, 12, belt.darkened(0.3))
	if harness_on:
		# Buckle and the back strap down to the leg loops.
		P.rect(im, tx - 1, ty + 3, 3, 3, STEEL)
		P.px(im, tx - 1, ty + 3, STEEL_LIT)
		P.px(im, tx, ty + 4, STEEL_DARK)
		P.vline(im, tx - 3, ty + 6, 4, HARNESS.darkened(0.15))
		P.vline(im, tx + 3, ty + 6, 4, HARNESS.darkened(0.3))
		# Gear loops.
		for gx in [-6, -4, 3, 5]:
			P.px(im, tx + gx, ty + 6, Color("47464d"))
	else:
		P.px(im, tx, ty + 4, Color("d8a63b"))


static func _chalk_bag(im: Image, tx: int, ty: int) -> void:
	var blue := Color("6f5aa6")
	P.rect(im, tx - 2, ty - 1, 5, 6, blue)
	P.rect(im, tx - 2, ty - 1, 2, 6, Color("6f5aa6"))
	P.rect(im, tx + 2, ty + 1, 1, 4, Color("235679"))
	P.hline(im, tx - 2, ty + 4, 5, Color("235679"))
	# Rolled white rim, drawstring and a dab of chalk.
	P.rect(im, tx - 3, ty - 2, 7, 2, Color("f5eee0"))
	P.hline(im, tx - 3, ty - 1, 7, Color("bdb8ae"))
	P.px(im, tx - 1, ty + 1, Color("f5eee0"))
	P.px(im, tx, ty + 2, Color("f5eee0"))


static func _rack(im: Image, tx: int, ty: int, cams: int, draws: int) -> void:
	# Cams hang in two staggered columns from the left gear loops: a lobed head
	# colored by size, a cable stem, a little sling.
	for i in mini(cams, 5):
		var c: Color = CAM_COLORS[i % CAM_COLORS.size()]
		var x := tx - 9 + (i % 2) * 3
		var y := ty + 6 + (i / 2) * 3 + (i % 2)
		P.rect(im, x, y, 3, 2, c)
		P.px(im, x, y, c.lightened(0.55))
		P.px(im, x + 2, y + 1, c.darkened(0.35))
		P.px(im, x + 1, y + 2, STEEL)
	for i in mini(draws, 4):
		var x := tx + 7 + (i % 2) * 2
		var y := ty + 4 + (i / 2) * 3
		P.rect(im, x, y, 1, 3, STEEL)
		P.px(im, x, y, STEEL_LIT)
		P.rect(im, x + 1, y + 1, 1, 3, Color("6f5aa6") if i % 2 == 0 else Color("f7a64a"))
		P.px(im, x, y + 3, STEEL_DARK)


static func _aiders(im: Image, tx: int, ty: int) -> void:
	# Two aider ladders (blue webbing, cream steps) hanging from the belt.
	for i in 2:
		var x := tx + 5 + i * 2
		P.rect(im, x, ty + 5, 1, 12 + i * 3, Color("6f5aa6"))
		P.vline(im, x, ty + 5, 12 + i * 3, Color("6f5aa6"))
		for k in 4:
			P.hline(im, x - 1, ty + 8 + k * 3, 3, Color("f5eee0"))
		P.px(im, x, ty + 5, STEEL)


static func _draw_leg(im: Image, hip: Vector2, joints: Array[Vector2], shoe: Color, shoe_dark: Color, sole: Color, crampons: bool, harness_on: bool) -> void:
	var knee := joints[0]
	var foot := joints[1]
	_seg(im, hip, knee, 4, PANTS)
	_seg(im, knee, foot + Vector2(0, -2), 3, PANTS)
	# Leg loop around the thigh.
	if harness_on:
		var mid := hip.lerp(knee, 0.45)
		P.line(im, mid + Vector2(-2, 0), mid + Vector2(2, 0), HARNESS.darkened(0.1), 1)
		P.px(im, roundi(mid.x) - 2, roundi(mid.y), HARNESS.lightened(0.3))
	# Rolled cuff above the shoe.
	var cf := foot + Vector2(0, -2)
	P.rect(im, roundi(cf.x) - 2, roundi(cf.y) - 1, 4, 2, PANTS.lightened(0.28))
	# Shoe: toe pointing at the rock, rubber rand and sole.
	var fx := roundi(foot.x)
	var fy := roundi(foot.y)
	P.rect(im, fx - 3, fy - 1, 6, 4, shoe)
	P.rect(im, fx - 3, fy - 1, 6, 1, shoe.lightened(0.32))
	P.px(im, fx - 3, fy, shoe.lightened(0.2))
	P.rect(im, fx + 2, fy, 1, 3, shoe_dark)
	P.rect(im, fx - 3, fy + 2, 6, 1, shoe_dark)
	P.rect(im, fx - 3, fy + 3, 6, 1, sole)
	P.px(im, fx - 1, fy + 1, Color("f5eee0"))
	if crampons:
		for i in 3:
			P.px(im, fx - 3 + i * 2, fy + 4, STEEL)
			P.px(im, fx - 3 + i * 2, fy + 5, STEEL_DARK)


static func _draw_arm(im: Image, shoulder: Vector2, joints: Array[Vector2], chalk: bool) -> void:
	var elbow := joints[0]
	var hand := joints[1]
	var up := Vector2(-1, -1)
	# Contours first so the arm separates from the shirt and hat behind it.
	P.line(im, shoulder, elbow, SHIRT.darkened(0.6), 5)
	P.line(im, elbow, hand, SKIN_SHADE.darkened(0.5), 4)
	# Sleeve: three tones. Forearm: skin, lit on the upper left.
	P.line(im, shoulder, elbow, SHIRT.darkened(0.22), 3)
	P.line(im, shoulder + up, elbow + up, SHIRT, 2)
	P.line(im, shoulder + up, elbow + up, SHIRT.lightened(0.2), 1)
	P.line(im, elbow, hand, SKIN_SHADE, 2)
	P.line(im, elbow + up, hand + up, SKIN, 2)
	P.line(im, elbow + up, hand + up, SKIN_LIT, 1)
	# Rolled sleeve cuff at the elbow.
	P.rect(im, roundi(elbow.x) - 2, roundi(elbow.y) - 1, 3, 2, SHIRT.darkened(0.1))
	P.hline(im, roundi(elbow.x) - 2, roundi(elbow.y) - 1, 3, SHIRT.lightened(0.25))
	# A hand: a fist of knuckles with a thumb alongside.
	var hx := roundi(hand.x)
	var hy := roundi(hand.y)
	P.rect(im, hx - 2, hy - 3, 5, 4, SKIN_SHADE.darkened(0.5))
	P.rect(im, hx - 2, hy - 3, 4, 4, SKIN)
	P.hline(im, hx - 2, hy - 3, 4, SKIN_LIT)
	P.px(im, hx - 1, hy - 1, SKIN_SHADE)
	P.px(im, hx, hy - 1, SKIN_SHADE)
	P.px(im, hx + 1, hy - 1, SKIN_SHADE)
	P.px(im, hx + 1, hy - 3, SKIN_SHADE)
	if chalk:
		P.rect(im, hx - 2, hy - 3, 4, 2, Color("f5eee0"))
		P.px(im, hx + 1, hy - 3, Color("e4ddcc"))
		P.px(im, hx - 3, hy - 2, Color("f5eee0"))


static func _draw_axe(im: Image, hand: Vector2) -> void:
	var hx := roundi(hand.x)
	var hy := roundi(hand.y)
	P.vline(im, hx, hy - 6, 15, Color("92693d"))
	P.vline(im, hx + 1, hy - 6, 15, Color("6b4829"))
	P.rect(im, hx - 4, hy - 8, 10, 2, STEEL)
	P.hline(im, hx - 4, hy - 8, 10, STEEL_LIT)
	P.rect(im, hx - 5, hy - 7, 2, 3, STEEL_DARK)
	P.rect(im, hx + 5, hy - 7, 2, 2, STEEL_DARK)
	P.rect(im, hx, hy + 8, 2, 2, STEEL)
	# Wrist leash.
	P.px(im, hx - 1, hy + 1, Color("f7a64a"))


## The head, from behind: hair, ears and a broad-brimmed hat with a band.
static func _head(im: Image, hx: int, hy: int, tilt: float) -> void:
	var hair := Color("6b4829")
	# Neck.
	P.rect(im, hx - 2, hy + 4, 4, 3, SKIN_SHADE)
	P.px(im, hx - 2, hy + 4, SKIN)
	# Hair, a little over the collar.
	P.shaded_ellipse(im, hx, hy, 4.5, 4.7, hair, hair.lightened(0.22), hair.darkened(0.22))
	P.rect(im, hx - 4, hy + 1, 8, 3, hair)
	P.rect(im, hx - 4, hy + 1, 2, 3, hair.lightened(0.2))
	P.rect(im, hx + 2, hy + 3, 2, 1, hair.darkened(0.2))
	# Ears.
	P.px(im, hx - 5, hy + 2, SKIN)
	P.px(im, hx - 5, hy + 3, SKIN_SHADE)
	P.px(im, hx + 4, hy + 2, SKIN_SHADE)
	P.px(im, hx + 4, hy + 3, SKIN_SHADE.darkened(0.15))
	# Hat: brim, crown, hatband, a bright highlight and a brim shadow on the hair.
	P.ellipse(im, hx, hy - 2, 6.6, 2.3, HAT.darkened(0.2))
	P.ellipse(im, hx - 0.5, hy - 3, 5.8, 1.8, HAT)
	P.hline(im, hx - 5, hy - 3, 4, HAT.lightened(0.18))
	P.shaded_ellipse(im, hx, hy - 4, 3.8, 3.2, HAT, HAT.lightened(0.3), HAT.darkened(0.22))
	P.hline(im, hx - 4, hy - 3, 8, Color("d8a63b"))
	P.hline(im, hx + 1, hy - 3, 3, Color("ad7a22"))
	P.hline(im, hx - 3, hy - 2, 7, HAT.darkened(0.45))


# ---------------------------------------------------------------- chimney

## A climber seen across a chimney: back on the near wall (left for side -1),
## knees up and feet flat on the far wall, hands pressing down at the hips.
## Painted for side -1 and mirrored for +1.
static func _paint_chimney(pose: Dictionary, kit: Dictionary, flags: Dictionary) -> Image:
	var im := P.make(SIZE.x, SIZE.y)
	var o := ORIGIN
	var shoes_red := int(kit.get("climbing_shoes", 0)) > 0
	var shoe_col := Color("b3362b") if shoes_red else Color("92693d")
	var shoe_dark := Color("b3362b") if shoes_red else Color("6b4829")
	var harness_on: bool = int(kit.get("harness", 0)) > 0 or flags.get("always_harness", false)
	var fr: Vector2 = pose.get("fr", Vector2(18, 10))
	var fl: Vector2 = pose.get("fl", Vector2(18, 18))
	# The back is flat on the wall at o.x - 6; torso leans back into it.
	var bx := roundi(o.x) - 5
	var ty := roundi(o.y)
	# Far leg and near leg: thigh forward, shin down to the foot on the far wall.
	for k in 2:
		var foot := o + (fr if k == 0 else fl)
		var hip := Vector2(bx + 3, ty + 6 + k * 2)
		var jn := _limb(hip, foot + Vector2(-2, -1), 10.5, 10.5, -1.0)
		var knee := jn[0]
		var leg_col := PANTS if k == 1 else PANTS.darkened(0.2)
		_seg(im, hip, knee, 4, leg_col)
		_seg(im, knee, foot + Vector2(-2, -1), 3, leg_col)
		var fx := roundi(foot.x)
		var fy := roundi(foot.y)
		# Sole flat against the far wall: toe up, heel down.
		P.rect(im, fx - 3, fy - 3, 4, 6, shoe_col)
		P.rect(im, fx - 3, fy - 3, 4, 1, shoe_col.lightened(0.3))
		P.rect(im, fx, fy - 3, 1, 6, Color("2b2a30"))
		P.rect(im, fx - 3, fy + 2, 3, 1, shoe_dark)
	# Torso, upright against the wall, shirt lit from the left.
	var s := SHIRT
	P.rect(im, bx, ty - 8, 9, 15, s)
	P.rect(im, bx, ty - 8, 2, 15, s.darkened(0.12))
	P.rect(im, bx + 2, ty - 8, 2, 14, s.lightened(0.15))
	P.rect(im, bx + 6, ty - 6, 3, 13, s.darkened(0.18))
	P.hline(im, bx, ty - 8, 9, s.lightened(0.3))
	P.rect(im, bx, ty + 2, 9, 3, HARNESS if harness_on else Color("86694b"))
	P.hline(im, bx, ty + 2, 9, HARNESS.lightened(0.3) if harness_on else Color("92693d"))
	P.rect(im, bx + 4, ty + 2, 3, 3, STEEL if harness_on else Color("d8a63b"))
	P.rect(im, bx, ty + 5, 9, 3, PANTS)
	# Rack on the belt in front.
	var cams := mini(int(kit.get("cam", 0)), 4)
	for i in cams:
		var c: Color = CAM_COLORS[i % CAM_COLORS.size()]
		P.rect(im, bx + 9, ty + 2 + i * 2, 2, 2, c)
		P.px(im, bx + 9, ty + 2 + i * 2, c.lightened(0.45))
	if int(kit.get("chalk_bag", 0)) > 0:
		P.rect(im, bx - 3, ty + 1, 3, 5, Color("6f5aa6"))
		P.rect(im, bx - 3, ty, 3, 1, Color("f5eee0"))
	# Arms: both hands pressed flat on the near wall beside the hips.
	for k in 2:
		var sh := Vector2(bx + 3 + k, ty - 5)
		var hand := Vector2(bx + 1 + k, ty + 6 + k * 2)
		var el := Vector2(bx + 6 + k, ty + 1)
		_draw_arm(im, sh, [el, hand] as Array[Vector2], false)
	# Head turned to look across at the far wall, in profile.
	var hx := bx + 5
	var hy := ty - 14
	P.rect(im, hx - 1, hy + 4, 4, 3, SKIN_SHADE)
	P.shaded_ellipse(im, hx + 1, hy, 4.8, 4.8, SKIN, SKIN_LIT, SKIN_SHADE)
	P.rect(im, hx + 5, hy + 1, 1, 2, SKIN)
	P.px(im, hx + 3, hy, Color("2a1b14"))
	P.rect(im, hx - 3, hy - 2, 5, 7, Color("6b4829"))
	P.rect(im, hx - 3, hy - 2, 2, 7, Color("92693d"))
	P.ellipse(im, hx + 1, hy - 3, 6.8, 2.2, HAT.darkened(0.2))
	P.ellipse(im, hx + 1, hy - 4, 6.0, 1.7, HAT)
	P.shaded_ellipse(im, hx + 1, hy - 5, 3.6, 3.0, HAT, HAT.lightened(0.3), HAT.darkened(0.22))
	P.hline(im, hx - 2, hy - 3, 7, Color("d8a63b"))
	_outline(im)
	if int(pose.get("side", -1)) > 0:
		im.flip_x()
		var shifted := P.make(SIZE.x, SIZE.y)
		shifted.blit_rect(im, Rect2i(0, 0, SIZE.x, SIZE.y), Vector2i(2 * roundi(o.x) - (SIZE.x - 1), 0))
		return shifted
	return im


# ---------------------------------------------------------------- belayer

## A person standing, seen from three-quarters behind, holding a rope.
## [param look] comes from ClimbProfiles.BELAYERS (its "id" picks the period
## clothes). [param mode]: "belay", "look_up", "sit", "anchor", "spot" (a
## boulderer's spotter, hands up) or "cheer", and
## [param frame] 0..2 (see the header).
static func belayer(look: Dictionary, mode := "belay", frame := 0) -> Texture2D:
	var key := "b|%s|%s|%d" % [str(look.get("id", "")), mode, frame]
	if _cache.has(key):
		return _cache[key]
	var im := _paint_belayer(look, mode, frame)
	var tex := ClimbHiRes.texture(im)
	_cache[key] = tex
	return tex


static func _paint_belayer(look: Dictionary, mode: String, frame: int) -> Image:
	var im := P.make(BSIZE.x, BSIZE.y)
	var id: String = str(look.get("id", ""))
	var skin := Color(look.get("skin", "e0ac7e"))
	var skin_shade := skin.darkened(0.2)
	var skin_lit := skin.lightened(0.14)
	var top := Color(look.get("top", "8a4a6a"))
	var bottom := Color(look.get("bottom", "4a4a58"))
	var cx := 24
	var seated := mode == "sit" or mode == "anchor"
	var base := 50 if seated else 48
	var hop := 0
	if mode == "cheer" and frame == 1:
		hop = 3
	var bob := 1 if (mode == "belay" or mode == "look_up") and frame == 2 else 0
	var knickers := id in ["dick_leonard", "jules_eichorn"]
	var boot := Color("47301f")
	var boot_dark := Color("47301f")
	if id == "john_muir":
		boot = Color("47301f")
	var sock := Color(look.get("socks", "8a6a4a"))
	# ---- legs
	if seated:
		# Legs stretched out toward the left, knees a little up.
		var lc := bottom
		P.rect(im, cx - 9, base - 6, 13, 5, lc)
		P.rect(im, cx - 9, base - 6, 13, 1, lc.lightened(0.2))
		P.rect(im, cx - 9, base - 2, 13, 1, lc.darkened(0.2))
		P.rect(im, cx - 14, base - 5, 5, 4, sock if knickers else lc)
		P.rect(im, cx - 18, base - 7, 5, 7, boot)
		P.rect(im, cx - 18, base - 7, 5, 1, boot.lightened(0.25))
		P.rect(im, cx - 18, base - 1, 6, 2, Color("2b2a30"))
		if knickers:
			P.px(im, cx - 16, base - 3, Color("93918f"))
			P.px(im, cx - 14, base - 1, Color("93918f"))
	else:
		var spread := 6
		var lt := base - 14 - hop
		for k in 2:
			var lx := cx - spread - 1 + k * (spread * 2 - 3) if mode != "cheer" else cx - 5 + k * 5
			var lw := 5
			var shade := 0.0 if k == 0 else 0.14
			var pc := bottom.darkened(shade)
			if knickers:
				# Baggy knickers to the knee, wool socks, hobnailed boots.
				P.rect(im, lx - 1, lt, lw + 2, 8, pc)
				P.rect(im, lx - 1, lt, 2, 8, pc.lightened(0.18))
				P.hline(im, lx - 1, lt + 7, lw + 2, pc.darkened(0.3))
				P.rect(im, lx, lt + 8, lw, 5 - hop, sock.darkened(shade))
				P.hline(im, lx, lt + 9, lw, sock.lightened(0.2))
			else:
				P.rect(im, lx, lt, lw, 13, pc)
				P.rect(im, lx, lt, 1, 13, pc.lightened(0.18))
				P.hline(im, lx, lt + 11, lw, pc.darkened(0.25))
			var by := base - 3 - hop
			P.rect(im, lx - 1, by, lw + 2, 4, boot if k == 0 else boot.darkened(0.12))
			P.hline(im, lx - 1, by, lw + 2, boot.lightened(0.28))
			P.rect(im, lx - 1, by + 3, lw + 2, 1, Color("2b2a30"))
			if knickers:
				P.px(im, lx, by + 3, Color("93918f"))
				P.px(im, lx + 2, by + 3, Color("93918f"))
				P.px(im, lx + 4, by + 3, Color("93918f"))
	# ---- torso
	var tw := 12
	var tx := cx - 6
	var ty := base - 26 + bob - hop
	if seated:
		tw = 11
		tx = cx - 5
		ty = base - 21
	var th := 14
	var coat := id == "john_muir"
	if coat:
		th = 20 if not seated else 15
		tw += 2
		tx -= 1
		if not seated:
			ty = base - 32 + bob - hop
	# Pack (behind).
	if str(look.get("pack", "")) != "":
		var pc2 := Color(look.pack)
		P.rect(im, tx + tw - 2, ty - 1, 6, 14, pc2.darkened(0.15))
		P.rect(im, tx + tw - 2, ty - 1, 2, 14, pc2)
		P.rect(im, tx + tw, ty + 1, 1, 8, pc2.lightened(0.2))
	P.rect(im, tx, ty, tw, th, top)
	P.rect(im, tx, ty, 2, th - 1, top.lightened(0.22))
	P.rect(im, tx + tw - 3, ty + 1, 3, th - 1, top.darkened(0.2))
	P.hline(im, tx, ty, tw, top.lightened(0.32))
	P.hline(im, tx, ty + th - 1, tw, top.darkened(0.28))
	_outfit(im, id, look, tx, ty, tw, th, top)
	# Harness belt with a device on the front (not for Muir, who ties in with a rope).
	var by2 := ty + th - 4
	if coat:
		by2 = ty + th - 5
		P.rect(im, tx - 1, by2, tw + 2, 2, Color("b0925f"))
		P.hline(im, tx - 1, by2, tw + 2, Color("d6bd88"))
		P.rect(im, tx + tw / 2 - 2, by2 + 1, 4, 3, ROPE_C)
		P.rect(im, tx + tw / 2 - 2, by2 + 3, 4, 1, ROPE_D)
	elif id != "chongo":
		P.rect(im, tx - 1, by2, tw + 2, 3, HARNESS)
		P.hline(im, tx - 1, by2, tw + 2, HARNESS.lightened(0.35))
		P.hline(im, tx - 1, by2 + 2, tw + 2, HARNESS.darkened(0.3))
		P.rect(im, tx - 1, by2 + 3, 3, 3, HARNESS.darkened(0.15))
		P.rect(im, tx + tw - 2, by2 + 3, 3, 3, HARNESS.darkened(0.3))
		# Gear loops with a couple of carabiners / a hammer for the drillers.
		P.px(im, tx + tw - 5, by2 + 3, STEEL)
		P.px(im, tx + tw - 5, by2 + 4, STEEL_DARK)
		P.px(im, tx + 3, by2 + 3, Color("b3362b") if id == "royal_robbins" else STEEL)
		P.px(im, tx + 3, by2 + 4, STEEL_DARK)
	if id == "george_anderson":
		# Drill hammer and a bit holder hanging at the hip.
		P.vline(im, tx + tw + 1, by2 + 1, 8, Color("92693d"))
		P.rect(im, tx + tw - 1, by2 + 8, 5, 3, STEEL_DARK)
		P.rect(im, tx + tw - 1, by2 + 8, 5, 1, STEEL)
	if id == "john_salathe" and not seated:
		var ap := Color(look.get("apron", "5a3a22"))
		P.rect(im, tx + 1, by2 + 3, tw - 2, 10, ap)
		P.rect(im, tx + 1, by2 + 3, 2, 10, ap.lightened(0.2))
		P.rect(im, tx + tw - 4, by2 + 3, 3, 10, ap.darkened(0.2))
		P.hline(im, tx + 1, by2 + 12, tw - 2, ap.darkened(0.35))
	if id == "john_salathe":
		P.vline(im, tx + tw + 1, by2 + 1, 6, Color("6b4829"))
		P.rect(im, tx + tw - 1, by2 + 6, 5, 3, Color("47464d"))
		P.rect(im, tx + tw - 1, by2 + 6, 5, 1, Color("93918f"))
	if id == "warren_harding":
		# A jug of wine on the back of the belt.
		P.rect(im, tx - 4, by2 + 1, 4, 6, Color("1d3f2b"))
		P.rect(im, tx - 4, by2 + 1, 1, 6, Color("437f45"))
		P.rect(im, tx - 3, by2 - 1, 2, 2, Color("1d3f2b"))
		P.px(im, tx - 3, by2 - 1, Color("d8a63b"))
	# ---- anchor: a sling from the belt to a bolt hanger on the wall above
	if mode == "anchor":
		var bx := tx + tw + 5
		var top_y := ty - 9
		P.line(im, Vector2(tx + tw - 2, by2 + 1), Vector2(bx, top_y + 3), Color("235679"), 3)
		P.line(im, Vector2(tx + tw - 2, by2 + 1), Vector2(bx, top_y + 3), Color("6f5aa6"), 2)
		P.px(im, bx, top_y + 4, Color("63b3c6"))
		P.rect(im, bx - 2, top_y - 2, 5, 4, STEEL)
		P.hline(im, bx - 2, top_y - 2, 5, STEEL_LIT)
		P.px(im, bx, top_y - 1, STEEL_DARK)
		P.rect(im, bx - 3, top_y - 4, 7, 2, STEEL_DARK)
		P.hline(im, bx - 3, top_y - 4, 7, STEEL)
	# ---- head
	var look_up := mode == "look_up"
	var hx := tx + tw / 2 - 1
	var hy := ty - 6
	if look_up:
		hy += 0
	_belayer_head(im, id, look, hx, hy, look_up, skin, skin_lit, skin_shade)
	# ---- arms
	_belayer_arms(im, id, look, mode, frame, tx, ty, tw, th, top, skin, skin_shade, skin_lit, by2)
	_outline(im)
	return im


## Sweaters, plaid, apron, stripes: what makes each partner read at a glance.
static func _outfit(im: Image, id: String, look: Dictionary, tx: int, ty: int, tw: int, th: int, top: Color) -> void:
	match id:
		"dick_leonard", "jules_eichorn":
			# A wool sweater: ribbed hem and cuffs, a band of pattern across the chest,
			# a rolled turtleneck.
			var pat := Color("e4ddcc") if id == "dick_leonard" else Color("5e4a38")
			P.hline(im, tx, ty + 4, tw, pat)
			P.hline(im, tx, ty + 6, tw, pat)
			for x in range(tx + 1, tx + tw - 1, 2):
				P.px(im, x, ty + 5, pat.darkened(0.2))
			for x in range(tx, tx + tw, 2):
				P.px(im, x, ty + th - 2, top.darkened(0.2))
		"john_salathe":
			# Leather blacksmith's apron: bib and straps.
			var ap := Color(look.get("apron", "5a3a22"))
			P.rect(im, tx + 2, ty + 3, tw - 4, th - 3, ap)
			P.rect(im, tx + 2, ty + 3, 2, th - 3, ap.lightened(0.2))
			P.rect(im, tx + tw - 5, ty + 3, 3, th - 3, ap.darkened(0.2))
			P.vline(im, tx + 3, ty, 4, ap.darkened(0.1))
			P.vline(im, tx + tw - 4, ty, 4, ap.darkened(0.2))
			P.px(im, tx + 5, ty + 6, Color("2a1b14"))
			P.hline(im, tx + 2, ty + 3, tw - 4, ap.darkened(0.3))
		"warren_harding":
			# Red-and-black plaid shirt.
			var dk := Color("2a1b14")
			for x in range(tx + 1, tx + tw, 3):
				P.vline(im, x, ty + 1, th - 3, dk)
			for y in range(ty + 2, ty + th - 2, 4):
				P.hline(im, tx, y, tw, dk)
			P.hline(im, tx, ty + 3, tw, top.lightened(0.2))
		"royal_robbins":
			# Collared work shirt with a chest pocket.
			P.rect(im, tx + 2, ty + 4, 3, 3, top.darkened(0.2))
			P.hline(im, tx + 2, ty + 4, 3, top.lightened(0.15))
			P.hline(im, tx + 1, ty + 1, tw - 2, top.lightened(0.4))
		"john_muir":
			# A long wool coat: lapel line, big buttons, a darker hem.
			P.vline(im, tx + tw / 2 - 1, ty + 1, th - 3, top.darkened(0.35))
			for k in 3:
				P.px(im, tx + tw / 2 + 1, ty + 4 + k * 4, Color("2a1b14"))
			P.hline(im, tx, ty + th - 3, tw, top.darkened(0.15))
			P.rect(im, tx + tw - 4, ty + 9, 3, 3, top.darkened(0.25))
			P.hline(im, tx + 1, ty + 1, tw - 2, top.lightened(0.18))
		"beverly_johnson":
			P.hline(im, tx, ty + 6, tw, top.lightened(0.28))
			P.hline(im, tx, ty + 7, tw, top.darkened(0.12))
		"george_anderson":
			P.hline(im, tx, ty + 5, tw, top.darkened(0.2))
		"bestor_robinson":
			# Heavy knit sweater with a shawl collar.
			P.hline(im, tx + 1, ty + 1, tw - 2, top.lightened(0.3))
			for x in range(tx, tx + tw, 2):
				P.px(im, x, ty + 7, top.darkened(0.15))
		"wren_alvarez":
			P.hline(im, tx + 1, ty + 1, tw - 2, top.lightened(0.3))
			P.rect(im, tx + 3, ty + 4, 5, 3, top.lightened(0.14))


static func _belayer_head(im: Image, id: String, look: Dictionary, hx: int, hy: int, look_up: bool, skin: Color, skin_lit: Color, skin_shade: Color) -> void:
	var hair := Color(look.get("hair", "5a3a22"))
	if id == "john_muir":
		hair = Color("93918f")
	var hair_lit := hair.lightened(0.2)
	var hair_dark := hair.darkened(0.22)
	var up := 1 if look_up else 0
	# Neck, longer when the chin is up.
	P.rect(im, hx - 2, hy + 4 - up, 5, 3 + up, skin_shade)
	var long_hair: bool = look.get("long", false)
	if long_hair:
		P.rect(im, hx - 1, hy, 7, 12, hair)
		P.rect(im, hx - 1, hy, 2, 12, hair_lit)
		P.rect(im, hx + 4, hy + 3, 2, 9, hair_dark)
		P.hline(im, hx - 1, hy + 11, 7, hair_dark)
	P.shaded_ellipse(im, hx, hy - up, 5, 5.2, skin, skin_lit, skin_shade)
	var hy2 := hy - up
	# Hair over the back of the head; the face is turned three-quarters to the left.
	if look.get("bald", false):
		P.rect(im, hx + 2, hy2 - 2, 3, 6, hair)
		P.rect(im, hx + 1, hy2 + 1, 2, 3, hair)
		P.px(im, hx - 2, hy2 - 4, skin_lit.lightened(0.3))
		P.px(im, hx - 1, hy2 - 4, skin_lit.lightened(0.3))
	else:
		P.shaded_ellipse(im, hx + 2, hy2 - 1, 4.3, 4.3, hair, hair_lit, hair_dark)
		P.rect(im, hx + 2, hy2 + 1, 3, 3, hair)
		if id == "warren_harding":
			# Scruffy, sticking out every which way.
			P.px(im, hx + 5, hy2, hair)
			P.px(im, hx + 4, hy2 - 4, hair)
			P.px(im, hx - 1, hy2 - 5, hair)
			P.px(im, hx + 5, hy2 + 3, hair_dark)
		if id == "wren_alvarez":
			# A ponytail swinging out the back.
			P.rect(im, hx + 4, hy2 + 1, 3, 4, hair)
			P.rect(im, hx + 5, hy2 + 4, 2, 3, hair_dark)
		if id == "dick_leonard" or id == "jules_eichorn":
			# Neat 1930s side part, a lock at the front.
			P.hline(im, hx - 3, hy2 - 4, 3, hair_lit)
			P.px(im, hx - 4, hy2 - 2, hair)
	# Face: eye, brow, cheek.
	var eye := Color("2a1b14")
	P.px(im, hx - 3, hy2, eye)
	if id in ["john_salathe", "john_muir", "warren_harding", "george_anderson", "royal_robbins"]:
		P.hline(im, hx - 4, hy2 - 1, 3, hair_dark if id != "john_salathe" else Color("93918f"))
	P.px(im, hx - 4, hy2 + 2, skin.lerp(Color("d47a9b"), 0.35))
	if look.get("glasses", false):
		P.hline(im, hx - 4, hy2, 3, Color("2a1b14"))
		P.px(im, hx - 4, hy2 + 1, Color("2a1b14"))
		P.px(im, hx - 2, hy2 + 1, Color("2a1b14"))
		P.px(im, hx - 3, hy2 + 1, Color("9fd8d9"))
	if look.has("beard"):
		var bc := Color(look.beard)
		if id == "john_muir":
			bc = Color("bdb8ae")
		if bool(look.get("long_beard", false)):
			# Muir's great beard, falling over the coat.
			P.rect(im, hx - 5, hy2 + 1, 6, 6, bc)
			P.rect(im, hx - 4, hy2 + 7, 5, 4, bc.darkened(0.08))
			P.rect(im, hx - 3, hy2 + 11, 3, 2, bc.darkened(0.16))
			P.rect(im, hx - 5, hy2 + 1, 2, 7, bc.lightened(0.2))
			P.px(im, hx + 1, hy2 + 4, bc.darkened(0.2))
		elif id == "warren_harding":
			# A goatee and stubble.
			P.rect(im, hx - 4, hy2 + 4, 3, 2, bc)
			P.rect(im, hx - 4, hy2 + 6, 2, 2, bc)
			P.px(im, hx - 3, hy2 + 3, bc.lightened(0.1))
			P.px(im, hx - 5, hy2 + 3, skin.darkened(0.25))
		else:
			P.rect(im, hx - 5, hy2 + 1, 5, 4, bc)
			P.rect(im, hx - 4, hy2 + 5, 4, 2, bc.darkened(0.1))
			P.rect(im, hx - 5, hy2 + 1, 1, 4, bc.lightened(0.18))
	# Stern line for Salathé.
	if id == "john_salathe":
		P.hline(im, hx - 4, hy2 + 3, 3, skin_shade.darkened(0.35))
		P.px(im, hx - 5, hy2 + 2, skin_shade)
	_belayer_hat(im, id, look, hx, hy2)


static func _belayer_hat(im: Image, id: String, look: Dictionary, hx: int, hy: int) -> void:
	var hat: String = look.get("hat", "")
	if hat == "":
		return
	var hc := Color(hat)
	var kind: String = look.get("hat_kind", "cap")
	if id == "royal_robbins":
		kind = "painter"
	match kind:
		"headband":
			P.rect(im, hx - 5, hy - 3, 11, 2, hc)
			P.hline(im, hx - 5, hy - 3, 11, hc.lightened(0.3))
			P.rect(im, hx + 5, hy - 2, 2, 3, hc.darkened(0.12))
		"bandana":
			P.rect(im, hx - 5, hy - 4, 11, 4, hc)
			P.hline(im, hx - 5, hy - 4, 11, hc.lightened(0.28))
			P.hline(im, hx - 5, hy - 1, 11, hc.darkened(0.15))
			P.rect(im, hx + 5, hy - 2, 3, 3, hc.darkened(0.1))
			P.px(im, hx + 6, hy + 1, hc.darkened(0.2))
			for x in range(hx - 4, hx + 5, 3):
				P.px(im, x, hy - 3, Color("f5eee0"))
		"fedora":
			P.ellipse(im, hx, hy - 3, 8.2, 2.4, hc.darkened(0.15))
			P.hline(im, hx - 7, hy - 3, 5, hc.lightened(0.1))
			P.shaded_ellipse(im, hx, hy - 5, 4.6, 3.8, hc, hc.lightened(0.22), hc.darkened(0.22))
			P.hline(im, hx - 4, hy - 3, 9, Color("2b2a30"))
			P.px(im, hx - 2, hy - 7, hc.darkened(0.25))
		"painter":
			# A white painter's cap: soft flat crown, short bill to the left.
			P.shaded_ellipse(im, hx + 1, hy - 3, 5.8, 3.6, hc, Color("f5eee0"), hc.darkened(0.2))
			P.rect(im, hx - 8, hy - 2, 5, 2, hc.darkened(0.12))
			P.hline(im, hx - 8, hy - 1, 5, hc.darkened(0.3))
			P.hline(im, hx - 4, hy - 2, 9, hc.darkened(0.15))
		_:
			P.shaded_ellipse(im, hx + 1, hy - 3, 5.6, 3.4, hc, hc.lightened(0.22), hc.darkened(0.22))
			P.rect(im, hx - 8, hy - 2, 5, 2, hc.darkened(0.15))
			P.hline(im, hx - 4, hy - 1, 9, hc.darkened(0.25))


static func _belayer_arms(im: Image, id: String, look: Dictionary, mode: String, frame: int, tx: int, ty: int, tw: int, th: int, top: Color, skin: Color, skin_shade: Color, skin_lit: Color, by2: int) -> void:
	var sh_l := Vector2(tx + 1, ty + 3)
	var sh_r := Vector2(tx + tw - 1, ty + 3)
	var dev := Vector2(tx - 3, by2 + 1)
	var guide: Vector2
	var brake: Vector2
	var sleeve := top
	if id in ["dick_leonard", "jules_eichorn", "bestor_robinson", "john_muir"]:
		sleeve = top.darkened(0.04)
	var rolled := id in ["john_salathe", "warren_harding", "royal_robbins", "beverly_johnson", "george_anderson"]
	match mode:
		"cheer":
			var wave := 2.0 if frame == 2 else 0.0
			guide = Vector2(tx - 6, ty - 12 - wave)
			brake = Vector2(tx + tw + 6, ty - 12 + wave)
		"sit":
			guide = Vector2(tx - 3, ty + 8)
			brake = Vector2(tx + 3, ty + 11)
		"spot":
			# Spotting a boulderer: both hands up, ready to steer a fall onto the pad.
			var bob := 1.0 if frame == 1 else 0.0
			guide = Vector2(tx - 3, ty - 9 + bob)
			brake = Vector2(tx + tw + 3, ty - 9 + bob)
		_:
			# Belaying: the guide hand feeds rope up, the brake hand at the hip.
			guide = Vector2(tx - 5, ty + 5)
			brake = Vector2(tx - 1, by2 + 6)
			if frame == 1:
				guide = Vector2(tx - 5, ty + 2)
				brake = Vector2(tx - 3, by2 + 3)
			elif frame == 2:
				guide = Vector2(tx - 3, by2 - 1)
				brake = Vector2(tx + 3, by2 + 7)
	# Rope: hand to device and a tail swinging down from the brake hand.
	if mode != "cheer" and mode != "spot":
		var rc := ROPE_C
		P.line(im, Vector2(guide.x, guide.y - 3), dev + Vector2(0, 1), rc, 1)
		# Device and locking carabiner.
		P.rect(im, roundi(dev.x) - 2, roundi(dev.y), 4, 3, STEEL)
		P.hline(im, roundi(dev.x) - 2, roundi(dev.y), 4, STEEL_LIT)
		P.px(im, roundi(dev.x), roundi(dev.y) + 1, STEEL_DARK)
		P.px(im, roundi(dev.x) - 1, roundi(dev.y) - 1, Color("b3362b"))
		P.px(im, roundi(dev.x), roundi(dev.y) - 1, STEEL)
		P.line(im, dev + Vector2(1, 2), brake + Vector2(-1, 1), rc, 1)
		var slack := 5 + (3 if frame == 1 else 0)
		P.line(im, brake + Vector2(0, 2), brake + Vector2(-2, slack + 4), rc, 1)
		P.px(im, roundi(brake.x) - 2, roundi(brake.y) + slack + 5, ROPE_D)
	for k in 2:
		var s := sh_l if k == 0 else sh_r
		var h := guide if k == 0 else brake
		var jn := _limb_out(s, h, 5.5, 6.0, -1.0 if k == 0 else 1.0)
		var sc := sleeve if k == 0 else sleeve.darkened(0.12)
		var up := Vector2(-1, -1)
		# Upper arm in sleeve tones (no heavy contour: it lies over the torso).
		P.line(im, s, jn[0], sc.darkened(0.45), 4)
		P.line(im, s, jn[0], sc.darkened(0.12), 3)
		P.line(im, s + up, jn[0] + up, sc, 2)
		P.line(im, s + up, jn[0] + up, sc.lightened(0.2), 1)
		# Forearm: bare if the sleeves are rolled, else the cuff runs to the wrist.
		var fcol := skin if rolled else sc
		var fshade := skin_shade if rolled else sc.darkened(0.2)
		P.line(im, jn[0], jn[1], fshade.darkened(0.45), 4)
		P.line(im, jn[0], jn[1], fshade, 2)
		P.line(im, jn[0] + up, jn[1] + up, fcol, 2)
		var hxp := roundi(jn[1].x)
		var hyp := roundi(jn[1].y)
		P.rect(im, hxp - 2, hyp - 2, 4, 4, skin_shade.darkened(0.5))
		P.rect(im, hxp - 2, hyp - 2, 3, 3, skin)
		P.px(im, hxp - 2, hyp - 2, skin_lit)
		P.px(im, hxp, hyp, skin_shade)
	if id == "john_muir" and mode != "cheer":
		# A walking stick planted beside him.
		var sx := tx + tw + 3
		P.vline(im, sx, ty - 8, th + 14, Color("92693d"))
		P.vline(im, sx + 1, ty - 8, th + 14, Color("6b4829"))
		P.px(im, sx, ty - 9, Color("b0925f"))
		P.px(im, sx, ty + th + 5, Color("2b2a30"))


# ---------------------------------------------------------------- hardware

## Small gear pictures for the wall: a cam in its crack, a quickdraw on a bolt
## (or an old piton), an anchor bolt, at their natural sizes. 12 x 20.
static func hardware(kind: String, color_index := 0) -> Texture2D:
	var key := "h|%s|%d" % [kind, color_index]
	if _cache.has(key):
		return _cache[key]
	var im := P.make(12, 20)
	match kind:
		"cam":
			_hw_cam(im, CAM_COLORS[color_index % CAM_COLORS.size()])
		"draw":
			_hw_draw(im, false)
		"pin_draw":
			_hw_draw(im, true)
		"bolt":
			P.rect(im, 3, 0, 6, 3, STEEL)
			P.hline(im, 3, 0, 6, STEEL_LIT)
			P.rect(im, 5, 1, 2, 1, STEEL_DARK)
			P.rect(im, 5, 3, 2, 2, STEEL_DARK)
	_outline(im)
	var tex := ClimbHiRes.texture(im)
	_cache[key] = tex
	return tex


static func _hw_cam(im: Image, c: Color) -> void:
	# Four lobes in the crack, an axle, a cable and a thumb trigger, a sling below.
	P.rect(im, 2, 1, 8, 5, STEEL)
	P.rect(im, 3, 2, 6, 3, c)
	P.rect(im, 3, 2, 6, 1, c.lightened(0.45))
	P.rect(im, 8, 2, 1, 3, c.darkened(0.3))
	P.vline(im, 6, 1, 5, STEEL_DARK)
	P.hline(im, 2, 1, 8, STEEL_LIT)
	P.px(im, 2, 5, STEEL_DARK)
	P.px(im, 9, 5, STEEL_DARK)
	P.rect(im, 5, 6, 2, 3, STEEL_DARK)
	P.rect(im, 5, 6, 1, 3, STEEL)
	P.rect(im, 4, 9, 4, 2, c.darkened(0.15))
	P.hline(im, 4, 9, 4, c.lightened(0.2))
	# Sling and a locker.
	P.rect(im, 5, 11, 2, 3, Color("d8a63b"))
	P.px(im, 5, 11, Color("f1cf6a"))
	P.rect(im, 4, 14, 4, 4, STEEL)
	P.rect(im, 5, 15, 2, 2, Color(0.082, 0.078, 0.11, 0))
	P.px(im, 5, 15, STEEL_DARK)
	P.px(im, 6, 15, STEEL_DARK)
	P.hline(im, 4, 14, 4, STEEL_LIT)


static func _hw_draw(im: Image, pin: bool) -> void:
	if pin:
		# An old piton: a blade driven into the crack with an eye, rusty.
		P.rect(im, 1, 0, 8, 3, Color("6b4829"))
		P.rect(im, 2, 0, 6, 1, Color("ad7a22"))
		P.rect(im, 4, 1, 2, 1, Color("2a1b14"))
		P.px(im, 8, 1, Color("7e531c"))
	else:
		# A bolt hanger.
		P.rect(im, 3, 0, 6, 3, STEEL)
		P.hline(im, 3, 0, 6, STEEL_LIT)
		P.rect(im, 5, 1, 2, 1, STEEL_DARK)
	# Top carabiner, sewn dyneema (blue with stitching), bottom carabiner.
	P.rect(im, 4, 3, 4, 3, STEEL)
	P.rect(im, 5, 4, 2, 1, STEEL_DARK)
	P.rect(im, 4, 6, 4, 6, Color("6f5aa6"))
	P.rect(im, 4, 6, 1, 6, Color("3a86a8"))
	P.rect(im, 7, 6, 1, 6, Color("6f5aa6"))
	P.px(im, 5, 8, Color("f5eee0"))
	P.px(im, 6, 10, Color("f5eee0"))
	P.rect(im, 3, 12, 6, 5, STEEL)
	P.hline(im, 3, 12, 6, STEEL_LIT)
	P.rect(im, 5, 13, 2, 3, STEEL_DARK)
	P.px(im, 8, 14, Color("f7a64a"))
