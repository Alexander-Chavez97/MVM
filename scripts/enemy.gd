class_name Enemy
extends CharacterBody2D
## Base for anything the player can hit and juggle (DMC-style).
##   NORMAL    -> runs _ai() (subclasses override it)
##   HITSTUN   -> stunned on the ground for the attack's hitstun time, no AI, no contact damage
##   AIRBORNE  -> launched: lighter gravity; every hit pops it back up (a bit less each time)
##   KNOCKDOWN -> landed after a juggle: lies there briefly, then gets back up
## Expects children: Health, Hurtbox, Body (any Node2D). Optional: ContactHitbox, HPLabel.

enum HitState { NORMAL, HITSTUN, AIRBORNE, KNOCKDOWN }

const JUGGLE_GRAVITY := 1400.0   ## px/s² while launched (lighter than normal = floatier juggles)

@export var gravity := 2200.0
@export var friction := 1600.0            ## px/s² slowdown from knockback on the ground
@export var contact_damage := 0.0         ## health squares per touch (0 = harmless)
@export var knockdown_time := 0.45
@export var launch_threshold := 250.0     ## upward knockback stronger than this launches it
@export var juggle_decay := 0.08          ## each extra air hit pops it up this much less (fraction)
@export var min_juggle_pop := 0.35        ## pops never get weaker than this fraction
@export var show_damage_numbers := true
@export var respawns := false             ## training dummies come back; real enemies die
@export var respawn_time := 1.0

var hit_state := HitState.NORMAL
var _stun := 0.0
var _juggle_count := 0
var _suspend := 0.0      # s frozen in the air (the player's tether pulls them up to meet it)

@onready var health: Health = $Health
@onready var hurtbox: Hurtbox = $Hurtbox
@onready var body: Node2D = $Body
@onready var contact: Hitbox = get_node_or_null("ContactHitbox")
@onready var hp_label: Label = get_node_or_null("HPLabel")


func _ready() -> void:
	add_to_group("enemies")
	hurtbox.hit_received.connect(_on_hit)
	health.died.connect(_on_died)
	health.changed.connect(func(cur: float, _max: float) -> void: _set_hp_label(cur))
	_set_hp_label(health.max_health)
	_set_hit_state(HitState.NORMAL)


func is_airborne() -> bool:
	return hit_state == HitState.AIRBORNE


func is_dead() -> bool:
	return health.is_dead()


## Center of the body, for aiming and the lock-on reticle.
func get_center() -> Vector2:
	return global_position + Vector2(0, -get_height() / 2.0)


func get_height() -> float:
	return get_size().y


func get_size() -> Vector2:
	var col := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if col != null and col.shape is RectangleShape2D:
		return (col.shape as RectangleShape2D).size
	return Vector2(32, 32)


## Freeze in mid-air for a moment (only while launched).
func suspend(time: float) -> void:
	if hit_state == HitState.AIRBORNE:
		_suspend = time
		velocity = Vector2.ZERO


## Override in subclasses: movement/decisions while not being hit. Set velocity.x here.
func _ai(_delta: float) -> void:
	if is_on_floor():
		velocity.x = move_toward(velocity.x, 0.0, friction * _delta)


func _physics_process(delta: float) -> void:
	match hit_state:
		HitState.NORMAL:
			if not is_on_floor():
				velocity.y += gravity * delta
			_ai(delta)
		HitState.HITSTUN:
			_stun -= delta
			if is_on_floor():
				velocity.x = move_toward(velocity.x, 0.0, friction * delta)
			else:
				velocity.y += gravity * delta
			if _stun <= 0.0:
				_set_hit_state(HitState.NORMAL)
		HitState.AIRBORNE:
			if _suspend > 0.0:
				_suspend -= delta
				velocity = Vector2.ZERO
			else:
				velocity.y += JUGGLE_GRAVITY * delta
			velocity.x = move_toward(velocity.x, 0.0, 200.0 * delta)   # light air drag
		HitState.KNOCKDOWN:
			_stun -= delta
			velocity.x = move_toward(velocity.x, 0.0, friction * 2.0 * delta)
			if not is_on_floor():
				velocity.y += gravity * delta
			if _stun <= 0.0:
				_set_hit_state(HitState.NORMAL)
	move_and_slide()
	if hit_state == HitState.AIRBORNE and is_on_floor() and velocity.y >= 0.0:
		_juggle_count = 0
		_stun = knockdown_time
		_set_hit_state(HitState.KNOCKDOWN)


func _on_hit(damage: float, knockback: Vector2, source: Hitbox) -> void:
	health.take_damage(damage)
	_flash()
	if show_damage_numbers:
		_damage_number(damage, source != null and source.bonus)
	var stun := source.hitstun if source != null else 0.3

	if hit_state == HitState.AIRBORNE:
		_suspend = 0.0
		# Juggle: keep it in the air. Upward pops get weaker the longer the juggle goes.
		_juggle_count += 1
		var pop := maxf(1.0 - juggle_decay * (_juggle_count - 1), min_juggle_pop)
		velocity.x = knockback.x * 0.5            # less sideways push so it stays near you
		velocity.y = knockback.y * pop if knockback.y < 0.0 else knockback.y   # spikes go full force
		_set_hit_state(HitState.AIRBORNE)
	elif knockback.y < -launch_threshold:
		# Launcher
		_juggle_count = 1
		velocity = knockback
		_set_hit_state(HitState.AIRBORNE)
	else:
		velocity = knockback
		_stun = stun
		_set_hit_state(HitState.HITSTUN)


func _set_hit_state(new_state: HitState) -> void:
	hit_state = new_state
	# Only hurts on touch while acting normally (being juggled shouldn't hurt the player)
	if contact != null:
		if new_state == HitState.NORMAL and contact_damage > 0.0 and not health.is_dead():
			if not contact.active:
				contact.activate(contact_damage, Vector2.ZERO)
		elif contact.active:
			contact.deactivate()
	# Placeholder pose: squashed while knocked down
	body.scale.y = 0.5 if new_state == HitState.KNOCKDOWN else 1.0


func _on_died() -> void:
	hurtbox.invincible = true
	if contact != null:
		contact.deactivate()
	var t := create_tween()
	t.tween_property(body, "modulate:a", 0.2, 0.3)
	if not respawns:
		t.tween_callback(queue_free)
		return
	await get_tree().create_timer(respawn_time).timeout
	health.heal_full()
	body.modulate.a = 1.0
	hurtbox.invincible = false
	_set_hit_state(HitState.NORMAL)


func _flash() -> void:
	body.self_modulate = Color(3, 3, 3)
	create_tween().tween_property(body, "self_modulate", Color.WHITE, 0.12)


func _set_hp_label(value: float) -> void:
	if hp_label != null:
		hp_label.text = str(ceili(value))


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
