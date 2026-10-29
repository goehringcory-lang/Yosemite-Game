class_name Wanderer
extends Node2D
## One big animal out wandering (Wanderers looks after them, Bear and
## MuleDeer draw them): it ambles along, stops to nose at the ground or
## graze, looks up when you come close and then goes on its way, away from
## you. Its young, or the rest of its little herd, keep behind the leader. It
## stands in the region's Entities, so it goes behind trees and people like
## anyone else.

## "wander", "forage" (head down), "watch" (looking at you), "leave".
var state := "wander"
## Its row on the sprite sheet.
var coat := 0
## A cub or a fawn.
var young := false
## The one it follows (a mother, or the head of a little herd).
var leader: Wanderer
## Its place behind the leader: 0 nearest, then 1, and so on.
var place := 0
var heading := Vector2.RIGHT
## Where it's walking to while it wanders: the far side of the view.
var target := Vector2.ZERO
var speed := 0.0
var facing := 1
## Seconds left in this state.
var timer := 0.0
## Seconds it has been about, and seconds of walking (for the steps).
var age := 0.0
var steps := 0.0
## Set once it has seen you, so it only stops to look the once.
var noticed := false


## A shadow on the ground under it, [param w] wide.
func draw_shadow(w: float) -> void:
	draw_rect(Rect2(Vector2(-w / 2.0, -3), Vector2(w, 3)), Color(0, 0, 0, 0.18))
	draw_rect(Rect2(Vector2(-w / 2.0 + 3, -1), Vector2(w - 6, 2)), Color(0, 0, 0, 0.12))


## Draws [param src] from [param sheet] with its feet on its position (or
## [param lift] above it), mirrored when facing left.
func draw_frame(sheet: Texture2D, src: Rect2, lift := 0.0) -> void:
	draw_set_transform(Vector2(0, -lift).round(), 0.0, Vector2(facing, 1))
	draw_texture_rect_region(sheet, Rect2(-src.size.x / 2.0, -src.size.y + 1, src.size.x, src.size.y), src)
	draw_set_transform(Vector2.ZERO)
