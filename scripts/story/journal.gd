class_name Journal
extends CanvasLayer
## The player's book, in four tabs:
##   Journal: the Guardian's Register, the guidebook's tick list, and perks
##   Quests: the main story's next step and every open quest
##   Press Book: the plants you've pressed, and where the rest grow
##   Backpack: everything you carry (climbing gear, food, forage) in slots
## J, Q, P and B open it on their tab (gamepad Y opens the Journal), Tab (LB/RB)
## turns to the next tab, and the tab's own key or Esc (B) closes it.
##
## World adds one of these. It pauses the clock while it's open.

enum Tab { JOURNAL, QUESTS, PRESS, BACKPACK }

const TAB_NAMES := ["Journal", "Quests", "Press Book", "Backpack"]
## The action that opens each tab, and the key it's on.
const TAB_ACTIONS := ["journal", "quests", "press_book", "backpack"]
const TAB_KEYS := ["J", "Q", "P", "B"]
## A plant that isn't in the press book yet shows as a shadow of itself.
const UNFOUND := Color(0.165, 0.106, 0.078, 0.4)
const HEADING := Color(1, 0.831, 0.541)
const DIM := Color(0.961, 0.933, 0.878, 0.6)
## The thin line under each section heading.
const RULE := Color(0.945, 0.812, 0.416, 0.45)
const PANEL_POS := Vector2(30, 16)
const PANEL_SIZE := Vector2(420, 238)
## How wide a line of text on the page is, leaving room for the scroll bar.
const LINE_WIDTH := 396
## Pixels one Up/Down press scrolls, and how long a held key waits before it
## repeats, then how often it repeats.
const SCROLL_STEP := 24
const REPEAT_DELAY := 0.35
const REPEAT_EVERY := 0.06
## A backpack slot: the icon's size on screen, and the slot's wood and its
## brighter look under the cursor (the same colors as the climbing toolbar).
const ICON_SIZE := Vector2(32, 32)
const SLOT_FILL := Color("b0925f")
const SLOT_EDGE := Color("47301f")
const SLOT_FILL_CHOSEN := Color("d6bd88")
const SLOT_EDGE_CHOSEN := Color("f5eee0")
## Lines of description the Backpack shows under the slots.
const DETAIL_LINES := 2

var _panel: PanelContainer
var _tab := Tab.JOURNAL
var _tab_labels: Array[Label] = []
var _scroll: ScrollContainer
var _fade_below: TextureRect
var _fade_above: TextureRect
var _body: VBoxContainer
## The slots of the Backpack or the Press Book in reading order, what each
## one holds ({"name", "count", "facts", "description"}), and the one under
## the cursor.
var _slots: Array[PanelContainer] = []
var _slot_items: Array[Dictionary] = []
var _cursor := 0
## Name and description of the slot under the cursor, under the page.
var _detail: VBoxContainer
var _detail_name: Label
var _detail_text: Label
## Controls hint and "more above/below" marks, under the page so they never scroll away.
var _footer: Label
var _more: Label
var _repeat := 0.0
var _tab_style: StyleBoxTexture
var _plain_style: StyleBoxEmpty
var _slot_style: StyleBoxFlat
var _slot_chosen_style: StyleBoxFlat


