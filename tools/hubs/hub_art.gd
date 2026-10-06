extends RefCounted
## Pixel art for the Village Store's foods (trail mix and dried apples). The
## village buildings and camp props moved to valley_art.gd, which draws them in
## the Ahwahnee's style. Drawn in code in the same style as tools/mapgen/art.gd;
## replace any PNG with hand-drawn art of the same size.

const Art = preload("res://tools/mapgen/art.gd")
const ITEM_ICONS := "res://assets/sprites/store_items.png"

var art := Art.new()


static func c(hex: String) -> Color:
	return Color(hex)


func save_all() -> void:
	_store_items().save_png(ITEM_ICONS)


## 16x16 icons: trail mix, then dried apples.
func _store_items() -> Image:
	var im := Image.create_empty(32, 16, false, Image.FORMAT_RGBA8)
	art.rect(im, 3, 3, 10, 12, c("c89a52"))
	art.rect(im, 3, 3, 10, 2, c("a07a3a"))
	for p in [[5, 8], [8, 10], [10, 7], [6, 12], [11, 12]]:
		art.px(im, p[0], p[1], c("6a4228"))
		art.px(im, p[0] + 1, p[1], c("e8d8a8"))
	art.outline(im, Rect2i(0, 0, 16, 16), Art.OUTLINE)
	for p in [[20, 6], [25, 8], [21, 11], [26, 12]]:
		art.ellipse(im, p[0] + 0.5, p[1] + 0.5, 3, 2.2, c("e8c878"))
		art.ellipse(im, p[0] + 0.5, p[1] + 0.5, 1.2, 0.8, c("c83a2a"))
	art.outline(im, Rect2i(16, 0, 16, 16), Art.OUTLINE)
	return im
