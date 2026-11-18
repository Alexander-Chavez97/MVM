class_name Hurtbox
extends Area2D
## Area that can be hit. The owner listens to hit_received and decides what happens
## (lose health, get knocked back, flash...). Set collision_layer to the team's hurtbox layer.

signal hit_received(damage: float, knockback: Vector2, source: Hitbox)

var invincible := false


func _ready() -> void:
	monitoring = false   # hurtboxes are found by hitboxes, they don't look for anything


## Returns false if the hit was ignored (invincible).
func receive_hit(damage: float, knockback: Vector2, source: Hitbox) -> bool:
	if invincible:
		return false
	hit_received.emit(damage, knockback, source)
	return true
