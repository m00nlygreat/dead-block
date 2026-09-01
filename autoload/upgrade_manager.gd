extends Node

## 처치 수 기반 성장 관리:
## 좀비를 처치하면 카운트가 쌓이고, 일정 처치 수(KILLS_PER_SPAWN)마다
## 업그레이드 화면(안전가옥)이 곧바로 열린다(UpgradeUI가 kills_changed 구독).
## 열린 화면에서 업그레이드를 코인으로 구매해 즉시 적용한다.
## 구매 내역은 런 한정(사망·추출 시 reset_run으로 초기화).

signal kills_changed(kills: int)
signal upgrade_applied(upgrade: UpgradeData)

const UPGRADE_DIR := "res://resources/upgrades"
const KILLS_PER_SPAWN := 10
const CHOICE_COUNT := 3

var kills := 0
var upgrade_levels := {}

var _pool: Array[UpgradeData] = []


func _ready() -> void:
	_load_pool()


func _load_pool() -> void:
	_pool.clear()
	var dir := DirAccess.open(UPGRADE_DIR)
	if dir == null:
		push_error("UpgradeManager: 업그레이드 폴더 없음: " + UPGRADE_DIR)
		return
	dir.list_dir_begin()
	var fname := dir.get_next()
	while fname != "":
		if not dir.current_is_dir() and fname.ends_with(".tres"):
			var res = ResourceLoader.load(UPGRADE_DIR + "/" + fname)
			if res is UpgradeData:
				_pool.append(res)
		fname = dir.get_next()
	dir.list_dir_end()
	_pool.sort_custom(func(a: UpgradeData, b: UpgradeData) -> bool: return a.id < b.id)


func add_kill() -> void:
	kills += 1
	kills_changed.emit(kills)


func upgrade_level(id: String) -> int:
	return upgrade_levels.get(id, 0)


## 현재 보유 단계 기준 구매가
func cost_of(u: UpgradeData) -> int:
	return u.cost * (1 + upgrade_level(u.id))


func can_buy(u: UpgradeData) -> bool:
	if u == null or upgrade_level(u.id) >= u.max_level:
		return false
	return GameState.coins >= cost_of(u)


## 코인 구매: 차감 성공 시 즉시 플레이어 적용
func purchase(id: String) -> bool:
	var up := _find(id)
	if not can_buy(up):
		return false
	if not GameState.spend_coins(cost_of(up)):
		return false
	upgrade_levels[id] = upgrade_level(id) + 1
	_apply_to_player(up)
	upgrade_applied.emit(up)
	return true


func draw_choices() -> Array[UpgradeData]:
	var avail: Array[UpgradeData] = []
	for u in _pool:
		if upgrade_level(u.id) < u.max_level:
			avail.append(u)
	var picks: Array[UpgradeData] = []
	while picks.size() < mini(CHOICE_COUNT, avail.size()):
		var total := 0.0
		for u in avail:
			if not picks.has(u):
				total += u.weight
		var r := randf() * total
		var chosen: UpgradeData = null
		for u in avail:
			if picks.has(u):
				continue
			r -= u.weight
			if r <= 0.0 or u == avail[avail.size() - 1]:
				chosen = u
				break
		if chosen != null and not picks.has(chosen):
			picks.append(chosen)
	return picks


func reset_run() -> void:
	kills = 0
	upgrade_levels.clear()
	kills_changed.emit(kills)


func _find(id: String) -> UpgradeData:
	for u in _pool:
		if u.id == id:
			return u
	return null


func _apply_to_player(up: UpgradeData) -> void:
	var p: Node = get_tree().get_first_node_in_group("player")
	if p == null or not p.has_method("apply_upgrade"):
		return
	p.apply_upgrade(up.effect_id, up.values[upgrade_level(up.id) - 1])
