class_name TreeZone
extends Node3D

## 나무 통과 감속 존. 충돌로 막지 않고 지나가는 몸체의 이동만 느려진다.
var radius := 1.0


func _ready() -> void:
	add_to_group("tree_zones")


## node 주변(수평 거리)에 감속 존이 있는지 검사. node는 씬 안에 있어야 한다.
static func slows(node: Node3D, body_margin := 0.3) -> bool:
	var tree := node.get_tree()
	if tree == null:
		return false
	for z in tree.get_nodes_in_group("tree_zones"):
		var zn := z as Node3D
		if zn == null or not is_instance_valid(zn):
			continue
		var r_v = zn.get("radius")
		if r_v == null:
			continue
		var d: Vector3 = node.global_position - zn.global_position
		d.y = 0.0
		if d.length() <= float(r_v) + body_margin:
			return true
	return false
