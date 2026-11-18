extends Enemy
## Basic enemy: patrols back and forth, chases the player when they're close and on its level,
## and hurts on touch. Won't walk off ledges. Hitstun/juggling comes from Enemy.

@export var patrol_speed := 60.0
@export var chase_speed := 140.0
@export var chase_range := 240.0        ## px horizontal distance to start chasing
@export var chase_height := 80.0        ## px; only chases if the player is roughly on its level

var dir := -1.0

@onready var shape: CollisionShape2D = $CollisionShape2D


func _ai(_delta: float) -> void:
	var speed := patrol_speed
	var player := _player_in_range()
	if player != null:
		var to_player := signf(player.global_position.x - global_position.x)
		if to_player != 0.0:
			dir = to_player
		speed = chase_speed
	if is_on_floor() and (_wall_ahead() or not _ground_ahead()):
		if player != null:
			speed = 0.0   # chasing: wait at the edge instead of jumping off
		else:
			dir = -dir    # patrolling: turn around
	velocity.x = dir * speed
	body.scale.x = -dir   # art faces left by default


func _player_in_range() -> Node2D:
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player == null or player.health.is_dead():
		return null
	var d := player.global_position - global_position
	if absf(d.x) < chase_range and absf(d.y) < chase_height:
		return player
	return null


func _wall_ahead() -> bool:
	return is_on_wall() and signf(get_wall_normal().x) == -dir


## Ray straight down just past the front foot.
func _ground_ahead() -> bool:
	var half_w := (shape.shape as RectangleShape2D).size.x / 2.0
	var from := global_position + Vector2(dir * (half_w + 2.0), -4.0)
	var ray := PhysicsRayQueryParameters2D.create(from, from + Vector2(0, 20), collision_mask, [get_rid()])
	return not get_world_2d().direct_space_state.intersect_ray(ray).is_empty()
