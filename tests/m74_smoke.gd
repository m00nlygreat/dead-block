extends Node

## m74: 난이도 페이즈(안전가옥 방문 수 기반) 검증.
## 좀비 스탯(HP·이속·피해·시야)은 건드리지 않고 스폰량(간격·상한·호드)만
## 스케일한다. P0(0~2회) → P1(3~5회) → P2(6~8회) → P3(9회~).

const PLAYER_SCENE := preload("res://scenes/player/player.tscn")
const SPAWNER := preload("res://scripts/world/zombie_spawner.gd")


func _ready() -> void:
	_run()


func _ticks(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _rare_ratio(spawner: Node, n: int) -> float:
	var big := 0
	for i in n:
		var s: int = spawner._roll_horde_size()
		if s >= 3:
			big += 1
	return float(big) / float(n)


func _run() -> void:
	var w := Node3D.new()
	add_child(w)
	var player := PLAYER_SCENE.instantiate()
	w.add_child(player)
	var spawner: Node = SPAWNER.new()
	w.add_child(spawner)
	await _ticks(5)
	GameState.reset_run_state()
	UpgradeManager.reset_run()
	await _ticks(2)

	UpgradeManager.safehouse_visits = 0
	var p0: int = spawner.current_phase()
	UpgradeManager.safehouse_visits = 2
	var p0b: int = spawner.current_phase()
	UpgradeManager.safehouse_visits = 3
	var p1: int = spawner.current_phase()
	UpgradeManager.safehouse_visits = 5
	var p1b: int = spawner.current_phase()
	UpgradeManager.safehouse_visits = 6
	var p2: int = spawner.current_phase()
	UpgradeManager.safehouse_visits = 9
	var p3: int = spawner.current_phase()
	UpgradeManager.safehouse_visits = 12
	var p3b: int = spawner.current_phase()
	print("T1_PHASE_MAPPING: ", p0 == 0 and p0b == 0 and p1 == 1 and p1b == 1
		and p2 == 2 and p3 == 3 and p3b == 3,
		" (%d/%d/%d/%d/%d/%d/%d)" % [p0, p0b, p1, p1b, p2, p3, p3b])

	UpgradeManager.safehouse_visits = 0
	var iv0: float = spawner.phase_interval(0)
	var mx0: int = spawner.phase_max(0)
	var iv1: float = spawner.phase_interval(1)
	var mx1: int = spawner.phase_max(1)
	var iv2: float = spawner.phase_interval(2)
	var mx2: int = spawner.phase_max(2)
	var iv3: float = spawner.phase_interval(3)
	var mx3: int = spawner.phase_max(3)
	print("T2_INTERVAL_AND_CAP: ",
		is_equal_approx(iv0, 4.0) and mx0 == 60
		and is_equal_approx(iv1, 3.2) and mx1 == 70
		and is_equal_approx(iv2, 2.6) and mx2 == 85
		and is_equal_approx(iv3, 2.0) and mx3 == 100,
		" (%.2f/%d %.2f/%d %.2f/%d %.2f/%d)" % [iv0, mx0, iv1, mx1, iv2, mx2, iv3, mx3])

	var w0: Array = spawner.phase_horde_weights(0)
	var w1: Array = spawner.phase_horde_weights(1)
	var w2: Array = spawner.phase_horde_weights(2)
	var w3: Array = spawner.phase_horde_weights(3)
	print("T3_HORDE_WEIGHTS: ",
		Array(w0) == [45, 52, 2, 1]
		and Array(w1) == [40, 50, 8, 2]
		and Array(w2) == [35, 48, 13, 4]
		and Array(w3) == [30, 45, 18, 7],
		" (%s %s %s %s)" % [str(w0), str(w1), str(w2), str(w3)])

	UpgradeManager.safehouse_visits = 0
	var rare0 := _rare_ratio(spawner, 4000)
	UpgradeManager.safehouse_visits = 9
	var rare3 := _rare_ratio(spawner, 4000)
	print("T4_BIG_HORDES_GROW: ", rare0 <= 0.05 and rare3 >= 0.18 and rare3 <= 0.32,
		" (P0 3~4마리 %.1f%% / P3 %.1f%%)" % [rare0 * 100.0, rare3 * 100.0])

	spawner.max_zombies = 5
	UpgradeManager.safehouse_visits = 0
	var cap0: int = spawner.phase_max(0)
	UpgradeManager.safehouse_visits = 9
	var cap3: int = spawner.phase_max(3)
	print("T5_EXPORT_OVERRIDE_RESPECTED: ", cap0 == 5 and cap3 == 45,
		" (P0 cap=%d / P3 cap=%d)" % [cap0, cap3])

	UpgradeManager.reset_run()
	print("T6_RESET_BACK_TO_P0: ",
		UpgradeManager.safehouse_visits == 0 and spawner.current_phase() == 0)

	print("M74_SMOKE_DONE")
	get_tree().quit(0)
