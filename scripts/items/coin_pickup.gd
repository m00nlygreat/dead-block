extends MagnetPickup

## 이 거리를 벗어난 안 주운 코인은 놓친 코인으로 기록 후 제거(스포너 디스폰 거리와 동일)
const DESPAWN_DIST := 40.0

@export var value := 1


func _ready() -> void:
	add_to_group("coins")
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node3D) -> void:
	if not body.is_in_group("player"):
		return
	finish_collect()


func _physics_process(delta: float) -> void:
	super(delta)
	_despawn_if_far()


func _despawn_if_far() -> void:
	if _collected or _target != null:
		return
	var player: Node3D = get_tree().get_first_node_in_group("player")
	if player == null:
		return
	if global_position.distance_to(player.global_position) > DESPAWN_DIST:
		GameState.add_missed_coins(value)
		queue_free()


func _collect() -> void:
	GameState.add_coins(value)
