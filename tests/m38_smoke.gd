extends Node

const PLAYER_SCENE := preload("res://scenes/player/player.tscn")


func _ready() -> void:
	_run()


func _ticks(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _hold_frames(consume_time: float) -> int:
	return int(ceil(consume_time * 60.0)) + 15


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
	player.survival_drain_mult = 120.0

	var h0: float = player.hunger
	var t0: float = player.thirst
	await _ticks(60)
	print("T1_STAT_DRAIN: ", player.hunger < h0 - 5.0 and player.thirst < t0 - 5.0,
		" (%.1f->%.1f / %.1f->%.1f)" % [h0, player.hunger, t0, player.thirst])

	player.hunger = 0.0
	player.thirst = 60.0
	player._starve_t = 0.0
	player.hp = 50.0
	await _ticks(140)
	print("T2_STARVE_DAMAGE: ", player.hp < 50.0, " HP: ", player.hp)

	player.survival_drain_mult = 1.0
	player.hunger = 70.0
	player.thirst = 70.0

	InventoryManager.add_item("water", 2)
	var widx := InventoryManager.quick_slots.find("water")
	InventoryManager.set_selected(widx)
	var dur0 := InventoryManager.get_current_durability("water")
	player.thirst = 20.0
	var tb: float = player.thirst
	Input.action_press("interact")
	await _ticks(_hold_frames(1.5))
	Input.action_release("interact")
	await _ticks(2)
	print("T3_DRINK_USES_DURABILITY: ",
		player.thirst > tb + 30.0 and InventoryManager.count_of("water") == 2
		and InventoryManager.get_current_durability("water") == dur0 - 1,
		" (thirst %.1f->%.1f, qty=2, dur %d->%d)" % [tb, player.thirst, dur0, InventoryManager.get_current_durability("water")])

	InventoryManager.set_selected(widx)
	Input.action_press("interact")
	await _ticks(30)
	Input.action_release("interact")
	await _ticks(2)
	print("T4_CANCEL_PARTIAL_HOLD: ",
		InventoryManager.count_of("water") == 2
		and InventoryManager.get_current_durability("water") == dur0 - 1
		and not player.is_consuming())

	Input.action_press("move_up")
	await _ticks(30)
	var pa: Vector3 = player.global_position
	await _ticks(60)
	var d_norm: float = player.global_position.distance_to(pa)
	Input.action_release("move_up")
	await _ticks(10)

	player.thirst = 15.0
	InventoryManager.set_selected(widx)
	Input.action_press("interact")
	await _ticks(5)
	Input.action_press("move_up")
	var pb: Vector3 = player.global_position
	await _ticks(60)
	var d_eat: float = player.global_position.distance_to(pb)
	Input.action_release("move_up")
	Input.action_release("interact")
	await _ticks(2)
	print("T5_SLOW_WHILE_CONSUMING: ", d_eat > 0.1 and d_eat < d_norm * 0.7,
		" (%.2f vs %.2f)" % [d_norm, d_eat])

	for k in 3:
		Input.action_press("interact")
		await _ticks(_hold_frames(1.5))
		Input.action_release("interact")
		await _ticks(2)
	var dur_final := InventoryManager.get_current_durability("water")
	print("T6_UNIT_BREAKS_RESETS_DURABILITY: ",
		InventoryManager.count_of("water") == 1 and dur_final == dur0,
		" (qty=%d, dur=%d)" % [InventoryManager.count_of("water"), dur_final])

	InventoryManager.add_item("bandage", 1)
	var bidx := InventoryManager.quick_slots.find("bandage")
	InventoryManager.set_selected(bidx)
	player.hp = 40.0
	Input.action_press("interact")
	await _ticks(_hold_frames(1.8))
	Input.action_release("interact")
	await _ticks(2)
	print("T7_BANDAGE_HEALS_AND_GONE: ",
		player.hp > 40.0 and InventoryManager.count_of("bandage") == 0,
		" HP: %.1f" % player.hp)

	print("M38_SMOKE_DONE")
	get_tree().quit(0)
