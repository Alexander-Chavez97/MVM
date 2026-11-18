extends CharacterBody2D
## Shapeshifter player.
## Movement: Hollow Knight style (no momentum, hold-to-rise jump, instant jump cut).
## Forms: stats come from FormData resources. Regular Guy is the base form;
## hold hold_wendigo / hold_chupacabra to stay transformed, let go to snap back.
## Abilities: Wendigo wall climb (automatic), Chupacabra dash (special),
## Regular Guy swing (hold special near a grapple point).
## Combat (DMC-style): per-form move sets (AttackData) with directional moves, launchers,
## air combos and cancels. Switching forms gives a damage bonus on your next hit.
## Origin is at the player's feet.

signal state_changed(old_state: State, new_state: State)
signal form_changed(form: FormData)
signal swap_blocked
signal died

enum State { IDLE, RUN, JUMP, FALL, CLIMB, DASH, SWING, ATTACK, HURT }
enum AttackPhase { STARTUP, ACTIVE, RECOVERY }
# IDLE/RUN/JUMP/FALL are worked out from movement each frame (see _update_state).
# The rest are entered and exited explicitly with _set_state.
const EXPLICIT_STATES := [State.CLIMB, State.DASH, State.SWING, State.ATTACK, State.HURT]
const SLAM_SPEED := 1000.0          ## px/s plummet for slam moves
const HANG_GRAVITY_SCALE := 0.12    ## gravity fraction during an air-hang attack
const HANG_MAX_FALL := 120.0        ## px/s max fall during an air-hang attack

@export var forms: Array[FormData] = []
@export var unlocked: Array[bool] = [true, true, true]  ## testing: all on. Final game: [true, false, false]
@export var swap_cooldown := 0.1         ## s between form switches
@export var coyote_time := 0.08
@export var jump_buffer_time := 0.1

@export_group("Combat")
@export var attack_buffer_time := 0.15       ## s an attack press is remembered (lets combos be mashed)
@export var switch_bonus_time := 1.0         ## s after switching forms where hits do bonus damage
@export var switch_bonus_multiplier := 1.5

@export_group("Getting hit")
@export var hurt_time := 0.25                ## s you lose control after being hit
@export var invincibility_time := 1.0        ## s you can't be hit again (you blink)
@export var hurt_knockback := Vector2(300, -250)   ## px/s away from whatever hit you
@export var respawn_delay := 1.0
@export var kill_y := 1500.0                 ## falling below this y kills you

var state := State.IDLE
var form: FormData
var form_index := 0
var facing := 1.0

var _coyote_timer := 0.0
var _jump_buffer_timer := 0.0
var _jump_hold_timer := 0.0
var _is_jumping := false
var _swap_timer := 0.0
var _last_held := 0        # form index of the most recently pressed hold button
var _last_desired := 0
var _wall_dir := 0.0          # wall side while climbing: -1 = wall on the left, 1 = on the right
var _wall_jump_lock := 0.0
var _wall_jump_dir := 0.0
var _dash_timer := 0.0
var _dash_cooldown_timer := 0.0
var _dash_dir := 1.0
var _air_dashes_left := 0
var _ghost_timer := 0.0
var _grapple_target: GrapplePoint
var _anchor := Vector2.ZERO
var _rope_length := 0.0
var _launched := false     # true after letting go of a swing: keep momentum until landing
var _rope: Line2D
var _attack_phase := AttackPhase.STARTUP
var _attack_timer := 0.0
var _attack_buffer_timer := 0.0
var _combo_index := 0
var _attack: AttackData            # move being performed
var _chain_key := ""               # "combo" / "air" while in a combo string, "" for single moves
var _hanging := false              # air hang active for this move
var _air_hang_charges := 1         # refills on landing, pogo, launcher follow, hook grab, wall grab
var _slam_landed := false
var _switch_bonus_timer := 0.0
var _shake := 0.0
var respawn_position := Vector2.ZERO   # set_checkpoint() changes this
var _hurt_timer := 0.0
var _iframe_timer := 0.0
var _dead := false

@onready var collision: CollisionShape2D = $CollisionShape2D
@onready var body: Node2D = $Body
@onready var torso: Polygon2D = $Body/Torso
@onready var eye: Polygon2D = $Body/Eye
@onready var sprite: AnimatedSprite2D = $Body/Sprite
@onready var hitbox: Hitbox = $Hitbox
@onready var slash: Polygon2D = $Hitbox/Slash
@onready var camera: Camera2D = $Camera2D
@onready var health: Health = $Health
@onready var hurtbox: Hurtbox = $Hurtbox
@onready var hurt_shape: CollisionShape2D = $Hurtbox/CollisionShape2D


