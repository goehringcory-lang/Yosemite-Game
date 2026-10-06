class_name ClimbUI
extends RefCounted
## The climbing screen's look-and-feel: a crisp pixel font, warm wood-and-
## parchment panels (in the spirit of Stardew's menus), and a set of tiny
## gear icons. Everything draws onto a CanvasItem during its draw pass.

const FONT_PATH := "res://assets/fonts/Tiny5-Regular.ttf"

# Wood frame, parchment, ink.
const WOOD_DARK := Color("3a2414")
const WOOD := Color("7a4a24")
const WOOD_LIGHT := Color("b07a3a")
const WOOD_HI := Color("d8a458")
const PAPER := Color("f2dcaa")
const PAPER_SHADE := Color("dcbe86")
const PAPER_DARK := Color("c4a06a")
const INK := Color("4a2c16")
const INK_SOFT := Color("7a5a38")
const CREAM := Color("fff4d6")
const SHADOW := Color(0.07, 0.04, 0.03, 0.9)

const GOOD := Color("7ac24a")
const GOOD_DARK := Color("3f7a2a")
const WARN := Color("e8663a")
const WARN_DARK := Color("9a3418")
const GOLD := Color("f6c040")
const SKY_BLUE := Color("5aa8e0")

static var _font: Font


static func font() -> Font:
	if _font == null:
		var loaded := load(FONT_PATH) as FontFile
		if loaded != null:
			loaded.antialiasing = TextServer.FONT_ANTIALIASING_NONE
			loaded.hinting = TextServer.HINTING_NONE
			loaded.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
			loaded.force_autohinter = false
			_font = loaded
		else:
			_font = ThemeDB.fallback_font
	return _font


## Text with a dark drop shadow, for use over the wall and sky.
static func text(ci: CanvasItem, pos: Vector2, s: String, color := CREAM, size := 10, width := -1.0, align := HORIZONTAL_ALIGNMENT_LEFT) -> void:
	var p := pos.round()
	ci.draw_string(font(), p + Vector2(0, 1), s, align, width, size, SHADOW)
	ci.draw_string(font(), p + Vector2(1, 0), s, align, width, size, SHADOW)
	ci.draw_string(font(), p + Vector2(1, 1), s, align, width, size, SHADOW)
	ci.draw_string(font(), p, s, align, width, size, color)


## Ink on parchment: no shadow.
static func ink(ci: CanvasItem, pos: Vector2, s: String, color := INK, size := 10, width := -1.0, align := HORIZONTAL_ALIGNMENT_LEFT) -> void:
	ci.draw_string(font(), pos.round(), s, align, width, size, color)


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
	ci.draw_rect(Rect2(r.position + Vector2(2, 3), r.size), Color(0, 0, 0, 0.28))
	if frame:
		ci.draw_rect(r, WOOD_DARK)
		ci.draw_rect(r.grow(-1), WOOD)
		ci.draw_rect(Rect2(r.position + Vector2(1, 1), Vector2(r.size.x - 2, 1)), WOOD_HI)
		ci.draw_rect(Rect2(r.position + Vector2(1, 1), Vector2(1, r.size.y - 2)), WOOD_LIGHT)
		ci.draw_rect(Rect2(r.position + Vector2(1, r.size.y - 2), Vector2(r.size.x - 2, 1)), WOOD_DARK)
		var inner := r.grow(-3)
		ci.draw_rect(inner, PAPER_DARK)
		ci.draw_rect(inner.grow(-1), paper)
		ci.draw_rect(Rect2(inner.position + Vector2(1, 1), Vector2(inner.size.x - 2, 1)), paper.lightened(0.35))
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
	ci.draw_rect(Rect2(r.position, Vector2(r.size.x, 1)), Color(1, 1, 1, 0.2))
	ci.draw_rect(Rect2(r.position + Vector2(0, r.size.y - 1), Vector2(r.size.x, 1)), Color(0, 0, 0, 0.35))


## A framed bar: [param frac] filled.
static func bar(ci: CanvasItem, r: Rect2, frac: float, fill: Color, dark: Color, back := Color("2a1c14")) -> void:
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
	ci.draw_rect(r, Color("2a1c14"))
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
		ci.draw_rect(Rect2(r.position.x, r.position.y + r.size.y * i / 4.0, r.size.x, 1), Color(0, 0, 0, 0.35))


