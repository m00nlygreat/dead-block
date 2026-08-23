extends Node


func _ready() -> void:
	_run()


func _ticks(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _run() -> void:
	var w: Node = load("res://scenes/core/stage1.tscn").instantiate()
	add_child(w)
	for i in 10:
		await get_tree().physics_frame

	var player: CharacterBody3D = w.get_node("Player")
	var car: Node3D = w.get_node("StartTrunk")
	player.global_position = Vector3(6, 0, 2.0)
	player.rotation.y = 0.0
	for i in 5:
		await get_tree().physics_frame

	print("START_DIST: ", snappedf(player.global_position.distance_to(car.global_position), 0.01))
	Input.action_press("move_up")
	for i in 150:
		await get_tree().physics_frame
	Input.action_release("move_up")

	var d := player.global_position.distance_to(car.global_position)
	print("END_DIST: ", snappedf(d, 0.01))
	print("PASSED_THROUGH: ", d < 1.0)
	print("PLAYER_Y: ", snappedf(player.global_position.y, 0.01))

	var slides := 0
	player.global_position = Vector3(6, 0, 2.0)
	for i in 5:
		await get_tree().physics_frame
	Input.action_press("move_up")
	for i in 40:
		await get_tree().physics_frame
		if player.get_slide_collision_count() > 0:
			slides += 1
			break
	Input.action_release("move_up")
	print("SLIDE_COLLISION_HAPPENED: ", slides > 0)
	get_tree().quit(0)