func _ready() -> void:
	layer = 25
	UiScale.layer(self)
	add_to_group("journal")
	_build_styles()
	_panel = PanelContainer.new()
	_panel.position = PANEL_POS
	_panel.custom_minimum_size = PANEL_SIZE
	_panel.size = PANEL_SIZE
	_panel.visible = false
	add_child(_panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 2)
	_panel.add_child(column)
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 4)
	column.add_child(tabs)
	for i in TAB_NAMES.size():
		var label := Label.new()
		label.mouse_filter = Control.MOUSE_FILTER_STOP
		label.gui_input.connect(_on_tab_input.bind(i))
		tabs.add_child(label)
		_tab_labels.append(label)
	_scroll = ScrollContainer.new()
	_scroll.custom_minimum_size.x = LINE_WIDTH + 8
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	# The page sits in a holder with a soft fade at whichever edge has more
	# to scroll to, so a line is never sliced off hard at the edge.
	var holder := Control.new()
	holder.custom_minimum_size.x = LINE_WIDTH + 8
	holder.size_flags_vertical = Control.SIZE_EXPAND_FILL
	holder.clip_contents = true
	column.add_child(holder)
	_scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	holder.add_child(_scroll)
	_fade_below = _edge_fade(holder, false)
	_fade_above = _edge_fade(holder, true)
	_detail = VBoxContainer.new()
	_detail.add_theme_constant_override("separation", 0)
	column.add_child(_detail)
	_detail.add_child(_rule())
	_detail_name = Label.new()
	_detail_name.add_theme_color_override("font_color", HEADING)
	_detail.add_child(_detail_name)
	_detail_text = Label.new()
	_detail_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail_text.custom_minimum_size.x = LINE_WIDTH
	_detail_text.max_lines_visible = DETAIL_LINES
	_detail_text.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_detail.add_child(_detail_text)
	# Always room for a full description, so the page doesn't jump as the cursor moves.
	_detail_text.custom_minimum_size.y = DETAIL_LINES * (_detail_text.get_line_height() + _detail_text.get_theme_constant("line_spacing"))
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


func _build_styles() -> void:
	# The open tab sits on a brass tag, like the pause menu's title.
	_tab_style = StyleBoxTexture.new()
	_tab_style.texture = load("res://assets/ui/tag.png")
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		_tab_style.set_texture_margin(side, 4.0)
	_tab_style.content_margin_left = 6.0
	_tab_style.content_margin_right = 6.0
	_plain_style = StyleBoxEmpty.new()
	_plain_style.content_margin_left = 6.0
	_plain_style.content_margin_right = 6.0
	_slot_style = StyleBoxFlat.new()
	_slot_style.bg_color = SLOT_FILL
	_slot_style.border_color = SLOT_EDGE
	_slot_style.set_border_width_all(1)
	_slot_style.set_content_margin_all(2.0)
	_slot_style.anti_aliasing = false
	_slot_chosen_style = _slot_style.duplicate()
	_slot_chosen_style.bg_color = SLOT_FILL_CHOSEN
	_slot_chosen_style.border_color = SLOT_EDGE_CHOSEN
	_slot_chosen_style.set_border_width_all(2)
	_slot_chosen_style.set_content_margin_all(2.0)


func is_open() -> bool:
	return _panel.visible


## The tab showing now (Tab.JOURNAL, QUESTS, PRESS or BACKPACK).
func tab() -> Tab:
	return _tab


func open(which := Tab.JOURNAL) -> void:
	if is_open():
		show_tab(which)
		return
	var hud := get_tree().get_first_node_in_group("hud") as HUD
	if hud and not hud.device_changed.is_connected(_refresh_hints):
		hud.device_changed.connect(_refresh_hints)
	_panel.visible = true
	show_tab(which)
	GameClock.paused = true
	MenuInput.pop_in(_panel)
	_set_player_can_act(false)


func close() -> void:
	if not is_open():
		return
	_panel.visible = false
	Sound.play("ui_close")
	GameClock.paused = false
	_set_player_can_act(true)


## Turns to tab [param which], at the top of its page.
func show_tab(which: Tab) -> void:
	_tab = which
	_cursor = 0
	_refresh()
	_scroll.scroll_vertical = 0
	_repeat = REPEAT_DELAY


func _unhandled_input(event: InputEvent) -> void:
	var asked := _tab_asked(event)
	if not is_open():
		if asked >= 0 and _player_can_act():
			open(asked as Tab)
			get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("ui_cancel") or asked == _tab:
		close()
		get_viewport().set_input_as_handled()
		return
	var turn := _tab_turn(event)
	if asked >= 0 or turn != 0:
		show_tab((asked if asked >= 0 else wrapi(_tab + turn, 0, Tab.size())) as Tab)
		Sound.play("ui_move")
		get_viewport().set_input_as_handled()
	elif _uses_slots():
		var step := Vector2i(MenuInput.horizontal(event), MenuInput.vertical(event))
		if step != Vector2i.ZERO:
			move_cursor(step)
			get_viewport().set_input_as_handled()
	else:
		# Up/Down (or the stick) scroll the page; holding repeats in _process.
		var step := MenuInput.vertical(event)
		if step != 0:
			scroll_by(step * SCROLL_STEP)
			_repeat = REPEAT_DELAY
			get_viewport().set_input_as_handled()
		elif event.is_action_pressed("ui_page_down", true) or event.is_action_pressed("ui_page_up", true):
			scroll_by((1 if event.is_action_pressed("ui_page_down", true) else -1) * (int(_scroll.size.y) - SCROLL_STEP))
			get_viewport().set_input_as_handled()


