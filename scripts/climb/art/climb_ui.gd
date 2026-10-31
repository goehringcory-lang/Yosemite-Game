class_name ClimbUI
extends RefCounted
## The climbing screen's look-and-feel: the game's font, wood-framed panels
## in the same dark brown with a gold edge as every other screen (the pause
## menu, the book, conversations), and a set of tiny gear icons. Everything draws onto a CanvasItem during its draw pass.

const FONT_PATH := "res://assets/fonts/NotoSans-Regular.ttf"

# Wood frame, parchment, ink.
const WOOD_DARK := Color("47301f")
const WOOD := Color("6b4829")
const WOOD_LIGHT := Color("ad7a22")
const WOOD_HI := Color("d8a63b")
# The "paper" is the dark board of the game's panels, and "ink" is cream.
const PAPER := Color("47301f")
const PAPER_SHADE := Color("47301f")
const PAPER_DARK := Color("2a1b14")
const GILT := Color("b0925f")
const INK := Color("e4ddcc")
const INK_SOFT := Color("d6bd88")
const CREAM := Color("f5eee0")
const SHADOW := Color(0.082, 0.078, 0.11, 0.9)

const GOOD := Color("84b04a")
const GOOD_DARK := Color("aecb62")
const WARN := Color("d9772a")
const WARN_DARK := Color("d9772a")
const GOLD := Color("d8a63b")
const SKY_BLUE := Color("3a86a8")

static var _font: Font


static func font() -> Font:
	# the pixel font, when chosen in Settings, is used here too
	if Settings.pixel_font:
		return Settings.ui_font()
	if _font == null:
		var loaded := load(FONT_PATH) as FontFile
		if loaded != null:
			loaded.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
			loaded.hinting = TextServer.HINTING_LIGHT
			loaded.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_AUTO
			loaded.force_autohinter = false
			_font = loaded
		else:
			_font = ThemeDB.fallback_font
	return _font


## For center/right alignment, [param pos] is the center or right edge of
## the text (Godot itself only aligns text inside a box): returns its left.
static func _aligned(pos: Vector2, s: String, size: int, align: int) -> Vector2:
	if align == HORIZONTAL_ALIGNMENT_LEFT:
		return pos
	var w := text_width(s, size)
	return pos - Vector2(w * 0.5 if align == HORIZONTAL_ALIGNMENT_CENTER else w, 0)


## Text with a dark drop shadow, for use over the wall and sky. A positive
## [param width] clips it.
static func text(ci: CanvasItem, pos: Vector2, s: String, color := CREAM, size := 10, width := -1.0, align := HORIZONTAL_ALIGNMENT_LEFT) -> void:
	var p := _aligned(pos, s, size, align).round()
	var left := HORIZONTAL_ALIGNMENT_LEFT
	ci.draw_string(font(), p + Vector2(0, 1), s, left, width, size, SHADOW)
	ci.draw_string(font(), p + Vector2(1, 0), s, left, width, size, SHADOW)
	ci.draw_string(font(), p + Vector2(1, 1), s, left, width, size, SHADOW)
	ci.draw_string(font(), p, s, left, width, size, color)


## Text with a 1 px dark outline all round, for labels over busy rock.
static func outlined(ci: CanvasItem, pos: Vector2, s: String, color := CREAM, size := 10, width := -1.0, align := HORIZONTAL_ALIGNMENT_LEFT) -> void:
	var p := _aligned(pos, s, size, align).round()
	var left := HORIZONTAL_ALIGNMENT_LEFT
	for dy in [-1, 0, 1]:
		for dx in [-1, 0, 1]:
			if dx != 0 or dy != 0:
				ci.draw_string(font(), p + Vector2(dx, dy), s, left, width, size, SHADOW)
	ci.draw_string(font(), p, s, left, width, size, color)


