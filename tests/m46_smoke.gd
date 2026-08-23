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

	var single_use: bool = ItemDB.get_item("water").durability == 1 \
		and ItemDB.get_item("food_canned").durability == 1 \
		and ItemDB.get_item("food_choco").durability == 1 \
		and ItemDB.get_item("painkiller").durability == 1 \
		and ItemDB.get_item("bandage").durability == 1
	print("T1_ALL_CONSUMABLES_SINGLE_USE_DATA: ", single_use)

	InventoryManager.add_item("water", 2)
	print("T2_TWO_BOTTLES: ", InventoryManager.count_of("water") == 2)

	player.thirst = 40.0
	InventoryManager.set_selected(_selected_slot_of("water"))
	Input.action_press("interact")
	await _ticks(10)
	print("T3_CONSUME_STARTED: ", player.is_consuming())
	await _ticks(120)
	print("T4_CONSUME_FINISHED: ", not player.is_consuming())
	print("T5_ONE_UNIT_REMOVED_PER_USE: ", InventoryManager.count_of("water") == 1)
	print("T6_THIRST_RESTORED: ", player.thirst > 40.0)

	Input.action_release("interact")
	await _ticks(5)
	player.thirst = 30.0
	Input.action_press("interact")
	await _ticks(10)
	print("T7_SECOND_BOTTLE_CONSUMES: ", player.is_consuming())
	await _ticks(120)
	Input.action_release("interact")
	await _ticks(5)
	print("T8_ITEM_GONE_AFTER_LAST_USE: ", InventoryManager.count_of("water") == 0)
	print("T9_HOTBAR_ENTRY_CLEARED: ", _selected_slot_of("water") == -1 and InventoryManager.get_selected_id() == "")

	print("M46_SMOKE_DONE")
	get_tree().quit(0)
