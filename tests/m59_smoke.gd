extends Node

## m59: 안전가옥 시간 기반 개방 검증 (120초 타이머).
## 킬을 쌓아도 열리지 않고, 타이머 만료(safehouse_due) 약 1초 후에 열린다.
## 코인 구매·잔고 비활성·닫기 재개·재개방·킬 카운트·코인 자석·리셋을 확인한다.

const PLAYER_SCENE := preload("res://scenes/player/player.tscn")
const ZOMBIE_SCENE := preload("res://scenes/zombie/zombie.tscn")
const COIN_SCENE := preload("res://scenes/items/coin_pickup.tscn")
const UPGRADE_UI_SCENE := preload("res://scenes/ui/upgrade_ui.tscn")


func _ready() -> void:
	_run()


func _ticks(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _wait_until(cond: Callable, timeout_ticks: int) -> bool:
	for i in timeout_ticks:
		if cond.call():
			return true
		await get_tree().physics_frame
	return cond.call()


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
	await _ticks(2)

	print("T1_KILLS_ACCUMULATE_NO_SCREEN: ",
		UpgradeManager.kills == 0 and not ui.visible and not get_tree().paused)

	GameState.add_coins(100)
	for i in 9:
		UpgradeManager.add_kill()
	print("T2_NINE_KILLS_STILL_CLOSED: ",
		UpgradeManager.kills == 9 and not ui.visible and not get_tree().paused)

	UpgradeManager.add_kill()
	await _ticks(30)
	print("T3A_TENTH_KILL_DOES_NOT_OPEN: ",
		UpgradeManager.kills == 10 and not ui.visible and not get_tree().paused,
		" (kills=%d visible=%s paused=%s)" % [
			UpgradeManager.kills, str(ui.visible), str(get_tree().paused)])

	UpgradeManager.debug_force_due()
	var not_instant: bool = not ui.visible and not get_tree().paused
	var opened: bool = await _wait_until(
		func() -> bool: return ui.visible and get_tree().paused, 200)
	print("T3B_TIMER_DUE_OPENS_SCREEN: ",
		not_instant and opened and ui._choices.size() == 3,
		" (instant=%s visible=%s paused=%s cards=%d)" % [
			str(not not_instant), str(ui.visible), str(get_tree().paused),
			ui._choices.size()])

	var picked: UpgradeData = ui._choices[0]
	var price: int = UpgradeManager.cost_of(picked)
	ui._on_card_pressed(0)
	print("T4_COIN_PURCHASE_APPLIES: ",
		UpgradeManager.upgrade_level(picked.id) == 1 and GameState.coins == 100 - price,
		" (picked=%s price=%d coins=%d)" % [picked.id, price, GameState.coins])

	GameState.spend_coins(GameState.coins)
	ui._refresh()
	var any_enabled := false
	for b in ui._card_buttons:
		if b.visible and not b.disabled:
			any_enabled = true
	print("T5_POOR_CARDS_DISABLED: ",
		GameState.coins == 0 and not any_enabled)

	ui._close()
	print("T6_CLOSE_RESUMES_GAME: ",
		not get_tree().paused and not ui.visible,
		" (paused=%s visible=%s)" % [str(get_tree().paused), str(ui.visible)])

	UpgradeManager.debug_force_due()
	var reopened: bool = await _wait_until(
		func() -> bool: return ui.visible and get_tree().paused, 200)
	print("T7_REOPENS_ON_NEXT_DUE: ",
		reopened and UpgradeManager.safehouse_visits >= 2,
		" (visits=%d visible=%s paused=%s)" % [
			UpgradeManager.safehouse_visits, str(ui.visible), str(get_tree().paused)])
	ui._close()
	await _ticks(2)

	GameState.add_coins(30)
	var kills_before: int = UpgradeManager.kills
	var z: Zombie = ZOMBIE_SCENE.instantiate()
	w.add_child(z)
	z.global_position = player.global_position + Vector3(1.5, 0.5, 0)
	await _ticks(3)
	z.take_damage(999.0, player.global_position)
	var kill_counted: bool = await _wait_until(
		func() -> bool: return UpgradeManager.kills == kills_before + 1, 120)
	print("T8_ZOMBIE_KILL_COUNTS: ", kill_counted,
		" (kills=%d)" % UpgradeManager.kills)

	var coins_before: int = GameState.coins
	var coin: MagnetPickup = COIN_SCENE.instantiate()
	w.add_child(coin)
	coin.global_position = player.global_position + Vector3(0.6, 0.3, 0)
	var coin_gone := await _wait_until(func() -> bool: return not is_instance_valid(coin), 300)
	print("T9_COIN_MAGNET_STILL_WORKS: ",
		coin_gone and GameState.coins == coins_before + 1,
		" (gone=%s coins=%d)" % [str(coin_gone), GameState.coins])

	UpgradeManager.reset_run()
	print("T10_RESET_RUN: ", UpgradeManager.kills == 0
		and UpgradeManager.upgrade_levels.is_empty()
		and UpgradeManager.safehouse_visits == 0)

	print("M59_SMOKE_DONE")
	get_tree().quit(0)
