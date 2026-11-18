extends CanvasLayer
## Hollow Knight-style health squares + current form name. Finds the player through the "player" group.

@onready var masks: MaskBar = $Margin/VBox/Masks
@onready var form_label: Label = $Margin/VBox/FormLabel


func _ready() -> void:
	_connect_player.call_deferred()   # wait a frame so the player has run its _ready


func _connect_player() -> void:
	var player := get_tree().get_first_node_in_group("player")
	if player == null:
		push_warning("HUD: no node in group 'player'")
		return
	player.health.changed.connect(_on_health_changed)
	player.form_changed.connect(_on_form_changed)
	masks.max_value = player.health.max_health
	masks.value = player.health.current
	_on_form_changed(player.form)


func _on_health_changed(current: float, max_value: float) -> void:
	masks.max_value = max_value
	masks.value = current


func _on_form_changed(form: FormData) -> void:
	form_label.text = form.form_name