func _ready() -> void:
	if forms.is_empty():
		push_error("Player has no forms assigned")
		return
	collision.shape = collision.shape.duplicate()  # don't edit the shared resource
	hurt_shape.shape = hurt_shape.shape.duplicate()
	add_to_group("player")
	respawn_position = global_position
	hurtbox.hit_received.connect(_on_hurt)
	health.died.connect(_on_died)
	_rope = Line2D.new()
	_rope.top_level = true     # points are in world coordinates
	_rope.width = 2.0
	_rope.default_color = Color(0.8, 0.75, 0.6)
	add_child(_rope)
	hitbox.hit_landed.connect(_on_hit_landed)
	_apply_form(0)


func _physics_process(delta: float) -> void:
	_update_timers(delta)
	_handle_form_input()
	match state:
		State.CLIMB:
			_climb_move()
		State.DASH:
			_dash_move(delta)
		State.SWING:
			_swing_move(delta)
		State.ATTACK:
			_attack_move(delta)
		State.HURT:
			_hurt_move(delta)
		_:
			if not _try_start_dash() and not _try_start_swing() and not _try_start_attack():
				_handle_jump(delta)
				_apply_gravity(delta)
				_handle_run()
	move_and_slide()
	if state == State.CLIMB:
		_climb_check()
	elif state == State.SWING:
		_swing_constrain()
	elif state not in [State.DASH, State.ATTACK, State.HURT]:
		if is_on_ceiling() and velocity.y < 0.0:
			_end_jump()
		_try_start_climb()
	body.scale.x = facing
	_update_grapple_target()
	_update_rope()
	_update_state()
	hurtbox.invincible = _dead or _iframe_timer > 0.0 or state == State.DASH   # dash = dodge
	if global_position.y > kill_y and not _dead:
		health.take_damage(health.current)   # fell out of the world


# ---------------------------------------------------------------- state machine

func _update_state() -> void:
	if state in EXPLICIT_STATES:
		return   # explicit states: only _set_state moves us out of them
	if is_on_floor():
		_set_state(State.RUN if velocity.x != 0.0 else State.IDLE)
	else:
		_set_state(State.JUMP if velocity.y < 0.0 else State.FALL)


func _set_state(new_state: State) -> void:
	if new_state == state:
		return
	var old := state
	state = new_state
	_play_animation()
	state_changed.emit(old, new_state)


func _play_animation() -> void:
	if not sprite.visible:
		return
	var anim: String = State.keys()[state].to_lower()   # IDLE -> "idle"
	if state == State.ATTACK and _attack != null and _attack.animation != "":
		anim = _attack.animation   # each move can have its own animation
	if sprite.sprite_frames.has_animation(anim):
		sprite.play(anim)


# ---------------------------------------------------------------- forms

## Form index -> input action that holds it. Index 0 (Regular Guy) is what you are with nothing held.
const HOLD_ACTIONS := {1: "hold_wendigo", 2: "hold_chupacabra"}


## Hold a button to be that form; let go to go back to Regular Guy.
## Both held: the one pressed last wins. If the form you want doesn't fit here
## (e.g. letting go of Chupacabra inside a tunnel), it keeps retrying and switches as soon as there's room.
func _handle_form_input() -> void:
	for i in HOLD_ACTIONS:
		if Input.is_action_just_pressed(HOLD_ACTIONS[i]):
			_last_held = i
	var desired := 0
	if _last_held != 0 and Input.is_action_pressed(HOLD_ACTIONS[_last_held]) and is_unlocked(_last_held):
		desired = _last_held
	else:
		for i in HOLD_ACTIONS:
			if Input.is_action_pressed(HOLD_ACTIONS[i]) and is_unlocked(i):
				desired = i
				break
	var new_request := desired != _last_desired   # only flash "blocked" once per request, not every frame
	_last_desired = desired
	if desired != form_index:
		try_switch_form(desired, new_request)


func is_unlocked(index: int) -> bool:
	return index < unlocked.size() and unlocked[index]


func unlock_form(index: int) -> void:
	while unlocked.size() <= index:
		unlocked.append(false)
	unlocked[index] = true


