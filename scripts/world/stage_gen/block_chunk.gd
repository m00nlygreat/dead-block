extends RefCounted


static func build(ctx: Dictionary) -> void:
	var rng: RandomNumberGenerator = ctx["rng"]
	var rect: Rect2 = ctx["rect"]
	var pattern: Dictionary = ctx["pattern"]
	var parent: Node3D = ctx["parent"]
	var placed: Array = ctx["placed"]
	_add_base(parent, rect)
	for slot in pattern["house_slots"]:
		var house: Node3D = ctx["house_scenes"][rng.randi_range(0, ctx["house_scenes"].size() - 1)].instantiate()
		house.scale = Vector3.ONE * float(ctx["house_scale"])
		var depth := rng.randf_range(1.8, 3.6)
		var jitter := rng.randf_range(-1.5, 1.5)
		var side: int = slot[0]
		var t: float = slot[1]
		match side:
			0:
				house.position = Vector3(rect.position.x + rect.size.x * t + jitter, 0, rect.position.y + depth)
				house.rotation.y = 0.0
			1:
				house.position = Vector3(rect.position.x + rect.size.x - depth, 0, rect.position.y + rect.size.y * t + jitter)
				house.rotation.y = -PI * 0.5
			2:
				house.position = Vector3(rect.position.x + rect.size.x * t + jitter, 0, rect.position.y + rect.size.y - depth)
				house.rotation.y = PI
			3:
				house.position = Vector3(rect.position.x + depth, 0, rect.position.y + rect.size.x * t + jitter)
				house.rotation.y = PI * 0.5
		parent.add_child(house)
		add_house_collider(house)
		placed.append("house:%.2f:%.2f:%.2f" % [house.position.x, house.position.z, house.rotation.y])
	var trees := rng.randi_range(pattern["tree_range"].x, pattern["tree_range"].y)
	for i in trees:
		var tree: Node3D = ctx["tree_scene"].instantiate()
		tree.scale = Vector3.ONE * float(ctx["tree_scale"])
		parent.add_child(tree)
		tree.position = Vector3(rect.position.x + rng.randf_range(2.0, rect.size.x - 2.0), 0, rect.position.y + rng.randf_range(2.0, rect.size.y - 2.0))
		tree.rotation.y = rng.randf() * TAU
		placed.append("tree:%.2f:%.2f" % [tree.position.x, tree.position.z])
	var want_cars := rng.randi_range(pattern["car_count"].x, pattern["car_count"].y)
	if want_cars > 0:
		var sides: Array = []
		for s in pattern["car_sides"]:
			if ctx["edge_check"].call(s):
				sides.append(s)
		for idx in range(sides.size() - 1, 0, -1):
			var k := rng.randi_range(0, idx)
			var tmp = sides[k]
			sides[k] = sides[idx]
			sides[idx] = tmp
		var rw := float(ctx["road_width"])
		for c in mini(want_cars, sides.size()):
			var s: int = sides[c]
			var t := rng.randf_range(0.3, 0.75)
			var pos: Vector3
			var rot := 0.0
			match s:
				0:
					pos = Vector3(rect.position.x + rect.size.x * t, 0, rect.position.y - rw * 0.5 + 1.2)
					rot = PI * 0.5 if rng.randf() < 0.5 else -PI * 0.5
				1:
					pos = Vector3(rect.position.x + rect.size.x + rw * 0.5 - 1.2, 0, rect.position.y + rect.size.y * t)
					rot = 0.0 if rng.randf() < 0.5 else PI
				2:
					pos = Vector3(rect.position.x + rect.size.x * t, 0, rect.position.y + rect.size.y + rw * 0.5 - 1.2)
					rot = PI * 0.5 if rng.randf() < 0.5 else -PI * 0.5
				3:
					pos = Vector3(rect.position.x - rw * 0.5 + 1.2, 0, rect.position.y + rect.size.y * t)
					rot = 0.0 if rng.randf() < 0.5 else PI
			var car: Node3D = ctx["car_scene"].instantiate()
			car.loot_table = ctx["tables"][rng.randi_range(0, ctx["tables"].size() - 1)]
			parent.add_child(car)
			car.global_position = pos
			car.rotation.y = rot
			placed.append("car:%.2f:%.2f:%.2f" % [pos.x, pos.z, rot])


static func _add_base(parent: Node3D, rect: Rect2) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(rect.size.x, 0.04, rect.size.y)
	mi.mesh = bm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.45, 0.48, 0.42)
	mat.roughness = 1.0
	mi.material_override = mat
	parent.add_child(mi)
	mi.global_position = Vector3(rect.position.x + rect.size.x * 0.5, 0.02, rect.position.y + rect.size.y * 0.5)


static func merged_aabb(root: Node3D) -> AABB:
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


static func add_house_collider(house: Node3D) -> void:
	var ab := merged_aabb(house)
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
