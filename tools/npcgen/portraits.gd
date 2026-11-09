extends SceneTree
## Paints a 40x40 head-and-shoulders portrait of everyone in the cast, from the
## same look data as their walking sprites (tools/npcgen/looks.gd), for the
## conversation box. Each one is saved under the name of the person's sprite
## sheet, so assets/sprites/npcs/wren_alvarez.png gets
## assets/sprites/portraits/wren_alvarez.png, and the player gets player.png.
## Each file is a strip of four 40x40 faces, one per mood in MOODS order
## (neutral, happy, sad, surprised); the conversation box picks one per line.
## Also writes docs/cast_portraits.png (every neutral face side by side) and
## docs/portrait_moods.png (a few people in all four moods).
##
##   godot --headless --path . -s res://tools/npcgen/portraits.gd
##   godot --headless --path . --import

const Looks = preload("res://tools/npcgen/looks.gd")

## The painting itself is PortraitPainter (scripts/story/portrait_painter.gd),
## which the game uses too for the player's own look.
const R := PortraitPainter.R
const OUT_DIR := "res://assets/sprites/portraits/"
const SHEET_PNG := "res://docs/cast_portraits.png"
const MOODS := PortraitPainter.MOODS

var _painter := PortraitPainter.new()


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	var ids: Array = Looks.LOOKS.keys()
	ids.sort()
	var all: Array[Image] = []
	var strips: Dictionary = {}
	for id: String in ids:
		var strip := _strip(Looks.LOOKS[id], id)
		strip.save_png(OUT_DIR + id + ".png")
		all.append(strip.get_region(Rect2i(0, 0, R, R)))
		strips[id] = strip
	var player := _strip(Looks.PLAYER, "player")
	player.save_png(OUT_DIR + "player.png")
	all.append(player.get_region(Rect2i(0, 0, R, R)))
	_save_sheet(all)
	_save_moods([strips.galen_clark, strips.wren_alvarez, strips.maria_lebrado, strips.warren_harding])
	print("%d portraits written to %s. Run godot --headless --path . --import next." % [all.size(), OUT_DIR])
	quit()


## Every mood of one person, side by side.
func _strip(look: Dictionary, id: String) -> Image:
	return _painter.strip(look, id)


func _save_moods(strips: Array) -> void:
	var sheet := Image.create_empty(R * MOODS.size() + 8, strips.size() * (R + 4) + 4, false, Image.FORMAT_RGBA8)
	sheet.fill(Color("e8dfcc"))
	for r in strips.size():
		for i in MOODS.size():
			sheet.fill_rect(Rect2i(4 + i * R, 4 + r * (R + 4), R - 2, R), Color("6a5440"))
		sheet.blend_rect(strips[r], Rect2i(0, 0, R * MOODS.size(), R), Vector2i(4, 4 + r * (R + 4)))
	sheet.resize(sheet.get_width() * 2, sheet.get_height() * 2, Image.INTERPOLATE_NEAREST)
	sheet.save_png("res://docs/portrait_moods.png")


func _save_sheet(all: Array[Image]) -> void:
	var cols := 10
	var rows := ceili(all.size() / float(cols))
	var sheet := Image.create_empty(cols * (R + 4) + 4, rows * (R + 4) + 4, false, Image.FORMAT_RGBA8)
	sheet.fill(Color("e8dfcc"))
	for i in all.size():
		var at := Vector2i(4 + (i % cols) * (R + 4), 4 + (i / cols) * (R + 4))
		sheet.fill_rect(Rect2i(at, Vector2i(R, R)), Color("6a5440"))
		sheet.blend_rect(all[i], Rect2i(0, 0, R, R), at)
	sheet.resize(sheet.get_width() * 2, sheet.get_height() * 2, Image.INTERPOLATE_NEAREST)
	sheet.save_png(SHEET_PNG)
