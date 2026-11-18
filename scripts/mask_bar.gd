@tool
class_name MaskBar
extends Control
## Hollow Knight-style health: one square per point of health.
## Supports half squares (the Wendigo takes half damage). Placeholder drawing until there's mask art.

@export var max_value := 5.0:
	set(v):
		max_value = v
		_update_size()
		queue_redraw()
@export var value := 5.0:
	set(v):
		if v < value:
			_lost_from = value      # remember what was lost so it can flash
			_flash = 0.25
		value = v
		queue_redraw()
@export var square_size := 22.0
@export var gap := 6.0
@export var fill_color := Color(0.92, 0.92, 0.95)
@export var empty_color := Color(0.2, 0.2, 0.25, 0.8)
@export var outline_color := Color(0.05, 0.05, 0.08)

var _flash := 0.0
var _lost_from := 0.0


func _ready() -> void:
	_update_size()


func _process(delta: float) -> void:
	if _flash > 0.0:
		_flash -= delta
		queue_redraw()


func _update_size() -> void:
	var n := ceili(max_value)
	custom_minimum_size = Vector2(n * square_size + maxi(n - 1, 0) * gap, square_size)


func _draw() -> void:
	for i in ceili(max_value):
		var rect := Rect2(i * (square_size + gap), 0, square_size, square_size)
		draw_rect(rect, empty_color)
		var fill := clampf(value - i, 0.0, 1.0)            # 1 = full, 0.5 = half, 0 = empty
		if fill > 0.0:
			draw_rect(Rect2(rect.position, Vector2(square_size * fill, square_size)), fill_color)
		# the part just lost flashes red for a moment
		var lost := clampf(_lost_from - i, 0.0, 1.0) - fill
		if _flash > 0.0 and lost > 0.0:
			var x := rect.position.x + square_size * fill
			draw_rect(Rect2(x, 0, square_size * lost, square_size), Color(1, 0.3, 0.3, _flash / 0.25))
		draw_rect(rect, outline_color, false, 2.0)
