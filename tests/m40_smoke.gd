extends Node

const BUILDER := preload("res://scripts/world/stage_builder.gd")
const RoadNetwork := preload("res://scripts/world/stage_gen/road_network.gd")

var _dbg: FileAccess


func _ready() -> void:
	_run()


func _log(msg: String) -> void:
	print(msg)
	if _dbg != null:
		_dbg.store_line(msg)
		_dbg.flush()


func _make_builder(seed_v: int) -> Node3D:
	var b: Node3D = BUILDER.new()
	b.seed_value = seed_v
	b.blocks = 3
	add_child(b)
	return b


func _run() -> void:
	_dbg = FileAccess.open("user://m40_progress.log", FileAccess.WRITE)
	await get_tree().physics_frame
	_log("M40_STEP_AWAIT_OK")

	var a := _make_builder(12345)
	_log("M40_STEP_BUILDER_A_ADDED")
	var sig_a: String = a.get_signature()
	var net_a: Dictionary = a.get_road_network()
	_log("M40_STEP_SIG_A len=%d" % sig_a.length())
	a.queue_free()
	await get_tree().process_frame

	var b := _make_builder(12345)
	var sig_b: String = b.get_signature()
	_log("M40_STEP_SIG_B len=%d" % sig_b.length())
	b.queue_free()
	await get_tree().process_frame

	var c := _make_builder(999)
	var sig_c: String = c.get_signature()
	var n: int = c.blocks
	c.queue_free()
	await get_tree().process_frame
	_log("M40_STEP_SIG_C_OK")

	_log("M40_T1_DETERMINISTIC: " + str(not sig_a.is_empty() and sig_a == sig_b))
	_log("M40_T2_SEED_CHANGES_LAYOUT: " + str(sig_c != sig_a))

	var total_nodes: int = (n + 1) * (n + 1)
	var visited := {RoadNetwork.node_key(0, 0): true}
	var queue := [[0, 0]]
	while not queue.is_empty():
		var cur: Array = queue.pop_front()
		var mask: int = net_a["masks"][RoadNetwork.node_key(cur[0], cur[1])]
		for d in [[RoadNetwork.DIR_N, cur[0], cur[1] - 1], [RoadNetwork.DIR_E, cur[0] + 1, cur[1]], [RoadNetwork.DIR_S, cur[0], cur[1] + 1], [RoadNetwork.DIR_W, cur[0] - 1, cur[1]]]:
			if mask & d[0] and not visited.get(RoadNetwork.node_key(d[1], d[2]), false):
				visited[RoadNetwork.node_key(d[1], d[2])] = true
				queue.append([d[1], d[2]])
	_log("M40_T3_ROAD_CONNECTED: " + str(visited.size() == total_nodes) + " (%d/%d)" % [visited.size(), total_nodes])

	var min_span_edges: int = total_nodes - 1
	_log("M40_T4_EDGES_MIN_SPAN: " + str(net_a["edges"].size() >= min_span_edges) + " (%d>=%d)" % [net_a["edges"].size(), min_span_edges])

	var houses := 0
	var cars := 0
	var trees := 0
	var out_of_bounds := 0
	var limit: float = 200.0 * 0.5 + 5.0
	for entry in sig_a.split("\n"):
		if entry.begins_with("house"):
			houses += 1
		elif entry.begins_with("car"):
			cars += 1
		elif entry.begins_with("tree"):
			trees += 1
		var parts: PackedStringArray = entry.split(":")
		if parts.size() < 3:
			continue
		if absf(float(parts[1])) > limit or absf(float(parts[2])) > limit:
			out_of_bounds += 1
	_log("M40_T5_COUNTS_SANE: " + str(houses > 0 and cars >= 0 and trees >= 0) + " (houses=%d cars=%d trees=%d)" % [houses, cars, trees])
	_log("M40_T6_ALL_IN_BOUNDS: " + str(out_of_bounds == 0) + " (violations=%d)" % out_of_bounds)

	_log("M40_SMOKE_DONE")
	get_tree().quit(0)
