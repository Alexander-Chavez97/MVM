@tool
class_name GrapplePoint
extends Node2D
## A hook the Regular Guy can swing from. Drop grapple_point.tscn anywhere in a level.
## When it's the player's current target, a pulsing ring appears around it.
## Placeholder drawing: replace _draw() with a Sprite2D once there's art.

@export var radius := 8.0

var highlighted := false:
	set(value):
		if value == highlighted:
			return
		highlighted = value
		_t = 0.0
		queue_redraw()

var _t := 0.0


func _ready() -> void:
	add_to_group("grapple_points")


func _process(delta: float) -> void:
	if highlighted:
		_t += delta
		queue_redraw()


func _draw() -> void:
	var metal := Color(0.6, 0.6, 0.66)
	# ring
	draw_circle(Vector2.ZERO, radius, metal)
	draw_circle(Vector2.ZERO, radius * 0.45, Color(0.13, 0.12, 0.16))
	# hook hanging below: stem + J curve
	draw_line(Vector2(0, radius), Vector2(0, radius + 10), metal, 3.0)
	draw_arc(Vector2(-5, radius + 10), 5.0, 0.0, PI, 12, metal, 3.0)
	if highlighted:
		var pulse := 1.0 + 0.15 * sin(_t * 8.0)
		draw_arc(Vector2.ZERO, radius * 2.4 * pulse, 0.0, TAU, 32, Color(1, 0.85, 0.3), 2.0)
