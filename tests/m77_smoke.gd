extends Node

const PLAYER_SCENE := preload("res://scenes/player/player.tscn")
const ZOMBIE_SCENE := preload("res://scenes/zombie/zombie.tscn")


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
	bs.size = Vector3(300, 1, 300)
	cs.shape = bs
	cs.position.y = -0.5
	floor_body.add_child(cs)
	w.add_child(floor_body)


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
	InventoryManager.reset_run()
	await _ticks(2)

	# T1: 좀비 — 경직 없이도 선딜+모션 취소
	var z1: Zombie = ZOMBIE_SCENE.instantiate()
	w.add_child(z1)
	z1.global_position = Vector3(1.0, 0.5, 0.0)
	z1.state = Zombie.State.ATTACK
	z1._attack_cd = 0.0
	await _ticks(3)
	var windup_started: bool = z1._attack_windup > 0.0 and z1._lock_anim_t > 0.0
	z1.take_damage(5.0, player.global_position, 0.0, 0.0)
	var t1: bool = windup_started and z1._attack_windup == 0.0 and z1._lock_anim_t == 0.0
	print("T1_ZOMBIE_CANCEL_NO_STAGGER: ", t1, " (windup_started=", windup_started, ")")

	# T2: 좀비 — 취소된 공격은 타격 없음 (플레이어 HP 유지)
	var php_before: float = player.hp
	await _ticks(30)
	var t2: bool = is_equal_approx(player.hp, php_before)
	print("T2_ZOMBIE_CANCELLED_NO_HIT: ", t2, " (hp=", player.hp, " before=", php_before, ")")
	z1.queue_free()
	await _ticks(2)

	# T3: 플레이어 — 피격 시 대기 중 타격 무효화
	var z2: Zombie = ZOMBIE_SCENE.instantiate()
	w.add_child(z2)
	z2.global_position = player.global_position + Vector3(1.0, 0.0, 0.0)
	# 플레이어가 좀비를 바라보게 고정
	player.rotation.y = atan2(-1.0, 0.0)
	await _ticks(3)
	var zhp_before: float = z2.hp
	player._invuln = 0.0
	player._melee_cd = 0.0
	player._melee_attack()
	player.take_damage(5.0)
	var seq_invalidated: bool = true
	await _ticks(20)
	var t3: bool = is_equal_approx(z2.hp, zhp_before)
	print("T3_PLAYER_CANCEL_PENDING_HIT: ", t3, " (zhp=", z2.hp, " before=", zhp_before, ")")

	# T4: 플레이어 — 모션 잠금·궤적 중단
	var z3: Zombie = ZOMBIE_SCENE.instantiate()
	w.add_child(z3)
	z3.global_position = player.global_position + Vector3(5.0, 0.0, 0.0)
	await _ticks(2)
	player._invuln = 0.0
	player._melee_cd = 0.0
	player._melee_attack()
	var lock_started: bool = player._lock_anim_t > 0.0
	player.take_damage(5.0)
	# 무적 시간 중 두 번째 take는 무시되므로 _invuln 리셋 후 재확인용이 아니라 단일 피격 직후 상태 확인
	var t4: bool = lock_started and player._lock_anim_t == 0.0 and not player._swing_trail.is_playing()
	print("T4_PLAYER_CANCEL_MOTION: ", t4, " (lock_started=", lock_started, ")")

	# T5: 대조군 — 피격 없으면 타격 정상 적중
	z2.queue_free()
	z3.queue_free()
	await _ticks(5)
	player._invuln = 0.0
	await _ticks(30)
	var z4: Zombie = ZOMBIE_SCENE.instantiate()
	w.add_child(z4)
	z4.global_position = player.global_position + Vector3(1.0, 0.0, 0.0)
	player.rotation.y = atan2(-1.0, 0.0)
	await _ticks(3)
	var z4_before: float = z4.hp
	player._melee_cd = 0.0
	player._melee_attack()
	await _ticks(20)
	var t5: bool = z4.hp < z4_before
	print("T5_CONTROL_HIT_WITHOUT_CANCEL: ", t5, " (zhp=", z4.hp, " before=", z4_before, ")")

	print("M77_SMOKE_DONE")
	get_tree().quit(0)
