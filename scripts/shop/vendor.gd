class_name Vendor
extends StaticBody2D
## Someone who trades gear or supplies for goods: food, forage, fish, store
## goods, cans of King Cobra (Barter, TradeValues). Interact to see what they
## have. What they offer comes from their ShopData.

@export var shop: ShopData
## Placeholder clothing color until real sprites exist.
@export var color := Color(0.55, 0.35, 0.25)
## A character sheet (see tools/npcgen, CharacterSheet). When set, the
## vendor is drawn from it, facing [member facing] (0 down, 1 up, 2 left,
## 3 right).
@export var sprite_sheet: Texture2D
@export_range(0, 3) var facing := 0


var _marker: QuestMarker
## While trading: their lines show emotes over their head (on_line).
var _talking := false
var _last_emote := ""
## Their mouth moves until then (seconds, on Time's clock).
var _speaking_until := 0.0


func _ready() -> void:
	queue_redraw()
	add_to_group("talkers")
	if shop and shop.talk_target != "":
		_marker = QuestMarker.new(shop.talk_target)
		add_child(_marker)


func _process(_delta: float) -> void:
	if sprite_sheet:
		queue_redraw()


func _draw() -> void:
	GroundShadow.draw_under(self)
	if sprite_sheet:
		# Blinking, and talking while their lines are up, so the shopkeeper
		# isn't a statue.
		var col: int = CharacterSheet.Col.STAND
		var now := Time.get_ticks_msec() / 1000.0
		if now < _speaking_until:
			col = CharacterSheet.Col.TALK if int(now * 7.0) % 2 == 0 else CharacterSheet.Col.STAND
		elif CharacterSheet.blinking(now, hash(name)):
			col = CharacterSheet.Col.BLINK
		draw_texture_rect_region(sprite_sheet, Rect2(-16, -48, 32, 48), CharacterSheet.region(sprite_sheet, CharacterSheet.FACINGS[facing], col))
		return
	draw_rect(Rect2(-8, -28, 16, 22), color)
	draw_circle(Vector2(0, -34), 7.0, Color(0.8, 0.62, 0.48))
	draw_rect(Rect2(-10, -42, 20, 4), color.darkened(0.3))
	draw_rect(Rect2(-8, -6, 6, 6), Color(0.25, 0.22, 0.28))
	draw_rect(Rect2(2, -6, 6, 6), Color(0.25, 0.22, 0.28))


## A line was shown (DialogueBox.say): if it's the keeper's, the feeling of
## it pops up over their head, as people's do (NPC.on_line).
func on_line(speaker: String, text: String, mood: String) -> void:
	if not _talking or shop == null or speaker != shop.keeper:
		return
	_speaking_until = Time.get_ticks_msec() / 1000.0 + clampf(text.length() * 0.04, 0.6, 2.6)
	var kind := Emote.for_line(text, mood)
	if kind != "" and kind != _last_emote:
		Emote.pop(self, kind)
		_last_emote = kind


func get_prompt() -> String:
	return "Trade with %s" % shop.keeper if shop else "Trade"


## Offers the player can take right now.
func available_offers() -> Array[ShopOffer]:
	return offers_open(shop)


## Trades for [param offer]. Returns what the player paid, or {} if they couldn't.
func buy(offer: ShopOffer) -> Dictionary:
	var paid := trade_for(offer, shop)
	if not paid.is_empty():
		GearSale.note_trade(shop, offer)
	return paid


## The offers in [param data] the player can take right now: they own what
## each one requires, and don't have as many as it allows already.
static func offers_open(data: ShopData) -> Array[ShopOffer]:
	var result: Array[ShopOffer] = []
	for offer in data.offers:
		if offer.requires_quest != "" and not QuestLog.is_completed(offer.requires_quest):
			continue
		if not Gear.has_all(offer.requires):
			continue
		if offer.max_owned > 0 and _owned(offer) >= offer.max_owned:
			continue
		if GearSale.taken_today(data, offer):
			continue
		result.append(offer)
	return result


## True if the player can pay for [param offer] (sold from [param data]):
## goods worth enough to them, or the items it swaps for.
static func can_pay(offer: ShopOffer, data: ShopData = null) -> bool:
	if offer.trade.is_empty():
		return Barter.can_afford(offer.price, data)
	for id: String in offer.trade:
		if Inventory.count(id) < int(offer.trade[id]):
			return false
	return true


