extends RefCounted

const TILE := 4.0


static func build_straight(parent: Node3D, mats: Dictionary, center: Vector3, horizontal: bool, length: float, road_width: float) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(length, 0.02, road_width) if horizontal else Vector3(road_width, 0.02, length)
	mi.mesh = bm
	mi.material_override = mats["asphalt"]
	parent.add_child(mi)
	mi.global_position = Vector3(center.x, 0.01, center.z)
	var count := int(length / TILE)
	for f in count:
		var o := -length * 0.5 + TILE * (float(f) + 0.5)
		if absf(o) < road_width * 0.75:
			continue
		var dash := MeshInstance3D.new()
		var dm := BoxMesh.new()
		dm.size = Vector3(TILE * 0.4, 0.01, 0.22)
		dash.mesh = dm
		dash.material_override = mats["dash"]
		parent.add_child(dash)
		if horizontal:
			dash.global_position = Vector3(center.x + o, 0.03, center.z)
		else:
			dash.rotation.y = PI * 0.5
			dash.global_position = Vector3(center.x, 0.03, center.z + o)


static func build_junction(parent: Node3D, mats: Dictionary, pos: Vector2, road_width: float) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(road_width, 0.02, road_width)
	mi.mesh = bm
	mi.material_override = mats["cross"]
	parent.add_child(mi)
	mi.global_position = Vector3(pos.x, 0.012, pos.y)