## Returns true if the switch happened.
func try_switch_form(index: int, show_blocked := true) -> bool:
	if index == form_index or index >= forms.size() or not is_unlocked(index):
		return false
	if _swap_timer > 0.0:
		return false
	if state == State.ATTACK and _attack_phase != AttackPhase.RECOVERY:
		return false
	if state == State.HURT:
		return false   # can't switch mid-swing; it happens as soon as recovery starts (DMC-style cancel)
	var offset = _find_fit_offset(forms[index].collision_size)
	if offset == null:
		if show_blocked:
			_flash(Color(1, 0.3, 0.3))   # no room for that form here
			swap_blocked.emit()
		return false
	global_position.x += offset
	_apply_form(index)
	_switch_bonus_timer = switch_bonus_time
	_swap_timer = swap_cooldown
	_pop()
	return true


func _apply_form(index: int) -> void:
	form_index = index
	form = forms[index]
	if state == State.CLIMB and not form.can_wall_climb:
		_set_state(State.FALL)   # let go of the wall
	if state == State.DASH and not form.can_dash:
		_end_dash()
	if state == State.ATTACK:
		_end_attack()   # switching cancels the recovery; the new form starts its own combo
	if state == State.SWING and not form.can_swing:
		_release_swing(false)   # e.g. swing, then hold RB to drop as the Wendigo
	var size := form.collision_size
	(collision.shape as RectangleShape2D).size = size
	collision.position = Vector2(0, -size.y / 2.0)   # keep the box standing on the feet
	# Hurtbox a bit smaller than the body, so near-misses don't count as hits
	(hurt_shape.shape as RectangleShape2D).size = (size - Vector2(4, 4)).max(Vector2(4, 4))
	hurt_shape.position = collision.position

	# Placeholder rectangle until real art is assigned
	var hw := size.x / 2.0
	torso.polygon = PackedVector2Array([Vector2(-hw, -size.y), Vector2(hw, -size.y), Vector2(hw, 0), Vector2(-hw, 0)])
	torso.color = form.placeholder_color
	eye.position = Vector2(hw - 7.0, -size.y + 5.0)

	var has_art := form.sprite_frames != null
	sprite.visible = has_art
	torso.visible = not has_art
	eye.visible = not has_art
	if has_art:
		sprite.sprite_frames = form.sprite_frames
		_play_animation()
	form_changed.emit(form)


## Checks whether a body of `size` fits where the player stands.
## Tries the current spot, then nudges left/right (for widening next to a wall).
## Returns the x offset that fits, or null if none does.
func _find_fit_offset(size: Vector2) -> Variant:
	var shape := RectangleShape2D.new()
	shape.size = size - Vector2(2, 2)   # tiny margin so resting on the floor doesn't count as overlapping
	var params := PhysicsShapeQueryParameters2D.new()
	params.shape = shape
	params.collision_mask = collision_mask
	params.exclude = [get_rid()]
	var space := get_world_2d().direct_space_state
	var current_width := (collision.shape as RectangleShape2D).size.x
	var nudge := maxf(size.x - current_width, 0.0) / 2.0 + 1.0
	for offset_x: float in [0.0, -nudge, nudge]:
		params.transform = Transform2D(0.0, global_position + Vector2(offset_x, -size.y / 2.0 - 1.0))
		if space.intersect_shape(params, 1).is_empty():
			return offset_x
	return null


func _pop() -> void:
	body.scale = Vector2(facing * 1.25, 0.8)
	var t := create_tween()
	t.tween_property(body, "scale", Vector2(facing, 1.0), 0.12)
	_flash(Color(1.6, 1.6, 1.6))


func _flash(color: Color) -> void:
	body.modulate = color
	create_tween().tween_property(body, "modulate", Color.WHITE, 0.15)


# ---------------------------------------------------------------- movement

func _update_timers(delta: float) -> void:
	_swap_timer = maxf(_swap_timer - delta, 0.0)
	_wall_jump_lock = maxf(_wall_jump_lock - delta, 0.0)
	_dash_cooldown_timer = maxf(_dash_cooldown_timer - delta, 0.0)
	_switch_bonus_timer = maxf(_switch_bonus_timer - delta, 0.0)
	_iframe_timer = maxf(_iframe_timer - delta, 0.0)
	if Input.is_action_just_pressed("attack"):
		_attack_buffer_timer = attack_buffer_time
	else:
		_attack_buffer_timer = maxf(_attack_buffer_timer - delta, 0.0)
	if is_on_floor():
		_coyote_timer = coyote_time
		_air_hang_charges = 1
		_refill_dashes(false)   # runs every frame on the ground: don't wipe the cooldown
	else:
		_coyote_timer = maxf(_coyote_timer - delta, 0.0)
	if Input.is_action_just_pressed("jump"):
		_jump_buffer_timer = jump_buffer_time
	else:
		_jump_buffer_timer = maxf(_jump_buffer_timer - delta, 0.0)