## Trades for [param offer] with the keeper selling from [param data]:
## takes its price in goods (Barter.pay), or the items it swaps for, and
## hands it over. Returns what the player paid (item id -> count), or {} if
## they couldn't.
static func trade_for(offer: ShopOffer, data: ShopData = null) -> Dictionary:
	var paid := {}
	if offer.trade.is_empty():
		paid = Barter.pay(offer.price, data)
	elif can_pay(offer):
		for id: String in offer.trade:
			Inventory.remove(id, int(offer.trade[id]))
		paid = offer.trade.duplicate()
	if paid.is_empty():
		return {}
	if offer.kind == "gear":
		Gear.add(offer.id, offer.amount)
	else:
		Inventory.add(offer.id, offer.amount)
	return paid


## The picture of what [param offer] gets you.
static func icon_of(offer: ShopOffer) -> Texture2D:
	if offer.kind == "gear" and offer.id == "cam":
		return Gear.get_gear(Gear.next_cam()).icon # the next size on your rack
	if offer.kind == "gear" and Gear.get_gear(offer.id):
		return Gear.get_gear(offer.id).icon
	var item := ItemDB.get_item(offer.id)
	return item.icon if item else null


static func name_of(offer: ShopOffer) -> String:
	var name := offer.id
	if offer.kind == "gear" and Gear.get_gear(offer.id):
		name = Gear.get_gear(offer.id).display_name
	elif ItemDB.get_item(offer.id):
		name = ItemDB.get_item(offer.id).display_name
	return name if offer.amount == 1 else ItemDB.count_name(offer.amount, name)


## What [param offer] costs, for the list: "costs 30", or "for 2 Brown Trout".
## (Prices are in trade value: 1 = what 1 energy of food is worth.)
static func cost_of(offer: ShopOffer) -> String:
	if offer.trade.is_empty():
		return "costs %d" % offer.price
	return "for " + Barter.describe(offer.trade)


## The card beside the list for [param offer]: what it costs against what
## your pack is worth to this keeper, what they'd take for it (so nothing
## you meant to keep goes by surprise), and how many you have already.
static func card_of(offer: ShopOffer, data: ShopData = null) -> Dictionary:
	var thing: Resource = Gear.get_gear(offer.id) if offer.kind == "gear" else ItemDB.get_item(offer.id)
	var rows := []
	if offer.trade.is_empty():
		var plan := Barter.plan(offer.price, data)
		rows.append([null, "Costs %d of the %d your pack is worth here" % [offer.price, Barter.purse(data)], plan.is_empty()])
		if not plan.is_empty():
			var taking := Barter.describe(plan.taken) if not plan.taken.is_empty() else ""
			if int(plan.tab) > 0:
				taking = ("%s, and %d off your tab" % [taking, int(plan.tab)]) if taking != "" else "%d off your tab" % int(plan.tab)
			rows.append([null, "They'd take " + taking, false])
			if int(plan.change) > 0:
				rows.append([null, "%d left over goes on your tab" % int(plan.change), false])
	else:
		for id: String in offer.trade:
			var item := ItemDB.get_item(id)
			rows.append([item.icon if item else null, "Swap %s (you have %d)" % [ItemDB.count_name(int(offer.trade[id]), item.display_name if item else id), Inventory.count(id)],
				Inventory.count(id) < int(offer.trade[id])])
	var facts := "You have %d" % _owned(offer)
	if offer.once_a_day:
		facts += " · one swap a day"
	return {"title": name_of(offer), "rows": rows, "facts": facts,
		"note": thing.description if thing else ""}


