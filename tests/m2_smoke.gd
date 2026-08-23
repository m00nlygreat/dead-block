extends Node

const PLAYER_SCENE := preload("res://scenes/player/player.tscn")
const CONTAINER_SCENE := preload("res://scenes/world/loot_container.tscn")
const TRASH_TABLE := preload("res://resources/loot_tables/trash_common.tres")


func _ready() -> void:
	_run()


func _floor(w: Node3D) -> void:
	var floor_body := StaticBody3D.new()
	floor_body.collision_layer = 1
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(300, 1, 300)
	cs.shape = bs
	cs.position.y = -0.5
	floor_body.add_child(cs)
	w.add_child(floor_body)


func _run() -> void:
	print("ITEMS_LOADED: ", ItemDB.all_items().size())

	var w := Node3D.new()
	add_child(w)
	_floor(w)

	var player: CharacterBody3D = PLAYER_SCENE.instantiate()
	w.add_child(player)

	var container: Node3D = CONTAINER_SCENE.instantiate()
	container.loot_table = TRASH_TABLE
	container.position = Vector3(1.8, 0, 1.4)
	w.add_child(container)
	for i in 10:
		await get_tree().process_frame

	player.global_position = container.global_position + Vector3(1.2, 0, 0)
	for i in 10:
		await get_tree().process_frame

	var target = player.get_interact_target()
	print("TARGET_FOUND: ", target == container)

	Input.action_press("interact")
	var waited := 0
	while not container.searched and waited < 600:
		await get_tree().physics_frame
		waited += 1
	Input.action_release("interact")

	print("CONTAINER_SEARCHED: ", container.searched, " TICKS: ", waited)
	print("GAINED_SOMETHING: ", InventoryManager.total_weight() > 0.0)

	var pk: Node3D = load("res://scenes/items/item_pickup.tscn").instantiate()
	pk.setup("bandage", 2)
	w.add_child(pk)
	pk.global_position = player.global_position + Vector3(0.8, 0, 0)
	for i in 10:
		await get_tree().process_frame

	target = player.get_interact_target()
	print("PICKUP_TARGET: ", target == pk)
	Input.action_press("interact")
	for i in 30:
		await get_tree().process_frame
	Input.action_release("interact")

	print("BANDAGE_COUNT: ", InventoryManager.count_of("bandage"))

	var overflow_guard := false
	for i in 100:
		if InventoryManager.add_item("scrap_metal", 1) == 0:
			overflow_guard = true
			break
	print("OVERFLOW_GUARD: ", overflow_guard, " WEIGHT_NOW: ", snappedf(InventoryManager.total_weight(), 0.1))

	var moved_cancel := false
	var c2: Node3D = CONTAINER_SCENE.instantiate()
	c2.loot_table = TRASH_TABLE
	c2.position = Vector3(-6, 0, -4)
	w.add_child(c2)
	player.global_position = Vector3(-6, 0, -4) + Vector3(1.2, 0, 0)
	for i in 5:
		await get_tree().process_frame
	Input.action_press("move_up")
	Input.action_press("interact")
	for i in 120:
		await get_tree().process_frame
	Input.action_release("move_up")
	Input.action_release("interact")
	moved_cancel = not c2.searched
	print("MOVE_CANCELS_SEARCH: ", moved_cancel)

	player.global_position = Vector3.ZERO
	for i in 5:
		await get_tree().process_frame
	Input.action_press("move_left")
	for i in 60:
		await get_tree().physics_frame
	Input.action_release("move_left")
	for i in 10:
		await get_tree().physics_frame
	var face_err := absf(angle_difference(player.rotation.y, PI * 0.5))
	print("FACES_MOVE_DIR: ", face_err < 0.15, " ERR: ", snappedf(face_err, 0.01))

	print("M2_SMOKE_DONE")
	get_tree().quit(0)