# ---------------------------------------------------------------- icons

## 12 x 12 gear icons. Letters index into ICON_COLORS.
const ICON_COLORS := {
	"k": Color("2a1f1a"), "w": Color("f4f0e6"), "g": Color("c4c8d2"), "G": Color("7a808e"),
	"r": Color("d8452e"), "R": Color("8a2a1c"), "b": Color("3a78c8"), "B": Color("24488a"),
	"y": Color("f0c040"), "Y": Color("b08420"), "o": Color("e88a30"), "n": Color("9a6a3a"),
	"N": Color("5a3a1e"), "p": Color("8a5ab0"), "c": Color("6ad0e0"), "e": Color("6ab04a"),
	"E": Color("3a7a2c"), "s": Color("f0c088"), "t": Color("d8d0b8"), "T": Color("a8a088"),
	"m": Color("e060a0"), "d": Color("505868"),
}

const ICONS := {
	"cam": [
		"............",
		"....kkkk....",
		"...kggggk...",
		"..kgGrrGgk..",
		"..kgrrrrgk..",
		"..kGrrrrGk..",
		"...kGGGGk...",
		"....kyyk....",
		"....kyyk....",
		"...kyYYyk...",
		"...kyyyyk...",
		"....kkkk....",
	],
	"quickdraw": [
		"............",
		"...kkkk.....",
		"..kgggGk....",
		"..kg..gk....",
		"..kgGGgk....",
		"...kbbk.....",
		"...kbBk.....",
		"...kbBk.....",
		"..kgGGgk....",
		"..kg..gk....",
		"..kgggGk....",
		"...kkkk.....",
	],
	"climbing_shoes": [
		"............",
		"............",
		".kk.........",
		".krk........",
		".krrkk......",
		".krrrrkk....",
		".krwrrrrk...",
		".krrrrrrrkk.",
		".kRRRRRRRRk.",
		".kkkkkkkkkk.",
		"............",
		"............",
	],
	"approach_shoes": [
		"............",
		"............",
		".kk.........",
		".knk........",
		".knnkk......",
		".knnnnkk....",
		".knwnnnnk...",
		".knnnnnnnkk.",
		".kNNNNNNNNk.",
		".kkkkkkkkkk.",
		"............",
		"............",
	],
	"chalk_bag": [
		"............",
		"....kkkk....",
		"...kwwwwk...",
		"..kkkkkkkk..",
		"..kbbbbbbk..",
		".kbbbbbbbbk.",
		".kbbwwwwbbk.",
		".kbbwbbwbbk.",
		".kbbwwwwbbk.",
		".kBbbbbbbBk.",
		"..kBBBBBBk..",
		"...kkkkkk...",
	],
	"rope": [
		"............",
		"..kkkkkkkk..",
		".krrRrrRrrk.",
		"kRrkkkkkkrRk",
		"krrk....krrk",
		"kRrk....kRrk",
		"krrk....krrk",
		"kRrkkkkkkrRk",
		".krrRrrRrrk.",
		"..kkkkkkkk..",
		"............",
		"............",
	],
	"harness": [
		"............",
		".kkkkkkkkkk.",
		".kyyyyyyyyk.",
		".kkkkkkkkkk.",
		".ky.kyyk.yk.",
		".ky.kggk.yk.",
		".ky.kkkk.yk.",
		".kYk.kk.kYk.",
		".kyk....kyk.",
		".kyk....kyk.",
		".kkk....kkk.",
		"............",
	],
	"belay_device": [
		"............",
		"...kkkkkk...",
		"..kggggggk..",
		".kgGkkkkGgk.",
		".kgk....kgk.",
		".kgGkkkkGgk.",
		"..kggggggk..",
		"...kGGGGk...",
		"....kggk....",
		"...kg..gk...",
		"....kkkk....",
		"............",
	],
	"aiders": [
		"............",
		"..kbbbbbbk..",
		"..kbkkkkbk..",
		"..kwwwwwwk..",
		"..kbkkkkbk..",
		"..kwwwwwwk..",
		"..kbkkkkbk..",
		"..kwwwwwwk..",
		"..kbkkkkbk..",
		"..kwwwwwwk..",
		"..kbbbbbbk..",
		"...kkkkkk...",
	],
	"ascenders": [
		"............",
		"...kkkk.....",
		"..kyyyyk....",
		"..kygGyk....",
		"..kyyyyk....",
		"..kGGGGk....",
		"..kggggkkk..",
		"..kgddgyyyk.",
		"..kggggkkk..",
		"..kGGGGk....",
		"...kkkk.....",
		"............",
	],
	"haul_bag": [
		"............",
		"....kkkk....",
		"...kooook...",
		"..kooooook..",
		".kooyyyyook.",
		".kooyYYyook.",
		".kooyyyyook.",
		".kooooooook.",
		".koRRRRRRok.",
		"..kRRRRRRk..",
		"...kkkkkk...",
		"............",
	],
	"portaledge": [
		"............",
		"............",
		".kkkkkkkkkk.",
		".koooooooook",
		".kooooooooo.",
		".kkkkkkkkkk.",
		".kg......gk.",
		".kg......gk.",
		".kg......gk.",
		".kg......gk.",
		".kk......kk.",
		"............",
	],
	"ice_axe": [
		"............",
		"..kkkkkk....",
		".kcccccgk...",
		"kccgGkGggk..",
		"kkkk.kk.....",
		".....kn.....",
		".....kn.....",
		".....kn.....",
		".....kn.....",
		".....kn.....",
		".....kg.....",
		".....kk.....",
	],
	"crampons": [
		"............",
		"............",
		"..kkkkkkkk..",
		".kggggggggk.",
		".kgyyggyygk.",
		".kggggggggk.",
		"..kGGGGGGk..",
		"..kgkgkgkgk.",
		"..kgkgkgkgk.",
		"..kkkkkkkk..",
		"............",
		"............",
	],
	"food": [
		"............",
		".....e......",
		"....eEk.....",
		"...kkkkk....",
		"..krrrrrk...",
		".krrwrrrrk..",
		".krwrrrrrk..",
		".krrrrrrRk..",
		"..krrrrRk...",
		"...kRRRk....",
		"....kkk.....",
		"............",
	],
	"chalk": [
		"............",
		"............",
		"....kkkk....",
		"...kwwwwk...",
		"..kwwwwwwk..",
		"..kwwwwwwk..",
		"...kkkkkk...",
		"............",
		"............",
		"............",
		"............",
		"............",
	],
	"pin": [
		"............",
		"............",
		"..kk........",
		".kRRkkkkkk..",
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
		".....kyk....",
		"....kyyyk...",
		"kkkkkyyykkkk",
		".kyyyyyyyyk.",
		"..kyyyyyyk..",
		"...kyyyyk...",
		"..kyyk.yyk..",
		"..kyk...kyk.",
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
		".kek.kek....",
		"..kekek.....",
		"...kek......",
		"....k.......",
		"............",
	],
}

