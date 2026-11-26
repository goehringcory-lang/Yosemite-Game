class_name ClimberStyle
extends RefCounted
## What the v2 climber wears: the player's own look (PlayerLook: skin, hair
## and its style, beard, glasses, hat and its color, shirt style and color,
## legs style and color) as color ramps the painter shades with, plus the
## climbing kit that never changes (shoes, harness, chalk bag).
##
## While the player wears the shipped look the colors are the old climbing
## screen's (ClimbSprites.DEFAULT_COLORS), so the climber you knew stays the
## same person. Every color goes through Palette32, the game's palette.
##
##   var style := ClimberStyle.current()     # cached until the look changes
##   style.shirt[ClimberStyle.BASE]

## Ramp slots, dark to light.
const OUTLINE := 0
const SHADE := 1
const BASE := 2
const LIGHT := 3
const HI := 4

var skin: PackedColorArray
var hair: PackedColorArray
var hat: PackedColorArray
var shirt: PackedColorArray
## Plaid lines, stripes, a vest's back panel, a jacket's yoke.
var shirt2: PackedColorArray
var pants: PackedColorArray
var shoe: PackedColorArray
var rubber: PackedColorArray
var harness: PackedColorArray
var chalk_bag: PackedColorArray
var steel: PackedColorArray
var tape: PackedColorArray
var rope: PackedColorArray

## short, long, braid, bun, wild, bald
var hair_style := "short"
## none, mustache, goatee, short, long
var beard := "none"
var glasses := false
## wide, campaign, cap, beanie, fedora, headband, none
var hat_kind := "wide"
## shirt, plaid, stripes, sweater, vest, jacket, suspenders
var top_style := "shirt"
## pants, knickers, skirt
var bottom_style := "pants"
## The PlayerLook.version this was made for.
var version := -1

static var _current: ClimberStyle


## The style for the look the player wears now.
static func current() -> ClimberStyle:
	if _current == null or _current.version != PlayerLook.version:
		_current = make()
	return _current


static func make() -> ClimberStyle:
	var s := ClimberStyle.new()
	s.version = PlayerLook.version
	var shipped := PlayerLook.is_default()
	var d: Dictionary = ClimbSprites.DEFAULT_COLORS
	s.skin = ramp(d.skin if shipped else _pick("skin"), 0.9)
	s.hair_style = str(PlayerLook.chosen_value("hair_style"))
	s.hair = ramp(d.hair if shipped else _pick("hair"))
	s.beard = str(PlayerLook.chosen_value("beard"))
	s.glasses = bool(PlayerLook.chosen_value("glasses"))
	s.hat_kind = str(PlayerLook.chosen_value("hat"))
	s.hat = ramp(d.hat if shipped else _pick("hat_color"))
	s.top_style = str(PlayerLook.chosen_value("top_style"))
	var top: Color = d.shirt if shipped else _pick("top")
	s.shirt = ramp(top)
	var second := top.lightened(0.45) if top.get_luminance() < 0.3 else top.darkened(0.4)
	if s.top_style == "vest":
		second = Color("e4ddcc") if top.get_luminance() < 0.6 else Color("6a6a70")
	s.shirt2 = ramp(Palette32.nearest(second))
	s.bottom_style = str(PlayerLook.chosen_value("bottom_style"))
	s.pants = ramp(d.pants if shipped else _pick("bottom"))
	s.shoe = ramp(Color("b3362b"))
	s.rubber = ramp(Color("2b2a30"))
	s.harness = ramp(ClimbSprites.HARNESS)
	s.chalk_bag = ramp(Color("6f5aa6"))
	s.steel = ramp(ClimbSprites.STEEL)
	s.tape = ramp(Color("f5eee0"))
	s.rope = ramp(ClimbSprites.ROPE_C)
	return s


static func _pick(part: String) -> Color:
	return Palette32.nearest(Color(str(PlayerLook.chosen_value(part))))


## Five tones from [param c]: an outline, a shade, the base, a light and a
## highlight. Shades lean cool and lights warm, the way the game's painted
## art is shaded. [param contrast] under 1 flattens skin a little.
static func ramp(c: Color, contrast := 1.0) -> PackedColorArray:
	var cool := Color(0.16, 0.18, 0.32)
	var warm := Color(1.0, 0.93, 0.72)
	var out := PackedColorArray()
	out.append(c.lerp(cool, 0.35).darkened(0.62))
	out.append(c.lerp(cool, 0.12 * contrast).darkened(0.26 * contrast))
	out.append(c)
	out.append(c.lerp(warm, 0.12 * contrast).lightened(0.14 * contrast))
	out.append(c.lerp(warm, 0.25).lightened(0.32 * contrast))
	return out


## [param r] one step darker (a limb on the far side of the body).
static func far(r: PackedColorArray) -> PackedColorArray:
	var out := PackedColorArray()
	out.append(r[OUTLINE])
	out.append(r[SHADE].darkened(0.18))
	out.append(r[SHADE])
	out.append(r[BASE])
	out.append(r[LIGHT])
	return out
