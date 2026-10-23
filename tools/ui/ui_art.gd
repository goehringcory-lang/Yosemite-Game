extends Node
## Draws the UI's art into assets/ui. The nine-slice panel is a warm wooden
## frame: a two-tone bevel lit from the upper left, a brass line and brass corner
## studs round a deep brown inset, with a soft drop shadow down and to the right.
## Its variants are a lighter banner and a plaque with planks inside. The small
## sprites are a speaker tag, a menu highlight bar and the bobbing next arrow.
##   godot --headless --path . res://tools/ui/ui_art.tscn
## The theme (assets/ui/theme.tres) stretches the panels with an 8 px margin.

const SIZE := 32
## The frame's own size. The columns and rows past it are the drop shadow.
const FRAME := 30
## Pixels in from the frame's edge where the inset starts.
const INSET := 6
## The nine-slice margin the theme keeps unstretched.
const STRETCH_MARGIN := 8

const OUTLINE := "150d07"
const OUTLINE_LIT := "2e1d0f"
const BEVEL_LIT := "d9a767"
const BEVEL_MID := "b07d47"
const BEVEL_SHADE := "7a4c2a"
const BODY_LIT := "9e6b3c"
const BODY_MID := "7f5231"
const BODY_SHADE := "58391f"
const LIP_LIT := "5f3e23"
const LIP_SHADE := "37220f"
const BRASS_LIT := "ecca80"
const BRASS_MID := "d4a852"
const BRASS_SHADE := "9a7234"
const INSET_SHADE := "140c07"
const INSET_LIGHT := "4a3322"
const SHADOW := Color(0.04, 0.02, 0.01)
const STUD := {"o": "2a1a0c", "h": "fbe6a6", "b": "d9b25e", "s": "8f6d30"}
const PLANK_A := "4b3019"
const PLANK_B := "3f2715"
const PLANK_TOP := "5e3d22"
const PLANK_SEAM := "24160c"


func _ready() -> void:
	var panel := _blank()
	_frame(panel, Color("3c2918"), Color("231a14"), false)
	_shadow(panel)
	_save(panel, "panel")
	# the same panel with a lighter interior, for banners over busy ground
	var banner := _blank()
	_frame(banner, Color("4f3825"), Color("37281b"), false)
	_shadow(banner)
	_save(banner, "panel_banner")
	# the clock and place-name plaques: wooden planks inside the same frame
	var plaque := _blank()
	_frame(plaque, Color(PLANK_A), Color(PLANK_B), true)
	_shadow(plaque)
	_save(plaque, "plaque")
	var tag := Image.create_empty(12, 12, false, Image.FORMAT_RGBA8)
	_tag(tag)
	_save(tag, "tag")
	var select := Image.create_empty(8, 7, false, Image.FORMAT_RGBA8)
	_select(select)
	_save(select, "select")
	var next := Image.create_empty(9, 6, false, Image.FORMAT_RGBA8)
	_next(next)
	_save(next, "next")
	print("ui art painted")
	get_tree().quit()


func _blank() -> Image:
	return Image.create_empty(SIZE, SIZE, false, Image.FORMAT_RGBA8)


func _save(im: Image, name: String) -> void:
	var path := ProjectSettings.globalize_path("res://assets/ui/%s.png" % name)
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	im.save_png(path)


## The frame: outline, bevel, wood body, brass line and the inset. The top-left
## half of each ring is lit and the bottom-right half sits in shade.
func _frame(im: Image, top: Color, bottom: Color, planks: bool) -> void:
	var last := FRAME - 1
	for y in FRAME:
		for x in FRAME:
			var cx := mini(x, last - x)
			var cy := mini(y, last - y)
			var r := mini(cx, cy)
			if cx + cy <= 1:
				continue # the chamfered corner sits outside the frame
			# t runs from 0 at the lit upper-left corner to 1 at the shaded lower-right
			var t := float(x + y) / float(2 * last)
			var lit := t < 0.4
			var shade := t > 0.6
			var color := Color(0, 0, 0, 0)
			match r:
				0:
					color = Color(OUTLINE_LIT if t < 0.5 else OUTLINE)
				1:
					color = Color(BEVEL_LIT if lit else (BEVEL_SHADE if shade else BEVEL_MID))
				2:
					color = Color(BODY_LIT if lit else (BODY_SHADE if shade else BODY_MID))
					# wood grain: short runs along the top and bottom rails
					if cy < cx and (x * 7 + 3) % 17 < 3:
						color = color.darkened(0.14)
				3:
					color = Color(LIP_LIT if lit else LIP_SHADE)
				4:
					color = Color(BRASS_LIT if lit else (BRASS_SHADE if shade else BRASS_MID))
				5:
					# the inset's edge: a dark line on the lit side, a faint catch on the other
					color = Color(INSET_SHADE if lit else (INSET_LIGHT if shade else BODY_SHADE))
				_:
					color = _inside(x, y, top, bottom, planks)
			im.set_pixel(x, y, color)
	_studs(im)


