extends Node

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


func _spawn_zombie(w: Node3D, pos: Vector3) -> Zombie:
	var z: Zombie = ZOMBIE_SCENE.instantiate()
	w.add_child(z)
	z.global_position = pos
	return z


func _run() -> void:
	var w := Node3D.new()
	add_child(w)
	_floor(w)
	var player := PLAYER_SCENE.instantiate()
	w.add_child(player)
	player.global_position = Vector3.ZERO
	await _ticks(5)

	# 물리 활성 좀비 상태 캡처: 방향 전환 가능해야(true) 의미가 있다.
	var near := _spawn_zombie(w, player.global_position + Vector3(5.0, 0.0, 0.0))
	near.visibility_dist = 35.0
	await _ticks(3)
	var near_visible := near._model.visible
	near.global_position = player.global_position + Vector3(5.0, 0.0, 0.0)
	var loss_before: float = near.velocity.length()
	await _ticks(3)
	var loss_after: float = near.velocity.length()
	print("T1_NEAR_ACTIVE: ", near_visible)
	print("T1_NEAR_PHYSICS_RAN: ", loss_after >= loss_before)

	# 멀리(반경 밖) 좀비: 물리 스킵 + 모델 숨김
	var far := _spawn_zombie(w, player.global_position + Vector3(200.0, 0.0, 0.0))
	far.visibility_dist = 35.0
	await _ticks(6)
	print("T2_FAR_HIDDEN: ", not far._model.visible)

	# 플레이어가 가까워지면 다시 표시
	far.global_position = player.global_position + Vector3(5.0, 0.0, 0.0)
	await _ticks(3)
	print("T3_REAPPEARS: ", far._model.visible)

	# 기본 무한이면 멀어도 숨기지 않음(회귀 방지)
	var base := _spawn_zombie(w, player.global_position + Vector3(500.0, 0.0, 0.0))
	await _ticks(6)
	print("T4_DEFAULT_UNLIMITED: ", base._model.visible)

	# 스폰러가 visibility_dist를 좀비에 전파하는지 확인
	var spawner := Node.new()
	spawner.set_script(SPAWNER_SCRIPT)
	spawner.visibility_dist = 30.0
	spawner.interval = 0.1
	w.add_child(spawner)
	player.global_position = Vector3.ZERO
	await _ticks(10)
	var propagated := false
	for z in get_tree().get_nodes_in_group("zombies"):
		if absf(z.visibility_dist - 30.0) < 0.01:
			propagated = true
	print("T5_SPAWNER_PROPAGATES: ", propagated)

	print("M70_SMOKE_DONE")
	get_tree().quit(0)