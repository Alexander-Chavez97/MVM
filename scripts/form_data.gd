class_name FormData
extends Resource
## Stats for one shapeshifter form. Switching forms = swapping which FormData the player uses.
## Edit the .tres files in res://resources/forms/ to tune each form.

@export var form_name := "Form"

@export_group("Movement")
@export var run_speed := 250.0
@export var jump_speed := 450.0
@export var max_hold_time := 0.2
@export var min_hold_time := 0.06
@export var gravity := 2200.0
@export var max_fall_speed := 650.0

@export_group("Body")
@export var collision_size := Vector2(20, 40)  ## px; the box sits on the player's feet
@export var placeholder_color := Color.WHITE   ## used until real art exists

@export_group("Wall climb")
@export var can_wall_climb := false
@export var climb_speed := 140.0               ## px/s up/down while on a wall
@export var wall_jump_push := 260.0            ## px/s away from the wall
@export var wall_jump_lock_time := 0.15        ## s horizontal input is ignored after a wall jump
@export var ledge_hop_speed := 300.0           ## px/s upward boost when climbing over the top

@export_group("Dash")
@export var can_dash := false
@export var dash_speed := 700.0                ## px/s during the dash
@export var dash_time := 0.15                  ## s; distance = speed * time (105 px by default)
@export var dash_cooldown := 0.35              ## s after a dash ends
@export var air_dashes := 1                    ## dashes allowed before touching the ground again

@export_group("Swing")
@export var can_swing := false
@export var swing_range := 200.0               ## px; max distance to grab a grapple point
@export var swing_gravity := 1400.0            ## px/s² while on the rope
@export var swing_pump := 500.0                ## px/s² from holding left/right while swinging
@export var max_swing_speed := 750.0
@export var reel_speed := 150.0                ## px/s rope shortens/lengthens with up/down
@export var min_rope_length := 40.0
@export var swing_jump_boost := 300.0          ## px/s extra upward speed when jumping off the rope
@export var launch_air_control := 900.0        ## px/s² steering after letting go (momentum is kept)

@export_group("Combat")
@export var health_multiplier := 1.0
@export var attack_damage := 8.0
@export var attack_reach := 44.0               ## px the hitbox sticks out in front of the body
@export var attack_height := 36.0              ## px tall
@export var attack_startup := 0.08             ## s before the hit comes out
@export var attack_active := 0.08              ## s the hitbox is live
@export var attack_recovery := 0.15            ## s after; chain the next hit, jump, dash or switch forms here
@export var combo_length := 3                  ## hits in the combo; the last one is the finisher
@export var finisher_multiplier := 1.5         ## finisher damage and knockback
@export var knockback := 220.0                 ## px/s pushed on the target
@export var hitstop := 0.05                    ## s freeze-frame when a hit lands
@export var screen_shake := 2.0                ## px camera shake when a hit lands

@export_group("Art")
## Set this when the animations are ready. Expected names: idle, run, jump, fall, climb, dash, swing, attack
@export var sprite_frames: SpriteFrames
