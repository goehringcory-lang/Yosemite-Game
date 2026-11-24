extends SceneTree
## Draws the pictures for camping anywhere (Backpacking): the backpacking
## pack's gear icon (assets/sprites/gear/backpacking_pack.png, 64x64, drawn
## on a 32x32 grid and doubled like the other gear), and Ranger Pruitt, the
## wilderness ranger, painted the way the player's own look is in the game
## (FigurePainter and PortraitPainter, then the 32px pass in Palette32):
## assets/sprites/npcs/wilderness_ranger.png and the portrait strip
## assets/sprites/portraits/wilderness_ranger.png.
## Run: godot --headless --path . -s res://tools/npcgen/backpacking_art.gd

const OUTLINE := "2a1f1a"
## The pack: forest-green canvas on a grey frame, a foam pad rolled on top.
const BAG_HI := "6a8a4a"
const BAG := "4a6a3a"
const BAG_DK := "34502a"
const FRAME_HI := "d0d0d0"
const FRAME := "a8a8a8"
const PAD := "c8a860"
const PAD_DK := "8a7440"
const TENT := "3a6a5a"
const BUCKLE := "2a2a30"

## Ranger Pruitt: NPS gray and green, flat hat, badge, a pack as big as yours.
const RANGER := {
	"skin": "a8703f", "hair": "2a1e18", "hair_style": "short", "beard": "short", "beard_color": "2a1e18",
	"hat": "campaign", "hat_color": "7a6038", "hat_band": "3a2a20",
	"top": "a8a690", "top_style": "shirt", "top2": "8a8870", "bottom": "3e5034", "belt": "3a2a20",
	"badge": true, "shoes": "3a2a20", "pack": "backpacking", "pack_color": "5a6a3a", "carry": ["notebook"],
}

var im: Image


func _init() -> void:
	var icon := pack_icon()
	icon.resize(64, 64, Image.INTERPOLATE_NEAREST)
	icon.save_png(ProjectSettings.globalize_path("res://assets/sprites/gear/backpacking_pack.png"))
	print("drew backpacking_pack")
	var sheet := Palette32.character_sheet(FigurePainter.new().draw_sheet(RANGER))
	sheet.save_png(ProjectSettings.globalize_path("res://assets/sprites/npcs/wilderness_ranger.png"))
	print("drew wilderness_ranger sheet")
	var faces := Palette32.snap(PortraitPainter.new().strip(RANGER, "wilderness_ranger"))
	faces.save_png(ProjectSettings.globalize_path("res://assets/sprites/portraits/wilderness_ranger.png"))
	print("drew wilderness_ranger portrait")
	quit()


func rect(x: int, y: int, w: int, h: int, hex: String) -> void:
	im.fill_rect(Rect2i(x, y, w, h), Color(hex))


## The pack stood up, front on: the bag on its frame, a pocket and two
## buckled straps, the pad rolled across the top and the tent bag below.
func pack_icon() -> Image:
	im = Image.create_empty(32, 32, false, Image.FORMAT_RGBA8)
	# the frame, poking out above and below the bag
	rect(8, 2, 3, 28, OUTLINE)
	rect(21, 2, 3, 28, OUTLINE)
	rect(9, 3, 1, 26, FRAME_HI)
	rect(22, 3, 1, 26, FRAME)
	# the bag
	rect(9, 7, 14, 17, OUTLINE)
	rect(10, 8, 12, 15, BAG)
	rect(10, 8, 3, 15, BAG_HI)
	rect(19, 8, 3, 15, BAG_DK)
	rect(10, 11, 12, 1, BAG_DK) # the lid's edge
	# the front pocket
	rect(12, 15, 8, 6, OUTLINE)
	rect(13, 16, 6, 4, BAG_DK)
	rect(13, 16, 6, 1, BAG)
	# straps and buckles
	rect(12, 8, 1, 7, BAG_DK)
	rect(19, 8, 1, 7, BAG_DK)
	rect(11, 13, 3, 2, BUCKLE)
	rect(18, 13, 3, 2, BUCKLE)
	# the pad, rolled across the top
	rect(4, 3, 24, 6, OUTLINE)
	rect(5, 4, 22, 4, PAD)
	rect(5, 4, 22, 1, "e4cc88")
	rect(5, 7, 22, 1, PAD_DK)
	for x in [8, 14, 20]:
		rect(x, 4, 1, 4, PAD_DK)
	# the tent bag under it all
	rect(7, 23, 18, 6, OUTLINE)
	rect(8, 24, 16, 4, TENT)
	rect(8, 24, 16, 1, "5a8a7a")
	rect(8, 27, 16, 1, "2a4a40")
	rect(15, 24, 1, 4, BUCKLE)
	return im
