extends Node

const ZOMBIE_SCENE := preload("res://scenes/zombie/zombie.tscn")
const PLAYER_SCENE := preload("res://scenes/player/player.tscn")
const HUD_SCENE := preload("res://scenes/ui/hud.tscn")


func _ready() -> void:
	_run()


func _ticks(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


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
	var w := Node3D.new()
	add_child(w)
	_floor(w)

	var player: CharacterBody3D = PLAYER_SCENE.instantiate()
	w.add_child(player)
	var hud: CanvasLayer = HUD_SCENE.instantiate()
	w.add_child(hud)
	for i in 10:
		await get_tree().physics_frame

	print("T13_BAT_TO_HOTBAR: ", InventoryManager.add_item("weapon_bat", 1) == 1 and InventoryManager.quick_slots.has("weapon_bat"))

	var ev := InputEventKey.new()
	ev.keycode = KEY_3
	ev.pressed = true
	Input.parse_input_event(ev)
	await _ticks(3)
	print("T14_KEY_SELECTS: ", InventoryManager.selected_slot == 2)

	var wheel := InputEventMouseButton.new()
	wheel.button_index = MOUSE_BUTTON_WHEEL_DOWN
	wheel.pressed = true
	Input.parse_input_event(wheel)
	await _ticks(3)
	print("T15_WHEEL_CYCLES: ", InventoryManager.selected_slot == 3)

	InventoryManager.set_selected(0)
	var before_count: int = InventoryManager.count_of("weapon_bat")
	var dropped: String = InventoryManager.drop_selected()
	await _ticks(2)
	print("T16_DROP_REMOVES: ", dropped == "weapon_bat" and InventoryManager.count_of("weapon_bat") == before_count - 1)
	print("T17_HOTBAR_CLEARED_WHEN_EMPTY: ", not InventoryManager.quick_slots.has("weapon_bat"))

	player.take_damage(9999.0)
	await _ticks(5)
	print("T18_PLAYER_DEAD: ", player.is_dead())
	print("T19_GAMEOVER_SHOWN: ", hud._go_root.visible)

	InventoryManager.reset_run()
	await _ticks(2)
	print("T20_RESET_RUN_CLEAN: ", InventoryManager.total_weight() == 0.0 and InventoryManager.quick_slots.all(func(s): return s == null))

	print("M37_SMOKE_DONE")
	get_tree().quit(0)