## The tab whose key [param event] presses (J, Q or B), or -1.
func _tab_asked(event: InputEvent) -> int:
	for i in TAB_ACTIONS.size():
		if event.is_action_pressed(TAB_ACTIONS[i]):
			return i
	return -1


## +1 for Tab or RB, -1 for Shift+Tab or LB, 0 for anything else. The mouse
## wheel is on the tab actions too (it flips the map's tabs), but here it scrolls.
func _tab_turn(event: InputEvent) -> int:
	if event.is_action_pressed("ui_focus_prev") or (event is InputEventJoypadButton and event.is_action_pressed("tab_previous")):
		return -1
	if event.is_action_pressed("ui_focus_next") or (event is InputEventJoypadButton and event.is_action_pressed("tab_next")):
		return 1
	return 0


func _on_tab_input(event: InputEvent, which: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and which != _tab:
		show_tab(which as Tab)


func _process(delta: float) -> void:
	if not is_open():
		return
	_refresh_more()
	if _uses_slots():
		return
	var held := int(Input.is_action_pressed("move_down") or Input.is_action_pressed("ui_down")) \
			- int(Input.is_action_pressed("move_up") or Input.is_action_pressed("ui_up"))
	if held == 0:
		_repeat = REPEAT_DELAY
		return
	_repeat -= delta
	if _repeat <= 0.0:
		_repeat = REPEAT_EVERY
		scroll_by(held * SCROLL_STEP)


## Scrolls the page by [param pixels] (negative is up).
func scroll_by(pixels: int) -> void:
	_scroll.scroll_vertical = maxi(0, _scroll.scroll_vertical + pixels)


func _refresh() -> void:
	for child in _body.get_children():
		_body.remove_child(child)
		child.queue_free()
	_slots.clear()
	_slot_items.clear()
	match _tab:
		Tab.JOURNAL:
			_journal_page()
		Tab.QUESTS:
			_quests_page()
		Tab.PRESS:
			_press_page()
		Tab.BACKPACK:
			_backpack_page()
	_detail.visible = _uses_slots()
	_refresh_cursor()
	_refresh_hints()


## True on the tabs laid out as slots with a cursor (the Backpack and the
## Press Book); the others are pages that scroll.
func _uses_slots() -> bool:
	return _tab == Tab.BACKPACK or _tab == Tab.PRESS


## The tab names and the controls hint, in the current device's buttons.
func _refresh_hints() -> void:
	var tree := get_tree()
	var gamepad := MenuInput.button(tree, "k", "g") == "g"
	for i in _tab_labels.size():
		var label := _tab_labels[i]
		label.text = TAB_NAMES[i] if gamepad else "%s  %s" % [TAB_KEYS[i], TAB_NAMES[i]]
		label.add_theme_color_override("font_color", HEADING if i == _tab else DIM)
		label.add_theme_stylebox_override("normal", _tab_style if i == _tab else _plain_style)
	var move := "[%s] Choose" % MenuInput.button(tree, "Arrows", "Stick") if _uses_slots() \
			else "[%s] Scroll" % MenuInput.button(tree, "Up/Down", "Stick")
	var close_key := "Y/B" if _tab == Tab.JOURNAL else "B"
	_footer.text = "%s   [%s] Next tab   [%s] Close" % [move, MenuInput.button(tree, "Tab", "LB/RB"),
		MenuInput.button(tree, "%s/Esc" % TAB_KEYS[_tab], close_key)]


## "More below" with a down arrow while there's more page below, "More above" with an up arrow at the end of a long page.
func _refresh_more() -> void:
	var bar := _scroll.get_v_scroll_bar()
	var hidden_below := bar.max_value - bar.page - _scroll.scroll_vertical
	_fade_below.visible = hidden_below > 1.0
	_fade_above.visible = _scroll.scroll_vertical > 0
	if hidden_below > 1.0:
		_more.text = "More below   "
		MenuInput.badge(_more, load("res://assets/ui/next.png"), true)
	elif _scroll.scroll_vertical > 0:
		_more.text = "More above   "
		MenuInput.badge(_more, load("res://assets/ui/next.png"), true, true)
	else:
		_more.text = ""
		MenuInput.badge(_more, null, true)


# ---------------------------------------------------------------- the Journal tab

func _journal_page() -> void:
	_register()
	_friends()
	if QuestLog.final_entry >= 0:
		_heading("The last page")
		var entry: String = QuestLog.FINAL_ENTRIES[QuestLog.final_entry].entry
		_line("\"%s\"" % entry if entry != "" else "Left blank.", DIM if entry == "" else Color.WHITE)
	_guidebook()
	_perks()


## The Register's pages: the stories you've heard, front pages first, with
## later hands in the margins.
func _register() -> void:
	var pages := RegisterPages.written()
	if pages.is_empty():
		_heading("The Guardian's Register")
		_line("No pages yet. When you finish someone's story, they write one here.", DIM)
		return
	_heading("The Guardian's Register: %d page%s" % [pages.size(), "" if pages.size() == 1 else "s"])
	for page: Dictionary in pages:
		_line("%s · %s" % [page.by, page.text])
		for note: String in page.notes:
			_line("     " + note, DIM)
		if page.review:
			_line("     (Placeholder pending tribal review.)", DIM)


## Everyone you've got to know, with their hearts (Friendship).
func _friends() -> void:
	var known: Array[CharacterData] = []
	for character: CharacterData in QuestLog.CHARACTERS + QuestLog.STAFF:
		if int(Friendship.points.get(character.id, 0)) > 0:
			known.append(character)
	_heading("Friends")
	if known.is_empty():
		_line("Talk with people each day, finish their quests, and bring them a gift now and then (G) to get to know them.", DIM)
		return
	known.sort_custom(func(a: CharacterData, b: CharacterData) -> bool: return Friendship.points[a.id] > Friendship.points[b.id])
	for character in known:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 1)
		var face := _face(character.display_name, 16)
		face.custom_minimum_size.x = 20 # a little room after the face
		row.add_child(face)
		var name_label := Label.new()
		name_label.text = character.display_name
		name_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		name_label.custom_minimum_size.x = 124
		row.add_child(name_label)
		var hearts := Friendship.hearts(character.id)
		for i in Friendship.MAX_HEARTS:
			var heart := TextureRect.new()
			heart.texture = Hearts.texture(i < hearts)
			heart.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
			heart.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			row.add_child(heart)
		if not Friendship.can_gift(character.id):
			var note := Label.new()
			note.text = "   gift given this week"
			note.add_theme_color_override("font_color", DIM)
			row.add_child(note)
		_body.add_child(row)


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
		var star := " *" if entry.main else ""
		_check_line(entry.ticked, "%s%s  %s" % [route.display_name, star, route.grade], Color(0.827, 0.894, 0.541) if entry.ticked else Color.WHITE)
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
			_line("%s: %s" % [perk.name, perk.effect], Color(0.827, 0.894, 0.541))
			_line("     " + perk.flavor + (" (Placeholder pending tribal review.)" if perk.get("review", false) else ""), DIM)
		else:
			var p := Perks.progress(perk)
			var count := " (%d of %d)" % [p[0], p[1]] if p[1] > 1 else ""
			_check_line(false, "%s: %s%s" % [perk.name, perk.how, count], DIM)