## The trading part of a conversation with [param keeper] (who sells from
## [param data]): the list of what's on offer, round and round until the
## player is done. With [param quiet], a keeper with nothing to offer yet
## just says nothing (Greg, before you have a rod).
static func trade_menu(box: DialogueBox, data: ShopData, keeper: String, quiet := false) -> void:
	while true:
		var offers := offers_open(data)
		var extras := _extras(data)
		if offers.is_empty() and extras.is_empty():
			if not quiet:
				await box.say([{"speaker": keeper, "text": data.nothing_yet}])
			break
		var options := []
		var icons := []
		var details := []
		for offer in offers:
			icons.append(icon_of(offer))
			# the card beside the list says the rest (and shows a price you
			# can't meet in red)
			options.append("%s · %s" % [name_of(offer), cost_of(offer)])
			details.append(card_of(offer, data))
		for extra: Dictionary in extras:
			options.append(extra.label)
			icons.append(extra.icon)
			details.append(extra.card)
		options.append("Done")
		icons.append(null)
		details.append(null)
		var prompt := purse_line(data)
		var choice := await box.choose(prompt, options, keeper, icons, details)
		if choice >= offers.size() and choice < offers.size() + extras.size():
			match extras[choice - offers.size()].kind:
				"sell":
					await sell_menu(box, data, keeper)
				"toast":
					await _toast(box, keeper)
			continue
		if choice < 0 or choice >= offers.size():
			break
		var offer := offers[choice]
		var paid := trade_for(offer, data)
		if not paid.is_empty():
			GearSale.note_trade(data, offer)
		if paid.is_empty():
			var short := "That's more than your pack's worth to me. Come back with more to trade." if offer.trade.is_empty() \
				else "Bring me %s and it's yours." % Barter.describe(offer.trade)
			await box.say([{"speaker": keeper, "text": short}])
		else:
			var lines: Array[Dictionary] = [{"speaker": keeper, "text": "Deal. You hand over %s and get %s." % [Barter.describe(paid), name_of(offer)]}]
			var full := full_up_line(data, paid)
			if full != "":
				lines.append({"speaker": keeper, "text": full})
			await box.say(lines)


## "Your pack is worth 86 in trade here (and 12 on your tab). What do you want?"
static func purse_line(data: ShopData) -> String:
	var key := Market.key_of(data)
	var tab := Market.tab(key)
	var worth := Barter.purse(data) - tab
	var on_tab := " (and %d on your tab)" % tab if tab > 0 else ""
	return "Your pack is worth %d in trade here%s. What do you want?" % [worth, on_tab]


## What a keeper says when they've had their fill of something you just
## paid with ("I'm about full up on greens"), so a low price isn't a mystery.
const FULL_UP_LINES := {
	"fresh": "That's me full up on fresh greens and berries for a few days. I'll give you more for something that keeps.",
	"wild": "I've got nuts and roots coming out my ears. Give it a few days.",
	"fish": "No more fish for a bit, please. The whole place smells like the river.",
	"cooked": "That's plenty of campfire cooking for now. Ask me again in a couple of days.",
	"store": "I've had my fill of store food this week.",
	"curio": "My shelf's full of old junk already. Bring me more in a few days.",
	"cobra": "Okay, okay, that's enough King Cobra for one day. Ask me tomorrow, I'll be thirsty again.",
}


static func full_up_line(data: ShopData, paid: Dictionary) -> String:
	var full := Market.full_up(Market.key_of(data))
	for id: String in paid:
		var sort := TradeValues.sort_of(id)
		if sort in full and FULL_UP_LINES.has(sort):
			return FULL_UP_LINES[sort]
	return ""


## The rows under the offers: selling your spare gear, and a can to share
## over a new route. Each is {kind, label, icon, card}.
static func _extras(data: ShopData) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if not GearSale.sellable(data).is_empty():
		var want := GearSale.wanted(data)
		var note := "They'll pay in food that keeps. You always keep what your hardest route needs."
		if want != "" and GearSale.spare(want) > 0:
			note = "They're after a %s this week and will pay full value for one. " % Gear.get_gear(want).display_name + note
		result.append({"kind": "sell", "label": "Sell some spare gear", "icon": null,
			"card": {"title": "Sell spare gear", "rows": [], "facts": "", "note": note}})
	var route := GearSale.toast_route()
	if data.toasts and route != null and Inventory.count(GearSale.CAN) > 0:
		var can := ItemDB.get_item(GearSale.CAN)
		result.append({"kind": "toast", "label": "Share a King Cobra · %s" % route.display_name, "icon": can.icon if can else null,
			"card": {"title": "Share a King Cobra", "rows": [[can.icon if can else null, "Give 1 King Cobra (you have %d)" % Inventory.count(GearSale.CAN), false]],
				"facts": "You topped out %s" % route.display_name,
				"note": "Climbers tell the story of a send over a cold can. They might pass you something off their rack."}})
	return result


