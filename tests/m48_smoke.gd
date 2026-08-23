extends Node

const PLAYER_SCENE := preload("res://scenes/player/player.tscn")


func _ready() -> void:
	_run()


func _ticks(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _selected_slot_of(id: String) -> int:
	for i in InventoryManager.HOTBAR_SIZE:
		if InventoryManager.quick_slots[i] == id:
			return i
	return -1


func _run() -> void:
	var w := Node3D.new()
	add_child(w)
	var player := PLAYER_SCENE.instantiate()
	w.add_child(player)
	await _ticks(5)

	InventoryManager.add_item("weapon_bat")
	await _ticks(3)
	print("T1_EQUIPPED_FRESH: ", InventoryManager.equipped_weapon_id == "weapon_bat" and InventoryManager.equipped_durability == 25)

	InventoryManager.equipped_durability = 13
	player._drop_selected()
	await _ticks(2)
	var pk: Node = null
	for c in w.get_children():
		if c is Area3D and c.get("item_id") != null and c.get("item_id") == "weapon_bat":
			pk = c
			break
	print("T2_DROP_CARRIES_DURABILITY: ", pk != null and pk.durability_left == 13)
	print("T3_DROP_REMOVED_FROM_INV: ", InventoryManager.count_of("weapon_bat") == 0 and InventoryManager.equipped_weapon_id == "")

	pk.complete_interaction(player)
	await _ticks(3)
	print("T4_PICKUP_KEEPS_DURABILITY: ", InventoryManager.count_of("weapon_bat") == 1 and InventoryManager.equipped_weapon_id == "weapon_bat" and InventoryManager.equipped_durability == 13)

	InventoryManager.set_selected(1)
	await _ticks(2)
	print("T5_UNEQUIPPED_STILL_TRACKED: ", InventoryManager.equipped_weapon_id == "" and InventoryManager.get_current_durability("weapon_bat") == 13)

	InventoryManager.set_selected(_selected_slot_of("weapon_bat"))
	await _ticks(2)
	InventoryManager.weapon_used()
	print("T6_REEQUIP_AND_USE: ", InventoryManager.equipped_durability == 12)

	print("M48_SMOKE_DONE")
	get_tree().quit(0)
