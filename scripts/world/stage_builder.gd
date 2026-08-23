extends Node3D

const HOUSE_SCENES := [
	preload("res://assets/city-kit-suburban/Models/GLB format/building-type-a.glb"),
	preload("res://assets/city-kit-suburban/Models/GLB format/building-type-b.glb"),
	preload("res://assets/city-kit-suburban/Models/GLB format/building-type-c.glb"),
	preload("res://assets/city-kit-suburban/Models/GLB format/building-type-d.glb"),
	preload("res://assets/city-kit-suburban/Models/GLB format/building-type-e.glb"),
	preload("res://assets/city-kit-suburban/Models/GLB format/building-type-f.glb"),
]
const TREE_SCENE := preload("res://assets/city-kit-suburban/Models/GLB format/tree-large.glb")
const CAR_SCENE := preload("res://scenes/world/car_trunk.tscn")
const TABLES := [
	preload("res://resources/loot_tables/trash_common.tres"),
	preload("res://resources/loot_tables/med_cabinet.tres"),
]

@export var seed_value := 20260822
@export var blocks := 3
@export var block_size := 26.0
@export var road_width := 8.0
@export var world_extent := 200.0
@export var house_scale := 3.4
@export var tree_scale := 3.8

var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.seed = seed_value
	_build()


func _total() -> float:
	return blocks * block_size + (blocks + 1) * road_width


func _half() -> float:
	return _total() * 0.5


func _build() -> void:
	_add_collision_floor()
	_add_ground()
	_add_roads()
	for bx in blocks:
		for bz in blocks:
			_build_block(bx, bz)
	_add_boundary()


func _add_collision_floor() -> void:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(world_extent, 1.0, world_extent)
	cs.shape = bs
	body.add_child(cs)
	add_child(body)
	body.global_position = Vector3(0, -0.5, 0)


func _add_ground() -> void:
	var mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(world_extent, world_extent)
	mi.mesh = pm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.22, 0.23, 0.24)
	mat.roughness = 1.0
	mi.material_override = mat
	add_child(mi)


func _add_box(pos: Vector3, size: Vector3, color: Color, y: float) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 1.0
	mi.material_override = mat
	add_child(mi)
	mi.global_position = Vector3(pos.x, y, pos.z)


const TILE := 4.0


func _road_lines() -> Array[float]:
	var lines: Array[float] = []
	var half := _half()
	for i in blocks + 1:
		lines.append(-half + road_width * 0.5 + i * (block_size + road_width))
	return lines


func _tile_kind(cx: float, cz: float, lines: Array[float]) -> int:
	var near_h := false
	var near_v := false
	for l in lines:
		if absf(cx - l) < road_width * 0.5:
			near_v = true
		if absf(cz - l) < road_width * 0.5:
			near_h = true
	if near_h and near_v:
		return 3
	if near_h:
		return 1
	if near_v:
		return 2
	return 0


func _add_roads() -> void:
	var t: float = _total()
	var half := _half()
	var n := int(t / TILE)
	var asphalt := StandardMaterial3D.new()
	asphalt.albedo_color = Color(0.3, 0.31, 0.32)
	asphalt.roughness = 1.0
	var crossing_mat := StandardMaterial3D.new()
	crossing_mat.albedo_color = Color(0.33, 0.34, 0.35)
	crossing_mat.roughness = 1.0
	var dash_mesh := BoxMesh.new()
	dash_mesh.size = Vector3(TILE * 0.4, 0.01, 0.22)

	var lines := _road_lines()
	for gx in n:
		for gz in n:
			var cx := -half + TILE * (float(gx) + 0.5)
			var cz := -half + TILE * (float(gz) + 0.5)
			var kind := _tile_kind(cx, cz, lines)
			if kind == 0:
				continue
			var mi := MeshInstance3D.new()
			var bm := BoxMesh.new()
			bm.size = Vector3(TILE, 0.02, TILE)
			mi.mesh = bm
			mi.material_override = crossing_mat if kind == 3 else asphalt
			add_child(mi)
			mi.global_position = Vector3(cx, 0.01, cz)
			if kind == 3 or _near_any_line(_cross_axis_coord(kind, cx, cz), lines, road_width * 0.8):
				continue
			for k in 2:
				var dash := MeshInstance3D.new()
				dash.mesh = dash_mesh
				dash.material_override = null
				var dash_mat := StandardMaterial3D.new()
				dash_mat.albedo_color = Color(0.85, 0.85, 0.8)
				dash.material_override = dash_mat
				add_child(dash)
				var off := -TILE * 0.25 + k * TILE * 0.5
				if kind == 1:
					dash.global_position = Vector3(cx + off, 0.03, cz)
				else:
					dash.rotation.y = PI * 0.5
					dash.global_position = Vector3(cx, 0.03, cz + off)