## Ink on parchment: no shadow.
static func ink(ci: CanvasItem, pos: Vector2, s: String, color := INK, size := 10, width := -1.0, align := HORIZONTAL_ALIGNMENT_LEFT) -> void:
	ci.draw_string(font(), _aligned(pos, s, size, align).round(), s, HORIZONTAL_ALIGNMENT_LEFT, width, size, color)


## Like [method ink], but each "[key]" in [param s] is drawn as a pixel
## button (see ButtonHints), for the keys hints on the climbing screens.
static func keys(ci: CanvasItem, pos: Vector2, s: String, color := INK, size := 10, align := HORIZONTAL_ALIGNMENT_LEFT) -> void:
	var f := font()
	var w := keys_width(s, size)
	if align != HORIZONTAL_ALIGNMENT_LEFT:
		pos.x -= w * 0.5 if align == HORIZONTAL_ALIGNMENT_CENTER else w
	ButtonHints.draw_hint(ci, f, size, s, Vector2(pos.x, pos.y - f.get_ascent(size)).round(), color)


static func keys_width(s: String, size := 10) -> float:
	return ButtonHints.line_width(font(), size, s)


## The name of the button to show in a keys hint drawn on [param ci]:
## [param keyboard] ("Space") or [param gamepad] ("X"), for the device in use.
## The climbing screens' pad buttons are listed on the pause menu's Controls
## page: E is A, Space is X, Esc is B, Shift is Y, and the arrows are the stick.
static func button(ci: CanvasItem, keyboard: String, gamepad: String) -> String:
	return MenuInput.button(ci.get_tree() if ci and ci.is_inside_tree() else null, keyboard, gamepad)


static func wrapped(ci: CanvasItem, pos: Vector2, s: String, width: float, color := INK, size := 10, shadow := false, line_gap := 2) -> int:
	var f := font()
	var lines := wrap_lines(s, width, size)
	var y := 0.0
	for line in lines:
		if shadow:
			text(ci, pos + Vector2(0, y), line, color, size)
		else:
			ink(ci, pos + Vector2(0, y), line, color, size)
		y += size + line_gap
	return lines.size()


