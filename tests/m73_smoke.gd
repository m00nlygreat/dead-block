extends Node

## m73: 근접 무기 궤적/사거리 이펙트(SwingTrail).
## - T1: 재질이 탑다운에서 보이도록 설정(양면 컬링·깊이 테스트 off·unshaded·알파).
## - T2: play()가 재생 상태·파라미터(reach/arc/color)를 저장하고 표시된다.
## - T3: 필+바깥 호+측면선 3개 표면으로 구성된다.
## - T4: 지오메트리 가로폭이 사거리·각도와 일치한다(사정거리 표시).
## - T5: 각도가 넓어지면 폭이 넓어진다(궤적 범위 반영).
## - T6: 사거리가 길어지면 바깥 호가 멀어진다(사정거리 반영).
## - T7: SWEEP+FADE 후 자동 소멸한다.
## - T8: 실제 근접 공격(배트)이 이펙트를 띄우고 스탯과 일치한다.
## - T9: 부엌칼 공격은 칼 전용 색상·스탯으로 표시된다.
## - T10: 트레일이 플레이어 자식이라 facing을 따라간다.

const PLAYER_SCENE := preload("res://scenes/player/player.tscn")


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
	GameState.reset_run_state()
	UpgradeManager.reset_run()
	InventoryManager.reset_run()
	var player: CharacterBody3D = PLAYER_SCENE.instantiate()
	w.add_child(player)
	player.global_position = Vector3.ZERO
	await _ticks(5)

	var trail: SwingTrail = player.get_node("SwingTrail")

	# T1: 재질 설정 — 탑다운 카메라(뒷면 시점)에서도 보이고 바닥에 묻히지 않아야 한다.
	var mat: StandardMaterial3D = trail.material_override as StandardMaterial3D
	var t1: bool = mat != null \
		and mat.shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED \
		and mat.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA \
		and mat.vertex_color_use_as_albedo \
		and mat.cull_mode == BaseMaterial3D.CULL_DISABLED \
		and mat.no_depth_test
	print("T1_TRAIL_MATERIAL: ", t1)

	# T2: play 상태.
	var orange := Color(1.0, 0.55, 0.1)
	trail.play(2.6, 100.0, orange)
	var t2: bool = trail.is_playing() and trail.visible \
		and is_equal_approx(trail._reach, 2.6) \
		and is_equal_approx(trail._arc, 100.0) \
		and trail._color == orange
	print("T2_PLAY_STATE: ", t2)

	# T3: 3개 표면(필·바깥 호·측면선).
	await _ticks(2)
	var t3: bool = trail._mesh.get_surface_count() == 3
	print("T3_THREE_SURFACES: ", t3, " (n=", trail._mesh.get_surface_count(), ")")

	# T4: 전체 스윕 지오메트리의 폭이 reach/arc와 일치.
	trail._rebuild(SwingTrail.SWEEP_TIME)
	var ab: AABB = trail._mesh.get_aabb()
	var half := deg_to_rad(50.0)
	var exp_x := 2.0 * 2.6 * sin(half)
	var t4: bool = absf(ab.size.x - exp_x) < 0.4 \
		and absf(ab.position.z + 2.6) < 0.2
	print("T4_RANGE_GEOMETRY: ", t4,
		" (size.x=%.2f exp=%.2f min.z=%.2f)" % [ab.size.x, exp_x, ab.position.z])

	# T5: 각도↑ → 폭↑ (동일 사거리 2.0).
	trail.play(2.0, 60.0, Color.WHITE)
	trail._rebuild(SwingTrail.SWEEP_TIME)
	var x60: float = trail._mesh.get_aabb().size.x
	trail.play(2.0, 140.0, Color.WHITE)
	trail._rebuild(SwingTrail.SWEEP_TIME)
	var x140: float = trail._mesh.get_aabb().size.x
	var t5: bool = x140 > x60 + 1.0
	print("T5_ARC_WIDENS: ", t5, " (60deg=%.2f 140deg=%.2f)" % [x60, x140])

	# T6: 사거리↑ → 바깥 호가 멀어짐 (동일 각도 90).
	trail.play(1.8, 90.0, Color.WHITE)
	trail._rebuild(SwingTrail.SWEEP_TIME)
	var z18: float = -trail._mesh.get_aabb().position.z
	trail.play(2.6, 90.0, Color.WHITE)
	trail._rebuild(SwingTrail.SWEEP_TIME)
	var z26: float = -trail._mesh.get_aabb().position.z
	var t6: bool = z26 > z18 + 0.5
	print("T6_REACH_EXTENDS: ", t6, " (1.8m=%.2f 2.6m=%.2f)" % [z18, z26])

	# T7: 종료 시점에 자동 소멸.
	trail.play(2.0, 90.0, Color.WHITE)
	await _ticks(2)
	var grew: bool = trail._t > 0.0
	trail._t = SwingTrail.SWEEP_TIME + SwingTrail.FADE_TIME - 0.01
	await _ticks(5)
	var t7: bool = grew and (not trail.is_playing()) and (not trail.visible)
	print("T7_AUTO_HIDE: ", t7)

	# T8: 배트 실공격이 스탯 일치 이펙트를 띄운다.
	InventoryManager.reset_run()
	InventoryManager.add_item("weapon_bat", 1)
	await _ticks(3)
	player._melee_cd = 0.0
	player._melee_attack()
	await _ticks(2)
	var ws: Dictionary = player._get_weapon_stats()
	var t8: bool = trail.is_playing() and trail.visible \
		and is_equal_approx(trail._reach, float(ws["reach"])) \
		and is_equal_approx(trail._arc, float(ws["arc"])) \
		and trail._color == player.BAT_TRAIL_COLOR
	print("T8_BAT_MELEE_TRAIL: ", t8,
		" (reach=%.2f arc=%.1f)" % [trail._reach, trail._arc])

	# T9: 부엌칼 실공격은 칼 색상·단거리로 표시된다.
	InventoryManager.reset_run()
	InventoryManager.add_item("weapon_kitchen_knife", 1)
	await _ticks(3)
	player._melee_cd = 0.0
	player._melee_attack()
	await _ticks(2)
	var ws2: Dictionary = player._get_weapon_stats()
	var t9: bool = trail.is_playing() \
		and is_equal_approx(trail._reach, float(ws2["reach"])) \
		and trail._color == player.KNIFE_TRAIL_COLOR \
		and trail._color != player.BAT_TRAIL_COLOR
	print("T9_KNIFE_MELEE_TRAIL: ", t9,
		" (reach=%.2f)" % [trail._reach])

	# T10: 플레이어 자식이라 회전을 따라간다.
	var t10: bool = trail.get_parent() == player
	player.rotation.y = 1.0
	await _ticks(2)
	t10 = t10 and is_equal_approx(trail.global_rotation.y, 1.0)
	print("T10_FOLLOWS_FACING: ", t10)

	print("M73_SMOKE_DONE")
	get_tree().quit(0)
