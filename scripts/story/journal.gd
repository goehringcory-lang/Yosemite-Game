class_name Journal
extends CanvasLayer
## The Guardian's Register: a page showing your active quests, climbing gear,
## the food in your pack, and what's in your chuckah. Press J (gamepad Y) to open or close it.
##
## World adds one of these. It pauses the clock while it's open.

const HEADING := Color(1.0, 0.85, 0.5)
const DIM := Color(1, 1, 1, 0.6)
## The thin line under each section heading.
const RULE := Color(0.85, 0.7, 0.37, 0.45)
## Pixels one Up/Down press scrolls, and how long a held key waits before it
## repeats, then how often it repeats.
const SCROLL_STEP := 24
const REPEAT_DELAY := 0.35
const REPEAT_EVERY := 0.06

var _panel: PanelContainer
var _scroll: ScrollContainer
var _body: VBoxContainer
## Controls hint and "more above/below" marks, under the page so they never scroll away.
var _footer: Label
var _more: Label
var _repeat := 0.0


func _ready() -> void:
	layer = 25
	add_to_group("journal")
	_panel = PanelContainer.new()
	_panel.position = Vector2(40, 20)
	_panel.custom_minimum_size = Vector2(400, 230)
	_panel.visible = false
	add_child(_panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 2)
	_panel.add_child(column)
	_scroll = ScrollContainer.new()
	_scroll.custom_minimum_size = Vector2(392, 206)
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(_scroll)
	var footer := HBoxContainer.new()
	column.add_child(footer)
	_footer = Label.new()
	_footer.add_theme_color_override("font_color", DIM)
	_footer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(_footer)
	_more = Label.new()
	_more.add_theme_color_override("font_color", HEADING)
	footer.add_child(_more)
	_body = VBoxContainer.new()
	_body.add_theme_constant_override("separation", 0)
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_body)


func is_open() -> bool:
	return _panel.visible


func open() -> void:
	if is_open():
		return
	_refresh()
	_scroll.scroll_vertical = 0
	_repeat = REPEAT_DELAY
	_panel.visible = true
	GameClock.paused = true
	_set_player_can_act(false)


func close() -> void:
	if not is_open():
		return
	_panel.visible = false
	GameClock.paused = false
	_set_player_can_act(true)


func _unhandled_input(event: InputEvent) -> void:
	var toggle := event.is_action_pressed("journal")
	if is_open() and (toggle or event.is_action_pressed("ui_cancel")):
		close()
		get_viewport().set_input_as_handled()
	elif toggle and _player_can_act():
		open()
		get_viewport().set_input_as_handled()
	elif is_open():
		# Up/Down (or the stick) scroll the page; holding repeats in _process.
		var step := _scroll_direction(event)
		if step != 0:
			scroll_by(step * SCROLL_STEP)
			_repeat = REPEAT_DELAY
			get_viewport().set_input_as_handled()
		elif event.is_action_pressed("ui_page_down", true) or event.is_action_pressed("ui_page_up", true):
			scroll_by((1 if event.is_action_pressed("ui_page_down", true) else -1) * (int(_scroll.size.y) - SCROLL_STEP))
			get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if not is_open():
		return
	_refresh_more()
	var held := int(Input.is_action_pressed("move_down") or Input.is_action_pressed("ui_down")) \
			- int(Input.is_action_pressed("move_up") or Input.is_action_pressed("ui_up"))
	if held == 0:
		_repeat = REPEAT_DELAY
		return
	_repeat -= delta
	if _repeat <= 0.0:
		_repeat = REPEAT_EVERY
		scroll_by(held * SCROLL_STEP)


## +1 for a fresh Down press, -1 for Up, 0 for anything else.
func _scroll_direction(event: InputEvent) -> int:
	if MenuInput.pressed(event, "move_down") or MenuInput.pressed(event, "ui_down"):
		return 1
	if MenuInput.pressed(event, "move_up") or MenuInput.pressed(event, "ui_up"):
		return -1
	return 0


## Scrolls the page by [param pixels] (negative is up).
func scroll_by(pixels: int) -> void:
	_scroll.scroll_vertical = maxi(0, _scroll.scroll_vertical + pixels)


func _refresh() -> void:
	for child in _body.get_children():
		_body.remove_child(child)
		child.queue_free()
	_heading("The Guardian's Register")

	var main := QuestLog.main_objective()
	if not main.is_empty():
		_heading("Main story")
		_line("%s: %s" % [main.quest.title, main.objective])
	elif not QuestLog.has_guidebook():
		_heading("Main story")
		_line("Pick up a climbing guidebook at the Mountain Shop in Curry Village.")
	elif QuestLog.final_entry_pending():
		_heading("Main story")
		_line("The Last Page: talk to Galen Clark and write your entry.")
	elif QuestLog.final_entry >= 0:
		_heading("The last page")
		var entry: String = QuestLog.FINAL_ENTRIES[QuestLog.final_entry].entry
		_line("\"%s\"" % entry if entry != "" else "Left blank.", DIM if entry == "" else Color.WHITE)

	_heading("Quests")
	var objectives := QuestLog.objectives()
	if objectives.is_empty():
		_line("No open quests. Talk to people around the valley.", DIM)
	for text in objectives:
		_line("- " + text)

	_register()

	_guidebook()

	_perks()

	_heading("Climbing gear")
	var any_gear := false
	for item: GearData in Gear.GEAR:
		var n := Gear.count(item.id)
		if n > 0:
			_gear_line(item, n)
			any_gear = true
	if not any_gear:
		_line("None yet.", DIM)

	_heading("Food in your pack (%d energy)" % FoodDB.carried_energy())
	var foods := FoodDB.edible_in_inventory()
	if foods.is_empty():
		_line("Nothing ready to eat. Forage, or cook at a campfire.", DIM)
	for id in foods:
		var item := ItemDB.get_item(id)
		var name := item.display_name if item else id
		var days := Larder.days_left(id)
		var keeps := "keeps %d day%s" % [days, "" if days == 1 else "s"] if days > 0 else "keeps"
		_line("- %s x%d: %d energy each, %s" % [name, Inventory.count(id), FoodDB.energy(id), keeps])

	if Granary.chuckahs_built > 0:
		_heading("Chuckah")
		_line("%d of %d acorns stored. They won't spoil." % [Granary.acorns, Granary.capacity])

	_refresh_footer()


