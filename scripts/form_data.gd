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

@export_group("Crossbow")
@export var can_shoot := false                 ## crossbow + tether bolt (Regular Guy)
@export var shot_cooldown := 0.18              ## s between tap shots (mash to fire fast)
@export var bolt_speed := 950.0
@export var bolt_damage := 2.0                 ## tap bolts are weak: they keep juggles going
@export var charge_time := 0.7                 ## s holding Shoot for a charged bolt
@export var charged_bolt_damage := 14.0        ## charged bolts pierce and knock back hard
@export var tether_range := 280.0              ## px; Special pulls you to your target within this
@export var tether_speed := 950.0

@export_group("Combat")
@export var health_multiplier := 1.0           ## damage taken is divided by this
@export var combo: Array[AttackData] = []      ## ground combo, in order (Attack)
@export var air_combo: Array[AttackData] = []  ## air combo, in order (Attack in the air)
@export var forward_attack: AttackData         ## Attack while holding left/right on the ground
@export var up_attack: AttackData              ## Attack while holding up (launcher)
@export var down_air_attack: AttackData        ## Attack while holding down in the air
@export var pause_finisher: AttackData         ## pause combo: wait a beat after combo hit `pause_after`, then Attack
@export var pause_after := 1                   ## combo index (0 = first hit) the pause comes after

@export_group("Art")
## Set this when the animations are ready. Expected names: idle, run, jump, fall, climb, dash, swing, attack
@export var sprite_frames: SpriteFrames
