extends Node

const UPGRADE_UI_SCENE := preload("res://scenes/ui/upgrade_ui.tscn")


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
	bs.size = Vector3(100, 1, 100)
	cs.shape = bs
	cs.position.y = -0.5
	floor_body.add_child(cs)
	w.add_child(floor_body)
	await _ticks(3)
	GameState.reset_run_state()
	UpgradeManager.reset_run()
	InventoryManager.reset_run()
	await _ticks(2)

	# T1: 무기 없음 -> 수리 불가
	var rep1: bool = InventoryManager.repair_equipped_to_full()
	print("T1_NO_WEAPON_NO_REPAIR: ", rep1 == false)

	# T2: 근접 무기 손상 -> 수리 성공
	InventoryManager.add_item("weapon_bat", 1)
	await _ticks(2)
	InventoryManager.weapon_used()
	InventoryManager.weapon_used()
	await _ticks(1)
	var cur: int = InventoryManager.equipped_durability
	var item = ItemDB.get_item("weapon_bat")
	var damaged: bool = cur == (item.durability - 2)
	var rep2: bool = InventoryManager.repair_equipped_to_full()
	var full: bool = InventoryManager.equipped_durability == item.durability
	print("T2_MELEE_REPAIR: ", damaged and rep2 and full, " (cur=", cur, " now=", InventoryManager.equipped_durability, ")")

	# T3: 가득 참 -> 수리 불가(false)
	var rep3: bool = InventoryManager.repair_equipped_to_full()
	print("T3_FULL_NO_REPAIR: ", rep3 == false)

	# T4: 원거리 무기 제외
	InventoryManager.reset_run()
	await _ticks(1)
	InventoryManager.add_item("weapon_9mm", 1)
	await _ticks(2)
	InventoryManager.equipped_durability = 5
	var rep4: bool = InventoryManager.repair_equipped_to_full()
	print("T4_RANGED_EXCLUDED: ", rep4 == false, " (mag=", InventoryManager.equipped_durability, ")")

	# T5: UI 버튼 존재 + 원거리 장착 시 비활성 문구
	var ui := UPGRADE_UI_SCENE.instantiate()
	add_child(ui)
	await _ticks(2)
	var has_btn: bool = ui.has_node("Root/Columns/CenterCol/BuyRepair")
	var btn: Button = ui.get_node("Root/Columns/CenterCol/BuyRepair") as Button
	ui.visible = true
	ui._refresh()
	await _ticks(1)
	var ranged_disabled: bool = btn.disabled and btn.text.contains("원거리")
	print("T5_UI_RANGED_DISABLED: ", has_btn and ranged_disabled, " (text=", btn.text.replace("\n", " / "), ")")

	# T6: 근접 손상 시 UI 활성화(코인 10개) + 구매 후 가득 참
	InventoryManager.reset_run()
	GameState.reset_run_state()
	GameState.add_coins(10)
	InventoryManager.add_item("weapon_bat", 1)
	await _ticks(2)
	InventoryManager.weapon_used()
	await _ticks(1)
	ui._refresh()
	await _ticks(1)
	var enabled_before: bool = not btn.disabled
	ui._on_buy_repair_pressed()
	await _ticks(1)
	var bat2 = ItemDB.get_item("weapon_bat")
	var bought_ok: bool = InventoryManager.equipped_durability == bat2.durability and GameState.coins == 0
	print("T6_UI_BUY_REPAIR_10COINS: ", enabled_before and bought_ok, " (coins=", GameState.coins, " dur=", InventoryManager.equipped_durability, ")")

	# T7: 코인 부족 시 버튼 비활성
	InventoryManager.weapon_used()
	GameState.reset_run_state()
	GameState.add_coins(9)
	await _ticks(1)
	ui._refresh()
	await _ticks(1)
	print("T7_COIN_SHORT_DISABLED: ", btn.disabled, " (coins=", GameState.coins, ")")

	InventoryManager.reset_run()
	GameState.reset_run_state()
	UpgradeManager.reset_run()
	ui.queue_free()
	print("M76_SMOKE_DONE")
	get_tree().quit(0)
