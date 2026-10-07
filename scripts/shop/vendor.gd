class_name Vendor
extends StaticBody2D
## Someone who trades gear or supplies for food. Interact to see what they
## have. What they offer comes from their ShopData.

@export var shop: ShopData
## Placeholder clothing color until real sprites exist.
@export var color := Color(0.55, 0.35, 0.25)
## A 48x96 character sheet (see tools/npcgen). When set, the vendor is drawn
## from it, facing [member facing] (0 down, 1 up, 2 left, 3 right).
@export var sprite_sheet: Texture2D
@export_range(0, 3) var facing := 0


func _ready() -> void:
	queue_redraw()


func _process(_delta: float) -> void:
	if sprite_sheet:
		queue_redraw()


func _draw() -> void:
	if sprite_sheet:
		# A slow breath so the shopkeeper isn't a statue.
		var bob := -1.0 if int(Time.get_ticks_msec() / 700) % 2 == 1 else 0.0
		draw_texture_rect_region(sprite_sheet, Rect2(-8, -24 + bob, 16, 24), Rect2(0, facing * 24, 16, 24))
		return
	draw_rect(Rect2(-4, -14, 8, 11), color)
	draw_circle(Vector2(0, -17), 3.5, Color(0.8, 0.62, 0.48))
	draw_rect(Rect2(-5, -21, 10, 2), color.darkened(0.3))
	draw_rect(Rect2(-4, -3, 3, 3), Color(0.25, 0.22, 0.28))
	draw_rect(Rect2(1, -3, 3, 3), Color(0.25, 0.22, 0.28))


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


func offer_name(offer: ShopOffer) -> String:
	var name := offer.id
	if offer.kind == "gear" and Gear.get_gear(offer.id):
		name = Gear.get_gear(offer.id).display_name
	elif ItemDB.get_item(offer.id):
		name = ItemDB.get_item(offer.id).display_name
	return name if offer.amount == 1 else ItemDB.count_name(offer.amount, name)


func interact(player: Player) -> void:
	player.can_act = false
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
		for offer in offers:
			options.append("%s for %d food energy%s" % [offer_name(offer), offer.price,
				"" if Barter.can_afford(offer.price) else " (not enough food)"])
		options.append("Done")
		var prompt := "You're carrying %d energy of food. What do you want?" % Barter.purse()
		var choice := await box.choose(prompt, options, shop.keeper)
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


func _owned(offer: ShopOffer) -> int:
	return Gear.count(offer.id) if offer.kind == "gear" else Inventory.count(offer.id)