## Picking which spare piece to sell to [param keeper], until done.
static func sell_menu(box: DialogueBox, data: ShopData, keeper: String) -> void:
	var cursor := 0
	while true:
		var spares := GearSale.sellable(data)
		if spares.is_empty():
			await box.say([{"speaker": keeper, "text": "That's all you can spare. Keep the rest, you'll need it up there."}])
			return
		var ids: Array = spares.keys()
		var options := []
		var icons := []
		var details := []
		var want := GearSale.wanted(data)
		for id: String in ids:
			var gear := Gear.get_gear(id)
			var paid := GearSale.payment(GearSale.price(data, id), data.pays_with)
			options.append("%s · worth %d" % [gear.display_name, GearSale.price(data, id)])
			icons.append(gear.icon)
			var facts := "You have %d, %d spare" % [Gear.count(id), spares[id]]
			details.append({"title": gear.display_name + (" · wanted" if id == want else ""),
				"rows": [[null, "They give %s" % Barter.describe(paid), false]],
				"facts": facts, "note": gear.description})
		options.append("Done")
		icons.append(null)
		details.append(null)
		var prompt := "What can you spare?"
		if want != "":
			var wanted_gear := Gear.get_gear(want)
			prompt = "I'm after a %s this week. Full value for one. What can you spare?" % (wanted_gear.display_name if wanted_gear else want)
		var choice := await box.choose(prompt, options, keeper, icons, details, cursor)
		if choice < 0 or choice >= ids.size():
			return
		cursor = choice
		var got := GearSale.sell(data, ids[choice])
		if not got.is_empty():
			await box.say([{"speaker": keeper, "text": "Deal. Here's %s for your %s." % [Barter.describe(got), Gear.get_gear(ids[choice]).display_name]}])


static func _toast(box: DialogueBox, keeper: String) -> void:
	var route := GearSale.toast_route()
	var gift := GearSale.toast(route)
	if gift.is_empty():
		return
	await box.say([
		{"speaker": "You", "text": "Topped out %s. This one's on me." % route.display_name},
		{"speaker": keeper, "text": "No way. Sit down, tell me the crux. ...Okay, that's a send. Here, take %s off my rack. Pay it forward." % GearSale.gift_name(gift)},
	])


## Shopkeepers with a name in the story keep friendship hearts too.
func can_receive_gift() -> bool:
	return shop != null and shop.talk_target != "" and GiftGiving.possible(shop.talk_target)


func receive_gift(player: Player) -> void:
	if shop and shop.talk_target != "":
		await GiftGiving.offer(player, shop.talk_target, shop.keeper, self)


func interact(player: Player) -> void:
	if shop == null:
		return
	if shop.talk_target != "":
		Friendship.note_talk(shop.talk_target)
	player.can_act = false
	_talking = true
	_last_emote = ""
	if _marker:
		_marker.hidden_while_talking = true
		_marker.refresh()
	var box := DialogueBox.open(player)
	# everyday talk (SmallTalk) stands in for the greeting
	var chatted := false
	if shop.talk_target != "":
		var story := Festivals.talk_to(shop.talk_target)
		story.append_array(BoardRequests.deliver(shop.talk_target))
		var region := _region_id()
		story.append_array(QuestLog.talk_to(shop.talk_target, shop.keeper, PackedStringArray([region]) if region != "" else PackedStringArray()))
		chatted = story.any(func(line: Dictionary) -> bool: return line.get("everyday", false))
		if story.is_empty() and HeartScenes.ready_for(shop.talk_target) > 0:
			await HeartScenes.play(box, shop.talk_target, shop.keeper, self)
			chatted = true
		elif not story.is_empty():
			await box.say(story)
	if shop.greeting != "" and not chatted:
		await box.say([{"speaker": shop.keeper, "text": shop.greeting}])
	await trade_menu(box, shop, shop.keeper)
	box.close()
	player.can_act = true
	_talking = false
	if _marker:
		_marker.hidden_while_talking = false
		_marker.refresh()


## The region they keep shop in, for small talk ("" if none).
func _region_id() -> String:
	var node := get_parent()
	while node and not node is Region:
		node = node.get_parent()
	return (node as Region).region_id if node else ""


static func _owned(offer: ShopOffer) -> int:
	return Gear.count(offer.id) if offer.kind == "gear" else Inventory.count(offer.id)