# ---------------------------------------------------------------- the Quests tab

func _quests_page() -> void:
	_heading("Main story")
	var main := QuestLog.main_objective()
	if not main.is_empty():
		_quest_card(main.quest, main.objective)
	elif not QuestLog.has_guidebook():
		_line("Pick up a climbing guidebook at the Mountain Shop in Curry Village.")
	elif QuestLog.final_entry_pending():
		_line("The Last Page: talk to Galen Clark and write your entry.")
	elif QuestLog.is_completed(QuestLog.FINALE_QUEST):
		_line("You found the lost Guardian. The valley is still open.", DIM)
	elif QuestLog.final_entry >= 0:
		_line("You've written your last page. It's in the Journal.", DIM)
	else:
		_line("Explore, and talk to people around the valley.", DIM)

	# The press book runs beside the main story, so it gets a card of its own.
	var press := QuestLog.press_objective()
	if not press.is_empty():
		_heading("The press book (%d of %d plants)" % [Herbarium.count(), Herbarium.total()])
		_quest_card(press.quest, press.objective)

	var shown: Array[QuestData] = []
	for card: Dictionary in [main, press]:
		if not card.is_empty():
			shown.append(card.quest)
	var open: Array[QuestData] = []
	for quest: QuestData in QuestLog.QUESTS:
		if QuestLog.active.has(quest.id) and not quest in shown:
			open.append(quest)
	_heading("Open quests (%d)" % open.size())
	if open.is_empty():
		_line("No open quests. Talk to people around the valley.", DIM)
	for quest in open:
		_quest_card(quest, QuestLog.objective_text(quest))

	# Who has something for you, as on a help-wanted board.
	var asking: Array[CharacterData] = []
	for character: CharacterData in QuestLog.CHARACTERS:
		var offer: QuestData = QuestLog.available_from(character.id)
		# the main story's and the press book's next steps are already shown above
		if offer != null and not offer in shown:
			asking.append(character)
	if not asking.is_empty():
		_heading("Looking for help (%d)" % asking.size())
		var flow := HFlowContainer.new()
		flow.add_theme_constant_override("h_separation", 10)
		flow.add_theme_constant_override("v_separation", 4)
		flow.custom_minimum_size.x = LINE_WIDTH
		for character in asking:
			var who := HBoxContainer.new()
			who.add_theme_constant_override("separation", 4)
			who.add_child(_face(character.display_name, 24))
			var name_label := Label.new()
			var home := character.home_now(QuestLog.is_completed)
			name_label.text = character.display_name + ("  · %s" % home if home != "" else "")
			name_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			who.add_child(name_label)
			flow.add_child(who)
		_body.add_child(flow)


