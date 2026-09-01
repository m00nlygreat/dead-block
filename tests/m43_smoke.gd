extends Node

const PLAYER_SCENE := preload("res://scenes/player/player.tscn")


func _ready() -> void:
	_run()


func _ticks(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _run() -> void:
	var w := Node3D.new()
	add_child(w)
	var player := PLAYER_SCENE.instantiate()
	w.add_child(player)
	await _ticks(5)

	print("T1_PICKUP_EQUIPS_ON_SELECTED_SLOT: ", InventoryManager.add_item("weapon_bat", 1) == 1 and InventoryManager.equipped_weapon_id == "weapon_bat")
	await _ticks(2)
	print("T2_VISUAL_HELD: ", player._weapon_visual != null)

	InventoryManager.set_selected(1)
	await _ticks(3)
	print("T3_SELECT_EMPTY_UNEQUIPS: ", InventoryManager.equipped_weapon_id == "" and InventoryManager.get_equipped_item() == null)
	print("T4_VISUAL_HOLSTERED: ", player._weapon_visual == null)

	InventoryManager.cycle_selected(-1)
	await _ticks(2)
	print("T5_BACK_TO_WEAPON_REEQUIPS: ", InventoryManager.equipped_weapon_id == "weapon_bat" and InventoryManager.equipped_durability == 40 and player._weapon_visual != null)

	InventoryManager.add_item("food_canned", 2)
	var canned_slot := -1
	for i in InventoryManager.HOTBAR_SIZE:
		if InventoryManager.quick_slots[i] == "food_canned":
			canned_slot = i
			break
	print("T6_CANNED_REGISTERED: ", canned_slot > 0)
	InventoryManager.set_selected(canned_slot)
	await _ticks(3)
	print("T7_CONSUMABLE_UNEQUIPS_WEAPON: ", InventoryManager.equipped_weapon_id == "" and player._weapon_visual == null)

	InventoryManager.set_selected(0)
	await _ticks(2)
	var dur_before_drop := InventoryManager.equipped_weapon_id == "weapon_bat"
	InventoryManager.drop_selected()
	await _ticks(2)
	print("T8_DROP_SELECTED_UNEQUIPS: ", dur_before_drop and InventoryManager.equipped_weapon_id == "" and InventoryManager.count_of("weapon_bat") == 0)

	print("M43_SMOKE_DONE")
	get_tree().quit(0)
