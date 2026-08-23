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
	bs.size = Vector3(300, 1, 300)
	cs.shape = bs
	cs.position.y = -0.5
	floor_body.add_child(cs)
	w.add_child(floor_body)

	var player := PLAYER_SCENE.instantiate()
	w.add_child(player)
	await _ticks(5)

	var z1: Zombie = ZOMBIE_SCENE.instantiate()
	w.add_child(z1)
	z1.global_position = Vector3(5, 0, 0)
	z1.rotation.y = PI * 0.5
	await _ticks(40)
	print("T1_SIGHT_CHASE: ", z1.state == Zombie.State.CHASE)

	var z2: Zombie = ZOMBIE_SCENE.instantiate()
	w.add_child(z2)
	z2.global_position = Vector3(0, 0, -14)
	z2.rotation.y = 0.0
	await _ticks(5)
	var noise_point: Vector3 = z2.global_position + Vector3(0, 0, -4)
	var d_before := z2.global_position.distance_to(noise_point)
	NoiseSystem.emit_noise(noise_point, 25.0, 1)
	await _ticks(45)
	var d_after := z2.global_position.distance_to(noise_point)
	print("T2_NOISE_SEEK: ", d_after < d_before - 0.2, " (%.2f -> %.2f)" % [d_before, d_after])

	player.global_position = Vector3(100, 0, 100)
	player.rotation.y = -PI * 0.5
	for i in 5:
		await get_tree().physics_frame

	var z3: Zombie = ZOMBIE_SCENE.instantiate()
	w.add_child(z3)
	z3.global_position = Vector3(100.9, 0, 100)
	await _ticks(5)

	Input.action_press("attack")
	await _ticks(2)
	Input.action_release("attack")
	await _ticks(30)
	print("T3_MELEE_DMG: ", is_instance_valid(z3) and z3.hp < z3.max_hp)

	var swings := 0
	while is_instance_valid(z3) and z3.hp > 0.0 and swings < 8:
		Input.action_press("attack")
		await _ticks(2)
		Input.action_release("attack")
		swings += 1
		await _ticks(50)
	await _ticks(140)
	print("T3_ZOMBIE_DEAD_FREED: ", not is_instance_valid(z3), " SWINGS: ", swings)

	player.global_position = Vector3(200, 0, 200)
	for i in 5:
		await get_tree().physics_frame
	var z4: Zombie = ZOMBIE_SCENE.instantiate()
	w.add_child(z4)
	z4.global_position = Vector3(200.9, 0, 200)
	await _ticks(420)
	print("T4_PLAYER_HURT: ", player.hp < player.max_hp, " HP: ", player.hp)

	print("M3_SMOKE_DONE")
	get_tree().quit(0)