func _handle_jump(delta: float) -> void:
	if _jump_buffer_timer > 0.0 and _coyote_timer > 0.0:
		_is_jumping = true
		_jump_hold_timer = 0.0
		_jump_buffer_timer = 0.0
		_coyote_timer = 0.0
	if not _is_jumping:
		return
	_jump_hold_timer += delta
	var held := Input.is_action_pressed("jump")
	if _jump_hold_timer < form.min_hold_time or (held and _jump_hold_timer < form.max_hold_time):
		velocity.y = -form.jump_speed
	elif not held:
		_end_jump()
	else:
		_is_jumping = false


func _end_jump() -> void:
	_is_jumping = false
	if velocity.y < 0.0:
		velocity.y = 0.0


func _apply_gravity(delta: float) -> void:
	if _is_jumping or is_on_floor():
		return
	velocity.y = minf(velocity.y + form.gravity * delta, form.max_fall_speed)


func _handle_run(update_facing := true) -> void:
	if _wall_jump_lock > 0.0:
		velocity.x = _wall_jump_dir * form.wall_jump_push   # keep flying away from the wall
		return
	# signf: analog stick acts digital (always full speed), like Hollow Knight
	var dir := signf(Input.get_axis("move_left", "move_right"))
	if _launched:
		if is_on_floor() or is_on_wall():
			_launched = false
		else:
			_steer_launch(dir, get_physics_process_delta_time())
			return
	if dir != 0.0 and update_facing:
		facing = signf(dir)
	velocity.x = dir * form.run_speed


# ---------------------------------------------------------------- wall climb (Wendigo)

## Grab a wall when: form can climb, touching a wall, holding toward it,
## and either in the air or pressing up.
func _try_start_climb() -> void:
	if not form.can_wall_climb or not is_on_wall() or _wall_jump_lock > 0.0:
		return
	var wall_side := -get_wall_normal().x                 # normal points away from the wall
	var dir := signf(Input.get_axis("move_left", "move_right"))
	if dir != wall_side:
		return
	if is_on_floor() and not Input.is_action_pressed("move_up"):
		return
	_wall_dir = wall_side
	_is_jumping = false
	_launched = false
	_air_hang_charges = 1
	velocity = Vector2.ZERO
	facing = _wall_dir
	_set_state(State.CLIMB)


func _climb_move() -> void:
	# Jump: kick off away from the wall. Holding jump still controls the height.
	if _jump_buffer_timer > 0.0:
		_jump_buffer_timer = 0.0
		_coyote_timer = 0.0
		_wall_jump_dir = -_wall_dir
		_wall_jump_lock = form.wall_jump_lock_time
		facing = _wall_jump_dir
		_is_jumping = true
		_jump_hold_timer = 0.0
		velocity = Vector2(_wall_jump_dir * form.wall_jump_push, -form.jump_speed)
		_set_state(State.JUMP)
		return

	# Pushing away from the wall: let go.
	var dir := signf(Input.get_axis("move_left", "move_right"))
	if dir == -_wall_dir:
		_set_state(State.FALL)
		return

	var climb := signf(Input.get_axis("move_up", "move_down"))
	velocity.y = climb * form.climb_speed   # no input = hold still
	velocity.x = _wall_dir * 60.0           # press into the wall so is_on_wall() stays true


func _climb_check() -> void:
	if state != State.CLIMB:
		return
	if is_on_floor() and velocity.y > 0.0:
		_set_state(State.IDLE)               # climbed down to the ground
	elif not is_on_wall():
		if velocity.y < 0.0:
			velocity.y = -form.ledge_hop_speed   # reached the top: hop over the edge
			velocity.x = _wall_dir * form.run_speed
		_set_state(State.FALL)


# ---------------------------------------------------------------- dash (Chupacabra)

