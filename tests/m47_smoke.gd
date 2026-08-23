extends Node

const PLAYER_SCENE := preload("res://scenes/player/player.tscn")
const CONTAINER_SCENE := preload("res://scenes/world/loot_container.tscn")
const PICKUP_SCENE := preload("res://scenes/items/item_pickup.tscn")
const LOOT := preload("res://resources/loot_tables/trash_common.tres")


func _ready() -> void:
	_run()


func _ticks(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _run() -> void:
	var w := Node3D.new()
	add_child(w)
	var floor_body := StaticBody3D.new()
	floor_body.collision_layer = 1
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(300, 1, 300)
	cs.shape = bs
	cs.position.y = -0.5
	floor_body.add_child(cs)
	w.add_child(floor_body)

	var player := PLAYER_SCENE.instantiate()
	w.add_child(player)
	await _ticks(5)

	var container := CONTAINER_SCENE.instantiate()
	container.loot_table = LOOT
	w.add_child(container)
	container.global_position = player.global_position + Vector3(1.0, 0.0, 0.0)

	var pk := PICKUP_SCENE.instantiate()
	pk.item_id = "water"
	pk.qty = 2
	w.add_child(pk)
	pk.global_position = player.global_position + Vector3(-1.6, 0.0, 0.0)
	await _ticks(5)

	print("T1_BOTH_IN_RANGE: ", player.get_interact_target() != null and container.can_interact())
	print("T2_PICKUP_WINS_EVEN_IF_FARTHER: ", player.get_interact_target() == pk)

	Input.action_press("interact")
	await _ticks(8)
	print("T3_ITEM_PICKED_FIRST: ", InventoryManager.count_of("water") == 2 and not container.searched and not is_instance_valid(pk))

	await _ticks(140)
	Input.action_release("interact")
	await _ticks(3)
	print("T4_SEARCH_RESUMES_AFTER_PICKUP: ", container.searched)

	print("M47_SMOKE_DONE")
	get_tree().quit(0)
