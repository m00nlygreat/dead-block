extends Node

const PLAYER_SCENE := preload("res://scenes/player/player.tscn")
const ZOMBIE_SCENE := preload("res://scenes/zombie/zombie.tscn")
const PISTOL_TRES := preload("res://resources/items/weapon_9mm.tres")
const PISTOL_MODEL := preload("res://scenes/items/pistol_model.tscn")
const TRASH_LOOT := preload("res://resources/loot_tables/trash_common.tres")


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
	var player := PLAYER_SCENE.instantiate()
	w.add_child(player)
	player.global_position = Vector3.ZERO
	await _ticks(5)
	GameState.reset_run_state()

	var ok := true
	ok = ok and PISTOL_TRES.id == "weapon_9mm"
	ok = ok and PISTOL_TRES.is_ranged
	ok = ok and is_equal_approx(PISTOL_TRES.damage, 30.0)
	ok = ok and is_equal_approx(PISTOL_TRES.headshot_chance, 0.1)
	ok = ok and PISTOL_TRES.projectile_speed > 0.0
	print("T1_TRES_RANGED: ", ok)

	print("T2_ITEMDB_REGISTERED: ",
		ItemDB.get_item("weapon_9mm") != null
		and ItemDB.get_item("weapon_9mm").display_name == "9mm 권총")

	print("T3_PICKUP_MODEL_MAPPED: ", PickupModels.has_model("weapon_9mm"))

	var model := PISTOL_MODEL.instantiate() as Node3D
	w.add_child(model)
	var meshes := 0
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		if (mi as MeshInstance3D).mesh != null:
			meshes += 1
	model.queue_free()
	print("T4_MODEL_HAS_MESHES: ", meshes >= 3, " (meshes=", meshes, ")")

	var equipped: bool = InventoryManager.add_item("weapon_9mm", 1) == 1 \
		and InventoryManager.equipped_weapon_id == "weapon_9mm"
	await _ticks(3)
	print("T5_EQUIP_AND_HOTBAR: ",
		equipped and player._weapon_visual != null and player._visual_id == "weapon_9mm"
		and InventoryManager.quick_slots.has("weapon_9mm"))
	print("T6_MAGAZINE_MAX: ", InventoryManager.equipped_durability == 14,
		" (mag=", InventoryManager.equipped_durability, "/14)")

	## 좀비 추가 시 물리 서버가 플레이어를 ~1m 띄움(headless 특성).
	## 머즐 높이 = player.y + 1.0 이므로 좀비 캡슐 중심을 그 높이에 둔다.
	var z: Zombie = ZOMBIE_SCENE.instantiate()
	w.add_child(z)
	z.set_physics_process(false)
	await _ticks(3)
	z.global_position = Vector3(0.0, player.global_position.y + 1.0, -6.0)
	z.max_hp = 500.0
	z.hp = 500.0
	await _ticks(2)

	Input.action_press("aim")
	Input.action_press("attack")
	await _ticks(6)
	Input.action_release("attack")
	Input.action_release("aim")
	await _ticks(2)

	var bullets := 0
	for c in get_tree().current_scene.get_children():
		if c is Bullet:
			bullets += 1
	print("T7_BULLET_SPAWNED: ", bullets >= 1, " (count=", bullets, ")")

	await _ticks(80)
	print("T8_BULLET_HIT_ZOMBIE: ", z.hp < 500.0 or z.state == z.State.DEAD, " (hp=", z.hp, ")")
	print("T9_AMMO_CONSUMED: ", InventoryManager.equipped_durability < 14,
		" (mag=", InventoryManager.equipped_durability, ")")

	var count_before: int = InventoryManager.count_of("weapon_9mm")
	var refilled: bool = InventoryManager.add_item("weapon_9mm", 1) == 1 \
		and InventoryManager.count_of("weapon_9mm") == count_before \
		and InventoryManager.equipped_durability == 14
	await _ticks(2)
	print("T10_PICKUP_REFILLS_NOT_STACKS: ", refilled,
		" (count=", InventoryManager.count_of("weapon_9mm"), " mag=", InventoryManager.equipped_durability, ")")

	InventoryManager.equipped_durability = 1
	InventoryManager.weapon_used()
	await _ticks(2)
	print("T11_EMPTY_NOT_BROKEN: ",
		InventoryManager.equipped_durability == 0
		and InventoryManager.count_of("weapon_9mm") > 0
		and InventoryManager.get_equipped_item() != null,
		" (mag=", InventoryManager.equipped_durability, " count=", InventoryManager.count_of("weapon_9mm"), ")")

	InventoryManager.reset_run()
	var fresh: bool = InventoryManager.add_item("weapon_9mm", 1) == 1 \
		and InventoryManager.quick_slots.has("weapon_9mm") \
		and InventoryManager.count_of("weapon_9mm") == 1
	await _ticks(2)
	print("T12_FRESH_PICKUP_REGISTERS_HOTBAR: ", fresh)

	var in_loot := false
	for e in TRASH_LOOT.entries:
		if e.item_id == "weapon_9mm":
			in_loot = true
	print("T13_PISTOL_IN_SPAWN_TABLE: ", in_loot)

	print("M9MM_SMOKE_DONE")
	get_tree().quit(0)