## Special: quick burst in the held direction (or facing). No gravity during it.
## Returns true if a dash started this frame.
func _try_start_dash() -> bool:
	if not form.can_dash or _dash_cooldown_timer > 0.0:
		return false
	if not Input.is_action_just_pressed("special"):
		return false
	if not is_on_floor():
		if _air_dashes_left <= 0:
			return false
		_air_dashes_left -= 1
	var dir := signf(Input.get_axis("move_left", "move_right"))
	_dash_dir = dir if dir != 0.0 else facing
	facing = _dash_dir
	_is_jumping = false
	_launched = false
	_dash_timer = form.dash_time
	_ghost_timer = 0.0
	velocity = Vector2(_dash_dir * form.dash_speed, 0.0)
	_set_state(State.DASH)
	return true


func _dash_move(delta: float) -> void:
	_dash_timer -= delta
	_ghost_timer -= delta
	if _ghost_timer <= 0.0:
		_spawn_ghost()
		_ghost_timer = 0.03

	# Ground dash can be cancelled into a jump (keeps the dash feeling responsive)
	if _jump_buffer_timer > 0.0 and _coyote_timer > 0.0:
		_end_dash()
		_handle_jump(delta)
		_handle_run()
		return

	if _dash_timer <= 0.0:
		_end_dash()
		_apply_gravity(delta)
		_handle_run()
		return

	velocity = Vector2(_dash_dir * form.dash_speed, 0.0)


## Gives back the air dash (and optionally clears its cooldown). Uses the dashing form's count,
## so it works even when you refill as the Regular Guy (e.g. grabbing a hook).
func _refill_dashes(clear_cooldown := true) -> void:
	var count := 0
	for f in forms:
		if f.can_dash:
			count = maxi(count, f.air_dashes)
	_air_dashes_left = count
	if clear_cooldown:
		_dash_cooldown_timer = 0.0


func _end_dash() -> void:
	_dash_cooldown_timer = form.dash_cooldown
	_set_state(State.FALL)   # _update_state picks the real state (idle/run/fall) right after


## Fading afterimage left behind during a dash.
func _spawn_ghost() -> void:
	var parent := get_parent()
	if parent == null:
		return
	var ghost := body.duplicate() as Node2D
	parent.add_child(ghost)
	ghost.global_position = body.global_position
	ghost.scale = body.scale
	ghost.z_index = -1
	ghost.modulate = Color(1, 1, 1, 0.4)
	var t := ghost.create_tween()
	t.tween_property(ghost, "modulate:a", 0.0, 0.15)
	t.tween_callback(ghost.queue_free)


# ---------------------------------------------------------------- swing (Regular Guy)

func _center() -> Vector2:
	return global_position + Vector2(0, -form.collision_size.y / 2.0)


## Pick the closest grapple point that's above you, in range, and not behind a wall.
## That one gets highlighted so the player knows Special will grab it.
func _update_grapple_target() -> void:
	var best: GrapplePoint = null
	if form.can_swing and state != State.SWING:
		var c := _center()
		var best_d := form.swing_range
		var space := get_world_2d().direct_space_state
		for node in get_tree().get_nodes_in_group("grapple_points"):
			var point := node as GrapplePoint
			if point == null:
				continue
			var gp := point.global_position
			if gp.y > c.y:
				continue   # only points above you
			var d := c.distance_to(gp)
			if d >= best_d:
				continue
			var ray := PhysicsRayQueryParameters2D.create(c, gp, collision_mask, [get_rid()])
			if not space.intersect_ray(ray).is_empty():
				continue   # wall in the way
			best = point
			best_d = d
	if best != _grapple_target:
		if is_instance_valid(_grapple_target):
			_grapple_target.highlighted = false
		_grapple_target = best
		if best != null:
			best.highlighted = true


func _try_start_swing() -> bool:
	if not form.can_swing or _grapple_target == null:
		return false
	if not Input.is_action_just_pressed("special"):
		return false
	_anchor = _grapple_target.global_position
	# Start slightly shorter than the real distance so the rope pulls tight right away
	_rope_length = maxf(_center().distance_to(_anchor) * 0.9, form.min_rope_length)
	_is_jumping = false
	_launched = false
	_refill_dashes()   # grabbing a hook gives the air dash back, so swing -> dash -> swing chains
	_air_hang_charges = 1
	_set_state(State.SWING)
	return true


