extends StaticBody3D

const PICKUP_SCENE := preload("res://scenes/items/item_pickup.tscn")
const LootVisual := preload("res://scripts/util/loot_visual.gd")

@export var loot_table: LootTable
@export var search_time := 1.0
@export var noise_radius := 8.0
## 수색 시 아이템이 나오지 않을 확률(0~1). 수색 가능 컨테이너가 늘어났을 때
## 전체 룻 밀도를 조절하는 용도. 수색 그 자체는 완료되고 소음도 발생한다.
@export var empty_chance := 0.0

var searched := false


func _ready() -> void:
	add_to_group("containers")


func can_interact() -> bool:
	return not searched and loot_table != null


func interact_label() -> String:
	return "수색"


func complete_interaction(_by: Node) -> void:
	searched = true
	NoiseSystem.emit_noise(global_position, noise_radius, 1)
	_apply_searched_visual()
	if randf() >= empty_chance:
		for r in loot_table.roll():
			var added: int = InventoryManager.add_item(r.id, r.qty)
			if added < r.qty:
				_spawn_remainder(r.id, r.qty - added)


## 수색 완료를 오브젝트 색상으로 표현한다. 기본은 자신(차량) 서브트리.
func _apply_searched_visual() -> void:
	LootVisual.apply_grayscale(self)


func _spawn_remainder(id: String, qty: int) -> void:
	var pk := PICKUP_SCENE.instantiate()
	pk.item_id = id
	pk.qty = qty
	get_parent().add_child(pk)
	pk.global_position = global_position + Vector3(randf_range(-0.8, 0.8), 0.0, randf_range(-0.8, 0.8))
