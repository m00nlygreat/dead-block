extends Node

const ZOMBIE_SCENE := preload("res://scenes/zombie/zombie.tscn")
const PLAYER_SCENE := preload("res://scenes/player/player.tscn")


func _ready() -> void:
	_run()


func _ticks(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


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

	# 파동 이펙트 생성 확인
	NoiseSystem.emit_walk_noise(Vector3(0, 0, 0), false)
	NoiseSystem.emit_melee_noise(Vector3(0, 0, 0))
	NoiseSystem.emit_gun_noise(Vector3(0, 0, 0))
	await get_tree().process_frame
	var ripples := 0
	for c in get_tree().current_scene.get_children():
		if c is NoiseRipple:
			ripples += 1
	print("R1_RIPPLE_SPAWNED: ", ripples >= 3, " count=", ripples)
	await _ticks(60)

	# 좀비가 소음 반경내일 때 on_noise가 불리는지 (on_noise -> state WANDER + 이동)
	var z: Zombie = ZOMBIE_SCENE.instantiate()
	w.add_child(z)
	z.global_position = Vector3(5, 0, 0)
	await _ticks(10)

	# 총 소음 15m — 좀비가 14m에 있으면 반응
	z.global_position = Vector3(0, 0, 14)
	z.state = Zombie.State.IDLE
	await _ticks(5)
	var before := z.global_position
	NoiseSystem.emit_gun_noise(Vector3(0, 0, 0))
	await _ticks(20)
	var moved_gun := z.global_position.distance_to(before) > 0.1
	print("R2_GUN_RADIUS: ", moved_gun, " state=", Zombie.State.keys()[z.state])

	# 이동(걷기) 소음 6m — 좀비가 5.5m에 있으면 반응
	z.global_position = Vector3(0, 0, 5.5)
	z.state = Zombie.State.IDLE
	await _ticks(5)
	before = z.global_position
	NoiseSystem.emit_walk_noise(Vector3(0, 0, 0), false)
	await _ticks(20)
	var moved_walk := z.global_position.distance_to(before) > 0.1
	print("R3_WALK_RADIUS: ", moved_walk, " state=", Zombie.State.keys()[z.state])

	# 근접 소음 5m — 좀비가 4.5m에 있으면 반응
	z.global_position = Vector3(0, 0, 4.5)
	z.state = Zombie.State.IDLE
	await _ticks(5)
	before = z.global_position
	NoiseSystem.emit_melee_noise(Vector3(0, 0, 0))
	await _ticks(20)
	var moved_melee := z.global_position.distance_to(before) > 0.1
	print("R4_MELEE_RADIUS: ", moved_melee, " state=", Zombie.State.keys()[z.state])

	# 반경 밖(거리 초과)은 반응 없음 — 총 15m, 좀비 20m
	z.global_position = Vector3(0, 0, 20)
	z.state = Zombie.State.IDLE
	z._move_point = Vector3(0, 0, 20)
	z._has_move_point = false
	await _ticks(5)
	before = z.global_position
	NoiseSystem.emit_gun_noise(Vector3(0, 0, 0))
	await _ticks(20)
	var moved_outside := z.global_position.distance_to(before) > 0.1
	print("R5_OUTSIDE_RADIUS_IGNORED: ", not moved_outside)

	# 6) 이동 소음 타이머 — 움직이는 플레이어가 200ms 간격으로 소음 발생(리플 생성으로 판정)
	var player := PLAYER_SCENE.instantiate()
	w.add_child(player)
	player.global_position = Vector3(0, 0, 10)
	await _ticks(5)
	await _ticks(30)
	var ripples_before := 0
	for c in get_tree().current_scene.get_children():
		if c is NoiseRipple:
			ripples_before += 1
	Input.action_press("move_up")
	await _ticks(60)
	Input.action_release("move_up")
	var ripples_after := 0
	for c in get_tree().current_scene.get_children():
		if c is NoiseRipple:
			ripples_after += 1
	var walk_fired := ripples_after > ripples_before
	print("R6_WALK_TIMER_FIRED: ", walk_fired, " ripples ", ripples_before, " -> ", ripples_after, " player_moved=", player.global_position.z < 9.0)

	print("NOISE_SMOKE_DONE")
	get_tree().quit(0)
