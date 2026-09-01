extends Node

const PLAYER_SCENE := preload("res://scenes/player/player.tscn")
const ZOMBIE_SCENE := preload("res://scenes/zombie/zombie.tscn")
const COIN_SCENE := preload("res://scenes/items/coin_pickup.tscn")
const SPAWNER_SCRIPT := preload("res://scripts/world/zombie_spawner.gd")


func _ready() -> void:
	_run()


func _ticks(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _floor(w: Node3D) -> void:
	var floor_body := StaticBody3D.new()
	floor_body.collision_layer = 1
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(400, 1, 400)
	cs.shape = bs
	cs.position.y = -0.5
	floor_body.add_child(cs)
	w.add_child(floor_body)


func _spawn_zombie(w: Node3D, pos: Vector3) -> Zombie:
	var z: Zombie = ZOMBIE_SCENE.instantiate()
	w.add_child(z)
	z.global_position = pos
	return z


func _zombies() -> Array:
	return get_tree().get_nodes_in_group("zombies")


func _coins() -> Array:
	return get_tree().get_nodes_in_group("coins")


func _run() -> void:
	var w := Node3D.new()
	add_child(w)
	_floor(w)
	var player := PLAYER_SCENE.instantiate()
	w.add_child(player)
	player.global_position = Vector3.ZERO
	await _ticks(5)
	GameState.reset_run_state()
	UpgradeManager.reset_run()

	var spawner := Node.new()
	spawner.set_script(SPAWNER_SCRIPT)
	spawner.max_zombies = 6
	var weights: Array[int] = [1, 0, 0, 0]
	spawner.horde_size_weights = weights
	w.add_child(spawner)

	# T1: 45m 밖 좀비는 스폰 사이클에 정리되고, 새 좀비만 남는다
	var far_z := _spawn_zombie(w, Vector3(45.0, 0.5, 0.0))
	await _ticks(2)
	spawner._try_spawn()
	await _ticks(3)
	print("T1_FAR_ZOMBIE_PRUNED: ",
		not is_instance_valid(far_z) or far_z.is_queued_for_deletion(),
		" count=", _zombies().size())

	# T2: 근거리 좀비는 다음 사이클에도 유지된다
	var kept_id: int = _zombies()[0].get_instance_id()
	spawner._try_spawn()
	await _ticks(3)
	var kept_alive := false
	for z in _zombies():
		if z.get_instance_id() == kept_id:
			kept_alive = true
	print("T2_NEAR_ZOMBIE_KEPT: ", kept_alive and _zombies().size() == 2)

	# T3: 상한 도달 시 가장 먼 좀비가 교체된다
	for i in 4:
		spawner._try_spawn()
	await _ticks(3)
	var cap_ok: bool = _zombies().size() == spawner.max_zombies
	var ids_before := {}
	var idx := 0
	for z in _zombies():
		z.global_position = Vector3(30.0, 0.5, float(idx % 4) * 0.5 - 0.75)
		idx += 1
		ids_before[z.get_instance_id()] = true
	spawner._try_spawn()
	await _ticks(3)
	var missing := 0
	var has_near := false
	for z in _zombies():
		if not ids_before.has(z.get_instance_id()):
			has_near = true
			continue
		missing += 1
	print("T3_REPLACE_FARTHEST_AT_CAP: ",
		cap_ok and _zombies().size() == 6 and missing == 5 and has_near,
		" (cap_fill=%s count=%d old_left=%d new=%s)" % [
			str(cap_ok), _zombies().size(), missing, str(has_near)])

	# T4: 디스폰된 좀비는 보상(코인·처치 수)이 없다
	print("T4_DESPAWN_NO_REWARD: ",
		GameState.coins == 0 and UpgradeManager.kills == 0)

	# T5: 40m 밖 안 주운 코인은 놓친 코인으로 기록 후 제거
	var coin_far := COIN_SCENE.instantiate()
	w.add_child(coin_far)
	coin_far.global_position = Vector3(50.0, 0.5, 0.0)
	await _ticks(3)
	print("T5_COIN_FAR_MISSED_RECORDED: ",
		(not is_instance_valid(coin_far) or coin_far.is_queued_for_deletion())
		and GameState.missed_coins == 1)

	# T6: 근거리 코인은 유지되고 기록도 불변
	var coin_near := COIN_SCENE.instantiate()
	w.add_child(coin_near)
	coin_near.global_position = Vector3(2.0, 0.5, 0.0)
	await _ticks(3)
	print("T6_COIN_NEAR_KEPT: ",
		_coin_nodes_valid() and GameState.missed_coins == 1,
		" coins=", _coins().size(), " missed=", GameState.missed_coins)

	# T7: 런 리셋 시 놓친 코인 기록 초기화
	GameState.reset_run_state()
	print("T7_RESET_CLEARS_MISSED: ", GameState.missed_coins == 0)

	print("M61_SMOKE_DONE")
	get_tree().quit(0)


func _coin_nodes_valid() -> bool:
	return _coins().size() > 0