static var _icon_cache: Dictionary = {}


static func icon_texture(id: String) -> Texture2D:
	if _icon_cache.has(id):
		return _icon_cache[id]
	var rows: Array = ICONS.get(id, [])
	if rows.is_empty():
		return null
	var im := Image.create_empty(12, 12, false, Image.FORMAT_RGBA8)
	for y in rows.size():
		var line: String = rows[y]
		for x in line.length():
			var ch := line[x]
			if ICON_COLORS.has(ch):
				im.set_pixel(x, y, ICON_COLORS[ch])
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
	ci.draw_rect(r.grow(1), WOOD_DARK)
	ci.draw_rect(r, Color("c9a06a") if not selected else Color("f2d27a"))
	ci.draw_rect(Rect2(r.position, Vector2(r.size.x, 1)), Color("e8c88a"))
	ci.draw_rect(Rect2(r.position + Vector2(0, r.size.y - 1), Vector2(r.size.x, 1)), Color("8a6a3a"))
	icon(ci, id, pos + Vector2(3, 3), Color(1, 1, 1, 0.35) if dim else Color.WHITE)
	if count >= 0:
		var s := str(count)
		var w := text_width(s, 10)
		text(ci, pos + Vector2(17 - w, 17), s, CREAM if not dim else Color(CREAM, 0.5), 10)
