extends RefCounted

## 차량·집 수색 시 아이템이 나오지 않을 확률. 수색 대상이 늘어난 만큼
## 블록당 기대 룻 수(≈2.5)를 유지하도록 산정했다.
## 차량 ≈2.5개/블록 × (1-0.5) + 집 ≈4.3개/블록 × (1-0.7) ≈ 2.5.
const CAR_EMPTY_CHANCE := 0.5
const HOUSE_EMPTY_CHANCE := 0.7
const HOUSE_LOOT_SCRIPT := preload("res://scripts/world/house_loot.gd")
const LootVisual := preload("res://scripts/util/loot_visual.gd")


static func build(ctx: Dictionary) -> void:
	var rng: RandomNumberGenerator = ctx["rng"]
	var rect: Rect2 = ctx["rect"]
	var pattern: Dictionary = ctx["pattern"]
	var parent: Node3D = ctx["parent"]
	var placed: Array = ctx["placed"]
	_add_base(parent, rect, ctx)
	for slot in pattern["house_slots"]:
		var house: Node3D = _make_house(ctx, rng, rect, slot)
		parent.add_child(house)
		add_house_collider(house)
		add_house_loot(house, ctx["tables"][rng.randi_range(0, ctx["tables"].size() - 1)], HOUSE_EMPTY_CHANCE)
		placed.append("house:%.2f:%.2f:%.2f" % [house.position.x, house.position.z, house.rotation.y])
	for slot in pattern.get("looted_house_slots", []):
		var lh: Node3D = _make_house(ctx, rng, rect, slot)
		parent.add_child(lh)
		add_house_collider(lh)
		LootVisual.apply_grayscale(lh)
		placed.append("looted_house:%.2f:%.2f:%.2f" % [lh.position.x, lh.position.z, lh.rotation.y])
	var trees := rng.randi_range(pattern["tree_range"].x, pattern["tree_range"].y)
	for i in trees:
		var tree: Node3D = ctx["tree_scene"].instantiate()
		tree.scale = Vector3.ONE * float(ctx["tree_scale"])
		parent.add_child(tree)
		tree.position = Vector3(rect.position.x + rng.randf_range(2.0, rect.size.x - 2.0), 0, rect.position.y + rng.randf_range(2.0, rect.size.y - 2.0))
		tree.rotation.y = rng.randf() * TAU
		placed.append("tree:%.2f:%.2f" % [tree.position.x, tree.position.z])
		_add_tree_zone(parent, tree)
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
			car.empty_chance = CAR_EMPTY_CHANCE
			parent.add_child(car)
			car.global_position = pos
			car.rotation.y = rot
			placed.append("car:%.2f:%.2f:%.2f" % [pos.x, pos.z, rot])
	var want_looted_cars := rng.randi_range(pattern["looted_car_count"].x, pattern["looted_car_count"].y)
	if want_looted_cars > 0:
		var lcar_sides: Array = []
		for s in pattern.get("looted_car_sides", pattern.get("car_sides", [])):
			if ctx["edge_check"].call(s):
				lcar_sides.append(s)
		if lcar_sides.size() > 0:
			for idx in range(lcar_sides.size() - 1, 0, -1):
				var k := rng.randi_range(0, idx)
				var tmp = lcar_sides[k]
				lcar_sides[k] = lcar_sides[idx]
				lcar_sides[idx] = tmp
			var rw2 := float(ctx["road_width"])
			for c in mini(want_looted_cars, lcar_sides.size()):
				var s: int = lcar_sides[c]
				var t := rng.randf_range(0.3, 0.75)
				var pos2: Vector3
				var rot2 := 0.0
				match s:
					0:
						pos2 = Vector3(rect.position.x + rect.size.x * t, 0, rect.position.y - rw2 * 0.5 + 1.2)
						rot2 = PI * 0.5 if rng.randf() < 0.5 else -PI * 0.5
					1:
						pos2 = Vector3(rect.position.x + rect.size.x + rw2 * 0.5 - 1.2, 0, rect.position.y + rect.size.y * t)
						rot2 = 0.0 if rng.randf() < 0.5 else PI
					2:
						pos2 = Vector3(rect.position.x + rect.size.x * t, 0, rect.position.y + rect.size.y + rw2 * 0.5 - 1.2)
						rot2 = PI * 0.5 if rng.randf() < 0.5 else -PI * 0.5
					3:
						pos2 = Vector3(rect.position.x - rw2 * 0.5 + 1.2, 0, rect.position.y + rect.size.y * t)
						rot2 = 0.0 if rng.randf() < 0.5 else PI
				var lcar: Node3D = ctx["car_scene"].instantiate()
				lcar.loot_table = null
				parent.add_child(lcar)
				lcar.global_position = pos2
				lcar.rotation.y = rot2
				lcar.searched = true
				LootVisual.apply_grayscale(lcar)
				placed.append("looted_car:%.2f:%.2f:%.2f" % [pos2.x, pos2.z, rot2])


