class_name Hitbox
extends Area2D
## Deals damage to Hurtboxes it overlaps while active. Each target is hit once per activation.
## Set collision_mask to the layer of the hurtboxes it should hit
## (player attacks: enemy hurtboxes = layer 3; enemy attacks: player hurtbox = layer 2).

signal hit_landed(hurtbox: Hurtbox)

var damage := 0.0
var knockback := Vector2.ZERO
var bonus := false           # attack had the switch bonus (lets targets show it differently)
var active := false
var _already_hit: Array[Hurtbox] = []

@onready var shape: CollisionShape2D = $CollisionShape2D


func _ready() -> void:
	monitorable = false
	shape.shape = shape.shape.duplicate()   # each hitbox resizes its own shape
	shape.disabled = true


func activate(dmg: float, kb: Vector2, is_bonus := false) -> void:
	damage = dmg
	knockback = kb
	bonus = is_bonus
	_already_hit.clear()
	active = true
	shape.set_deferred("disabled", false)


func deactivate() -> void:
	active = false
	shape.set_deferred("disabled", true)


func _physics_process(_delta: float) -> void:
	if not active:
		return
	for area in get_overlapping_areas():
		var hurtbox := area as Hurtbox
		if hurtbox == null or hurtbox in _already_hit:
			continue
		_already_hit.append(hurtbox)
		if hurtbox.receive_hit(damage, knockback, self):
			hit_landed.emit(hurtbox)
