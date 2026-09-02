extends Node

const ZOMBIE_SCENE := preload("res://scenes/zombie/zombie.tscn")
const PLAYER_SCENE := preload("res://scenes/player/player.tscn")


func _ready() -> void:
	_run()


func _ticks(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _chart() -> NoiseRipple:
	for c in get_tree().current_scene.get_children():
		if c is NoiseRipple:
			return c
	return null


func _run() -> void:
	var w := Node3D.new()
	add_child(w)

	var floor_body := StaticBody3D.new()
	floor_body.collision_layer = 1
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(400, 1, 400)
	cs.shape = bs
	cs.position.y = -0.5
	floor_body.add_child(cs)
	w.add_child(floor_body)

	# 1) 상시 유지 차트 1개 생성 + 총(15m) 소음 시 반지름이 올라가는지
	NoiseSystem.emit_gun_noise(Vector3(0, 0, 0))
	await _ticks(10)
	var ch := _chart()
	print("R1_CHART_SINGLETON: ", ch != null)
	if ch == null:
		print("NOISE_SMOKE_DONE")
		get_tree().quit(1)
		return
	# 잠시 기다려 반지름이 목표로 수렴한 뒤 측정
	await _ticks(20)
	print("R2_GUN_RADIUS_CHART: ", ch._current_radius > 5.0, " r=", snappedf(ch._current_radius, 0.1))

	# 2) 소음이 멈추면 감쇠 → 걷기(3m) 단독 반지름이 총(15m)보다 작은지, 3m 근처인지
	await _ticks(120)
	ch._current_radius = 0.0
	ch._target_radius = 0.0
	NoiseSystem.emit_walk_noise(Vector3(0, 0, 0), false)
	await _ticks(20)
	var walk_r := ch._current_radius
	print("R3_WALK_RADIUS_CHART: ", walk_r <= 5.0 and walk_r >= 1.0, " r=", snappedf(walk_r, 0.1))

	# 3) 소음이 멈추면 반지름이 감쇠(감소)
	await _ticks(120)
	print("R4_DECAY: ", ch._current_radius < 3.0, " r=", snappedf(ch._current_radius, 0.1))

	# 4) 좀비 반응 반경 — 총 15m, 좀비 14m
	var z: Zombie = ZOMBIE_SCENE.instantiate()
	w.add_child(z)
	z.global_position = Vector3(0, 0, 14)
	z.state = Zombie.State.IDLE
	await _ticks(5)
	var before := z.global_position
	NoiseSystem.emit_gun_noise(Vector3(0, 0, 0))
	await _ticks(20)
	print("R5_GUN_ZOMBIE_REACT: ", z.global_position.distance_to(before) > 0.1)

	# 5) 반경 밖(20m)은 무시
	z.global_position = Vector3(0, 0, 20)
	z.state = Zombie.State.IDLE
	z._move_point = Vector3(0, 0, 20)
	z._has_move_point = false
	await _ticks(5)
	before = z.global_position
	NoiseSystem.emit_gun_noise(Vector3(0, 0, 0))
	await _ticks(20)
	print("R6_OUTSIDE_IGNORED: ", z.global_position.distance_to(before) <= 0.1)

	# 6) 이동 소음 타이머 — 움직이는 플레이어가 차트 반지름을 올리는지
	await _ticks(120)
	ch._current_radius = 0.0
	ch._target_radius = 0.0
	await _ticks(10)
	var player := PLAYER_SCENE.instantiate()
	w.add_child(player)
	player.global_position = Vector3(0, 0, 10)
	await _ticks(5)
	var r0 := ch._current_radius
	Input.action_press("move_up")
	await _ticks(60)
	Input.action_release("move_up")
	print("R7_WALK_TIMER_CHART: ", ch._current_radius > r0 + 1.0, " r=", snappedf(ch._current_radius, 0.1), " r0=", snappedf(r0, 0.1), " moved=", player.global_position.z < 9.0)

	print("NOISE_SMOKE_DONE")
	get_tree().quit(0)
