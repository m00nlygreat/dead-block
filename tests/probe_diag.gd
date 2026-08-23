extends Node


func _ready() -> void:
	_run()


func _ticks(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _pure_roll(seed_v: int, axis: String, i: int, j: int) -> float:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%s|%s|%d|%d" % [seed_v, axis, i, j])
	return rng.randf()


func _run() -> void:
	var stage: Node3D = (load("res://scenes/core/stage1.tscn") as PackedScene).instantiate()
	add_child(stage)
	await _ticks(10)
	var player: Node3D = get_tree().get_first_node_in_group("player")
	var world: Node3D = stage.get_node("FloorBuilder")

	for spot in [Vector2i(0, 0), Vector2i(20, 20)]:
		player.global_position = Vector3(spot.x * 34.0, 1.0, spot.y * 34.0)
		await _ticks(45)
		var sv: int = world.run_seed()
		print("--- SPOT(%d,%d) seed=%d inst=%d edge_prob=%.2f player_dead=%s" % [
			spot.x, spot.y, sv, world.get_instance_id(), world.edge_prob,
			str(player.is_dead())])
		var shown := 0
		var true_direct := 0
		var true_callable := 0
		var true_pure := 0
		var total := 0
		for key in world.loaded_keys():
			if not key.begins_with("b_"):
				continue
			var p: PackedStringArray = key.split("_")
			var bx := int(p[1])
			var bz := int(p[2])
			for side in 4:
				total += 1
				var d: bool = world._side_active(bx, bz, side)
				var c: Variant = Callable(world, "_side_active").bind(bx, bz).call(side)
				var pu: bool = _pure_roll(sv, ["h", "v", "h", "v"][side], bx + (1 if side == 1 else 0), bz + (1 if side == 2 else 0)) < 0.72
				if d: true_direct += 1
				if c: true_callable += 1
				if pu: true_pure += 1
				if shown < 4 and not d:
					print("   sample b(%d,%d) side%d direct=%s callable=%s pure=%s" % [bx, bz, side, str(d), str(c), str(pu)])
					shown += 1
		print("   SUMMARY total=%d direct_true=%d callable_true=%d pure_true=%d" % [total, true_direct, true_callable, true_pure])
	print("PROBE_DIAG2_DONE")
	get_tree().quit(0)
