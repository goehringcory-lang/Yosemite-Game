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
	# Trail mix: a kraft-paper sack with its top rolled over, lit from the
	# left, and a little spill of almonds, raisins and oats at its foot.
	var kraft := [c("8a6232"), c("b08048"), c("c89a5a"), c("dcb478")]
	for y in range(4, 14):
		var w := 9 if y > 5 else 8
		var x0 := 3 if y > 5 else 4
		for x in range(x0, x0 + w):
			var t := float(x - x0) / (w - 1)
			art.px(im, x, y, kraft[3] if t < 0.2 else (kraft[2] if t < 0.65 else kraft[1]))
	# the rolled top, and its shadow
	art.rect(im, 3, 2, 9, 2, kraft[2])
	art.rect(im, 3, 2, 9, 1, kraft[3])
	art.rect(im, 4, 4, 8, 1, kraft[0])
	# a printed label with a pine on it
	art.rect(im, 5, 7, 5, 4, c("efe3c4"))
	art.px(im, 7, 7, c("3f6b3a"))
	art.rect(im, 6, 8, 3, 1, c("3f6b3a"))
	art.rect(im, 6, 9, 3, 1, c("4f8048"))
	art.px(im, 7, 10, c("6a4228"))
	# the spill: almonds, raisins and oats
	for p in [[11, 13, "b8784a"], [13, 14, "a0663a"], [12, 12, "3a1e22"], [14, 12, "4a2830"], [10, 14, "e8d8a8"], [13, 11, "e8d8a8"]]:
		art.px(im, p[0], p[1], c(p[2]))
	art.px(im, 12, 14, c("b8784a"))
	art.outline(im, Rect2i(0, 0, 16, 16), Art.OUTLINE)
	for p in [[20, 6], [25, 8], [21, 11], [26, 12]]:
		art.ellipse(im, p[0] + 0.5, p[1] + 0.5, 3, 2.2, c("e8c878"))
		art.ellipse(im, p[0] + 0.5, p[1] + 0.5, 1.2, 0.8, c("c83a2a"))
	art.outline(im, Rect2i(16, 0, 16, 16), Art.OUTLINE)
	return im