## A quest as a card: the face of whoever gave it, its title, and what to do
## next.
func _quest_card(quest: QuestData, objective: String) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	var giver := QuestLog.get_character(quest.giver)
	row.add_child(_face(giver.display_name if giver else "", 32))
	var words := VBoxContainer.new()
	words.add_theme_constant_override("separation", 0)
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var title := Label.new()
	title.text = quest.title + ("  · from %s" % giver.display_name if giver else "")
	title.add_theme_color_override("font_color", Color(1, 0.831, 0.541))
	words.add_child(title)
	var step := Label.new()
	step.text = objective
	step.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	step.custom_minimum_size.x = LINE_WIDTH - 40
	words.add_child(step)
	row.add_child(words)
	_body.add_child(row)


## A small framed portrait of [param speaker] (blank if they have none).
func _face(speaker: String, side: int) -> Control:
	var frame := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color("5e4a38")
	style.border_color = Color("b0925f")
	style.set_border_width_all(1)
	frame.add_theme_stylebox_override("panel", style)
	frame.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var picture := TextureRect.new()
	picture.texture = Portraits.for_speaker(speaker)
	picture.custom_minimum_size = Vector2(side, side)
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	picture.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	frame.add_child(picture)
	return frame


# ---------------------------------------------------------------- the Press Book tab

## The press book: every plant as a slot, grouped by where it grows. A plant
## not yet pressed is a shadow, and says where and when to look for it.
func _press_page() -> void:
	if not Herbarium.has_press():
		_heading("Press book")
		_line("You don't have a plant press yet. Enid Michael keeps the wildflower garden at the Museum in Yosemite Village.", DIM)
		return
	var by_hub := {}
	for plant: Dictionary in Herbarium.PLANTS:
		var hub: String = Herbarium.hubs_of(plant)[0]
		if not by_hub.has(hub):
			by_hub[hub] = []
		by_hub[hub].append(plant)
	for hub: String in by_hub:
		var pages: Array[Dictionary] = []
		var found := 0
		for plant: Dictionary in by_hub[hub]:
			found += int(Herbarium.has(plant.id))
			pages.append(_pressed(plant))
		var place: String = Herbarium.HUB_NAMES.get(hub, hub)
		_slot_section("%s (%d of %d)" % [place[0].to_upper() + place.substr(1), found, pages.size()], pages, "")
	_heading("The lost Guardian")
	var clues := Herbarium.clues()
	if clues.is_empty():
		_line("The old sheets in the press are labeled \"Collected for the Guardian of Yosemite.\" Nobody knows who that was.", DIM)
	for clue in clues:
		_line(clue)


