extends Node

## m75: 업그레이드 체감 개편 검증.
## 3단계·큰폭(피해 고정 +10·쿨 −12%·이속 +10%·HP +30·자석 +50%·스테 +35%),
## 타수 돌파(배트 3단계 = 60 = P0 좀비 1타), 근접 공용(칼·주먹 적용).

const PLAYER_SCENE := preload("res://scenes/player/player.tscn")
const HUD_SCENE := preload("res://scenes/ui/hud.tscn")


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
	bs.size = Vector3(600, 1, 600)
	cs.shape = bs
	cs.position.y = -0.5
	floor_body.add_child(cs)
	w.add_child(floor_body)

	var player := PLAYER_SCENE.instantiate()
	w.add_child(player)
	player.global_position = Vector3.ZERO
	var hud := HUD_SCENE.instantiate()
	add_child(hud)
	await _ticks(5)
	GameState.reset_run_state()
	UpgradeManager.reset_run()
	InventoryManager.reset_run()
	await _ticks(2)

	var six := ["up_damage", "up_cooldown", "up_move_speed",
		"up_max_hp", "up_pickup_radius", "up_stamina_regen"]
	var all_3 := true
	for id in six:
		var u: UpgradeData = null
		for cand in UpgradeManager._pool:
			if cand.id == id:
				u = cand
		if u == null or u.max_level != 3 or u.values.size() != 3:
			all_3 = false
	print("T1_SIX_UPGRADES_3_LEVELS: ", all_3)

	GameState.add_coins(9999)
	InventoryManager.add_item("weapon_bat", 1)
	await _ticks(3)
	for i in 3:
		UpgradeManager.purchase("up_damage")
	var ws: Dictionary = player._get_weapon_stats()
	print("T2_BAT_BREAKPOINT_L3: ",
		is_equal_approx(float(ws["damage"]), 60.0),
		" (dmg=%s, P0 좀비 HP60 1타)" % str(float(ws["damage"])))

	InventoryManager.add_item("weapon_kitchen_knife", 1)
	InventoryManager.set_selected(1)
	await _ticks(3)
	ws = player._get_weapon_stats()
	print("T3_KNIFE_DAMAGE_FLAT: ",
		is_equal_approx(float(ws["damage"]), 90.0),
		" (dmg=%s, P3 HP80 1타)" % str(float(ws["damage"])))

	for i in 3:
		UpgradeManager.purchase("up_cooldown")
		UpgradeManager.purchase("up_move_speed")
	print("T4_COOLDOWN_AND_SPEED: ",
		is_equal_approx(player.cooldown_mult, 0.64)
		and is_equal_approx(player.move_speed_mult, 1.3),
		" (cd=%s spd=%s)" % [str(player.cooldown_mult), str(player.move_speed_mult)])

	var hp_before: float = player.max_hp
	for i in 3:
		UpgradeManager.purchase("up_max_hp")
	print("T5_MAX_HP_PLUS90: ",
		is_equal_approx(player.max_hp, hp_before + 90.0),
		" (max_hp=%s)" % str(player.max_hp))

	for i in 3:
		UpgradeManager.purchase("up_pickup_radius")
		UpgradeManager.purchase("up_stamina_regen")
	print("T6_MAGNET_AND_STAMINA: ",
		is_equal_approx(player.pickup_radius_mult, 2.5)
		and is_equal_approx(player.stamina_regen_mult, 2.05),
		" (mag=%s stam=%s)" % [str(player.pickup_radius_mult), str(player.stamina_regen_mult)])

	player.apply_upgrade("bat_reach", 0.4)
	player.apply_upgrade("bat_targets", 1.0)
	ws = player._get_weapon_stats()
	var knife_universal: bool = is_equal_approx(float(ws["reach"]), 2.2) \
		and int(ws["targets"]) == 2
	player.apply_upgrade("bat_reach", -0.4)
	player.apply_upgrade("bat_targets", -1.0)
	InventoryManager.set_selected(0)
	await _ticks(2)
	print("T7_UNIVERSAL_ON_KNIFE: ", knife_universal,
		" (reach/targets on knife)")

	var toasts_before: int = hud._floating_toasts.size()
	hud.show_toast("프로브 토스트")
	print("T8_TOAST_API: ", hud._floating_toasts.size() == toasts_before + 1)

	UpgradeManager.reset_run()
	InventoryManager.reset_run()
	print("M75_SMOKE_DONE")
	get_tree().quit(0)
