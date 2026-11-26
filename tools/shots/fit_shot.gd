extends Node
## Screenshots of the dialogue box with the most it ever has to hold: a
## shop list with its card (long costs, a long note), a long name, and a
## campfire with more dishes than fit at once. Each box must stay inside
## the screen. Needs a window (not --headless):
##   SHOT_DIR=/tmp/shots xvfb-run -a godot --path . res://tools/shots/fit_shot.tscn
## SHOT_SIZE=1280x720 (or any size) checks another window size.


func _env(key: String, fallback: String) -> String:
	return OS.get_environment(key) if OS.get_environment(key) != "" else fallback


func _snap(dir: String, shot_name: String, box: DialogueBox) -> void:
	box.reveal_all()
	for i in 6:
		await get_tree().process_frame
	var rect := box._panel.get_global_rect()
	var inside := Rect2(Vector2.ZERO, UiScale.SCREEN).encloses(rect)
	print("%s: box %s %s" % [shot_name, rect, "fits" if inside else "RUNS OFF THE SCREEN"])
	var size := _env("SHOT_SIZE", "")
	get_viewport().get_texture().get_image().save_png("%s/fit_%s%s.png" % [dir, shot_name, "_" + size if size != "" else ""])


func _ready() -> void:
	var size := _env("SHOT_SIZE", "")
	if size != "":
		var parts := size.split("x")
		get_window().size = Vector2i(int(parts[0]), int(parts[1]))
	var dir := _env("SHOT_DIR", "user://")
	var backdrop := ColorRect.new()
	backdrop.color = Color(0.25, 0.35, 0.3)
	backdrop.size = Vector2(960, 540)
	add_child(backdrop)
	await get_tree().process_frame

	# Marty's rack: a card with long costs and what he'd take
	var long_take := "They'd take 3 Brown Trout, 2 Pilot Bread, 4 Trail Mix, and 12 off your tab"
	var card := {"title": "Mid nuts", "rows": [
		[null, "Costs 24 of the 701 your pack is worth here", false],
		[null, long_take, false],
		[null, "2 left over goes on your tab", false]],
		"facts": "You have 0 · one swap a day",
		"note": "A set of mid-sized wired nuts on one carabiner. Wedge one in a crack's narrowing."}
	var icon: Texture2D = load("res://assets/ui/next.png")
	var box := DialogueBox.open(self)
	box.choose("Your pack is worth 701 in trade here. What do you want?",
		["Mid nuts · costs 24", "Cam #0.5 · costs 50", "70 m rope · costs 104", "Sell some spare gear", "Done"],
		"Marty Kessler", [icon, icon, icon, null, null], [card, card, card, null, null])
	await _snap(dir, "shop", box)
	box.close()

	# a very long name and a very long option, no card
	box = DialogueBox.open(self)
	box.choose("Which way?", ["A very long option that goes on and on about the trail to the top of the falls and back down again",
		"Short"], "Wendell Archibald Fitzgerald-Montgomery the Third of Camp Four")
	await _snap(dir, "long_name", box)
	box.close()

	# a campfire with every recipe: more than fit at once
	var dishes := []
	var cards := []
	for i in 16:
		dishes.append("Dish number %d" % (i + 1))
		cards.append(card)
	dishes.append("Leave")
	cards.append(null)
	box = DialogueBox.open(self)
	box.choose("Campfire. What will you make? You're carrying plenty of food and the fire is hot and ready to cook on tonight.", dishes, "", [], cards, 12)
	await _snap(dir, "campfire", box)
	box.close()

	# a shop of long names: two-line options, a card and a face, so fewer
	# than eight show at once
	var goods := []
	var pics := []
	var shop_cards := []
	for i in 12:
		goods.append("Big Wall Supply Kit number %d with spare webbing · costs %d" % [i + 1, 40 + i])
		pics.append(icon)
		shop_cards.append(card)
	box = DialogueBox.open(self)
	box.choose("Your pack is worth 701 in trade here. What do you want?", goods, "Marty Kessler", pics, shop_cards, 9)
	await _snap(dir, "tall_shop", box)
	box.close()
	get_tree().quit()
