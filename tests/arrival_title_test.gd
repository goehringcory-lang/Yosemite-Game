extends Node
## Checks the region title card (ArrivalTitle): it shows the name, fades away
## by itself, a very long name stays on the 480 px screen, and the "Region
## titles" setting turns the HUD's show_arrival off.
## Run: godot --headless --path . res://tests/arrival_title_test.tscn
## Exit code is the number of failed checks.

var failures := 0


func check(cond: bool, what: String) -> void:
	print(("PASS  " if cond else "FAIL  ") + what)
	if not cond:
		failures += 1


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _ready() -> void:
	var card := ArrivalTitle.new()
	add_child(card)
	await get_tree().process_frame
	check(not card.visible, "hidden until asked")
	card.show_title("Yosemite Valley", "Where the walls rise")
	await get_tree().process_frame
	check(card.visible and card.is_showing() and card._title == "Yosemite Valley", "show_title shows the name")
	check(card.mouse_filter == Control.MOUSE_FILTER_IGNORE, "it never takes input")
	await _wait(1.0)
	check(card.modulate.a > 0.99, "fully faded in while it holds")
	card.show_title("Glacier Point", "")
	check(card._title == "Glacier Point", "a new call replaces the one showing")
	await _wait(4.0)
	check(not card.visible and card.modulate.a == 0.0 and not card.is_showing(), "it fades out on its own after ~4 s")

	var long_name := "The Very Long Name Of A Region In The High Sierra Beyond Tuolumne Meadows And Tenaya Lake"
	card.show_title(long_name, "x")
	var font := card.get_theme_default_font()
	var wide: float = font.get_string_size(long_name, HORIZONTAL_ALIGNMENT_LEFT, -1, card._title_size).x
	check(card._title_size < 16, "a long name steps the size down (%d)" % card._title_size)
	check(wide <= 480.0, "and stays within 480 px (%d px)" % wide)
	card.queue_free()

	var hud: Node = load("res://scenes/ui/hud.tscn").instantiate()
	add_child(hud)
	await get_tree().process_frame
	Settings.arrival_titles = false
	hud.show_arrival("Tuolumne Meadows", "High country")
	check(not hud.arrival_title.visible, "with Region titles off the HUD shows nothing")
	Settings.arrival_titles = true
	hud.show_arrival("Tuolumne Meadows", "High country")
	check(hud.arrival_title.visible, "with it on the HUD shows the card")
	Settings.arrival_titles = true

	print("%d failure(s)" % failures)
	get_tree().quit(failures)