func _swing_move(delta: float) -> void:
	# Jump: let go with an upward boost. Releasing Special: let go, keep momentum.
	if _jump_buffer_timer > 0.0:
		_jump_buffer_timer = 0.0
		_release_swing(true)
		return
	if not Input.is_action_pressed("special"):
		_release_swing(false)
		return

	var dir := signf(Input.get_axis("move_left", "move_right"))
	if dir != 0.0:
		facing = dir
	velocity.y += form.swing_gravity * delta
	velocity.x += dir * form.swing_pump * delta   # pump the swing

	var reel := signf(Input.get_axis("move_up", "move_down"))
	_rope_length = clampf(_rope_length + reel * form.reel_speed * delta, form.min_rope_length, form.swing_range)

	# Rope is taut: remove any velocity pointing away from the anchor.
	# What's left is the tangent (sideways) part, which is what makes it swing.
	var r := (_center() - _anchor).normalized()
	var outward := velocity.dot(r)
	if outward > 0.0:
		velocity -= r * outward
	velocity = velocity.limit_length(form.max_swing_speed)


## After moving, pull the player back onto the rope circle if they drifted past it.
func _swing_constrain() -> void:
	var to_player := _center() - _anchor
	var d := to_player.length()
	if d > _rope_length:
		move_and_collide(-to_player.normalized() * (d - _rope_length))


func _release_swing(jumped: bool) -> void:
	_set_state(State.FALL)
	_launched = true
	if jumped:
		velocity.y = minf(velocity.y, 0.0) - form.swing_jump_boost


## Air steering after a swing: you keep your speed, and holding a direction slowly bends it.
## Holding forward never slows you below your swing speed.
func _steer_launch(dir: float, delta: float) -> void:
	if dir == 0.0:
		return
	facing = dir
	if signf(velocity.x) == dir and absf(velocity.x) > form.run_speed:
		return
	velocity.x = move_toward(velocity.x, dir * form.run_speed, form.launch_air_control * delta)


func _update_rope() -> void:
	if state == State.SWING:
		_rope.points = PackedVector2Array([_center(), _anchor])
	elif _rope.get_point_count() > 0:
		_rope.clear_points()


# ---------------------------------------------------------------- combat
# Which move comes out (checked in this order):
#   holding up               -> up_attack (launcher)
#   holding down, in the air -> down_air_attack (stomp / dive / slam)
#   holding left/right, on the ground -> forward_attack (lunge)
#   otherwise                -> next hit of combo (ground) or air_combo (air)
# During a move's recovery you can chain into any of these, jump, dash, or switch forms.

func _try_start_attack() -> bool:
	if _attack_buffer_timer <= 0.0:
		return false
	var pick := _choose_attack(false)
	if pick.is_empty():
		return false
	_attack_buffer_timer = 0.0
	_start_move(pick)
	return true


## Returns {move, key, index} or {} if nothing should come out.
func _choose_attack(continuing: bool) -> Dictionary:
	var grounded := is_on_floor()
	var horiz := signf(Input.get_axis("move_left", "move_right"))
	if Input.is_action_pressed("move_up") and form.up_attack != null:
		return {move = form.up_attack, key = "", index = 0}
	if not grounded and Input.is_action_pressed("move_down") and form.down_air_attack != null:
		return {move = form.down_air_attack, key = "", index = 0}
	if grounded and horiz != 0.0 and form.forward_attack != null:
		facing = horiz   # lunge the way you're holding
		return {move = form.forward_attack, key = "", index = 0}
	var use_air := not grounded and not form.air_combo.is_empty()
	var key := "air" if use_air else "combo"
	var chain: Array = form.air_combo if use_air else form.combo
	var index := 0
	if continuing and _chain_key == key:
		index = _combo_index + 1
	if index >= chain.size():
		return {}   # combo finished: wait for recovery to end
	return {move = chain[index], key = key, index = index}


func _start_move(pick: Dictionary) -> void:
	_attack = pick.move
	_chain_key = pick.key
	_combo_index = pick.index
	_is_jumping = false
	_launched = false
	_slam_landed = false
	hitbox.radial = false
	# Air hang: the first hit of an air string spends the charge; later hits in that string keep it
	var airborne := not is_on_floor()
	if _combo_index == 0:
		_hanging = airborne and _attack.air_hang and _air_hang_charges > 0
		if _hanging:
			_air_hang_charges -= 1
	else:
		_hanging = _hanging and airborne and _attack.air_hang
	if _hanging:
		velocity.y = minf(velocity.y, 0.0)   # stop falling (keep rising if you were)
	if _attack.slam:
		velocity = Vector2.ZERO
	_attack_phase = AttackPhase.STARTUP
	_attack_timer = _attack.startup
	_set_state(State.ATTACK)
	_play_animation()   # restart it for each hit of a combo


