extends Node

## 시간 기반 성장 관리:
## 런 시작 후 SAFEHOUSE_INTERVAL(120초)마다 업그레이드 화면(안전가옥)이
## 열린다(UpgradeUI가 safehouse_due 구독). 제한 시간 안에 수색(룻·재료)과
## 사냥(코인)을 저울질하는 구조. kills는 전적·밸런스 지표로만 유지된다.
## 열린 화면에서 업그레이드를 코인으로 구매해 즉시 적용한다.
## 구매 내역은 런 한정(사망·추출 시 reset_run으로 초기화).

signal kills_changed(kills: int)
signal upgrade_applied(upgrade: UpgradeData)
signal safehouse_due
signal safehouse_visits_changed(visits: int)

const UPGRADE_DIR := "res://resources/upgrades"
const KILLS_PER_SPAWN := 10
const CHOICE_COUNT := 3
## 안전가옥 개방 간격(초) · 1스테이지 종료까지 방문 횟수
const SAFEHOUSE_INTERVAL := 120.0
const SAFEHOUSE_VISITS_TO_CLEAR := 10

var kills := 0
var time_to_safehouse := SAFEHOUSE_INTERVAL
var safehouse_visits := 0
var upgrade_levels := {}
## 이번 안전가옥 방문에서 이미 구매한 업그레이드 id 목록
var _purchased_this_visit: Array[String] = []

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
		## 익스포트(웹 포함)에서는 파일명이 .tres.remap으로 저장되므로 원래 경로로 복원한다.
		var base := fname.trim_suffix(".remap") if fname.ends_with(".remap") else fname
		if not dir.current_is_dir() and base.ends_with(".tres"):
			var res = ResourceLoader.load(UPGRADE_DIR + "/" + base)
			if res is UpgradeData:
				_pool.append(res)
		fname = dir.get_next()
	dir.list_dir_end()
	_pool.sort_custom(func(a: UpgradeData, b: UpgradeData) -> bool: return a.id < b.id)


func _process(delta: float) -> void:
	var tree := get_tree()
	if tree == null or tree.paused:
		return
	if tree.get_first_node_in_group("player") == null:
		return
	var ui: Node = tree.get_first_node_in_group("upgrade_ui")
	if ui != null and (ui as CanvasLayer).visible:
		return
	time_to_safehouse -= delta
	if time_to_safehouse <= 0.0:
		time_to_safehouse = SAFEHOUSE_INTERVAL
		safehouse_due.emit()


func add_kill() -> void:
	kills += 1
	kills_changed.emit(kills)


## 안전가옥이 실제로 열렸을 때 UI가 호출 — 방문 횟수 누적
func notify_safehouse_opened() -> void:
	safehouse_visits += 1
	safehouse_visits_changed.emit(safehouse_visits)


## 스모크 테스트용: 다음 개방까지 남은 시간을 강제로 당긴다
func debug_force_due(in_sec: float = 0.05) -> void:
	time_to_safehouse = in_sec


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
	if not _purchased_this_visit.has(id):
		_purchased_this_visit.append(id)
	_apply_to_player(up)
	upgrade_applied.emit(up)
	return true


func draw_choices() -> Array[UpgradeData]:
	var avail: Array[UpgradeData] = []
	for u in _pool:
		if upgrade_level(u.id) < u.max_level \
				and not _purchased_this_visit.has(u.id):
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
	time_to_safehouse = SAFEHOUSE_INTERVAL
	safehouse_visits = 0
	upgrade_levels.clear()
	visit_over()
	kills_changed.emit(kills)
	safehouse_visits_changed.emit(safehouse_visits)


## 안전가옥 닫힘 시 호출: 이번 방문 구매 내역 초기화
func visit_over() -> void:
	_purchased_this_visit.clear()


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
