extends Node

const PLAYER_SCENE := preload("res://scenes/player/player.tscn")
const ZOMBIE_SCENE := preload("res://scenes/zombie/zombie.tscn")
const KNIFE_TRES := preload("res://resources/items/weapon_kitchen_knife.tres")
const LOOT_TRES := preload("res://resources/loot_tables/trash_common.tres")
const KNIFE_MODEL := preload("res://scenes/items/knife_model.tscn")


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


func _check_tres_stats() -> bool:
	var ok := true
	ok = ok and KNIFE_TRES.id == "weapon_kitchen_knife"
	ok = ok and KNIFE_TRES.item_type == ItemData.Type.WEAPON
	ok = ok and is_equal_approx(KNIFE_TRES.damage, 60.0)
	ok = ok and is_equal_approx(KNIFE_TRES.reach, 1.8)
	ok = ok and is_equal_approx(KNIFE_TRES.arc_deg, 90.0)
	ok = ok and KNIFE_TRES.max_targets == 1
	ok = ok and KNIFE_TRES.durability == 12
	ok = ok and is_equal_approx(KNIFE_TRES.attack_cooldown, 0.6)
	ok = ok and KNIFE_TRES.knockback == 0.0
	ok = ok and is_equal_approx(KNIFE_TRES.stagger_time, 0.25)
	if not ok:
		print("  MISMATCH: dmg=", KNIFE_TRES.damage, " reach=", KNIFE_TRES.reach,
			" dur=", KNIFE_TRES.durability, " kb=", KNIFE_TRES.knockback,
			" st=", KNIFE_TRES.stagger_time)
	return ok


func _loot_has_knife() -> bool:
	for e in LOOT_TRES.entries:
		if e.item_id == "weapon_kitchen_knife":
			return true
	return false


func _model_aligned() -> bool:
	var holder := Node3D.new()
	add_child(holder)
	var inst := KNIFE_MODEL.instantiate() as Node3D
	holder.add_child(inst)
	var min_y := INF
	var max_y := -INF
	var max_abs_x := 0.0
	for mi in inst.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		if m.mesh == null:
			continue
		var ab: AABB = m.global_transform * m.mesh.get_aabb()
		min_y = minf(min_y, ab.position.y)
		max_y = maxf(max_y, ab.end.y)
		var mesh_max_x := maxf(absf(ab.position.x), absf(ab.end.x))
		max_abs_x = maxf(max_abs_x, mesh_max_x)
	holder.queue_free()
	var ok: bool = min_y > -0.06 and min_y < 0.05 \
		and max_y > 0.3 \
		and max_abs_x < 0.15
	if not ok:
		print("  MODEL min_y=", min_y, " max_y=", max_y, " max_abs_x=", max_abs_x)
	return ok


func _run() -> void:
	var w := Node3D.new()
	add_child(w)
	_floor(w)
	var player := PLAYER_SCENE.instantiate()
	w.add_child(player)
	player.global_position = Vector3.ZERO
	await _ticks(5)
	GameState.reset_run_state()

	print("T1_TRES_STATS: ", _check_tres_stats())
	print("T2_ITEMDB_REGISTERED: ",
		ItemDB.get_item("weapon_kitchen_knife") != null
		and ItemDB.get_item("weapon_kitchen_knife").display_name == "부억칼")
	print("T3_LOOT_TABLE_HAS_KNIFE: ", _loot_has_knife())
	print("T4_CLIP_REGISTERED: ", player._anim.has_animation(KnifeStab.CLIP_NAME))

	print("T5_MODEL_GRIP_ALIGNED: ", _model_aligned())

	print("T6_EQUIP_ATTACHES_VISUAL: ",
		InventoryManager.add_item("weapon_kitchen_knife", 1) == 1
		and InventoryManager.equipped_weapon_id == "weapon_kitchen_knife"
		and InventoryManager.equipped_durability == 12)
	await _ticks(3)
	print("T7_HAND_VISUAL_HELD: ",
		player._weapon_visual != null and player._visual_id == "weapon_kitchen_knife")

	var ws: Dictionary = player._get_weapon_stats()
	print("T8_WEAPON_STATS_APPLIED: ",
		is_equal_approx(float(ws["damage"]), 60.0)
		and is_equal_approx(float(ws["reach"]), 1.8)
		and float(ws["knockback"]) == 0.0
		and is_equal_approx(float(ws["stagger"]), 0.25)
		and is_equal_approx(float(ws["hit_delay"]), 0.14))

	player.apply_upgrade("bat_reach", 0.4)
	player.apply_upgrade("bat_targets", 1.0)
	ws = player._get_weapon_stats()
	var bat_gate_ok: bool = is_equal_approx(float(ws["reach"]), 1.8) \
		and int(ws["targets"]) == 1
	player.apply_upgrade("bat_reach", -0.4)
	player.apply_upgrade("bat_targets", -1.0)
	print("T13_BAT_UPGRADE_NOT_ON_KNIFE: ", bat_gate_ok)

	var z: Zombie = ZOMBIE_SCENE.instantiate()
	w.add_child(z)
	z.global_position = Vector3(0.0, 0.5, -1.2)
	await _ticks(3)

	Input.action_press("attack")
	await _ticks(2)
	Input.action_release("attack")
	await _ticks(11)

	print("T9_ONE_SHOT_KILL: ", z.hp <= 0.0 and z.state == z.State.DEAD, " (hp=", z.hp, ")")
	print("T10_NO_KNOCKBACK_STAGGER_YES: ",
		z._knockback == Vector3.ZERO and z._stagger_t > 0.0,
		" (kb=", z._knockback, " st=", z._stagger_t, ")")
	print("T11_DURABILITY_CONSUMED: ", InventoryManager.equipped_durability == 11)
	print("T12_PICKUP_MODEL_MAPPED: ", PickupModels.has_model("weapon_kitchen_knife"))

	print("M60_SMOKE_DONE")
	get_tree().quit(0)
