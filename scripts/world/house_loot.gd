extends "res://scripts/world/loot_container.gd"

## 집 수색 컨테이너. 건물 내부(수색 불가 구역)에 아이템이 떨어지지 않도록
## 잔여 드롭을 수색한 플레이어 주변 지면에 흩뿌린다.
const DROP_SPREAD := 1.1

var _last_by: Node = null


func complete_interaction(by: Node) -> void:
	_last_by = by
	super(by)


func _spawn_remainder(id: String, qty: int) -> void:
	var origin: Vector3
	if _last_by is Node3D:
		origin = (_last_by as Node3D).global_position
	else:
		origin = global_position
	var pk := PICKUP_SCENE.instantiate()
	pk.item_id = id
	pk.qty = qty
	get_parent().add_child(pk)
	pk.global_position = origin + Vector3(randf_range(-DROP_SPREAD, DROP_SPREAD), 0.0, randf_range(-DROP_SPREAD, DROP_SPREAD))


## 집은 컨테이너가 건물 노드의 자식이므로 건물 전체를 그레이스케일한다.
func _apply_searched_visual() -> void:
	if get_parent() is Node3D:
		LootVisual.apply_grayscale(get_parent() as Node3D)