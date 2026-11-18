class_name AttackData
extends Resource
## One move: a combo hit, a launcher, a lunge, a slam...
## Each form's moves live inside its .tres in res://resources/forms/ (expand them in the Inspector to tune).
## Knockback and lunge use x = forward (toward facing), y = up (negative) / down (positive).

@export var move_name := "Attack"
@export var animation := "attack"          ## animation to play if the form has art

@export_group("Hitbox")
@export var damage := 8.0
@export var reach := 44.0                  ## px wide
@export var height := 36.0                 ## px tall
@export var offset := Vector2.ZERO         ## extra offset from the default spot (x forward, y down)
@export var centered := false              ## hitbox on the body instead of in front (stomps, slams)

@export_group("Timing")
@export var startup := 0.08                ## s before the hit comes out
@export var active := 0.08                 ## s the hitbox is live
@export var recovery := 0.15               ## s after; chain, jump, dash or switch forms here

@export_group("On hit")
@export var knockback := Vector2(200, -60)
@export var hitstun := 0.35                ## s the enemy is stunned
@export var hitstop := 0.05                ## s freeze-frame
@export var screen_shake := 2.0

@export_group("Movement")
@export var lunge := Vector2.ZERO          ## px/s you move during startup + active (x forward, y down)
@export var air_hang := false              ## in the air: stall your fall so air combos keep you up
@export_enum("Never", "If jump held", "Always") var follow_launch := 0   ## rise with a launcher
@export var pogo := 0.0                    ## on hit: bounce up at this speed (and refresh your dash)
@export var slam := false                  ## plummet until landing, then a shockwave
@export var slam_radius := 110.0           ## px each side of the shockwave
