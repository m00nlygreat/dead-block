extends Node

## m72: 좀비 추적 우회 + 스폰 겹침 방지.
## - T1: 건물 벽(6m 폭)이 가로막아도 CHASE 좀비가 우회해 플레이어에 접근한다.
## - T2: 뭉친 좀비의 separation 벡터가 0이 아니다(겹침 방지).
## - T3: 구조물 내부 좌표는 is_spawn_free == false, 바깥은 true.
## - T4: 스폰된 좀비가 구조물과 겹치지 않는다.

const PLAYER_SCENE := preload("res://scenes/player/player.tscn")
const ZOMBIE_SCENE := preload("res://scenes/zombie/zombie.tscn")
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


func _wall(w: Node3D, pos: Vector3, size: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	body.add_child(cs)
	w.add_child(body)
	body.global_position = pos
	return body


func _spawn_zombie(w: Node3D, pos: Vector3) -> Zombie:
	var z: Zombie = ZOMBIE_SCENE.instantiate()
	w.add_child(z)
	z.global_position = pos
	return z


func _run() -> void:
	var w := Node3D.new()
	add_child(w)
	_floor(w)
	var player: CharacterBody3D = PLAYER_SCENE.instantiate()
	w.add_child(player)
	player.global_position = Vector3(0, 0, 10)
	player.hp = 10000.0
	player.max_hp = 10000.0
	await _ticks(5)

	# T1: 폭 6m 벽을 사이에 두고 추적 — 우회하면 공격 범위까지 접근한다.
	_wall(w, Vector3(0, 1, 5), Vector3(6, 2, 0.5))
	var z1: Zombie = _spawn_zombie(w, Vector3(0, 0, 0))
	z1.chase_speed = 3.3
	await _ticks(3)
	z1._player = player
	z1.state = Zombie.State.CHASE
	var d0: float = z1.global_position.distance_to(player.global_position)
	await _ticks(720)
	var d1: float = z1.global_position.distance_to(player.global_position)
	var detour_x: float = absf(z1.global_position.x)
	print("T1_WALL_DETOUR: ", d1 < d0 - 4.0 and (d1 < 2.5 or detour_x > 0.8 or z1.global_position.z > 6.0),
		" (%.2f -> %.2f, x=%.2f z=%.2f)" % [d0, d1, z1.global_position.x, z1.global_position.z])
	z1.queue_free()
	await _ticks(3)

	# T2: 겹친 좀비는 separation 벡터를 받는다.
	var za: Zombie = _spawn_zombie(w, Vector3(-20, 0, 0))
	var zb: Zombie = _spawn_zombie(w, Vector3(-19.5, 0, 0))
	await _ticks(3)
	var sep: Vector3 = za._separation_vector()
	print("T2_SEPARATION: ", sep.length() > 0.01, " (len=%.2f)" % sep.length())
	za.queue_free()
	zb.queue_free()
	await _ticks(3)

	# T3/T4: 스폰 안전 검사.
	var spawner := Node.new()
	spawner.set_script(SPAWNER_SCRIPT)
	w.add_child(spawner)
	_wall(w, Vector3(20, 1, 20), Vector3(4, 2, 4))
	await _ticks(3)
	var inside: bool = spawner.is_spawn_free(Vector3(20, 0, 20))
	var outside: bool = spawner.is_spawn_free(Vector3(30, 0, 30))
	print("T3_SPAWN_FREE_CHECK: ", (not inside) and outside,
		" (inside=%s outside=%s)" % [str(inside), str(outside)])

	spawner.min_dist = 3.0
	spawner.max_dist = 7.0
	player.global_position = Vector3(20, 0, 14)
	player.hp = 10000.0
	await _ticks(3)
	for i in 10:
		spawner._try_spawn()
		await _ticks(2)
	var overlapped := 0
	var spawned := 0
	for zn in get_tree().get_nodes_in_group("zombies"):
		if not is_instance_valid(zn) or not (zn is Node3D):
			continue
		var zp: Vector3 = (zn as Node3D).global_position
		# 스폰 링(3~7m) 안에서만 판정 — 멀리 있던 잔재는 제외.
		if zp.distance_to(player.global_position) > 9.0:
			continue
		spawned += 1
		var local: Vector3 = zp - Vector3(20, 0, 20)
		if absf(local.x) < 2.0 + 0.7 and absf(local.z) < 2.0 + 0.7:
			overlapped += 1
	print("T4_SPAWN_NO_OVERLAP: ", spawned > 0 and overlapped == 0,
		" (spawned=%d overlapped=%d)" % [spawned, overlapped])
	for zn2 in get_tree().get_nodes_in_group("zombies"):
		if is_instance_valid(zn2):
			(zn2 as Node).queue_free()
	await _ticks(3)

	# T5: 벽越し 사거리 — 벽 반대편 플레이어 앞에서 ATTACK에 굳지 않고 돌아간다.
	# 벽(폭 6m·두께 0.5, z -0.25~0.25)을 사이에 두고 거리 1.2m(사거리 1.35 안)에 배치.
	_wall(w, Vector3(-20, 1, 0), Vector3(6, 2, 0.5))
	player.global_position = Vector3(-20, 0, 0.2)
	player.hp = 10000.0
	await _ticks(2)
	var z5: Zombie = _spawn_zombie(w, Vector3(-20, 0, -1.0))
	await _ticks(3)
	z5._player = player
	z5.state = Zombie.State.CHASE
	await _ticks(2)
	var stuck_frames := 0
	for i in 600:
		await get_tree().physics_frame
		if not is_instance_valid(z5):
			break
		if z5.state == Zombie.State.ATTACK and absf(z5.global_position.x - -20.0) < 0.5 \
				and z5.global_position.z < 0.0:
			stuck_frames += 1
	var flanked: bool = absf(z5.global_position.x - -20.0) > 1.2 or z5.global_position.z > 0.3
	print("T5_NO_WALL_ATTACK_LOCK: ", flanked and stuck_frames < 300,
		" (x=%.2f z=%.2f stuck_frames=%d)" % [z5.global_position.x, z5.global_position.z, stuck_frames])
	z5.queue_free()
	await _ticks(3)

	# T6: 벽 앞 조향 진동 정량 — 연속 프레임 간 속도 방향 변화 평균이 작아야 한다.
	_wall(w, Vector3(20, 1, -10), Vector3(8, 2, 0.5))
	player.global_position = Vector3(20, 0, -4)
	player.hp = 10000.0
	await _ticks(2)
	var z6: Zombie = _spawn_zombie(w, Vector3(20, 0, -14))
	await _ticks(3)
	z6._player = player
	z6.state = Zombie.State.CHASE
	await _ticks(2)
	var prev: Vector3 = z6.velocity
	var turn_sum := 0.0
	var turn_n := 0
	for i in 150:
		await get_tree().physics_frame
		if not is_instance_valid(z6):
			break
		var cur: Vector3 = z6.velocity
		var a := Vector2(prev.x, prev.z)
		var b := Vector2(cur.x, cur.z)
		if a.length() > 0.5 and b.length() > 0.5:
			turn_sum += absf(a.angle_to(b))
			turn_n += 1
		prev = cur
	var avg_turn := 0.0
	if turn_n > 0:
		avg_turn = turn_sum / float(turn_n)
	print("T6_NO_JITTER: ", turn_n > 30 and avg_turn < 0.45,
		" (avg=%.3f rad n=%d)" % [avg_turn, turn_n])

	print("M72_SMOKE_DONE")
	get_tree().quit(0)
