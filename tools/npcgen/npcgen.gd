extends SceneTree
## Draws the placeholder pixel art for every person in the game: one 208×96
## sheet per character, in the same layout as assets/sprites/player.png
## (16×24 frames; rows down / up / left / right, and a column per pose in
## COLUMNS: stand, the two walking steps, a blink, two running strides,
## crouching, arms up, reaching out, carrying someone on your back (standing
## and two steps) and talking). The first three columns are the original
## stand / step A / step B, so a sheet cut down to them still works. Also draws the player sheet (assets/sprites/player.png), the icons
## for story items (assets/sprites/story_items.png) and a preview lineup of the
## whole cast (docs/cast_lineup.png).
##
##   godot --headless --path . -s res://tools/npcgen/npcgen.gd
##   godot --headless --path . --import      # so Godot picks up new PNGs
##
## Each look is a Dictionary in tools/npcgen/looks.gd. Replace any PNG with
## hand-drawn art in the same layout at any time; the game only reads the PNG.
##
## Style: a big head (hair included ~10 px), 2 px eyes with a light glint, a
## blush and 1 px nose and mouth. Front views get explicit 3-tone clothes and
## skin; every view is then lit from the upper left in screen space, so right
## views are drawn mirrored but shaded the same way. The outline is a dark
## shade of the touching colour, lighter on top and left. On step frames the
## upper body rises 1 px, and a soft oval shadow sits under the feet.

const Looks = preload("res://tools/npcgen/looks.gd")
const FW := FigurePainter.FW
const FH := FigurePainter.FH
const OUT_DIR := "res://assets/sprites/npcs/"
const PLAYER_PNG := "res://assets/sprites/player.png"
const ITEMS_PNG := "res://assets/sprites/story_items.png"
const LINEUP_PNG := "res://docs/cast_lineup.png"


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	var painter := ItemPainter.new()
	var sheets: Array[Image] = []
	for id: String in Looks.LOOKS:
		var sheet := painter.draw_sheet(Looks.LOOKS[id])
		sheet.save_png(ProjectSettings.globalize_path(OUT_DIR + id + ".png"))
		sheets.append(sheet)
		print("drew ", id)
	painter.draw_sheet(Looks.PLAYER).save_png(ProjectSettings.globalize_path(PLAYER_PNG))
	painter.draw_items().save_png(ProjectSettings.globalize_path(ITEMS_PNG))
	draw_lineup(sheets).save_png(ProjectSettings.globalize_path(LINEUP_PNG))
	print("done: %d characters" % sheets.size())
	quit()


