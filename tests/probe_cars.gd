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

	var spots := [
		Vector2i(0, 0), Vector2i(5, 0), Vector2i(10, 10), Vector2i(20, 20),
		Vector2i(40, 40), Vector2i(-15, -15), Vector2i(60, -30), Vector2i(100, 50),
	]
	for s in spots:
		player.global_position = Vector3(s.x * 34.0, 1.0, s.y * 34.0)
		await _ticks(45)
		var edges := 0
		var blocks := 0
		for key in world.loaded_keys():
			if key.begins_with("e_") or key.begins_with("j_"):
				edges += 1
			elif key.begins_with("b_"):
				blocks += 1
		print("BLOCK(%4d,%4d) blocks=%d road_nodes=%d cars=%d seed=%d" % [s.x, s.y, blocks, edges, _count_cars(), world.run_seed()])
	print("PROBE_CARS_DONE")
	get_tree().quit(0)
