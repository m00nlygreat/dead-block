extends Node

const PLAYER_SCENE := preload("res://scenes/player/player.tscn")
const ZOMBIE_SCENE := preload("res://scenes/zombie/zombie.tscn")
const STAGE_BUILDER := preload("res://scripts/world/stage_builder.gd")


func _ready() -> void:
	_run()


func _ticks(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _zone_count() -> int:
	return get_tree().get_nodes_in_group("tree_zones").size()


func _tree_count_of(builder: Node) -> int:
	var n := 0
	for entry in builder.get_signature().split("\n"):
		if entry.begins_with("tree:"):
			n += 1
	return n


func _run() -> void:
	var w := Node3D.new()
	add_child(w)

	var builder: Node3D = STAGE_BUILDER.new()
	builder.seed_value = 4242
	w.add_child(builder)
	await _ticks(3)
	var trees := _tree_count_of(builder)
	print("T1_ZONES_MATCH_TREES: ", trees > 0 and _zone_count() == trees,
		" (trees=%d zones=%d)" % [trees, _zone_count()])

	var radii_ok := true
	for z in get_tree().get_nodes_in_group("tree_zones"):
		var r_v = z.get("radius")
		if r_v == null or float(r_v) < 0.8 or float(r_v) > 3.0:
			radii_ok = false
	print("T2_ZONE_RADIUS_SANE: ", radii_ok)

	var floor_body := StaticBody3D.new()
	floor_body.collision_layer = 1
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(300, 1, 300)
	cs.shape = bs
	cs.position.y = -0.5
	floor_body.add_child(cs)
	w.add_child(floor_body)

	var zone := Node3D.new()
	zone.set_script(preload("res://scripts/world/tree_zone.gd"))
	w.add_child(zone)
	zone.global_position = Vector3(50, 0, 50)
	zone.radius = 2.5
	await _ticks(2)

	var player := PLAYER_SCENE.instantiate()
	w.add_child(player)
	await _ticks(5)
	player.survival_drain_mult = 0.0

	Input.action_press("move_up")
	player.global_position = Vector3(50, 0.5, 40)
	await _ticks(10)
	var p_out: Vector3 = player.global_position
	await _ticks(60)
	var d_out: float = player.global_position.distance_to(p_out)

	player.global_position = Vector3(50, 0.5, 50)
	await _ticks(20)
	var in_zone := TreeZone.slows(player)
	var p_in: Vector3 = player.global_position
	await _ticks(60)
	var d_in: float = player.global_position.distance_to(p_in)
	Input.action_release("move_up")
	await _ticks(5)
	var ratio: float = d_in / maxf(d_out, 0.001)
	print("T3_PLAYER_SLOWED_IN_TREE: ", in_zone and d_in > 0.1 and ratio > 0.25 and ratio < 0.65,
		" (in_zone=%s d=%.2f vs %.2f ratio=%.2f)" % [str(in_zone), d_in, d_out, ratio])

	var z: CharacterBody3D = ZOMBIE_SCENE.instantiate()
	z.variant_index = -1
	w.add_child(z)
	z.global_position = Vector3(80, 0.5, 80)
	await _ticks(3)
	var target := Vector3(90, 0.5, 80)
	z.global_position = Vector3(80, 0.5, 80)
	await _ticks(2)
	z._steer(target, z.wander_speed, 1.0 / 60.0)
	var v_out: Vector3 = z.velocity
	z.global_position = Vector3(50, 0.5, 50)
	await _ticks(2)
	z._steer(target, z.wander_speed, 1.0 / 60.0)
	var v_in: Vector3 = z.velocity
	var z_ratio: float = v_in.length() / maxf(v_out.length(), 0.001)
	print("T4_ZOMBIE_SLOWED_IN_TREE: ", absf(z_ratio - 0.45) < 0.05,
		" (%.2f vs %.2f ratio=%.2f)" % [v_in.length(), v_out.length(), z_ratio])

	print("M54_SMOKE_DONE")
	get_tree().quit(0)
