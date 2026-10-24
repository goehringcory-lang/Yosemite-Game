class_name TravelSlackline
extends Node
## Wren's slackline, the reward for gold at Camp 4 (the wren_slackline quest):
## once you carry it, every sturdy tree in an outdoor region can take one end.
## Walk up to a trunk with another tree a few strides off to one side, rig the
## line between them, and walk it on the slackline screen (SlacklineMinigame,
## with a line sized to the gap: SlacklineState.travel_line).
##
## StoryContent puts one of these in every outdoor region. It gives the trees
## their SlacklineAnchor once the line is yours (straight away if you win it
## while you're here), and keeps the one line you own rigged until you take it
## down or rig it somewhere else. A rigged line isn't saved: it's down again
## when you load a game.

const ABILITY := "travel_slackline"
## Tree name (after "Tree" in the generated maps) -> what it's called. Snags,
## stumps and the small flowering trees (dogwood, redbud, buckeye) aren't
## here: they won't hold a line.
const TREES := {
	"Ponderosa": "ponderosa pine", "SugarPine": "sugar pine", "Lodgepole": "lodgepole pine",
	"Whitebark": "whitebark pine", "GrayPine": "gray pine", "IncenseCedar": "incense cedar",
	"WhiteFir": "white fir", "BlackOak": "black oak", "LiveOak": "live oak",
	"BlueOak": "blue oak", "SequoiaGiant": "giant sequoia",
}
## How far apart two trees can be, in pixels, and how far off level (a share
## of the gap across): roughly side by side, a few strides apart.
const MIN_GAP := 128.0
const MAX_GAP := 448.0
const MAX_SLOPE := 0.5
const PIXELS_PER_METER := 16.0

const ANCHOR := preload("res://scripts/objects/slackline_anchor.gd")

## The trees that can hold a line, found once.
var trees: Array[StaticBody2D] = []
## The two trees the line is rigged between, or empty.
var rigged: Array[StaticBody2D] = []

var _region: Region
var _webbing: Node2D


func _ready() -> void:
	name = "TravelSlackline"
	_region = get_parent() as Region
	QuestLog.changed.connect(_refresh)
	_refresh()


## Gives the trees their anchors, once the line is yours.
func _refresh() -> void:
	if not trees.is_empty() or _region == null or not QuestLog.is_unlocked(ABILITY):
		return
	for node in _region.entities.get_children():
		if node is StaticBody2D and kind_of(node) != "":
			trees.append(node)
			node.add_child(ANCHOR.new())


## What [param tree] is called ("ponderosa pine"), or "" if it can't hold a
## line.
static func kind_of(tree: Node) -> String:
	var node_name := String(tree.name)
	if not node_name.begins_with("Tree"):
		return ""
	for key: String in TREES:
		if node_name.begins_with("Tree" + key):
			return TREES[key]
	return ""


## True if [param a] and [param b] are the right distance apart to rig.
static func can_span(a: Vector2, b: Vector2) -> bool:
	var gap := a.distance_to(b)
	return gap >= MIN_GAP and gap <= MAX_GAP and absf(b.y - a.y) <= absf(b.x - a.x) * MAX_SLOPE


## The nearest tree [param tree] can be rigged to, or null if none is the
## right distance off.
func partner_for(tree: StaticBody2D) -> StaticBody2D:
	var best: StaticBody2D = null
	var best_gap := INF
	for other in trees:
		if other == tree or not is_instance_valid(other):
			continue
		var gap := tree.position.distance_to(other.position)
		if gap < best_gap and can_span(tree.position, other.position):
			best = other
			best_gap = gap
	return best


## The line's length in whole meters between two trees.
static func meters_between(a: Node2D, b: Node2D) -> int:
	return roundi(a.position.distance_to(b.position) / PIXELS_PER_METER)


func is_rigged_on(tree: StaticBody2D) -> bool:
	return rigged.has(tree)


## Rigs the line from [param a] to [param b], taking it down wherever it was.
func rig(a: StaticBody2D, b: StaticBody2D) -> void:
	take_down()
	rigged = [a, b]
	_webbing = Webbing.new()
	_webbing.name = "RiggedSlackline"
	_webbing.from = a.position
	_webbing.to = b.position
	_region.entities.add_child(_webbing)


func take_down() -> void:
	rigged.clear()
	if _webbing:
		_webbing.queue_free()
		_webbing = null


## The slackline screen's line for what's rigged here.
func line() -> Dictionary:
	if rigged.size() < 2:
		return {}
	return SlacklineState.travel_line(meters_between(rigged[0], rigged[1]), _region.display_name)


## The webbing on the map, tied round both trunks on their pads. It sits at
## the nearer tree's foot so it y-sorts in front of both trunks.
class Webbing:
	extends Node2D

	const WEB := Color("d8a63b")
	const WEB_DARK := Color("7e531c")
	const PAD := Color("437f45")
	const TIE := 14.0

	var from := Vector2.ZERO
	var to := Vector2.ZERO

	func _ready() -> void:
		position = Vector2((from.x + to.x) / 2.0, maxf(from.y, to.y) + 1.0)

	func _draw() -> void:
		var a := from - position + Vector2(0, -TIE)
		var b := to - position + Vector2(0, -TIE)
		var points := PackedVector2Array()
		for i in 17:
			var u := i / 16.0
			points.append(a.lerp(b, u) + Vector2(0, sin(u * PI) * 6.0))
		draw_polyline(points, WEB_DARK, 3.0)
		draw_polyline(points, WEB, 1.5)
		for end in [a, b]:
			draw_rect(Rect2(end + Vector2(-7, -3), Vector2(14, 6)), PAD)
			draw_rect(Rect2(end + Vector2(-7, -1), Vector2(14, 2)), WEB_DARK)
