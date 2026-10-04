class_name Station
extends StaticBody2D
## A place to prepare food: a campfire, a bedrock mortar, or a leaching
## basin by the river. Interact to pick a known recipe and make it.

## Must match RecipeData.station.
@export_enum("campfire", "mortar", "leaching") var station := "campfire"
@export var display_name := "Campfire"


func _ready() -> void:
	queue_redraw()


## Placeholder art until real sprites exist.
func _draw() -> void:
	match station:
		"campfire":
			for i in 5:
				var angle := TAU * i / 5.0
				draw_circle(Vector2(cos(angle), sin(angle) * 0.5) * 6 + Vector2(0, -3), 2.0, Color(0.5, 0.48, 0.45))
			draw_colored_polygon(PackedVector2Array([Vector2(-3, -3), Vector2(3, -3), Vector2(0, -11)]), Color(1.0, 0.55, 0.15))
		"mortar":
			draw_rect(Rect2(-10, -8, 20, 9), Color(0.6, 0.58, 0.55))
			draw_circle(Vector2(-4, -4), 2.0, Color(0.35, 0.33, 0.3))
			draw_circle(Vector2(4, -4), 2.0, Color(0.35, 0.33, 0.3))
		"leaching":
			draw_circle(Vector2(0, -4), 7.0, Color(0.75, 0.68, 0.5))
			draw_circle(Vector2(0, -4), 4.5, Color(0.4, 0.6, 0.8))


func interact(player: Player) -> void:
	var recipes := Recipes.known_for(station)
	if recipes.is_empty():
		DialogueBox.say_to(player, [{"speaker": "", "text": "%s. You don't know anything to make here yet." % display_name}])
		return
	var options := []
	for recipe in recipes:
		var mark := "" if Recipes.can_make(recipe) else " (missing ingredients)"
		options.append("%s: %s%s" % [recipe.display_name, Recipes.describe_inputs(recipe), mark])
	options.append("Leave")
	player.can_act = false
	var box := DialogueBox.open(player)
	var choice := await box.choose("%s. What will you make?" % display_name, options)
	if choice >= 0 and choice < recipes.size():
		var recipe := recipes[choice]
		if Recipes.make(recipe):
			var item := ItemDB.get_item(recipe.output_id)
			await box.say([{"speaker": "", "text": "%s You made %d %s." % [
				recipe.description, recipe.output_count, item.display_name if item else recipe.output_id]}])
		else:
			await box.say([{"speaker": "", "text": "You need %s." % Recipes.describe_inputs(recipe)}])
	box.close()
	player.can_act = true
