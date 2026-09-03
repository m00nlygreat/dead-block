extends Node

## m64: 안전가옥 3분할 — 구매(중앙)·제작(우측) 검증.
## 붕대/생수 각 5코인 구매, 재료 제작(날붙이=고철2+천1 / 붕대=천2),
## 재료 부족 차단, 인벤 불가 시 환불을 확인한다.

const PLAYER_SCENE := preload("res://scenes/player/player.tscn")
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
	bs.size = Vector3(600, 1, 600)
	cs.shape = bs
	cs.position.y = -0.5
	floor_body.add_child(cs)
	w.add_child(floor_body)

	var player := PLAYER_SCENE.instantiate()
	w.add_child(player)
	player.global_position = Vector3.ZERO

	var ui := UPGRADE_UI_SCENE.instantiate()
	add_child(ui)
	await _ticks(5)
	GameState.reset_run_state()
	UpgradeManager.reset_run()
	InventoryManager.reset_run()
	await _ticks(2)

	seed(7)
	ui.try_open()
	await _ticks(2)
	print("T1_PANELS_PRESENT: ", ui.visible
		and ui._buy_buttons["bandage"] != null
		and ui._buy_buttons["water"] != null
		and ui._craft_buttons["weapon_blade"] != null
		and ui._craft_buttons["bandage"] != null,
		" (visible=%s)" % str(ui.visible))

	print("T2_NO_FUNDS_ALL_DISABLED: ",
		GameState.coins == 0
		and ui._buy_buttons["bandage"].disabled
		and ui._buy_buttons["water"].disabled
		and ui._craft_buttons["weapon_blade"].disabled
		and ui._craft_buttons["bandage"].disabled,
		" (coins=%d)" % GameState.coins)

	GameState.add_coins(10)
	ui._refresh()
	ui._on_buy_pressed("bandage")
	print("T3_BUY_BANDAGE_5G: ",
		GameState.coins == 5 and InventoryManager.count_of("bandage") == 1,
		" (coins=%d bandage=%d)" % [
			GameState.coins, InventoryManager.count_of("bandage")])

	ui._on_buy_pressed("water")
	print("T4_BUY_WATER_5G: ",
		GameState.coins == 0 and InventoryManager.count_of("water") == 1,
		" (coins=%d water=%d)" % [
			GameState.coins, InventoryManager.count_of("water")])

	InventoryManager.add_item("scrap_metal", 2)
	InventoryManager.add_item("cloth", 3)
	ui._refresh()
	var blade_ok_pre: bool = not ui._craft_buttons["weapon_blade"].disabled
	ui._on_craft_pressed("weapon_blade")
	var _s64 = InventoryManager._find_first_slot_of("weapon_blade")
	var _dur64: int = InventoryManager.slots[_s64]["durability"] if _s64 != -1 else -1
	print("T5_CRAFT_BLADE_2SCRAP_1CLOTH: ",
		blade_ok_pre
		and InventoryManager.count_of("weapon_blade") == 1
		and InventoryManager.count_of("scrap_metal") == 0
		and InventoryManager.count_of("cloth") == 2
		and _dur64 == 7,
		" (blade=%d scrap=%d cloth=%d dur=%d)" % [
			InventoryManager.count_of("weapon_blade"),
			InventoryManager.count_of("scrap_metal"),
			InventoryManager.count_of("cloth"),
			_dur64])

	var bandage_before: int = InventoryManager.count_of("bandage")
	ui._refresh()
	var craft_band_ok_pre: bool = not ui._craft_buttons["bandage"].disabled
	ui._on_craft_pressed("bandage")
	print("T6_CRAFT_BANDAGE_2CLOTH: ",
		craft_band_ok_pre
		and InventoryManager.count_of("bandage") == bandage_before + 1
		and InventoryManager.count_of("cloth") == 0,
		" (bandage=%d cloth=%d)" % [
			InventoryManager.count_of("bandage"),
			InventoryManager.count_of("cloth")])

	ui._refresh()
	var blocked: bool = ui._craft_buttons["bandage"].disabled
	ui._on_craft_pressed("bandage")
	print("T7_CRAFT_BLOCKED_WITHOUT_MATS: ",
		blocked and InventoryManager.count_of("bandage") == bandage_before + 1,
		" (disabled=%s bandage=%d)" % [
			str(blocked), InventoryManager.count_of("bandage")])

	GameState.add_coins(5)
	InventoryManager.add_item("scrap_metal", 60)
	InventoryManager.add_item("bandage", 60)
	ui._refresh()
	var water_before: int = InventoryManager.count_of("water")
	var coins_before: int = GameState.coins
	ui._on_buy_pressed("water")
	print("T8_FULL_INV_BUY_REFUNDS: ",
		GameState.coins == coins_before
		and InventoryManager.count_of("water") == water_before
		and InventoryManager.total_weight() > InventoryManager.MAX_WEIGHT - 0.11,
		" (coins=%d water=%d weight=%.2f)" % [
			GameState.coins, InventoryManager.count_of("water"),
			InventoryManager.total_weight()])

	ui._close()
	UpgradeManager.reset_run()
	InventoryManager.reset_run()
	print("M64_SMOKE_DONE")
	get_tree().quit(0)
