extends Node

const ZOMBIE_SCENE := preload("res://scenes/zombie/zombie.tscn")

@export var interval := 4.0
@export var max_zombies := 60
@export var min_dist := 14.0
@export var max_dist := 24.0
## 호드 크기별 가중치(인덱스+1마리). 1~2마리 호드가 대부분, 3~4마리는 극히 드묾.
@export var horde_size_weights: Array[int] = [45, 52, 2, 1]
@export var horde_spread := 2.2

var _t := 0.0


func _process(delta: float) -> void:
	_t += delta
	if _t < interval:
		return
	_t = 0.0
	_try_spawn()


func _roll_horde_size() -> int:
	var total := 0
	for w in horde_size_weights:
		total += w
	if total <= 0:
		return 1
	var roll := randi() % total
	for i in horde_size_weights.size():
		roll -= horde_size_weights[i]
		if roll < 0:
			return i + 1
	return 1


func _try_spawn() -> void:
	var player: Node3D = get_tree().get_first_node_in_group("player")
	if player == null:
		return
	var size := _roll_horde_size()
	var ang := randf() * TAU
	var d := randf_range(min_dist, max_dist)
	var center := player.global_position + Vector3(cos(ang) * d, 0.0, sin(ang) * d)
	for i in size:
		if get_tree().get_nodes_in_group("zombies").size() >= max_zombies:
			return
		var z := ZOMBIE_SCENE.instantiate()
		get_parent().add_child(z)
		var offset := Vector3.ZERO
		if i > 0:
			offset = Vector3(randf_range(-1.0, 1.0), 0.0, randf_range(-1.0, 1.0)).normalized() * randf_range(0.8, horde_spread)
		z.global_position = center + offset