func _attack_move(delta: float) -> void:
	_attack_timer -= delta
	match _attack_phase:
		AttackPhase.STARTUP:
			if _attack.slam:
				velocity = Vector2.ZERO   # hang in the air for a moment before slamming down
			if _attack_timer <= 0.0:
				_activate_hitbox()
		AttackPhase.ACTIVE:
			if _attack.slam and not _slam_landed:
				velocity = Vector2(0.0, SLAM_SPEED)
				if is_on_floor():
					_slam_shockwave()
				return   # plummeting: no other movement
			var landed_dive := _attack.lunge.y > 0.0 and is_on_floor()
			if _attack_timer <= 0.0 or landed_dive:
				_to_recovery()
		AttackPhase.RECOVERY:
			if _attack_buffer_timer > 0.0:
				var pick := _choose_attack(true)
				if not pick.is_empty():
					_attack_buffer_timer = 0.0
					_start_move(pick)
			if _attack_phase == AttackPhase.RECOVERY:   # (didn't chain above)
				if _jump_buffer_timer > 0.0 and _coyote_timer > 0.0:
					_end_attack()
					_handle_jump(delta)
				elif form.can_dash and Input.is_action_just_pressed("special"):
					_end_attack()
					if _try_start_dash():
						return
				elif _attack_timer <= 0.0:
					_end_attack()

	if state != State.ATTACK:
		_apply_gravity(delta)
		_handle_run()
		return
	var lunging := _attack.lunge != Vector2.ZERO and _attack_phase != AttackPhase.RECOVERY
	if lunging:
		velocity.x = facing * _attack.lunge.x
		if _attack.lunge.y != 0.0:
			velocity.y = _attack.lunge.y
	elif is_on_floor():
		velocity.x = 0.0          # ground attacks root you
	else:
		_handle_run(false)        # air control, but no turning around mid-swing
	if _hanging:
		velocity.y = minf(velocity.y + form.gravity * HANG_GRAVITY_SCALE * delta, HANG_MAX_FALL)
	elif not (lunging and _attack.lunge.y != 0.0):
		_apply_gravity(delta)


func _activate_hitbox() -> void:
	_attack_phase = AttackPhase.ACTIVE
	_attack_timer = _attack.active
	var bonus := _switch_bonus_timer > 0.0
	var dmg := _attack.damage * (switch_bonus_multiplier if bonus else 1.0)
	var size := Vector2(_attack.reach, _attack.height)
	var x := 0.0
	if not _attack.centered:
		x = facing * ((form.collision_size.x + size.x) / 2.0 + _attack.offset.x)
	_place_hitbox(Vector2(x, -form.collision_size.y / 2.0 + _attack.offset.y), size)
	var kb := Vector2(facing * _attack.knockback.x, _attack.knockback.y)
	if _attack.slam:
		kb = Vector2(0.0, 600.0)   # while falling, spike anything below; the shockwave uses the move's knockback
	hitbox.activate(dmg, kb, bonus, _attack.hitstun)
	_show_slash(size, bonus)

	# Launchers: rise with the enemy so you meet it at the top (DMC "High Time")
	if _attack.follow_launch == 2 or (_attack.follow_launch == 1 and Input.is_action_pressed("jump")):
		velocity.y = -_launch_follow_speed(_attack.knockback.y)
		_air_hang_charges = 1
		_jump_buffer_timer = 0.0   # the jump press was used for following, not for a jump-cancel
		_coyote_timer = 0.0


## Same height as the launched enemy despite different gravity:
##   enemy rises h = v_e² / (2 g_e);  you need v_p = sqrt(2 g_p h) = |v_e| * sqrt(g_p / g_e)
func _launch_follow_speed(enemy_launch_y: float) -> float:
	return absf(enemy_launch_y) * sqrt(form.gravity / Enemy.JUGGLE_GRAVITY)


func _slam_shockwave() -> void:
	_slam_landed = true
	_attack_timer = _attack.active
	var size := Vector2(_attack.slam_radius * 2.0, 40.0)
	_place_hitbox(Vector2(0.0, -20.0), size)
	hitbox.radial = true   # push everything away from where you landed
	hitbox.activate(_attack.damage, _attack.knockback, false, _attack.hitstun)
	_show_slash(size, false)
	_shake = maxf(_shake, _attack.screen_shake)


func _place_hitbox(pos: Vector2, size: Vector2) -> void:
	hitbox.position = pos
	(hitbox.shape.shape as RectangleShape2D).size = size


