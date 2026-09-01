extends Node

## m65: 안전가옥 개방 파동(원형 밀어내기) 검증.
## 안전가옥이 열릴 때(try_open), 플레이어 반경 내 좀비들은 바깥으로
## 넉백을 받고, 반경 밖·죽은 좀비는 넉백을 받지 않는다.

const PLAYER_SCENE := preload("res://scenes/player/player.tscn")
const ZOMBIE_SCENE := preload("res://scenes/zombie/zombie.tscn")
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
	await _ticks(2)

	## 반경(WAVE_RADIUS=8) 내 좀비 2마리 (각기 다른 방향)
	var zb1 := ZOMBIE_SCENE.instantiate()
	w.add_child(zb1)
	zb1.global_position = Vector3(3.0, 0.0, 0.0)
	var zb2 := ZOMBIE_SCENE.instantiate()
	w.add_child(zb2)
	zb2.global_position = Vector3(0.0, 0.0, -5.0)
	## 반경 밖 좀비 (12m — 시야 반경 10m 밖 + 파동 반경 8m 밖)
	var zb_far := ZOMBIE_SCENE.instantiate()
	w.add_child(zb_far)
	zb_far.global_position = Vector3(12.0, 0.0, 0.0)
	## 죽은 좀비 — 반경 내지만 넉백 없어야 함
	var zb_dead := ZOMBIE_SCENE.instantiate()
	w.add_child(zb_dead)
	zb_dead.global_position = Vector3(-4.0, 0.0, 0.0)
	zb_dead.take_damage(9999.0, zb_dead.global_position)
	await _ticks(2)

	## try_open()은 파동을 즉시 발사하고 pause 상태로 만든다.
	## 좀비가 공격·이동할 시간을 주지 않아 위치/반경 판정이 결정적이다.
	GameState.add_coins(100)
	var opened: bool = ui.try_open()
	print("T1_OPENED: ", opened, " (visible=%s paused=%s)" % [
		str(ui.visible), str(get_tree().paused)])

	var kb1: Vector3 = zb1.get("_knockback") as Vector3
	var kb2: Vector3 = zb2.get("_knockback") as Vector3
	var kb_far: Vector3 = zb_far.get("_knockback") as Vector3
	var kb_dead: Vector3 = zb_dead.get("_knockback") as Vector3
	print("T2_INNER_PUSHED: ",
		kb1.length() > 0.0 and kb2.length() > 0.0,
		" (kb1=%.2f kb2=%.2f)" % [kb1.length(), kb2.length()])
	print("T3_OUTCENTER_DIR: ",
		kb1.dot(Vector3(1, 0, 0)) > 0.0 and kb2.dot(Vector3(0, 0, -1)) > 0.0,
		" (kb1=%.2f kb2=%.2f)" % [
			kb1.dot(Vector3(1, 0, 0)), kb2.dot(Vector3(0, 0, -1))])
	print("T4_FAR_AND_DEAD_STILL: ",
		kb_far.length() == 0.0 and kb_dead.length() == 0.0,
		" (kbfar=%.2f kbdead=%.2f)" % [kb_far.length(), kb_dead.length()])

	ui._close()
	await _ticks(2)
	UpgradeManager.reset_run()
	print("M65_SMOKE_DONE")
	get_tree().quit(0)