## The controls hint in the current device's buttons.
func _refresh_footer() -> void:
	var tree := get_tree()
	_footer.text = "[%s] Scroll   [%s] Close" % [MenuInput.button(tree, "Up/Down", "Stick"),
		MenuInput.button(tree, "J/Esc", "Y/B")]


## "More v" while there's more page below, "^ Top" at the end of a long page.
func _refresh_more() -> void:
	var bar := _scroll.get_v_scroll_bar()
	var hidden_below := bar.max_value - bar.page - _scroll.scroll_vertical
	if hidden_below > 1.0:
		_more.text = "More below  v"
	elif _scroll.scroll_vertical > 0:
		_more.text = "^  More above"
	else:
		_more.text = ""


## The Register's pages: the stories you've heard, front pages first, with
## later hands in the margins. Your own last page shows under Main story.
func _register() -> void:
	var pages := RegisterPages.written()
	if pages.is_empty():
		return
	_heading("The Register: %d page%s" % [pages.size(), "" if pages.size() == 1 else "s"])
	for page: Dictionary in pages:
		_line("%s: %s" % [page.by, page.text])
		for note: String in page.notes:
			_line("     " + note, DIM)
		if page.review:
			_line("     (Placeholder pending tribal review.)", DIM)


## The guidebook's tick list: every route, its grade, the gear it needs, and
## whether you've topped it out. A * marks the routes the main story needs.
func _guidebook() -> void:
	if not QuestLog.has_guidebook():
		_heading("Guidebook")
		_line("You don't have one yet. The Mountain Shop in Curry Village sells them.", DIM)
		return
	_heading("Guidebook: tick list (%d of %d)" % [Guidebook.ticked_count(), Guidebook.routes().size()])
	var hardest := Guidebook.hardest_tick()
	_line("Hardest grade: %s (%s). The Nose, climbed free, is 5.13." % [Guidebook.yds_label(hardest.grade), hardest.display_name] if hardest
		else "Grades run from 5.5 (a ladder with good holds) to 5.13 (the Nose, climbed free).", DIM)
	var chapter := ""
	for entry in Guidebook.entries():
		var route: RouteData = entry.route
		if route.guide_chapter != chapter:
			chapter = route.guide_chapter
			_line(chapter.to_upper(), DIM)
		var box := "[x]" if entry.ticked else "[ ]"
		var star := " *" if entry.main else ""
		_line("%s %s%s  %s" % [box, route.display_name, star, route.grade], Color(0.7, 1.0, 0.7) if entry.ticked else Color.WHITE)
		if not entry.ticked:
			var need: String = Guidebook.gear_text(route)
			if entry.ready:
				_line("     Needs %s. You're ready." % need, DIM)
			else:
				_line("     Needs %s. Still missing: %s." % [need, ", ".join(entry.missing)], DIM)


## Perks: what people and experience have taught you. Earned ones show their
## effect and a line of history; the rest show how to earn them.
func _perks() -> void:
	_heading("Perks: what the valley taught you (%d of %d)" % [Perks.earned.size(), Perks.PERKS.size()])
	for perk: Dictionary in Perks.PERKS:
		if Perks.has(perk.id):
			_line("%s: %s" % [perk.name, perk.effect], Color(0.7, 1.0, 0.7))
			_line("     " + perk.flavor + (" (Placeholder pending tribal review.)" if perk.get("review", false) else ""), DIM)
		else:
			var p := Perks.progress(perk)
			var count := " (%d of %d)" % [p[0], p[1]] if p[1] > 1 else ""
			_line("[ ] %s: %s%s" % [perk.name, perk.how, count], DIM)


func _gear_line(item: GearData, count: int) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	if item.icon:
		var icon := TextureRect.new()
		icon.texture = item.icon
		icon.custom_minimum_size = Vector2(32, 32)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		row.add_child(icon)
	var label := Label.new()
	label.text = item.display_name if count == 1 else ItemDB.count_name(count, item.display_name)
	label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(label)
	_body.add_child(row)


## A section heading: a gap above (but not at the top of the page), the
## title in gold, and a thin rule under it.
func _heading(text: String) -> void:
	if _body.get_child_count() > 0:
		var gap := Control.new()
		gap.custom_minimum_size.y = 5
		_body.add_child(gap)
	var label := Label.new()
	label.text = text
	label.add_theme_color_override("font_color", HEADING)
	_body.add_child(label)
	var rule := ColorRect.new()
	rule.color = RULE
	rule.custom_minimum_size = Vector2(384, 1)
	rule.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_body.add_child(rule)
	var under := Control.new()
	under.custom_minimum_size.y = 2
	_body.add_child(under)


func _line(text: String, color := Color.WHITE) -> void:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(384, 0)
	label.add_theme_color_override("font_color", color)
	_body.add_child(label)


func _player() -> Player:
	var world := get_tree().get_first_node_in_group("world")
	return world.player if world else null


func _player_can_act() -> bool:
	var player := _player()
	return player == null or player.can_act


func _set_player_can_act(value: bool) -> void:
	var player := _player()
	if player:
		player.can_act = value
