extends Area3D

@export var value := 1


func _ready() -> void:
	add_to_group("coins")
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node3D) -> void:
	if not body.is_in_group("player"):
		return
	GameState.add_coins(value)
	set_deferred("monitoring", false)
	queue_free()
