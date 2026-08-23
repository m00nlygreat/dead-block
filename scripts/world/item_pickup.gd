extends Area3D

@export var item_id := ""
@export var qty := 1
## 드롭 전 남은 내구도(-1이면 신규/최대치)
@export var durability_left := -1


func _ready() -> void:
	_update_label()


func can_interact() -> bool:
	return qty > 0


func interact_priority() -> int:
	return 1


func interact_label() -> String:
	return "주움"


func complete_interaction(_by: Node) -> void:
	var added: int = InventoryManager.add_item(item_id, qty, durability_left)
	qty -= added
	if qty <= 0:
		queue_free()
	else:
		durability_left = -1
		_update_label()


func setup(id: String, amount: int) -> void:
	item_id = id
	qty = amount


func _update_label() -> void:
	var item = ItemDB.get_item(item_id)
	var display := item_id
	if item != null:
		display = item.display_name
	$Label3D.text = "%s ×%d" % [display, qty]