## The figure painter (scripts/player/figure_painter.gd, which the game uses
## too for the player's own look), plus the story items' icons.
class ItemPainter extends FigurePainter:
	# ---------------------------------------------------------------- items

	## 16×16 icons for story items, in the order of Looks.ITEMS. Each has three
	## tones lit from the upper left, a dark coloured outline, and a glint.
	func draw_items() -> Image:
		im = Image.create_empty(16 * Looks.ITEMS.size(), 16, false, Image.FORMAT_RGBA8)
		dy = 0
		mirror = false
		for i in Looks.ITEMS.size():
			ox = i * 16
			oy = 0
			match Looks.ITEMS[i]:
				"lamon_apple":
					var r := Color("c83030")
					rect(4, 5, 8, 9, r)
					rect(3, 6, 10, 7, r)
					rect(5, 14, 6, 1, r)
					rect(4, 6, 2, 6, tone(r, 0.3))
					rect(10, 7, 2, 7, tone(r, -0.4))
					rect(5, 13, 6, 1, tone(r, -0.4))
					px(5, 7, GLINT)
					px(5, 8, tone(r, 0.5))
					rect(7, 2, 1, 3, "5a3a1a")
					rect(8, 2, 3, 2, "5a9a30")
					px(8, 2, "7ac040")
					px(10, 3, "3a7a20")
				"degnan_loaf":
					var b := Color("b0783a")
					rect(2, 7, 12, 6, b)
					rect(3, 6, 10, 1, b)
					rect(2, 7, 12, 1, tone(b, 0.25))
					rect(3, 12, 10, 1, tone(b, -0.35))
					rect(12, 8, 1, 4, tone(b, -0.35))
					for x in [4, 7, 10]:
						rect(x, 8, 2, 1, tone(b, 0.45))
					px(4, 9, GLINT)
				"pine_nuts":
					for p in [Vector2i(3, 8), Vector2i(7, 5), Vector2i(11, 8), Vector2i(7, 10)]:
						var n := Color("8a5a3a")
						rect(p.x, p.y, 2, 3, n)
						rect(p.x, p.y, 1, 2, tone(n, 0.3))
						rect(p.x + 1, p.y + 1, 1, 2, tone(n, -0.35))
						px(p.x, p.y + 2, tone(n, -0.5))
					px(7, 5, GLINT)
				"model_a_axle":
					rect(2, 7, 12, 2, "6a6a70")
					rect(2, 7, 12, 1, "9a9aa0")
					rect(2, 8, 12, 1, "4a4a52")
					rect(1, 5, 2, 6, "4a4a50")
					rect(13, 5, 2, 6, "34343a")
					rect(1, 5, 1, 2, "7a7a84")
					px(6, 8, "8a5a3a")
					px(10, 7, "8a5a3a")
					px(4, 7, GLINT)
				"anderson_eyebolt":
					var m := Color("7a7a80")
					rect(5, 2, 6, 5, m)
					rect(6, 3, 4, 3, Color(0, 0, 0, 0))
					rect(7, 6, 2, 8, m)
					rect(5, 2, 1, 5, tone(m, 0.3))
					rect(7, 6, 1, 8, tone(m, 0.3))
					rect(10, 2, 1, 5, tone(m, -0.35))
					rect(8, 6, 1, 8, tone(m, -0.35))
					px(7, 9, tone(m, -0.5))
					px(8, 11, tone(m, -0.5))
					px(5, 3, GLINT)
					px(8, 13, "5a4a3a")
				"sourdough_starter":
					var g := Color("d8d0c0")
					rect(4, 4, 8, 2, "7a5a3a")
					rect(4, 4, 2, 2, tone(Color("7a5a3a"), 0.3))
					rect(4, 6, 8, 8, g)
					rect(10, 6, 2, 8, tone(g, -0.3))
					rect(5, 7, 5, 5, "f0e8d0")
					rect(9, 7, 1, 5, tone(Color("f0e8d0"), -0.2))
					px(5, 7, GLINT)
				"rental_shoes":
					# A pair of rental climbing shoes tied together by the laces, with a shop tag.
					var s := Color("c8502e")
					rect(1, 7, 7, 4, s)
					rect(1, 10, 8, 2, "222226")
					rect(8, 9, 7, 3, s)
					rect(8, 12, 7, 1, "222226")
					rect(1, 7, 7, 1, tone(s, 0.3))
					rect(8, 9, 7, 1, tone(s, 0.3))
					rect(8, 11, 7, 1, tone(s, -0.35))
					px(4, 8, "f0e8d8")
					px(11, 10, "f0e8d8")
					px(2, 8, GLINT)
					rect(6, 3, 1, 5, "f0e8d8")
					rect(9, 4, 4, 3, "e8dcb0")
					px(10, 5, "5a3a24")
			outline_frame16()
		return im


	## Outlines the 16×16 item icon at ox.
	func outline_frame16() -> void:
		outline_region(ox, 0, 16, 16)


# ---------------------------------------------------------------- preview

## Every character facing down, standing, at 4× on a light background.
func draw_lineup(sheets: Array[Image]) -> Image:
	const S := 4
	const PER_ROW := 8
	var rows := ceili(sheets.size() / float(PER_ROW))
	var out := Image.create_empty(PER_ROW * (FW + 4) * S, rows * (FH + 4) * S, false, Image.FORMAT_RGBA8)
	out.fill(Color("e8e0cc"))
	for i in sheets.size():
		var frame := sheets[i].get_region(Rect2i(0, 0, FW, FH))
		frame.resize(FW * S, FH * S, Image.INTERPOLATE_NEAREST)
		var at := Vector2i((i % PER_ROW) * (FW + 4) * S + 2 * S, (i / PER_ROW) * (FH + 4) * S + 2 * S)
		out.blend_rect(frame, Rect2i(Vector2i.ZERO, frame.get_size()), at)
	return out
