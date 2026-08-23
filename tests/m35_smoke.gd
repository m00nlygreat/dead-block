extends Node

const ZOMBIE_SCENE := preload("res://scenes/zombie/zombie.tscn")
const PLAYER_SCENE := preload("res://scenes/player/player.tscn")
const SPAWNER := preload("res://scripts/world/zombie_spawner.gd")


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

	print("T5_BAT_AUTOEQUIP: ", InventoryManager.add_item("weapon_bat", 1) == 1 and InventoryManager.equipped_weapon_id == "weapon_bat")
	print("T5_DURABILITY: ", InventoryManager.equipped_durability == 25)

	player.global_position = Vector3.ZERO
	player.rotation.y = -PI * 0.5

	var zs := []
	for i in 3:
		var z: Zombie = ZOMBIE_SCENE.instantiate()
		w.add_child(z)
		z.global_position = Vector3(0.8 + i * 1.2, 0, 0)
		zs.append(z)
	await _ticks(5)

	Input.action_press("attack")
	await _ticks(2)
	Input.action_release("attack")
	await _ticks(40)

	var hit_count := 0
	for z in zs:
		if is_instance_valid(z) and z.hp < z.max_hp:
			hit_count += 1
	print("T6_TWO_TARGETS_HIT: ", hit_count == 2, " HITS: ", hit_count)
	print("T6_DURABILITY_DECREMENTED: ", InventoryManager.equipped_durability == 24)

	InventoryManager.equipped_durability = 1
	var z4: Zombie = ZOMBIE_SCENE.instantiate()
	w.add_child(z4)
	z4.global_position = Vector3(2.0, 0, 0.3)
	z4.rotation.y = PI
	await _ticks(5)
	Input.action_press("attack")
	await _ticks(2)
	Input.action_release("attack")
	await _ticks(40)
	print("T7_WEAPON_BREAKS: ", InventoryManager.equipped_weapon_id == "" and InventoryManager.count_of("weapon_bat") == 0)
	print("T7_FISTS_NOW: ", InventoryManager.get_equipped_item() == null)

	var spawner: Node = SPAWNER.new()
	spawner.interval = 0.3
	w.add_child(spawner)
	var before := get_tree().get_nodes_in_group("zombies").size()
	await _ticks(90)
	var after := get_tree().get_nodes_in_group("zombies").size()
	print("T8_SPAWNER_WORKS: ", after > before, " (%d -> %d)" % [before, after])

	print("M35_SMOKE_DONE")
	get_tree().quit(0)
