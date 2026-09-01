extends Node

const ZOMBIE_SCENE := preload("res://scenes/zombie/zombie.tscn")

@export var interval := 4.0
@export var max_zombies := 60
@export var min_dist := 14.0
@export var max_dist := 24.0
## 호드 크기별 가중치(인덱스+1마리). 1~2마리 호드가 대부분, 3~4마리는 극히 드묾.
@export var horde_size_weights: Array[int] = [45, 52, 2, 1]
@export var horde_spread := 2.2
## 이 거리를 벗어난 좀비는 보상 없이 제거(카메라 최대 줌 13m의 화면 밖 거리).
## 상한(60)이 먼 좀비로 영구 채워져 스폰이 멎는 문제를 막는다.
@export var despawn_dist := 40.0

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
	var alive := _prune_far(player)
	var size := _roll_horde_size()
	var ang := randf() * TAU
	var d := randf_range(min_dist, max_dist)
	var center := player.global_position + Vector3(cos(ang) * d, 0.0, sin(ang) * d)
	for i in size:
		if alive.size() >= max_zombies and not _pop_farthest(alive, player):
			return
		var z := ZOMBIE_SCENE.instantiate()
		z.variant_index = randi_range(-1, Zombie.VARIANT_SCENES.size() - 1)
		get_parent().add_child(z)
		var offset := Vector3.ZERO
		if i > 0:
			offset = Vector3(randf_range(-1.0, 1.0), 0.0, randf_range(-1.0, 1.0)).normalized() * randf_range(0.8, horde_spread)
		z.global_position = center + offset
		alive.append(z)


## 플레이어에서 멀어진 좀비를 보상 없이 제거하고 살아남은 목록을 돌려준다.
func _prune_far(player: Node3D) -> Array:
	var keep: Array = []
	for z in get_tree().get_nodes_in_group("zombies"):
		if not is_instance_valid(z) or z.is_queued_for_deletion():
			continue
		if z.global_position.distance_to(player.global_position) > despawn_dist:
			z.queue_free()
		else:
			keep.append(z)
	return keep


## 상한 도달 시 가장 먼 좀비 한 마리를 비워 교체 스폰 자리를 만든다.
func _pop_farthest(alive: Array, player: Node3D) -> bool:
	var farthest: Node3D = null
	var best := -1.0
	for z in alive:
		if not is_instance_valid(z) or z.is_queued_for_deletion():
			continue
		var d: float = z.global_position.distance_to(player.global_position)
		if d > best:
			best = d
			farthest = z
	if farthest == null:
		return false
	farthest.queue_free()
	alive.erase(farthest)
	return true