## What a slot shows for [param plant]: its name and drawing, and either its
## natural history and where you found it, or where and when to look.
func _pressed(plant: Dictionary) -> Dictionary:
	if not Herbarium.has(plant.id):
		return {"name": plant.name, "count": 1, "icon": Herbarium.icon(plant.id), "facts": "not yet pressed",
			"description": "Look in: " + Herbarium.hint(plant), "dim": true}
	var entry: Dictionary = Herbarium.pressed[plant.id]
	var found: String = " Found at %s." % entry.where if str(entry.get("where", "")) != "" else ""
	return {"name": plant.name, "count": 1, "icon": Herbarium.icon(plant.id), "facts": plant.latin,
		"description": plant.note + found, "dim": false}


# ---------------------------------------------------------------- the Backpack tab

func _backpack_page() -> void:
	var gear: Array[Dictionary] = []
	for item: GearData in Gear.GEAR:
		var n := Gear.count(item.id)
		if n > 0:
			gear.append({"name": item.display_name, "count": n, "icon": item.icon, "facts": "", "description": item.description})
	_slot_section("Climbing gear", gear, "None yet.")

	var foods := FoodDB.edible_in_inventory()
	var meals: Array[Dictionary] = []
	for id in foods:
		meals.append(_carried(id))
	_slot_section("Food (%d energy)" % FoodDB.carried_energy(), meals, "Nothing ready to eat. Forage, or cook at a campfire.")

	var others := Inventory.items.keys().filter(func(id: String) -> bool: return ItemDB.get_item(id) != null and not foods.has(id))
	others.sort_custom(func(a: String, b: String) -> bool: return ItemDB.get_item(a).display_name < ItemDB.get_item(b).display_name)
	var rest: Array[Dictionary] = []
	for id: String in others:
		rest.append(_carried(id))
	_slot_section("Forage and other things", rest, "Nothing yet.")

	if Granary.chuckahs_built > 0:
		_heading("Chuckah")
		_line("%d of %d acorns stored. They won't spoil." % [Granary.acorns, Granary.capacity])


## What a slot shows for carried item [param id]: its count, what it's worth
## as food, and how long it keeps.
func _carried(id: String) -> Dictionary:
	var item := ItemDB.get_item(id)
	var facts := PackedStringArray()
	if FoodDB.is_edible(id):
		facts.append("%d energy each" % FoodDB.energy(id))
	elif FoodDB.is_food(id):
		facts.append("not ready to eat")
	var days := Larder.days_left(id)
	if days > 0:
		facts.append("keeps %d day%s" % [days, "" if days == 1 else "s"])
	elif FoodDB.is_food(id):
		facts.append("keeps")
	return {"name": item.display_name, "count": Inventory.count(id), "icon": item.icon,
		"facts": ", ".join(facts), "description": item.description}


## A heading and a wrapping row of slots, or [param empty] when there are none.
func _slot_section(title: String, items: Array[Dictionary], empty: String) -> void:
	_heading(title)
	if items.is_empty():
		_line(empty, DIM)
		return
	var flow := HFlowContainer.new()
	flow.custom_minimum_size.x = LINE_WIDTH
	flow.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	flow.add_theme_constant_override("h_separation", 2)
	flow.add_theme_constant_override("v_separation", 2)
	_body.add_child(flow)
	for item in items:
		flow.add_child(_slot(item))


