extends Node

const PLAYER_SCENE := preload("res://scenes/player/player.tscn")
const CONTAINER_SCENE := preload("res://scenes/world/loot_container.tscn")
const CAR_SCENE := preload("res://scenes/world/car_trunk.tscn")


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
	InventoryManager.reset_run()

	# T1: 섭취 시작 후 수색 가능 컨테이너가 근처에 나타나도 섭취는 끝까지 완료
	InventoryManager.add_item("water", 1)
	var widx := InventoryManager.quick_slots.find("water")
	InventoryManager.set_selected(widx)
	player.thirst = 10.0
	var tb: float = player.thirst
	var dur0 := InventoryManager.get_current_durability("water")

	Input.action_press("interact")
	await _ticks(20)
	print("M39_T1_STARTED_EATING: ", player.is_consuming())

	var box := CONTAINER_SCENE.instantiate()
	box.loot_table = load("res://resources/loot_tables/trash_common.tres")
	box.search_time = 60.0
	w.add_child(box)
	box.global_position = player.global_position + Vector3(1.0, 0.0, 0.0)
	await _ticks(5)
	print("M39_T1_TARGET_NEAR_WHILE_EATING: ", player.get_interact_target() == box)

	await _ticks(90)
	Input.action_release("interact")
	await _ticks(2)
	print("M39_T1_CONSUME_FINISHED_DESPITE_SEARCH_AREA: ",
		not player.is_consuming() and player.thirst > tb + 30.0
		and InventoryManager.get_current_durability("water") == dur0 - 1,
		" (thirst %.1f->%.1f)" % [tb, player.thirst])
	print("M39_T1_NO_SEARCH_DURING_EAT: ", InventoryManager.slots.any(func(s): return s != null and s["id"] == "scrap") == false)

	# T2: 차량 콜라이더가 모델 축(Z 길이)과 정렬, 좌우 과대 없음
	var car := CAR_SCENE.instantiate()
	w.add_child(car)
	await _ticks(2)
	var shape_node: CollisionShape3D = car.get_node("Shape")
	var sz: Vector3 = shape_node.shape.size
	print("M39_T2_CAR_COLLIDER_ALIGNED: ", sz.x <= 1.8 and sz.z >= 2.6,
		" (x=%.1f y=%.1f z=%.1f)" % [sz.x, sz.y, sz.z])

	print("M39_SMOKE_DONE")
	get_tree().quit(0)
