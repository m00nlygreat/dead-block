extends Node

const CONTAINER_SCENE := preload("res://scenes/world/loot_container.tscn")

@export var container_scene: PackedScene
@export var tables: Array[LootTable] = []
@export var interval := 10.0
@export var max_containers := 18
@export var min_dist := 16.0
@export var max_dist := 30.0

var _t := 0.0


func _scene() -> PackedScene:
	return container_scene if container_scene != null else CONTAINER_SCENE


func _process(delta: float) -> void:
	_t += delta
	if _t < interval:
		return
	_t = 0.0
	_try_spawn()


func _live_count() -> int:
	var n := 0
	for c in get_tree().get_nodes_in_group("containers"):
		if is_instance_valid(c) and c.can_interact():
			n += 1
	return n


func _try_spawn() -> void:
	if tables.is_empty() or _live_count() >= max_containers:
		return
	var player: Node3D = get_tree().get_first_node_in_group("player")
	if player == null:
		return
	var ang := randf() * TAU
	var d := randf_range(min_dist, max_dist)
	var c := _scene().instantiate()
	c.loot_table = tables[randi() % tables.size()]
	get_parent().add_child(c)
	c.global_position = player.global_position + Vector3(cos(ang) * d, 0.0, sin(ang) * d)