func _cross_axis_coord(kind: int, cx: float, cz: float) -> float:
	return cz if kind == 1 else cx


func _near_any_line(v: float, lines: Array[float], tol: float) -> bool:
	for l in lines:
		if absf(v - l) < tol:
			return true
	return false


func _build_block(bx: int, bz: int) -> void:
	var half: float = _half()
	var step: float = block_size + road_width
	var x0: float = -half + road_width + bx * step
	var z0: float = -half + road_width + bz * step
	var cx := x0 + block_size * 0.5
	var cz := z0 + block_size * 0.5

	_add_box(Vector3(cx, 0, cz), Vector3(block_size, 0.04, block_size), Color(0.45, 0.48, 0.42), 0.02)

	var per_side := 2
	var spacing := block_size / float(per_side)
	for s in 4:
		for i in per_side:
			if _rng.randf() < 0.15:
				continue
			var along := x0 + spacing * (float(i) + 0.5) + _rng.randf_range(-1.5, 1.5)
			var depth: float = _rng.randf_range(1.8, 3.6)
			var h: Node3D = HOUSE_SCENES[_rng.randi_range(0, HOUSE_SCENES.size() - 1)].instantiate()
			h.scale = Vector3.ONE * house_scale
			match s:
				0:
					h.position = Vector3(along, 0, z0 + depth)
					h.rotation.y = 0.0
				1:
					h.position = Vector3(along, 0, z0 + block_size - depth)
					h.rotation.y = PI
				2:
					h.position = Vector3(x0 + depth, 0, along)
					h.rotation.y = PI * 0.5
				3:
					h.position = Vector3(x0 + block_size - depth, 0, along)
					h.rotation.y = -PI * 0.5
			add_child(h)
			_add_house_collider(h)

		for i in per_side:
			var tx := x0 + _rng.randf_range(2.0, block_size - 2.0)
			var tz := z0 + _rng.randf_range(2.0, block_size - 2.0)
			if _rng.randf() < 0.5:
				var tree: Node3D = TREE_SCENE.instantiate()
				tree.scale = Vector3.ONE * tree_scale
				add_child(tree)
				tree.position = Vector3(tx, 0, tz)
				tree.rotation.y = _rng.randf() * TAU

	var car_spots := [
		Vector3(x0 - road_width * 0.5 + 1.2, 0, z0 + block_size * 0.35),
		Vector3(x0 + block_size + road_width * 0.5 - 1.2, 0, z0 + block_size * 0.7),
	]
	for spot in car_spots:
		if _rng.randf() < 0.55:
			continue
		var car: Node3D = CAR_SCENE.instantiate()
		car.loot_table = TABLES[_rng.randi_range(0, TABLES.size() - 1)]
		add_child(car)
		car.global_position = spot
		car.rotation.y = PI if _rng.randf() < 0.5 else 0.0


func _merged_aabb(root: Node3D) -> AABB:
	var inv: Transform3D = root.global_transform.affine_inverse()
	var merged := AABB()
	var first := true
	for mi in root.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		if m.mesh == null:
			continue
		var ab: AABB = inv * (m.global_transform * m.mesh.get_aabb())
		if first:
			merged = ab
			first = false
		else:
			merged = merged.merge(ab)
	return merged


func _add_house_collider(house: Node3D) -> void:
	var ab := _merged_aabb(house)
	if ab.size.length() < 0.1:
		return
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = ab.size
	cs.shape = bs
	body.add_child(cs)
	house.add_child(body)
	cs.position = ab.get_center()


func _add_boundary() -> void:
	var half: float = _world_half()
	for r in [[Vector3(0, half, 0), Vector3(world_extent, 8, 1)], [Vector3(0, -half, 0), Vector3(world_extent, 8, 1)], [Vector3(half, 0, 0), Vector3(1, 8, world_extent)], [Vector3(-half, 0, 0), Vector3(1, 8, world_extent)]]:
		var body := StaticBody3D.new()
		body.collision_layer = 1
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = r[1]
		cs.shape = bs
		body.add_child(cs)
		add_child(body)
		body.global_position = r[0] + Vector3(0, 4, 0)


func _world_half() -> float:
	return world_extent * 0.5
