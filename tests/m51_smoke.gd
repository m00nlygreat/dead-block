extends Node

const PLAYER_SCENE := preload("res://scenes/player/player.tscn")
const TRASH_LOOT := preload("res://resources/loot_tables/trash_common.tres")


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

	var soda = ItemDB.get_item("drink_soda")
	var booze = ItemDB.get_item("drink_booze")
	print("T1_NEW_DRINKS_EXIST: ", soda != null and booze != null)
	print("T2_DRINKS_ARE_THIRST_CONSUMABLES: ", soda.is_consumable() and soda.thirst_restore > 0 and booze.is_consumable() and booze.thirst_restore > 0)
	print("T3_DRINKS_SINGLE_USE: ", soda.durability == 1 and booze.durability == 1)

	var trash_ids: Array = []
	for e in TRASH_LOOT.entries:
		trash_ids.append(e.item_id)
	print("T4_TRASH_HAS_ALL_DRINKS: ", trash_ids.has("water") and trash_ids.has("drink_soda") and trash_ids.has("drink_booze"))

	var seen := {}
	for i in 400:
		for r in TRASH_LOOT.roll():
			seen[r["id"]] = true
	print("T5_ROLL_DROPS_ALL: ", seen.has("water") and seen.has("drink_soda") and seen.has("drink_booze"))

	InventoryManager.add_item("drink_soda", 2)
	player.thirst = 20.0
	InventoryManager.set_selected(_selected_slot_of("drink_soda"))
	Input.action_press("interact")
	await _ticks(10)
	print("T6_SODA_CONSUME_STARTED: ", player.is_consuming())
	await _ticks(90)
	Input.action_release("interact")
	await _ticks(5)
	print("T7_SODA_QUENCHED_AND_GONE: ", player.thirst > 40.0 and InventoryManager.count_of("drink_soda") == 1)

	print("M51_SMOKE_DONE")
	get_tree().quit(0)
