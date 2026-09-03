extends Node

## m68: 안전가옥 권총 탄창 가득 구매 + 빈 권총 주먹 평타 대체.
## (1) 권총(weapon_9mm) 보유 시 코인 7로 장탄을 14발로 보충, 미보유 시 구매 불가.
## (2) 장탄 0인 권총을 쥔 채 공격하면 발사 대신 주먹(맨손 근접)이 나가고 탄약을 소모하지 않는다.

const PLAYER_SCENE := preload("res://scenes/player/player.tscn")
const ZOMBIE_SCENE := preload("res://scenes/zombie/zombie.tscn")
const UPGRADE_UI_SCENE := preload("res://scenes/ui/upgrade_ui.tscn")


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
	UpgradeManager.reset_run()
	InventoryManager.reset_run()
	await _ticks(2)

	var ui := UPGRADE_UI_SCENE.instantiate()
	add_child(ui)
	seed(7)
	ui.try_open()
	await _ticks(2)
	var ammo_btn: Button = ui._buy_ammo_button
	print("T1_AMMO_BUTTON_PRESENT: ",
		ammo_btn != null and ui.visible, " (visible=%s)" % str(ui.visible))

	print("T2_AMMO_DISABLED_WITHOUT_GUN: ",
		InventoryManager.count_of("weapon_9mm") == 0 and ammo_btn.disabled,
		" (gun=%d disabled=%s)" % [
			InventoryManager.count_of("weapon_9mm"), str(ammo_btn.disabled)])

	InventoryManager.add_item("weapon_9mm", 1)
	await _ticks(2)
	ui._refresh()
	print("T3_AMMO_DISABLED_NO_COINS: ",
		GameState.coins == 0 and ammo_btn.disabled,
		" (coins=%d disabled=%s)" % [GameState.coins, str(ammo_btn.disabled)])

	GameState.add_coins(6)
	ui._refresh()
	print("T4_BADLY_PRICED_7_NO_BUY: ",
		GameState.coins == 6 and ammo_btn.disabled
		and InventoryManager.equipped_durability == 14,
		" (coins=%d disabled=%s mag=%d)" % [
			GameState.coins, str(ammo_btn.disabled),
			InventoryManager.equipped_durability])

	## 총을 쏴서 장탄을 소모시킨 뒤 7코인 구매로 14발 보충을 확인한다.
	InventoryManager.weapon_used()
	await _ticks(2)
	var drained: int = InventoryManager.equipped_durability
	GameState.add_coins(4)
	ui._refresh()
	var buyable: bool = not ammo_btn.disabled and GameState.coins == 10
	ui._on_buy_ammo_pressed()
	await _ticks(2)
	print("T5_BUY_REFILLS_TO_MAX_7G: ",
		buyable
		and GameState.coins == 3
		and InventoryManager.equipped_durability == 14
		and drained == 13,
		" (before=%d after=%d coins=%d)" % [
			drained, InventoryManager.equipped_durability, GameState.coins])

	ui._close()

	## — 빈 권총 주먹 평타 —
	## 장탄을 0으로 만든다.
	InventoryManager.equipped_durability = 0
	var _s68 = InventoryManager._find_first_slot_of("weapon_9mm")
	if _s68 != -1:
		InventoryManager.slots[_s68]["durability"] = 0
	var z: Zombie = ZOMBIE_SCENE.instantiate()
	w.add_child(z)
	z.set_physics_process(false)
	await _ticks(3)
	z.global_position = Vector3(0.0, player.global_position.y + 1.0, -1.0)
	z.max_hp = 500.0
	z.hp = 500.0
	await _ticks(2)

	var before_hp: float = z.hp
	var before_mag: int = InventoryManager.equipped_durability
	Input.action_press("attack")
	await _ticks(2)
	Input.action_release("attack")
	await _ticks(25)

	print("T6_EMPTY_GUN_FISTS: ",
		z.hp < before_hp
		and InventoryManager.equipped_durability == before_mag
		and InventoryManager.get_equipped_item() != null,
		" (hp=%.1f->%.1f mag=%d)" % [
			before_hp, z.hp, InventoryManager.equipped_durability])

	## 장탄이 있으면 빈총 주먹 대체가 일어나지 않아야 한다(공격만 누르면 근접 미발동).
	InventoryManager.refill_magazine("weapon_9mm")
	await _ticks(2)
	var full_before: float = z.hp
	Input.action_press("attack")
	await _ticks(2)
	Input.action_release("attack")
	await _ticks(20)
	print("T7_AMMO_PRESENT_NO_FIST: ",
		InventoryManager.equipped_durability >= 1 and is_equal_approx(z.hp, full_before),
		" (mag=%d hp=%.1f->%.1f)" % [
			InventoryManager.equipped_durability, full_before, z.hp])

	z.queue_free()
	ui.queue_free()

	UpgradeManager.reset_run()
	InventoryManager.reset_run()
	print("M68_SMOKE_DONE")
	get_tree().quit(0)
