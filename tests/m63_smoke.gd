extends Node

## m63: 안전가옥 시간 기반 1초 지연 개방 검증.
## 타이머 만료 직후에는 열리지 않고(날아오는 코인 회수 시간 확보),
## 약 1초 뒤에 개방된다. 지연 중 리셋되면 개방이 취소된다.

const PLAYER_SCENE := preload("res://scenes/player/player.tscn")
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

	GameState.add_coins(100)
	for i in 10:
		UpgradeManager.add_kill()
	await _ticks(30)
	print("T1_KILLS_DO_NOT_OPEN: ",
		UpgradeManager.kills == 10 and not ui.visible and not get_tree().paused,
		" (kills=%d visible=%s paused=%s)" % [
			UpgradeManager.kills, str(ui.visible), str(get_tree().paused)])

	UpgradeManager.debug_force_due()
	await _ticks(2)
	print("T1B_NO_INSTANT_OPEN: ",
		not ui.visible and not get_tree().paused,
		" (visible=%s paused=%s)" % [str(ui.visible), str(get_tree().paused)])

	var coin: MagnetPickup = COIN_SCENE.instantiate()
	w.add_child(coin)
	coin.global_position = player.global_position + Vector3(0.0, 0.3, 0.0)
	var coin_gone := await _wait_until(
		func() -> bool: return not is_instance_valid(coin), 60)
	print("T2_LAST_COIN_COLLECTED_BEFORE_OPEN: ",
		coin_gone and GameState.coins == 101 and not ui.visible,
		" (gone=%s coins=%d visible=%s)" % [
			str(coin_gone), GameState.coins, str(ui.visible)])

	var opened: bool = await _wait_until(
		func() -> bool: return ui.visible and get_tree().paused, 200)
	print("T3_OPENS_AFTER_DELAY: ", opened,
		" (visible=%s paused=%s)" % [str(ui.visible), str(get_tree().paused)])
	ui._close()
	await _ticks(2)

	UpgradeManager.reset_run()
	await _ticks(2)
	GameState.spend_coins(GameState.coins)
	UpgradeManager.debug_force_due()
	UpgradeManager.reset_run()
	var opened_anyway: bool = await _wait_until(
		func() -> bool: return ui.visible or get_tree().paused, 140)
	print("T4_RESET_CANCELS_PENDING: ",
		not opened_anyway and not ui.visible and not get_tree().paused,
		" (visible=%s paused=%s)" % [str(ui.visible), str(get_tree().paused)])

	ui._close()
	await _ticks(2)
	UpgradeManager.reset_run()
	print("M63_SMOKE_DONE")
	get_tree().quit(0)