## One pixel of the inset: a lit top edge over a flat fill, or planks laid in
## staggered rows. The lit edge stays inside the 8 px the theme never
## stretches: the stretched middle is one color, or a stripe of the lighter
## tone would grow with the panel and cut through its first line of text.
func _inside(x: int, y: int, top: Color, bottom: Color, planks: bool) -> Color:
	if not planks:
		return top if y < STRETCH_MARGIN else bottom
	var row := y - INSET
	var course := row / 6
	if row % 6 == 0:
		return Color(PLANK_SEAM)
	if row % 6 == 1:
		return Color(PLANK_TOP)
	return Color(PLANK_A if course % 2 == 0 else PLANK_B)


## Brass studs in the four corners, lit from the upper left.
func _studs(im: Image) -> void:
	var pattern := [
		["o", "h", "o"],
		["h", "b", "s"],
		["o", "s", "o"],
	]
	for origin: Vector2i in [Vector2i(1, 1), Vector2i(FRAME - 4, 1), Vector2i(1, FRAME - 4), Vector2i(FRAME - 4, FRAME - 4)]:
		for dy in 3:
			for dx in 3:
				im.set_pixel(origin.x + dx, origin.y + dy, Color(STUD[pattern[dy][dx]]))


## A soft drop shadow: two steps down and to the right of the frame.
func _shadow(im: Image) -> void:
	for y in range(2, SIZE):
		for x in range(2, SIZE):
			if x < FRAME and y < FRAME:
				continue
			var d := maxi(x, y) - (FRAME - 1)
			var alpha := 0.5 if d == 1 else 0.22
			im.set_pixel(x, y, Color(SHADOW.r, SHADOW.g, SHADOW.b, alpha))


## A small brass-edged plate. Its top row is the lit brass edge and its bottom
## row the brass underline that sits against the box's text.
func _tag(im: Image) -> void:
	for y in 12:
		for x in 12:
			var color := Color("553420")
			if x == 0 or x == 11:
				color = Color(OUTLINE)
			elif y == 0:
				color = Color(BRASS_LIT)
			elif y == 11:
				color = Color("b8914a")
			elif y == 1:
				color = Color("7a5230")
			elif y == 10:
				color = Color("42291a")
			im.set_pixel(x, y, color)


## A translucent gold bar for the chosen menu row, with a brighter left tick.
func _select(im: Image) -> void:
	for y in 7:
		for x in 8:
			var color := Color(0.85, 0.7, 0.37, 0.2)
			if y == 0:
				color = Color(0.94, 0.81, 0.51, 0.42)
			elif y == 6:
				color = Color(0.6, 0.43, 0.18, 0.4)
			elif x == 0:
				color = Color(0.94, 0.81, 0.51, 0.85)
			im.set_pixel(x, y, color)


## A small downward arrow with a dark outline, for "more to come" in dialogue.
func _next(im: Image) -> void:
	var mask := ["#######", ".#####.", "..###..", "...#..."]
	var fill := ["f3d88e", "f3d88e", "e0b660", "b98a3e"]
	for y in 6:
		for x in 9:
			if _arrow_filled(mask, x - 1, y - 1):
				var row := y - 1
				im.set_pixel(x, y, Color(fill[row]))
			elif _arrow_filled(mask, x - 1, y - 2) or _arrow_filled(mask, x - 1, y) \
					or _arrow_filled(mask, x - 2, y - 1) or _arrow_filled(mask, x, y - 1):
				im.set_pixel(x, y, Color(OUTLINE_LIT))


func _arrow_filled(mask: Array, x: int, y: int) -> bool:
	if y < 0 or y >= mask.size() or x < 0 or x >= mask[0].length():
		return false
	return mask[y][x] == "#"
