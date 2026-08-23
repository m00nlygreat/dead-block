extends Node

const INF_WORLD := preload("res://scripts/world/infinite_world.gd")
const PLAYER_SCENE := preload("res://scenes/player/player.tscn")


func _ready() -> void:
	_run()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _parse_indices(world: Node, prefix: String) -> Array:
	var out: Array = []
	for key in world.loaded_keys():
		var parts: PackedStringArray = String(key).split("_")
		if parts[0] == prefix:
			out.append(Vector2i(int(parts[1]), int(parts[2])))
	return out


func _run() -> void:
	var world: Node3D = INF_WORLD.new()
	world.seed_value = 777
	add_child(world)
	await _frames(2)

	var player := PLAYER_SCENE.instantiate()
	add_child(player)
	player.global_position = Vector3(3.0, 0.5, 3.0)
	await _frames(40)

	print("M41_T1_STREAM_LOADED_AT_ORIGIN: ", world.loaded_count() > 0,
		" (loaded=%d seed=%d)" % [world.loaded_count(), world.run_seed()])
	var origin_blocks: int = _parse_indices(world, "b").size()
	print("M41_T1B_BLOCK_COUNT_NEAR_ORIGIN: ", origin_blocks == 25, " (blocks=%d)" % origin_blocks)

	player.global_position = Vector3(600.0, 0.5, 600.0)
	await _frames(40)
	var far_blocks: Array = _parse_indices(world, "b")
	var expect := Vector2i(floori(600.0 / 34.0), floori(600.0 / 34.0))
	var near_far := false
	for c in far_blocks:
		if absi(c.x - expect.x) <= 2 and absi(c.y - expect.y) <= 2:
			near_far = true
			break
	print("M41_T2_WORLD_EXTENDS_FAR: ", near_far and world.loaded_count() > 0,
		" (expect_cell=%s loaded=%d)" % [str(expect), world.loaded_count()])

	var still_near_origin := false
	for c in _parse_indices(world, "b"):
		if absi(c.x) < 8 and absi(c.y) < 8:
			still_near_origin = true
			break
	print("M41_T3_FAR_CHUNKS_UNLOADED: ", not still_near_origin and far_blocks.size() == 25,
		" (far_blocks=%d)" % far_blocks.size())

	var w2: Node3D = INF_WORLD.new()
	w2.seed_value = 777
	add_child(w2)
	await _frames(2)
	var mismatch := 0
	for i in range(-6, 7):
		for j in range(-6, 7):
			if world._edge_active("h", i, j) != w2._edge_active("h", i, j):
				mismatch += 1
			if world._edge_active("v", i, j) != w2._edge_active("v", i, j):
				mismatch += 1
	print("M41_T4_DETERMINISTIC_EDGES: ", mismatch == 0, " (mismatch=%d)" % mismatch)

	var active_h := 0
	var total_h := 0
	for i in range(-10, 11):
		for j in range(-10, 11):
			total_h += 1
			if world._edge_active("h", i, j):
				active_h += 1
	var ratio: float = float(active_h) / float(total_h)
	print("M41_T5_EDGE_DENSITY_SANE: ", ratio > 0.55 and ratio < 0.9,
		" (ratio=%.2f)" % ratio)

	print("M41_SMOKE_DONE")
	get_tree().quit(0)
