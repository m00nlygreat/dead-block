extends RefCounted

const TILE := 4.0

# 도로 박스는 규격이 고정이라 전 청크가 BoxMesh를 공유한다.
# (청크마다 new하면 로드/언로드 반복에 리소스가 쌓여 웹 메모리를 압박한다.)
static var _mesh_cache: Dictionary = {}


static func _shared_box(key: String, size: Vector3) -> BoxMesh:
	if not _mesh_cache.has(key):
		var bm := BoxMesh.new()
		bm.size = size
		_mesh_cache[key] = bm
	return _mesh_cache[key]


static func build_straight(parent: Node3D, mats: Dictionary, center: Vector3, horizontal: bool, length: float, road_width: float) -> void:
	var mi := MeshInstance3D.new()
	if horizontal:
		mi.mesh = _shared_box("straight_h_%.2f_%.2f" % [length, road_width], Vector3(length, 0.02, road_width))
	else:
		mi.mesh = _shared_box("straight_v_%.2f_%.2f" % [length, road_width], Vector3(road_width, 0.02, length))
	mi.material_override = mats["asphalt"]
	parent.add_child(mi)
	mi.global_position = Vector3(center.x, 0.01, center.z)
	var count := int(length / TILE)
	for f in count:
		var o := -length * 0.5 + TILE * (float(f) + 0.5)
		if absf(o) < road_width * 0.75:
			continue
		var dash := MeshInstance3D.new()
		dash.mesh = _shared_box("dash", Vector3(TILE * 0.4, 0.01, 0.22))
		dash.material_override = mats["dash"]
		parent.add_child(dash)
		if horizontal:
			dash.global_position = Vector3(center.x + o, 0.03, center.z)
		else:
			dash.rotation.y = PI * 0.5
			dash.global_position = Vector3(center.x, 0.03, center.z + o)


static func build_junction(parent: Node3D, mats: Dictionary, pos: Vector2, road_width: float) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = _shared_box("junction_%.2f" % road_width, Vector3(road_width, 0.02, road_width))
	mi.material_override = mats["cross"]
	parent.add_child(mi)
	mi.global_position = Vector3(pos.x, 0.012, pos.y)