## Placeholder slash showing the exact hit area. Gold = switch bonus.
func _show_slash(size: Vector2, bonus: bool) -> void:
	var h := size / 2.0
	slash.polygon = PackedVector2Array([Vector2(-h.x, -h.y), Vector2(h.x, -h.y), Vector2(h.x, h.y), Vector2(-h.x, h.y)])
	slash.color = Color(1, 0.8, 0.25, 0.5) if bonus else Color(1, 1, 1, 0.35)
	slash.visible = true


func _to_recovery() -> void:
	hitbox.deactivate()
	slash.visible = false
	_attack_phase = AttackPhase.RECOVERY
	_attack_timer = _attack.recovery


func _end_attack() -> void:
	hitbox.deactivate()
	hitbox.radial = false
	slash.visible = false
	_combo_index = 0
	_chain_key = ""
	_hanging = false
	_set_state(State.FALL)   # _update_state picks the real state right after


func _on_hit_landed(_hurt: Hurtbox) -> void:
	_switch_bonus_timer = 0.0   # bonus is used up by the first hit that connects
	Juice.hitstop(self, _attack.hitstop)
	_shake = maxf(_shake, _attack.screen_shake)
	if _attack.pogo > 0.0 and state == State.ATTACK:
		# Bounce off (Hollow Knight pogo): up you go, dash and air hang refreshed
		velocity.y = -_attack.pogo
		_refill_dashes()
		_air_hang_charges = 1
		_to_recovery()


func _process(delta: float) -> void:
	# Blink while invincible after a hit (self_modulate so it doesn't fight the flash/death fade)
	if _iframe_timer > 0.0 and not _dead:
		body.self_modulate.a = 0.3 if fmod(_iframe_timer, 0.14) < 0.07 else 1.0
	elif body.self_modulate.a != 1.0:
		body.self_modulate.a = 1.0
	# Camera shake (decays quickly)
	if _shake > 0.0:
		_shake = maxf(_shake - 30.0 * delta, 0.0)
		camera.offset = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * _shake
	elif camera.offset != Vector2.ZERO:
		camera.offset = Vector2.ZERO


# ---------------------------------------------------------------- getting hit

func set_checkpoint(pos: Vector2) -> void:
	respawn_position = pos


## Hurtbox got hit. Health is Hollow Knight-style squares (5 by default); enemies deal 1 per hit.
## Damage is divided by the form's health_multiplier and rounded to half squares:
## Regular Guy 1, Wendigo (2.0) 0.5, Chupacabra (0.6) 1.5. Never less than half a square.
func _on_hurt(damage: float, _knockback: Vector2, source: Hitbox) -> void:
	if _dead:
		return
	# Knocked away from whatever hit you (Hollow Knight style: fixed strength, not the attacker's)
	var from_x := source.global_position.x if source != null else global_position.x + facing
	var dir := signf(global_position.x - from_x)
	if dir == 0.0:
		dir = -facing

	# Drop whatever you were doing
	match state:
		State.ATTACK:
			_end_attack()
		State.SWING:
			_release_swing(false)
		State.DASH:
			_end_dash()
	_is_jumping = false
	_launched = false

	_iframe_timer = invincibility_time
	health.take_damage(maxf(snappedf(damage / form.health_multiplier, 0.5), 0.5))
	if _dead:
		return   # _on_died already took over
	velocity = Vector2(dir * hurt_knockback.x, hurt_knockback.y)
	_hurt_timer = hurt_time
	_set_state(State.HURT)
	_flash(Color(1, 0.25, 0.25))
	Juice.hitstop(self, 0.08)
	_shake = maxf(_shake, 5.0)


func _hurt_move(delta: float) -> void:
	_hurt_timer -= delta
	_apply_gravity(delta)
	if is_on_floor():
		velocity.x = move_toward(velocity.x, 0.0, 1500.0 * delta)
	if _hurt_timer <= 0.0 and not _dead:
		_set_state(State.FALL)


func _on_died() -> void:
	_dead = true
	died.emit()
	_set_state(State.HURT)
	velocity.x = 0.0
	create_tween().tween_property(body, "modulate:a", 0.0, 0.4)
	await get_tree().create_timer(respawn_delay).timeout
	global_position = respawn_position
	velocity = Vector2.ZERO
	health.heal_full()
	body.modulate.a = 1.0
	_dead = false
	_iframe_timer = invincibility_time   # a moment of safety after respawning
	_set_state(State.FALL)
