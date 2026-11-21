class_name HappeningFigure
extends Node2D
## Someone out in the park for one of today's Happenings, standing where
## it's going on (HappeningField places them). A small speech mark floats
## over them until it's done; talk to them to see what's up.

const MARK_BOB := 2.0
const MARK_COLOR := Color(1.0, 0.92, 0.55)
const MARK_EDGE := Color(0.24, 0.17, 0.1)

var happening: Dictionary = {}
var _sprite: Sprite2D
var _clock := 0.0
var _busy := false
var facing := Vector2i.DOWN


func setup(for_happening: Dictionary, look: CharacterData) -> void:
	happening = for_happening
	name = "Happening_" + str(happening.id)
	if look and look.sprite_sheet:
		_sprite = Sprite2D.new()
		CharacterSheet.setup(_sprite, look.sprite_sheet)
		_sprite.offset = Vector2(0, -22)
		var size := float(happening.get("scale", 1.0))
		_sprite.scale = Vector2(size, size)
		add_child(_sprite)
		LitSprites.attach_sprite(_sprite)
	# witnesses look the way the moment is, up the wall or out over the view
	facing = Vector2i.UP if happening.kind == "witness" else Vector2i.DOWN
	var hitbox := Area2D.new()
	hitbox.name = "Hitbox"
	hitbox.collision_layer = 4
	hitbox.collision_mask = 0
	hitbox.monitoring = false
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = Vector2(28, 32)
	shape.shape = box
	shape.position = Vector2(0, -14)
	hitbox.add_child(shape)
	add_child(hitbox)


func get_prompt() -> String:
	return "Talk to %s" % happening.get("who", "them")


func interact(player: Player) -> void:
	if _busy:
		return
	_busy = true
	var was := facing
	var to := player.global_position - global_position
	facing = (Vector2i.RIGHT if to.x > 0 else Vector2i.LEFT) if absf(to.x) > absf(to.y) else (Vector2i.DOWN if to.y > 0 else Vector2i.UP)
	player.can_act = false
	var box := DialogueBox.open(player)
	await Happenings.talk(box, happening.id)
	box.close()
	player.can_act = true
	facing = was
	_busy = false
	queue_redraw()


func _process(delta: float) -> void:
	_clock += delta
	if _sprite:
		var col: int = CharacterSheet.Col.TALK if _busy and int(_clock * 7.0) % 2 == 0 else CharacterSheet.Col.STAND
		if not _busy and CharacterSheet.blinking(_clock, hash(name)):
			col = CharacterSheet.Col.BLINK
		_sprite.frame = CharacterSheet.frame(_sprite.texture, facing, col)
	queue_redraw()


func _draw() -> void:
	GroundShadow.draw_under(self)
	if _busy or Happenings.is_done(happening.id):
		return
	# a little speech mark with three dots, bobbing over their head
	var at := Vector2(0, -54 + sin(_clock * 3.0) * MARK_BOB).round()
	draw_rect(Rect2(at + Vector2(-8, -6), Vector2(16, 10)), MARK_EDGE)
	draw_rect(Rect2(at + Vector2(-7, -5), Vector2(14, 8)), MARK_COLOR)
	draw_rect(Rect2(at + Vector2(-2, 4), Vector2(4, 2)), MARK_EDGE)
	draw_rect(Rect2(at + Vector2(-1, 3), Vector2(2, 2)), MARK_COLOR)
	for x in [-4, 0, 4]:
		draw_rect(Rect2(at + Vector2(x - 1, -2), Vector2(2, 2)), MARK_EDGE)
