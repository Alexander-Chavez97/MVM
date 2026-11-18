extends CharacterBody2D
## Basic enemy: patrols back and forth, chases the player when they're close and on its level,
## and hurts on touch. Won't walk off ledges. Built from the same Health/Hurtbox/Hitbox pieces as everything else.

@export var patrol_speed := 60.0
@export var chase_speed := 140.0
@export var chase_range := 240.0        ## px horizontal distance to start chasing
@export var chase_height := 80.0        ## px; only chases if the player is roughly on its level
@export var contact_damage := 15.0
@export var gravity := 2200.0
@export var stagger_time := 0.25        ## s it stops moving after being hit
@export var friction := 1600.0          ## px/s² slowdown from knockback

var dir := -1.0
var _stagger := 0.0
var _color := Color.WHITE

@onready var health: Health = $Health
@onready var hurtbox: Hurtbox = $Hurtbox
@onready var contact: Hitbox = $ContactHitbox
@onready var body: Polygon2D = $Body
@onready var shape: CollisionShape2D = $CollisionShape2D


func _ready() -> void:
	_color = body.color
	hurtbox.hit_received.connect(_on_hit)
	health.died.connect(_on_died)
	contact.activate(contact_damage, Vector2.ZERO)   # always on; the player's i-frames stop repeat hits


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y += gravity * delta

	if _stagger > 0.0:
		_stagger -= delta
		if is_on_floor():
			velocity.x = move_toward(velocity.x, 0.0, friction * delta)
	else:
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
	move_and_slide()


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


func _on_hit(damage: float, knockback: Vector2, _source: Hitbox) -> void:
	health.take_damage(damage)
	velocity = knockback
	_stagger = stagger_time
	body.color = Color(3, 3, 3)
	create_tween().tween_property(body, "color", _color, 0.12)


func _on_died() -> void:
	contact.deactivate()
	hurtbox.invincible = true
	set_physics_process(false)
	var t := create_tween().set_parallel()
	t.tween_property(body, "modulate:a", 0.0, 0.3)
	t.tween_property(body, "scale:y", 0.2, 0.3)
	t.chain().tween_callback(queue_free)
