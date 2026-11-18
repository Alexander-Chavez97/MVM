extends CharacterBody2D
## Training dummy: takes hits, gets knocked back, shows damage numbers, respawns after dying.
## Good for tuning attack numbers. Real enemies will reuse Health + Hurtbox the same way.

@export var gravity := 2200.0
@export var friction := 1800.0     ## px/s² slowdown after knockback (on the ground)
@export var respawn_time := 1.0

var _color := Color.WHITE

@onready var health: Health = $Health
@onready var hurtbox: Hurtbox = $Hurtbox
@onready var body: Polygon2D = $Body
@onready var hp_label: Label = $HPLabel


func _ready() -> void:
	_color = body.color
	hurtbox.hit_received.connect(_on_hit)
	health.died.connect(_on_died)
	health.changed.connect(func(cur: float, _max: float) -> void: hp_label.text = str(ceili(cur)))
	hp_label.text = str(ceili(health.max_health))


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y += gravity * delta
	elif velocity.y > 0.0:
		velocity.y = 0.0
	if is_on_floor():
		velocity.x = move_toward(velocity.x, 0.0, friction * delta)
	move_and_slide()


func _on_hit(damage: float, knockback: Vector2, source: Hitbox) -> void:
	health.take_damage(damage)
	velocity = knockback
	body.color = Color(3, 3, 3)   # white flash
	create_tween().tween_property(body, "color", _color, 0.12)
	_damage_number(damage, source != null and source.bonus)


func _on_died() -> void:
	hurtbox.invincible = true
	var t := create_tween()
	t.tween_property(body, "modulate:a", 0.25, 0.2)
	await get_tree().create_timer(respawn_time).timeout
	health.heal_full()
	hurtbox.invincible = false
	body.modulate.a = 1.0


func _damage_number(amount: float, bonus: bool) -> void:
	var label := Label.new()
	label.text = str(snappedf(amount, 0.1)).trim_suffix(".0")
	label.modulate = Color(1, 0.8, 0.25) if bonus else Color.WHITE
	label.z_index = 20
	get_parent().add_child(label)
	label.global_position = global_position + Vector2(randf_range(-14, 6), -70)
	var t := label.create_tween()
	t.set_parallel()
	t.tween_property(label, "position:y", label.position.y - 30, 0.6)
	t.tween_property(label, "modulate:a", 0.0, 0.6).set_delay(0.2)
	t.chain().tween_callback(label.queue_free)