## 집 노드를 슬롯(side, t) 위치에 맞춰 생성한다. 활성 집·털린 집 배치에 공용.
static func _make_house(ctx: Dictionary, rng: RandomNumberGenerator, rect: Rect2, slot: Array) -> Node3D:
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
	return house


static func _add_tree_zone(parent: Node3D, tree: Node3D) -> void:
	var zone := Node3D.new()
	zone.set_script(preload("res://scripts/world/tree_zone.gd"))
	parent.add_child(zone)
	zone.global_position = tree.global_position
	var ab := merged_aabb(tree)
	# 수관 폭의 절반 + 여유. 너무 좁으면 장애물로 느껴지지 않아 하한을 둔다.
	zone.radius = clampf(maxf(ab.size.x, ab.size.z) * 0.5 + 0.3, 0.8, 3.0)


static var _shared_base_mesh: BoxMesh
static var _shared_base_mat: StandardMaterial3D


static func _add_base(parent: Node3D, rect: Rect2, ctx: Dictionary) -> void:
	var mi := MeshInstance3D.new()
	# 실게임은 infinite_world가 공유 메시·재질을 넘기고, 구 ctx(테스트)는
	# 정적 공유본으로 폴백한다. 어느 쪽도 청크마다 새로 만들지 않는다.
	if ctx.has("base_mesh") and ctx.has("base_mat"):
		mi.mesh = ctx["base_mesh"]
		mi.material_override = ctx["base_mat"]
	else:
		if _shared_base_mesh == null:
			_shared_base_mesh = BoxMesh.new()
			_shared_base_mesh.size = Vector3(rect.size.x, 0.04, rect.size.y)
		if _shared_base_mat == null:
			_shared_base_mat = StandardMaterial3D.new()
			_shared_base_mat.albedo_color = Color(0.45, 0.48, 0.42)
			_shared_base_mat.roughness = 1.0
		mi.mesh = _shared_base_mesh
		mi.material_override = _shared_base_mat
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


## 집을 수색 컨테이너로 만든다. 집의 병합 AABB를 그대로 상호작용 범위로 쓰고,
## 콜라이더는 world 레이어 1(이동 차단)과 별개로 interactable 레이어 4에만 실어
## 플레이어 이동을 막지 않는다. 수색 완료는 라벨 대신 건물 그레이스케일로 표시한다.
static func add_house_loot(house: Node3D, loot_table: LootTable, empty_chance: float) -> void:
	var ab := merged_aabb(house)
	if ab.size.length() < 0.1:
		return
	var body := StaticBody3D.new()
	body.collision_layer = 8
	body.collision_mask = 0
	body.set_script(HOUSE_LOOT_SCRIPT)
	body.loot_table = loot_table
	body.empty_chance = empty_chance
	var cs := CollisionShape3D.new()
	cs.name = "CollisionShape3D"
	var bs := BoxShape3D.new()
	bs.size = ab.size
	cs.shape = bs
	body.add_child(cs)
	var center: Vector3 = ab.get_center()
	body.position = center
	cs.position = Vector3.ZERO
	house.add_child(body)