## One framed slot: the icon, and how many in the corner when there's more
## than one. Things with no icon yet (the cooked dishes) show their name.
func _slot(item: Dictionary) -> PanelContainer:
	var slot := PanelContainer.new()
	slot.mouse_filter = Control.MOUSE_FILTER_PASS # the wheel still scrolls the page
	slot.gui_input.connect(_on_slot_input.bind(_slots.size()))
	var icon := TextureRect.new()
	icon.texture = item.icon
	icon.custom_minimum_size = ICON_SIZE
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if item.get("dim", false):
		icon.modulate = UNFOUND
	slot.add_child(icon)
	if item.icon == null:
		var name_label := Label.new()
		name_label.text = "\n".join(item.name.split(" ").slice(0, 3)) # a word a line
		name_label.clip_text = true
		name_label.add_theme_font_size_override("font_size", 7)
		name_label.add_theme_constant_override("line_spacing", -2)
		name_label.add_theme_color_override("font_color", SLOT_EDGE)
		name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(name_label)
	if item.count > 1:
		var count := Label.new()
		count.text = str(item.count)
		count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		count.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
		# small, in the bottom-right corner, ringed in dark: clear of the art
		count.size_flags_horizontal = Control.SIZE_SHRINK_END
		count.size_flags_vertical = Control.SIZE_SHRINK_END
		count.add_theme_font_size_override("font_size", 8)
		count.add_theme_color_override("font_outline_color", Color("2a1b14"))
		count.add_theme_constant_override("outline_size", 4)
		count.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(count)
	_slots.append(slot)
	_slot_items.append(item)
	return slot


func _on_slot_input(event: InputEvent, index: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_cursor = index
		_refresh_cursor()


## Moves the Backpack's cursor one slot left or right, or to the nearest slot
## in the row above or below.
func move_cursor(step: Vector2i) -> void:
	if _slots.is_empty():
		return
	var target := _cursor
	if step.x != 0:
		target = clampi(_cursor + step.x, 0, _slots.size() - 1)
	else:
		var here := _slots[_cursor].get_global_rect().get_center()
		var nearest := INF
		for i in _slots.size():
			var there := _slots[i].get_global_rect().get_center()
			var rows := (there.y - here.y) * step.y
			# The closest row first, then the closest slot along it.
			var distance := rows * 1000.0 + absf(there.x - here.x)
			if rows >= 1.0 and distance < nearest:
				nearest = distance
				target = i
	if target == _cursor:
		if step.y < 0:
			_scroll.scroll_vertical = 0 # back up to the first heading
		elif step.y > 0:
			scroll_by(SCROLL_STEP * 2) # on to whatever is written under the slots
		return
	_cursor = target
	Sound.play("ui_move")
	_refresh_cursor()
	_scroll.ensure_control_visible(_slots[_cursor])


## Marks the slot under the cursor and describes it under the page.
func _refresh_cursor() -> void:
	for i in _slots.size():
		_slots[i].add_theme_stylebox_override("panel", _slot_chosen_style if i == _cursor else _slot_style)
	if _slots.is_empty():
		_detail_name.text = "Your pack is empty." if _tab == Tab.BACKPACK else ""
		_detail_text.text = ""
		return
	var item := _slot_items[_cursor]
	_detail_name.text = item.name if item.count == 1 else "%s x%d" % [item.name, item.count]
	if item.facts != "":
		_detail_name.text += "   (%s)" % item.facts
	_detail_text.text = item.description


# ---------------------------------------------------------------- page pieces

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
	_body.add_child(_rule())
	var under := Control.new()
	under.custom_minimum_size.y = 2
	_body.add_child(under)


func _rule() -> ColorRect:
	var rule := ColorRect.new()
	rule.color = RULE
	rule.custom_minimum_size = Vector2(LINE_WIDTH, 1)
	rule.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	return rule


## A strip that fades the page into the panel at its top or bottom edge.
func _edge_fade(holder: Control, top: bool) -> TextureRect:
	return MenuInput.edge_fade(holder, top, 8.0)


## A line with a drawn checkbox in front of it (ticked or not).
func _check_line(ticked: bool, text: String, color := Color.WHITE) -> void:
	_line("     " + text, color)
	MenuInput.badge(_body.get_child(_body.get_child_count() - 1), MenuInput.checkbox_texture(ticked))


func _line(text: String, color := Color.WHITE) -> void:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(LINE_WIDTH, 0)
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
