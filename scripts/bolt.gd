extends Hitbox
## Crossbow bolt. A moving Hitbox: flies straight, hits hurtboxes, stops at walls.
## Tap bolts stop at the first enemy; charged bolts pierce through everything.

var velocity := Vector2.ZERO
var pierce := false
var hitstop := 0.0
var shooter: Node = null      # the player, told about hits so it can lock on
var _life := 1.2


func _ready() -> void:
	super()
	body_entered.connect(func(_b: Node2D) -> void: queue_free())   # hit a wall
	hit_landed.connect(_on_bolt_hit)


func launch(dir: Vector2, speed: float, dmg: float, kb: Vector2, stun: float, charged: bool) -> void:
	velocity = dir * speed
	rotation = dir.angle()
	pierce = charged
	hitstop = 0.06 if charged else 0.0
	activate(dmg, kb, false, stun)
	if charged:
		scale = Vector2(1.6, 1.8)
		$Visual.color = Color(1.0, 0.85, 0.3)


func _physics_process(delta: float) -> void:
	position += velocity * delta
	_life -= delta
	if _life <= 0.0:
		queue_free()
		return
	super(delta)


func _on_bolt_hit(hurt: Hurtbox) -> void:
	if shooter != null and shooter.has_method("on_bolt_hit"):
		shooter.on_bolt_hit(hurt)
	if hitstop > 0.0:
		Juice.hitstop(self, hitstop)
	if not pierce:
		queue_free()