static func wrap_lines(s: String, width: float, size := 10) -> PackedStringArray:
	var f := font()
	var out := PackedStringArray()
	for para in s.split("\n"):
		var line := ""
		for word in para.split(" "):
			var trial := word if line == "" else line + " " + word
			if f.get_string_size(trial, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x > width and line != "":
				out.append(line)
				line = word
			else:
				line = trial
		out.append(line)
	return out


static func text_width(s: String, size := 10) -> float:
	return font().get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x


## A wooden-framed parchment panel with a 1 px highlight and a drop shadow.
static func panel(ci: CanvasItem, r: Rect2, paper := PAPER, frame := true) -> void:
	r = Rect2(r.position.round(), r.size.round())
	ci.draw_rect(Rect2(r.position + Vector2(2, 3), r.size), Color(0.082, 0.078, 0.11, 0.28))
	if frame:
		ci.draw_rect(r, WOOD_DARK)
		ci.draw_rect(r.grow(-1), WOOD)
		# Bevel: the upper-left rims catch the light, the lower-right rims fall
		# into shade.
		ci.draw_rect(Rect2(r.position + Vector2(1, 1), Vector2(r.size.x - 2, 1)), WOOD_HI)
		ci.draw_rect(Rect2(r.position + Vector2(1, 1), Vector2(1, r.size.y - 2)), WOOD_LIGHT)
		ci.draw_rect(Rect2(r.position + Vector2(r.size.x - 2, 2), Vector2(1, r.size.y - 4)), WOOD_DARK)
		ci.draw_rect(Rect2(r.position + Vector2(1, r.size.y - 2), Vector2(r.size.x - 2, 1)), WOOD_DARK)
		# Grain: short darker and lighter dashes along the top and bottom rails.
		for gx in range(7, int(r.size.x) - 9, 11):
			var k := gx / 11
			ci.draw_rect(Rect2(r.position + Vector2(gx, 2 + k % 2), Vector2(4, 1)), WOOD_LIGHT)
			ci.draw_rect(Rect2(r.position + Vector2(gx + 5, r.size.y - 3 - k % 2), Vector2(3, 1)), WOOD_DARK)
		var inner := r.grow(-3)
		ci.draw_rect(inner, GILT) # the gold edge round the board
		ci.draw_rect(inner.grow(-1), paper)
		# The paper sits in a recess: the frame throws a shadow across its top
		# and left, and the bottom and right catch a little light.
		ci.draw_rect(Rect2(inner.position + Vector2(1, 1), Vector2(inner.size.x - 2, 1)), PAPER_DARK.darkened(0.12))
		ci.draw_rect(Rect2(inner.position + Vector2(1, 1), Vector2(1, inner.size.y - 2)), PAPER_DARK.darkened(0.06))
		ci.draw_rect(Rect2(inner.position + Vector2(inner.size.x - 2, 2), Vector2(1, inner.size.y - 4)), paper.lightened(0.18))
		ci.draw_rect(Rect2(inner.position + Vector2(2, 2), Vector2(inner.size.x - 4, 1)), paper.lightened(0.35))
		# Little rivets in the corners.
		for c: Vector2 in [Vector2(2, 2), Vector2(r.size.x - 4, 2), Vector2(2, r.size.y - 4), Vector2(r.size.x - 4, r.size.y - 4)]:
			ci.draw_rect(Rect2(r.position + c, Vector2(2, 2)), WOOD_DARK)
			ci.draw_rect(Rect2(r.position + c, Vector2(1, 1)), WOOD_HI)
	else:
		ci.draw_rect(r, paper)


## A dark glass panel for text over the sky (no parchment).
static func glass(ci: CanvasItem, r: Rect2, alpha := 0.62) -> void:
	r = Rect2(r.position.round(), r.size.round())
	ci.draw_rect(r, Color(0.07, 0.05, 0.1, alpha))
	ci.draw_rect(Rect2(r.position, Vector2(r.size.x, 1)), Color(0.961, 0.933, 0.878, 0.2))
	ci.draw_rect(Rect2(r.position + Vector2(0, r.size.y - 1), Vector2(r.size.x, 1)), Color(0.082, 0.078, 0.11, 0.35))


## A framed bar: [param frac] filled.
static func bar(ci: CanvasItem, r: Rect2, frac: float, fill: Color, dark: Color, back := Color("2a1b14")) -> void:
	frac = clampf(frac, 0.0, 1.0)
	ci.draw_rect(r.grow(1), WOOD_DARK)
	ci.draw_rect(r, back)
	var w := roundf(r.size.x * frac)
	if w > 0:
		ci.draw_rect(Rect2(r.position, Vector2(w, r.size.y)), fill)
		ci.draw_rect(Rect2(r.position, Vector2(w, 1)), fill.lightened(0.4))
		ci.draw_rect(Rect2(r.position + Vector2(0, r.size.y - 1), Vector2(w, 1)), dark)


## A vertical energy bar like Stardew's: fills from the bottom.
static func energy_bar(ci: CanvasItem, r: Rect2, frac: float, low: bool, flash: float) -> void:
	frac = clampf(frac, 0.0, 1.0)
	panel(ci, r.grow(3))
	ci.draw_rect(r, Color("2a1b14"))
	var h := roundf(r.size.y * frac)
	var top := r.position.y + r.size.y - h
	var col := WARN if low else GOOD
	var dark := WARN_DARK if low else GOOD_DARK
	if flash > 0.0:
		col = col.lerp(Color.WHITE, flash)
	if h > 0:
		ci.draw_rect(Rect2(r.position.x, top, r.size.x, h), col)
		ci.draw_rect(Rect2(r.position.x, top, r.size.x, 1), col.lightened(0.45))
		ci.draw_rect(Rect2(r.position.x, top, 2, h), col.lightened(0.18))
		ci.draw_rect(Rect2(r.position.x + r.size.x - 2, top, 2, h), dark)
	# Tick marks every quarter.
	for i in range(1, 4):
		ci.draw_rect(Rect2(r.position.x, r.position.y + r.size.y * i / 4.0, r.size.x, 1), Color(0.082, 0.078, 0.11, 0.35))


# ---------------------------------------------------------------- icons

## 12 x 12 gear icons. Letters index into ICON_COLORS.
const ICON_COLORS := {
	"k": Color("2a1b14"), "w": Color("f5eee0"), "g": Color("bdb8ae"), "G": Color("6a6a70"),
	"r": Color("b3362b"), "R": Color("b3362b"), "b": Color("6f5aa6"), "B": Color("6f5aa6"),
	"y": Color("d8a63b"), "Y": Color("ad7a22"), "o": Color("d9772a"), "n": Color("92693d"),
	"N": Color("6b4829"), "p": Color("6f5aa6"), "c": Color("63b3c6"), "e": Color("84b04a"),
	"E": Color("5c8f3c"), "s": Color("d6bd88"), "t": Color("e4ddcc"), "T": Color("bdb8ae"),
	"m": Color("d47a9b"), "d": Color("47464d"),
	"h": Color("f5eee0"), "H": Color("f7a64a"), "O": Color("a84a1c"), "l": Color("63b3c6"),
	"u": Color("f1cf6a"), "a": Color("d6bd88"), "P": Color("6f5aa6"), "q": Color("e4ddcc"),
}

## Light from the upper left: highlights (w, h, l, u) top-left, shade (R, B, Y, O) bottom-right.
const ICONS := {
	"cam": [
		"............",
		"...kkkkkk...",
		"..khrrrrRk..",
		".khrrgGrrRk.",
		".krrRgGRrrk.",
		".kRRkgGkRRk.",
		"..kkkgGkkk..",
		"....kddk....",
		"...kuyyYk...",
		"...kuyyYk...",
		"...kyYYYk...",
		"....kkkk....",
	],
	"quickdraw": [
		"............",
		"...kkkkkk...",
		"..khwgggGk..",
		"..kg....Gk..",
		"..kgGGGGGk..",
		"...klbbBk...",
		"...kbbbBk...",
		"...kbbBBk...",
		"..kgGGGGGk..",
		"..kg....Gk..",
		"..khwgggGk..",
		"...kkkkkk...",
	],
	"climbing_shoes": [
		"............",
		"............",
		".kkkk.......",
		".kHrrk......",
		".krrrrkk....",
		".krwrrrrkk..",
		".krrrrwrrrk.",
		".kHrrrrrrrrk",
		".kwwwwwwwwRk",
		".kddddddddk.",
		"..kkkkkkkk..",
		"............",
	],
	"approach_shoes": [
		"............",
		"............",
		".kkkk.......",
		".kunnk......",
		".knnnnkk....",
		".knwnnnnkk..",
		".knnnnwnnnk.",
		".kunnnnnnnnk",
		".kTTTTTTTTNk",
		".kNdNdNdNdk.",
		"..kkkkkkkk..",
		"............",
	],
	"chalk_bag": [
		"....kkkk....",
		"...kwwwwk...",
		"..kwhwwwwk..",
		"..kkkkkkkk..",
		"..klbbbbBk..",
		".klbbbbbbBk.",
		".kbbwwwwbBk.",
		".kbbwbbwbBk.",
		".kbbwwwwbBk.",
		".kbbbbbbBBk.",
		"..kBBBBBBk..",
		"...kkkkkk...",
	],
	"rope": [
		"............",
		"..kkkkkkkk..",
		".kHrrRrrrRk.",
		"kHrkkkkkkrRk",
		"krrk....krRk",
		"kRrk....krRk",
		"krrk....kRRk",
		"kRrkkkkkkrRk",
		".kRrrRrrRRk.",
		"..kkkkkkkk..",
		"............",
		"............",
	],
	"harness": [
		"............",
		".kkkkkkkkkk.",
		".kuyyyyyyYk.",
		".kkkkkkkkkk.",
		".ky.kyyk.yk.",
		".ky.kgwk.yk.",
		".ky.kGGk.Yk.",
		".kyk.kk.kYk.",
		".kyk....kYk.",
		".kuk....kYk.",
		".kkk....kkk.",
		"............",
	],
	"belay_device": [
		"............",
		"...kkkkkk...",
		"..khggggGk..",
		".khgGkkGggk.",
		".kgk....kGk.",
		".kgGkkkkGgk.",
		"..kggggGGk..",
		"...kGGGGk...",
		"....kgGk....",
		"...krkkrk...",
		"....kkkk....",
		"............",
	],
	"aiders": [
		"............",
		"..kbbbbbbk..",
		"..klkkkkBk..",
		"..kwwwwwTk..",
		"..klkkkkBk..",
		"..kwwwwwTk..",
		"..klkkkkBk..",
		"..kwwwwwTk..",
		"..klkkkkBk..",
		"..kwwwwwTk..",
		"..kbbbbBBk..",
		"...kkkkkk...",
	],
	"ascenders": [
		"............",
		"...kkkk.....",
		"..kuyyYk....",
		"..kyghYk....",
		"..kyyyYk....",
		"..kGGGGk....",
		"..kghggkkk..",
		"..kgddgyyyk.",
		"..kgGGgkkk..",
		"..kGGGGk....",
		"...kkkk.....",
		"............",
	],
	"haul_bag": [
		"............",
		"....kkkk....",
		"...kHooOk...",
		"..kHoooooOk.",
		".kHooyyyyOk.",
		".kooyuYYyOk.",
		".kooyyyyyOk.",
		".kooooooooOk",
		".koRRRRRRROk",
		"..kRRRRRRRk.",
		"...kkkkkkk..",
		"............",
	],
	"portaledge": [
		"............",
		".kkkkkkkkkk.",
		".kgGGGGGGGGk",
		"kkkkkkkkkkkk",
		"kHoooooooooO",
		"koooooooooOk",
		"kkkkkkkkkkkk",
		".kg......Gk.",
		".kg......Gk.",
		".kg......Gk.",
		".kg......Gk.",
		".kk......kk.",
	],
	"ice_axe": [
		"............",
		".kkkkkkk....",
		"kkgwwgggGk..",
		"kggkkkkkGGk.",
		"kkk.knk.kk..",
		"....knk.....",
		"....knk.....",
		"....knk.....",
		"....kNk.....",
		"....kNk.....",
		"....kGk.....",
		".....k......",
	],
	"crampons": [
		"............",
		"............",
		"..kkkkkkkk..",
		".khggggggGk.",
		".kguyggyyGk.",
		".kgggggggGk.",
		"..kGGGGGGk..",
		"..khkgkgkGk.",
		"..kgkgkgkGk.",
		"..kkkkkkkk..",
		"............",
		"............",
	],
	"food": [
		".....e......",
		"....eEk.....",
		"...kkkkkk...",
		"..kHrrrrRk..",
		".kHwrrrrrRk.",
		".krwrrrrrRk.",
		".krrrrrrrRk.",
		".kRrrrrrRRk.",
		"..kRrrrRRk..",
		"...kRRRRk...",
		"....kkkk....",
		"............",
	],
	"chalk": [
		"............",
		"............",
		"....kkkk....",
		"...kwhwwk...",
		"..kwhwwwTk..",
		"..kwwwwwTk..",
		"..kwwwwTTk..",
		"...kkkkkk...",
		"............",
		"............",
		"............",
		"............",
	],
	"pin": [
		"............",
		"............",
		"..kk........",
		".kHRkkkkkk..",
		".kRNnnnnnGk.",
		".kRNnnnnGgk.",
		"..kkkkkkkk..",
		"............",
		"............",
		"............",
		"............",
		"............",
	],
	"star": [
		"............",
		".....kk.....",
		".....kuk....",
		"....kuyyk...",
		"kkkkkuyyYkkk",
		".kuyyyyyyYk.",
		"..kyyyyyYk..",
		"...kyyyYk...",
		"..kyyk.Yyk..",
		"..kyk...kYk.",
		"..kk.....kk.",
		"............",
	],
	"check": [
		"............",
		"............",
		"..........kk",
		".........kek",
		"........kek.",
		"kk.....kek..",
		"kek...kek...",
		".kek.kEk....",
		"..kekEk.....",
		"...kEk......",
		"....k.......",
		"............",
	],
}

static var _icon_cache: Dictionary = {}


static func icon_texture(id: String) -> Texture2D:
	if _icon_cache.has(id):
		return _icon_cache[id]
	# "cam:2" is the cam in size 2's color (CamSizes): its lobes and its sling.
	var colors := ICON_COLORS
	if id.begins_with("cam:"):
		var c := CamSizes.color(int(id.get_slice(":", 1)))
		colors = ICON_COLORS.duplicate()
		colors.merge({"h": c.lightened(0.45), "r": c, "R": c.darkened(0.3), "u": c.lightened(0.3), "y": c.darkened(0.1), "Y": c.darkened(0.35)}, true)
	var rows: Array = ICONS.get(id.get_slice(":", 0), [])
	if rows.is_empty():
		return null
	var im := Image.create_empty(12, 12, false, Image.FORMAT_RGBA8)
	for y in rows.size():
		var line: String = rows[y]
		for x in line.length():
			var ch := line[x]
			if colors.has(ch):
				im.set_pixel(x, y, colors[ch])
	var tex := ImageTexture.create_from_image(im)
	_icon_cache[id] = tex
	return tex


static func icon(ci: CanvasItem, id: String, pos: Vector2, tint := Color.WHITE) -> void:
	var tex := icon_texture(id)
	if tex:
		ci.draw_texture(tex, pos.round(), tint)


## An inventory slot (like Stardew's toolbar): framed square, icon, count.
static func slot(ci: CanvasItem, pos: Vector2, id: String, count := -1, dim := false, selected := false) -> void:
	var r := Rect2(pos.round(), Vector2(18, 18))
	ci.draw_rect(r.grow(1), WOOD_DARK if not selected else Color("7e531c"))
	ci.draw_rect(r, Color("b0925f") if not selected else Color("f1cf6a"))
	# Inset: shadowed top and left, lit bottom and right.
	var shade := Color("b0925f") if not selected else Color("d8a63b")
	var lit := Color("d6bd88") if not selected else Color("ffd48a")
	ci.draw_rect(Rect2(r.position, Vector2(r.size.x, 1)), shade)
	ci.draw_rect(Rect2(r.position, Vector2(1, r.size.y)), shade)
	ci.draw_rect(Rect2(r.position + Vector2(1, r.size.y - 1), Vector2(r.size.x - 1, 1)), lit)
	ci.draw_rect(Rect2(r.position + Vector2(r.size.x - 1, 1), Vector2(1, r.size.y - 1)), lit)
	# A soft shadow under the icon, then the icon.
	if not dim and icon_texture(id) != null:
		ci.draw_texture(icon_texture(id), pos.round() + Vector2(4, 4), Color(0.165, 0.106, 0.078, 0.25))
	icon(ci, id, pos + Vector2(3, 3), Color(0.961, 0.933, 0.878, 0.35) if dim else Color.WHITE)
	if count >= 0:
		# the count on a small dark badge in the corner, inside the slot
		var s := str(count)
		var w := text_width(s, 8)
		var badge := Rect2((pos + Vector2(18 - w - 2, 11)).round(), Vector2(w + 2, 8))
		ci.draw_rect(badge, Color(0.165, 0.106, 0.078, 0.8))
		text(ci, pos + Vector2(17 - w, 18), s, CREAM if not dim else Color(CREAM, 0.5), 8)
