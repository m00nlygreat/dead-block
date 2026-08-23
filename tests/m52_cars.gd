extends Node


func _ready() -> void:
	_run()


func _ticks(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _count_cars() -> int:
	var n := 0
	for c in get_tree().get_nodes_in_group("containers"):
		if is_instance_valid(c) and not c.is_queued_for_deletion() \
				and c.scene_file_path.ends_with("car_trunk.tscn"):
			n += 1
	return n


func _run() -> void:
	var stage: Node3D = (load("res://scenes/core/stage1.tscn") as PackedScene).instantiate()
	add_child(stage)
	await _ticks(10)
	var player: Node3D = get_tree().get_first_node_in_group("player")
	var world: Node3D = stage.get_node("FloorBuilder")

	var spots := [Vector2i(0, 0), Vector2i(20, 20), Vector2i(40, 40), Vector2i(-15, -15), Vector2i(60, -30)]
	var ok_all := true
	var results: Array = []
	for s in spots:
		player.global_position = Vector3(s.x * 34.0, 1.0, s.y * 34.0)
		await _ticks(45)
		if _count_cars() <= 1:
			ok_all = false
		results.append("(%d,%d)=%d" % [s.x, s.y, _count_cars()])
	print("T1_CARS_SPAWN_EVERYWHERE: ", ok_all, " ", " ".join(PackedStringArray(results)))

	player.global_position = Vector3(20 * 34.0, 1.0, 20 * 34.0)
	await _ticks(45)
	var ec_true := 0
	var ec_n := 0
	for key in world.loaded_keys():
		if not key.begins_with("b_"):
			continue
		var p: PackedStringArray = key.split("_")
		for side in 4:
			ec_n += 1
			if world._side_active(int(p[1]), int(p[2]), side):
				ec_true += 1
	print("T2_EDGE_CHECK_ALIVE: ", ec_n > 0 and float(ec_true) / float(ec_n) > 0.3, " (%d/%d)" % [ec_true, ec_n])

	print("M52_CARS_DONE")
	get_tree().quit(0)
