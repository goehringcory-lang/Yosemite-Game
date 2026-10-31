class_name Vendor
extends StaticBody2D
## Someone who trades gear or supplies for food. Interact to see what they
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
	return trade_for(offer)


func offer_icon(offer: ShopOffer) -> Texture2D:
	return icon_of(offer)


func offer_name(offer: ShopOffer) -> String:
	return name_of(offer)


func offer_card(offer: ShopOffer) -> Dictionary:
	return card_of(offer)


## The offers in [param data] the player can take right now: they own what
## each one requires, and don't have as many as it allows already.
static func offers_open(data: ShopData) -> Array[ShopOffer]:
	var result: Array[ShopOffer] = []
	for offer in data.offers:
		if not Gear.has_all(offer.requires):
			continue
		if offer.max_owned > 0 and _owned(offer) >= offer.max_owned:
			continue
		result.append(offer)
	return result


## True if the player can pay for [param offer]: food enough, or the items
## it swaps for.
static func can_pay(offer: ShopOffer) -> bool:
	if offer.trade.is_empty():
		return Barter.can_afford(offer.price)
	for id: String in offer.trade:
		if Inventory.count(id) < int(offer.trade[id]):
			return false
	return true


## Trades for [param offer]: takes its price in food, or the items it swaps
## for, and hands it over. Returns what the player paid (item id -> count),
## or {} if they couldn't.
static func trade_for(offer: ShopOffer) -> Dictionary:
	var paid := {}
	if offer.trade.is_empty():
		paid = Barter.pay(offer.price)
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
		return CamSizes.icon(Gear.count("cam")) # the next size on your rack
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
static func cost_of(offer: ShopOffer) -> String:
	if offer.trade.is_empty():
		return "costs %d" % offer.price
	return "for " + Barter.describe(offer.trade)


## The card beside the list for [param offer]: what it is, what it costs
## against the food (or the fish) you carry, and how many you have already.
static func card_of(offer: ShopOffer) -> Dictionary:
	var thing: Resource = Gear.get_gear(offer.id) if offer.kind == "gear" else ItemDB.get_item(offer.id)
	var rows := []
	if offer.trade.is_empty():
		rows.append([null, "Costs %d of your %d energy" % [offer.price, Barter.purse()], not Barter.can_afford(offer.price)])
	else:
		for id: String in offer.trade:
			var item := ItemDB.get_item(id)
			rows.append([item.icon if item else null, "Swap %s (you have %d)" % [ItemDB.count_name(int(offer.trade[id]), item.display_name if item else id), Inventory.count(id)],
				Inventory.count(id) < int(offer.trade[id])])
	return {"title": name_of(offer), "rows": rows, "facts": "You have %d" % _owned(offer),
		"note": thing.description if thing else ""}


## The trading part of a conversation with [param keeper] (who sells from
## [param data]): the list of what's on offer, round and round until the
## player is done. With [param quiet], a keeper with nothing to offer yet
## just says nothing (Greg, before you have a rod).
static func trade_menu(box: DialogueBox, data: ShopData, keeper: String, quiet := false) -> void:
	while true:
		var offers := offers_open(data)
		if offers.is_empty():
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
			details.append(card_of(offer))
		options.append("Done")
		icons.append(null)
		details.append(null)
		var prompt := "You're carrying %d energy of food. What do you want?" % Barter.purse()
		var choice := await box.choose(prompt, options, keeper, icons, details)
		if choice < 0 or choice >= offers.size():
			break
		var offer := offers[choice]
		var paid := trade_for(offer)
		if paid.is_empty():
			var short := "That's more food than you've got. Come back after some foraging." if offer.trade.is_empty() \
				else "Bring me %s and it's yours." % Barter.describe(offer.trade)
			await box.say([{"speaker": keeper, "text": short}])
		else:
			await box.say([{"speaker": keeper, "text": "Deal. You hand over %s and get %s." % [Barter.describe(paid), name_of(offer)]}])


## Shopkeepers with a name in the story keep friendship hearts too.
func can_receive_gift() -> bool:
	return shop != null and shop.talk_target != "" and GiftGiving.possible(shop.talk_target)


func receive_gift(player: Player) -> void:
	if shop and shop.talk_target != "":
		await GiftGiving.offer(player, shop.talk_target, shop.keeper, self)


func interact(player: Player) -> void:
	if shop and shop.talk_target != "":
		Friendship.note_talk(shop.talk_target)
	player.can_act = false
	_talking = true
	_last_emote = ""
	if _marker:
		_marker.hidden_while_talking = true
		_marker.refresh()
	var box := DialogueBox.open(player)
	if shop.talk_target != "":
		var story := Festivals.talk_to(shop.talk_target)
		story.append_array(BoardRequests.deliver(shop.talk_target))
		story.append_array(QuestLog.talk_to(shop.talk_target, shop.keeper))
		if not story.is_empty():
			await box.say(story)
	if shop.greeting != "":
		await box.say([{"speaker": shop.keeper, "text": shop.greeting}])
	await trade_menu(box, shop, shop.keeper)
	box.close()
	player.can_act = true
	_talking = false
	if _marker:
		_marker.hidden_while_talking = false
		_marker.refresh()


static func _owned(offer: ShopOffer) -> int:
	return Gear.count(offer.id) if offer.kind == "gear" else Inventory.count(offer.id)
