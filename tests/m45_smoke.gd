extends Node

const PLAYER_SCENE := preload("res://scenes/player/player.tscn")
const HUD_SCENE := preload("res://scenes/ui/hud.tscn")
const CONTAINER_SCENE := preload("res://scenes/world/car_trunk.tscn")
const LOOT := preload("res://resources/loot_tables/trash_common.tres")


func _ready() -> void:
	_run()


func _ticks(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _head_screen(hud: Node, player: Node3D) -> Vector2:
	var cam := get_viewport().get_camera_3d()
	return cam.unproject_position(player.global_position + Vector3.UP * hud.HEAD_OFFSET)


func _over_head(bar: Control, head: Vector2) -> bool:
	var center_x: float = bar.position.x + bar.size.x * 0.5
	var bottom_y: float = bar.position.y + bar.size.y
	var on_screen: bool = bar.position.x >= -1.0 and bar.position.y >= -1.0
	return absf(center_x - head.x) <= 2.0 and bottom_y <= head.y + 0.5 and on_screen


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
	var hud := HUD_SCENE.instantiate()
	w.add_child(hud)
	var cam := Camera3D.new()
	cam.fov = 45.0
	cam.rotation_degrees = Vector3(-86.0, 0.0, 0.0)
	w.add_child(cam)

	await _ticks(5)
	cam.global_position = player.global_position + Vector3(0.0, 10.4, 0.73)
	cam.current = true
	await _ticks(3)

	var container := CONTAINER_SCENE.instantiate()
	container.loot_table = LOOT
	w.add_child(container)
	container.global_position = player.global_position + Vector3(1.0, 0.0, 0.0)
	await _ticks(5)

	Input.action_press("interact")
	await _ticks(8)
	var head := _head_screen(hud, player)
	print("T1_SEARCH_BAR_SHOWN: ", hud._bar.visible and hud._player.is_searching())
	print("T2_SEARCH_BAR_OVER_HEAD: ", hud._bar.visible and _over_head(hud._bar, head), " bar=", hud._bar.position, " head=", head)

	Input.action_release("interact")
	await _ticks(3)
	print("T3_SEARCH_BAR_HIDDEN_ON_RELEASE: ", not hud._bar.visible)

	InventoryManager.add_item("water", 1)
	var water_slot := -1
	for i in InventoryManager.HOTBAR_SIZE:
		if InventoryManager.quick_slots[i] == "water":
			water_slot = i
			break
	InventoryManager.set_selected(water_slot)
	container.searched = true
	Input.action_press("interact")
	await _ticks(8)
	head = _head_screen(hud, player)
	print("T4_USE_BAR_SHOWN: ", hud._use_bar.visible and hud._player.is_consuming())
	print("T5_USE_BAR_OVER_HEAD: ", hud._use_bar.visible and _over_head(hud._use_bar, head))

	Input.action_release("interact")
	await _ticks(3)
	print("T6_USE_BAR_HIDDEN_ON_RELEASE: ", not hud._use_bar.visible)

	print("M45_SMOKE_DONE")
	get_tree().quit(0)
