extends Node

const ZOMBIE_SCENE := preload("res://scenes/zombie/zombie.tscn")

@export var interval := 5.0
@export var max_zombies := 40
@export var min_dist := 14.0
@export var max_dist := 24.0

var _t := 0.0


func _process(delta: float) -> void:
	_t += delta
	if _t < interval:
		return
	_t = 0.0
	_try_spawn()


func _try_spawn() -> void:
	if get_tree().get_nodes_in_group("zombies").size() >= max_zombies:
		return
	var player: Node3D = get_tree().get_first_node_in_group("player")
	if player == null:
		return
	var ang := randf() * TAU
	var d := randf_range(min_dist, max_dist)
	var z := ZOMBIE_SCENE.instantiate()
	get_parent().add_child(z)
	z.global_position = player.global_position + Vector3(cos(ang) * d, 0.0, sin(ang) * d)
