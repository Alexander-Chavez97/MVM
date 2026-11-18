class_name Juice
## Small game-feel helpers.


## Freeze-frame on hit: slows the whole game almost to a stop for `duration` real seconds.
static func hitstop(node: Node, duration: float) -> void:
	if duration <= 0.0 or not node.is_inside_tree():
		return
	Engine.time_scale = 0.05
	# process_always = true, in_physics = false, ignore_time_scale = true -> counts real time
	await node.get_tree().create_timer(duration, true, false, true).timeout
	Engine.time_scale = 1.0
