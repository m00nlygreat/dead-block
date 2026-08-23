extends Node

const PLAYER_SCENE := preload("res://scenes/player/player.tscn")
const SPAWNER := preload("res://scripts/world/zombie_spawner.gd")


func _ready() -> void:
	_run()


func _ticks(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _run() -> void:
	var w := Node3D.new()
	add_child(w)
	var player := PLAYER_SCENE.instantiate()
	w.add_child(player)
	var spawner: Node = SPAWNER.new()
	w.add_child(spawner)
	await _ticks(5)

	var sizes := {}
	var ok_range := true
	for i in 4000:
		var s: int = spawner._roll_horde_size()
		if s < 1 or s > 4:
			ok_range = false
		sizes[s] = int(sizes.get(s, 0)) + 1
	var common: float = float(int(sizes.get(1, 0)) + int(sizes.get(2, 0))) / 4000.0
	var rare: float = float(int(sizes.get(3, 0)) + int(sizes.get(4, 0))) / 4000.0
	print("T1_SIZE_IN_RANGE: ", ok_range, " ", sizes)
	print("T2_SMALL_DOMINANT: ", common >= 0.9 and rare <= 0.05, " (1~2마리 %.1f%% / 3~4마리 %.1f%%)" % [common * 100.0, rare * 100.0])

	var counts_ok := true
	var cluster_ok := true
	var dist_ok := true
	for trial in 20:
		spawner._try_spawn()
		await _ticks(1)
		var zs := get_tree().get_nodes_in_group("zombies")
		if zs.size() < 1 or zs.size() > 4:
			counts_ok = false
		var pts: Array[Vector3] = []
		for z in zs:
			pts.append((z as Node3D).global_position)
		for a in pts.size():
			for b in range(a + 1, pts.size()):
				if pts[a].distance_to(pts[b]) > spawner.horde_spread * 2.0 + 0.5:
					cluster_ok = false
			if Vector2(pts[a].x - player.global_position.x, pts[a].z - player.global_position.z).length() \
					< spawner.min_dist - spawner.horde_spread - 0.5:
				dist_ok = false
		for z in zs:
			z.free()
		await _ticks(1)
	print("T3_SPAWN_IS_HORDE_UNIT: ", counts_ok, " CLUSTERED: ", cluster_ok, " MIN_DIST: ", dist_ok)

	spawner.max_zombies = 5
	for i in 10:
		spawner._try_spawn()
	await _ticks(1)
	var total := get_tree().get_nodes_in_group("zombies").size()
	print("T4_MAX_CAP_RESPECTED: ", total <= 5, " (%d)" % total)

	print("M44_SMOKE_DONE")
	get_tree().quit(0)
