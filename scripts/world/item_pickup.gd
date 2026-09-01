extends Area3D

@export var item_id := ""
@export var qty := 1
## 드롭 전 남은 내구도(-1이면 신규/최대치)
@export var durability_left := -1


func _ready() -> void:
	_apply_visual()
	_update_label()


func _apply_visual() -> void:
	var scene := PickupModels.get_scene(item_id)
	var mesh_mi: MeshInstance3D = $Mesh
	if scene != null:
		mesh_mi.visible = false
		var holder := Node3D.new()
		holder.name = "Visual"
		add_child(holder)
		holder.position = Vector3(0.0, 0.05, 0.0)
		var inst := scene.instantiate() as Node3D
		inst.scale = Vector3.ONE * PickupModels.get_scale(item_id)
		inst.rotation = Vector3(deg_to_rad(PickupModels.get_tilt(item_id)), randf() * TAU, 0.0)
		holder.add_child(inst)
	else:
		var item = ItemDB.get_item(item_id)
		if item != null:
			var mat := StandardMaterial3D.new()
			mat.albedo_color = ItemData.rarity_color(item.rarity)
			mat.roughness = 0.7
			mesh_mi.material_override = mat


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
