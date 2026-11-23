class_name TargetReticle
extends Node2D
## Lock-on marker drawn around the player's current target. Placeholder drawing.

var target_size := Vector2(30, 40)
var _t := 0.0


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	var pulse := 1.0 + 0.08 * sin(_t * 6.0)
	var h := target_size / 2.0 * pulse + Vector2(6, 6)
	var c := Color(1.0, 0.35, 0.3, 0.9)
	var l := 8.0
	# four corner brackets
	for sx in [-1.0, 1.0]:
		for sy in [-1.0, 1.0]:
			var corner := Vector2(sx * h.x, sy * h.y)
			draw_line(corner, corner - Vector2(sx * l, 0), c, 2.0)
			draw_line(corner, corner - Vector2(0, sy * l), c, 2.0)
