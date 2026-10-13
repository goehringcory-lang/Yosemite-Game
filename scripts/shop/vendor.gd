class_name Vendor
extends StaticBody2D
## Someone who trades gear or supplies for food. Interact to see what they
## have. What they offer comes from their ShopData.

@export var shop: ShopData
## Placeholder clothing color until real sprites exist.
@export var color := Color(0.55, 0.35, 0.25)
## A 96x192 character sheet (see tools/npcgen). When set, the vendor is drawn
## from it, facing [member facing] (0 down, 1 up, 2 left, 3 right).
@export var sprite_sheet: Texture2D
@export_range(0, 3) var facing := 0


var _marker: QuestMarker


func _ready() -> void:
	queue_redraw()
	if shop and shop.talk_target != "":
		_marker = QuestMarker.new(shop.talk_target)
		add_child(_marker)


func _process(_delta: float) -> void:
	if sprite_sheet:
		queue_redraw()


func _draw() -> void:
	GroundShadow.draw_under(self)
	if sprite_sheet:
		# A slow breath so the shopkeeper isn't a statue.
		var bob := -2.0 if int(Time.get_ticks_msec() / 700) % 2 == 1 else 0.0
		draw_texture_rect_region(sprite_sheet, Rect2(-16, -48 + bob, 32, 48), Rect2(0, facing * 48, 32, 48))
		return
	draw_rect(Rect2(-8, -28, 16, 22), color)
	draw_circle(Vector2(0, -34), 7.0, Color(0.8, 0.62, 0.48))
	draw_rect(Rect2(-10, -42, 20, 4), color.darkened(0.3))
	draw_rect(Rect2(-8, -6, 6, 6), Color(0.25, 0.22, 0.28))
	draw_rect(Rect2(2, -6, 6, 6), Color(0.25, 0.22, 0.28))


func get_prompt() -> String:
	return "Trade with %s" % shop.keeper if shop else "Trade"


## Offers the player can take right now.
func available_offers() -> Array[ShopOffer]:
	var result: Array[ShopOffer] = []
	for offer in shop.offers:
		if not Gear.has_all(offer.requires):
			continue
		if offer.max_owned > 0 and _owned(offer) >= offer.max_owned:
			continue
		result.append(offer)
	return result


## Trades for [param offer]. Returns what the player paid, or {} if they couldn't.
func buy(offer: ShopOffer) -> Dictionary:
	var paid := Barter.pay(offer.price)
	if paid.is_empty():
		return {}
	if offer.kind == "gear":
		Gear.add(offer.id, offer.amount)
	else:
		Inventory.add(offer.id, offer.amount)
	return paid


## The picture of what [param offer] gets you.
func offer_icon(offer: ShopOffer) -> Texture2D:
	if offer.kind == "gear" and Gear.get_gear(offer.id):
		return Gear.get_gear(offer.id).icon
	var item := ItemDB.get_item(offer.id)
	return item.icon if item else null


func offer_name(offer: ShopOffer) -> String:
	var name := offer.id
	if offer.kind == "gear" and Gear.get_gear(offer.id):
		name = Gear.get_gear(offer.id).display_name
	elif ItemDB.get_item(offer.id):
		name = ItemDB.get_item(offer.id).display_name
	return name if offer.amount == 1 else ItemDB.count_name(offer.amount, name)


## The card beside the list for [param offer]: what it is, what it costs
## against the food you carry, and how many you have already.
func offer_card(offer: ShopOffer) -> Dictionary:
	var thing: Resource = Gear.get_gear(offer.id) if offer.kind == "gear" else ItemDB.get_item(offer.id)
	var rows := [[null, "Costs %d of your %d energy" % [offer.price, Barter.purse()], not Barter.can_afford(offer.price)]]
	return {"title": offer_name(offer), "rows": rows, "facts": "You have %d" % _owned(offer),
		"note": thing.description if thing else ""}


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
	if _marker:
		_marker.hidden_while_talking = true
		_marker.refresh()
	var box := DialogueBox.open(player)
	if shop.talk_target != "":
		var story := QuestLog.talk_to(shop.talk_target, shop.keeper)
		if not story.is_empty():
			await box.say(story)
	if shop.greeting != "":
		await box.say([{"speaker": shop.keeper, "text": shop.greeting}])
	while true:
		var offers := available_offers()
		if offers.is_empty():
			await box.say([{"speaker": shop.keeper, "text": shop.nothing_yet}])
			break
		var options := []
		var icons := []
		var details := []
		for offer in offers:
			icons.append(offer_icon(offer))
			# the card beside the list says the rest (and shows a price you
			# can't meet in red)
			options.append("%s · costs %d" % [offer_name(offer), offer.price])
			details.append(offer_card(offer))
		options.append("Done")
		icons.append(null)
		details.append(null)
		var prompt := "You're carrying %d energy of food. What do you want?" % Barter.purse()
		var choice := await box.choose(prompt, options, shop.keeper, icons, details)
		if choice < 0 or choice >= offers.size():
			break
		var offer := offers[choice]
		var paid := buy(offer)
		if paid.is_empty():
			await box.say([{"speaker": shop.keeper, "text": "That's more food than you've got. Come back after some foraging."}])
		else:
			await box.say([{"speaker": shop.keeper, "text": "Deal. You hand over %s and get %s." % [Barter.describe(paid), offer_name(offer)]}])
	box.close()
	player.can_act = true
	if _marker:
		_marker.hidden_while_talking = false
		_marker.refresh()


func _owned(offer: ShopOffer) -> int:
	return Gear.count(offer.id) if offer.kind == "gear" else Inventory.count(offer.id)
