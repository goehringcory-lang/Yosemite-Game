class_name GuardianGap
extends RegionDoor
## The gap in the talus under the Royal Arches, behind the Ahwahnee: the way
## into the Guardian's cave. It's shut until Galen Clark sends you in (The
## Lost Guardian), but it doesn't sit still until then. As the leads pile up
## (GuardianSearch.board), it changes:
##
##   0  two fallen blocks, and a gap between them
##   1  cold air coming out (once Clark has told you about the tin box, or
##      four sightings are in)
##   2  frost on the blocks in any season (once the press book is full or the
##      Register's last page is written)
##   3  a glint deep inside (once Clark sends you in): the way is open
##
## The first time you look at it, the Journal's case board says so.

## Set the first time you look at the gap (QuestLog.unlocks).
const SEEN := "talus_gap_seen"
## Sightings in before the cold air starts.
const COLD_SIGHTINGS := 4

const LOOKS := [
	"Two fallen blocks lean together at the foot of the Royal Arches, and there's a dark gap between them. It doesn't feel like yours to go into. Not yet.",
	"Cold air comes out of the gap between the fallen blocks, steady as breathing, smelling of wet stone. Somewhere in there is the tin box Clark never opened. It doesn't feel like yours to go into. Not yet.",
	"There's frost on the blocks round the gap, whatever the season, and the cold air comes out of it like a sigh. You could almost go in. Clark would want to know first.",
]

var _time := 0.0


## How far along the gap is (see the class notes).
static func stage() -> int:
	if QuestLog.active.has(QuestLog.FINALE_QUEST) or QuestLog.is_completed(QuestLog.FINALE_QUEST):
		return 3
	if QuestLog.is_completed("enid_full_press") or QuestLog.is_completed(QuestLog.LAST_PAGE_QUEST):
		return 2
	if QuestLog.is_completed("clark_grove_sprigs") or GuardianSearch.sightings().size() >= COLD_SIGHTINGS:
		return 1
	return 0


## The case board's line about the gap.
static func journal_line() -> String:
	if QuestLog.is_completed(QuestLog.FINALE_QUEST):
		return "The cave under the Royal Arches: a looking-glass, and a tin box, empty now."
	match stage():
		3:
			return "Clark has sent you into the gap in the talus under the Royal Arches, behind the Ahwahnee."
		2:
			return "The gap in the talus under the Royal Arches has frost round it now, in any season. Ask Clark."
		1:
			if QuestLog.is_unlocked(SEEN):
				return "The gap in the talus under the Royal Arches breathes cold air. Clark's tin box is in there somewhere."
			return "Clark remembers a gap in the talus under the Royal Arches, behind the Ahwahnee, and a tin box he left alone."
	if QuestLog.is_unlocked(SEEN):
		return "You've seen a gap in the talus under the Royal Arches, behind the Ahwahnee. It didn't feel like yours to go into."
	return "Nobody has said where to look yet."


func _ready() -> void:
	set_process(true)
	var overlay := Node2D.new()
	overlay.name = "Breath"
	overlay.z_index = 1
	overlay.draw.connect(_draw_breath.bind(overlay))
	add_child(overlay)


func _process(delta: float) -> void:
	_time += delta
	var breath: Node2D = get_node_or_null("Breath")
	if breath and stage() >= 1:
		breath.queue_redraw()


func get_prompt() -> String:
	if not is_unlocked():
		return "Look at %s" % label
	return "Go into %s" % label


func interact(player: Player) -> void:
	if not is_unlocked():
		if not QuestLog.is_unlocked(SEEN):
			QuestLog.unlocks.append(SEEN)
			QuestLog.changed.emit()
		get_tree().call_group("hud", "show_message", LOOKS[mini(stage(), LOOKS.size() - 1)])
		return
	super.interact(player)


## Cold air drifting out of the gap, frost on the blocks, and a glint deep
## inside, depending on [method stage].
func _draw_breath(on: Node2D) -> void:
	var now := stage()
	if now <= 0:
		return
	# the gap's mouth sits about here on the cave_mouth sprite
	var mouth := Vector2(0, -22)
	for i in 5:
		var t := fmod(_time * 0.35 + i / 5.0, 1.0)
		var at := mouth + Vector2(sin(t * TAU + i) * 6.0 + (i - 2) * 3.0, -t * 26.0)
		var alpha := sin(t * PI) * 0.35
		on.draw_rect(Rect2(at, Vector2(6 - i % 2 * 2, 2)), Color(0.9, 0.95, 1.0, alpha))
	if now >= 2:
		for spot in [Vector2(-22, -30), Vector2(-14, -40), Vector2(16, -34), Vector2(22, -24), Vector2(-26, -18), Vector2(8, -42)]:
			on.draw_rect(Rect2(spot, Vector2(3, 1)), Color(0.92, 0.97, 1.0, 0.8))
			on.draw_rect(Rect2(spot + Vector2(1, -1), Vector2(1, 1)), Color(1, 1, 1, 0.9))
	if now >= 3:
		var pulse := 0.5 + 0.5 * sin(_time * 3.0)
		on.draw_rect(Rect2(mouth + Vector2(-1, 4), Vector2(2, 2)), Color(1, 0.95, 0.7, 0.6 + 0.4 * pulse))
		on.draw_rect(Rect2(mouth + Vector2(-3, 5), Vector2(6, 1)), Color(1, 0.95, 0.7, 0.25 * pulse))
		on.draw_rect(Rect2(mouth + Vector2(0, 2), Vector2(1, 6)), Color(1, 0.95, 0.7, 0.25 * pulse))
