extends Node

const ZOMBIE_SCENE := preload("res://scenes/zombie/zombie.tscn")

@export var interval := 4.0
@export var max_zombies := 60
@export var min_dist := 14.0
@export var max_dist := 24.0
## 호드 크기별 가중치(인덱스+1마리). 1~2마리 호드가 대부분, 3~4마리는 극히 드묾.
@export var horde_size_weights: Array[int] = [45, 52, 2, 1]
@export var horde_spread := 2.2
## 이 거리를 벗어난 좀비는 보상 없이 제거(카메라 최대 줌 13m의 화면 밖 거리).
## 상한(60)이 먼 좀비로 영구 채워져 스폰이 멎는 문제를 막는다.
@export var despawn_dist := 40.0
## 생성한 좀비의 가시 최적화 반경. 0 이하(기본)면 좀비 기본값(무한)을 유지한다.
## 실제 게임 씬(stage1)에서 좁혀, 플레이어 반경 밖 좀비의 물리/AI·렌더링을 낮춘다.
@export var visibility_dist := -1.0
## 난이도 페이즈(안전가옥 방문 수 기반, 3회차마다 상승):
## P0(0~2회) → P1(3~5회) → P2(6~8회) → P3(9회~).
## 좀비 스탯(HP·이속·피해·시야)은 건드리지 않고 스폰량만 스케일한다.
## export 기본값이 P0 기준이라 P0 계수는 항등(테스트 오버라이드와 충돌 없음).
## 기본값(간격 4.0/상한 60/가중치 [45,52,2,1]) 기준 실효값:
## 간격 4.0→3.2→2.6→2.0 / 상한 60→70→85→100 /
## 가중치 [45,52,2,1]→[40,50,8,2]→[35,48,13,4]→[30,45,18,7].
const PHASE_INTERVAL_MULT := [1.0, 0.8, 0.65, 0.5]
const PHASE_MAX_BONUS := [0, 10, 25, 40]
## 호드 가중치 이동량: w0·w1에서 덜어 w2·w3에 얹는다(기본값 기준 위 실효값과 일치)
const PHASE_W0_TAKE := [0, 5, 10, 15]
const PHASE_W1_TAKE := [0, 2, 4, 7]
const PHASE_W2_GIVE := [0, 6, 11, 16]
const PHASE_W3_GIVE := [0, 1, 3, 6]

## 스폰 지점 안전 검사: 좀비 캡슐(반경 0.35) + 여유. world 레이어(건물·차량)와
## 겹치면 스폰하지 않고 다른 후보를 찾는다.
const SPAWN_CLEAR_RADIUS := 0.6
const SPAWN_PROBE_HEIGHT := 0.65
const CENTER_TRIES := 12
const MEMBER_TRIES := 8

## 스폰 안전 검사 프로브 형태. 쿼리마다 new하면 스폰 사이클당 수십 개씩
## 할당되므로 하나로 공유한다(트랜스폼은 쿼리마다 새로 지정).
static var _probe_shape: SphereShape3D

var _t := 0.0


## 현재 난이도 페이즈(0~3). UpgradeManager 오토로드가 없으면(단독 테스트)
## P0으로 폴백한다.
func current_phase() -> int:
	var um: Node = get_tree().root.get_node_or_null("UpgradeManager")
	if um == null:
		return 0
	return mini(int(um.get("safehouse_visits")) / 3, 3)


func phase_interval(phase: int) -> float:
	return interval * PHASE_INTERVAL_MULT[clampi(phase, 0, 3)]


func phase_max(phase: int) -> int:
	return max_zombies + PHASE_MAX_BONUS[clampi(phase, 0, 3)]


## 페이즈 적용 호드 가중치: export 기본값에서 w0·w1을 덜어 w2·w3으로 이동.
## 기본값보다 작은 가중치에는 깎을 만큼만 깎고, 실제 덜어낸 만큼만 얹는다.
func phase_horde_weights(phase: int) -> Array[int]:
	var p := clampi(phase, 0, 3)
	var w: Array[int] = [int(horde_size_weights[0]), int(horde_size_weights[1]),
		int(horde_size_weights[2]), int(horde_size_weights[3])]
	var take0: int = mini(w[0], PHASE_W0_TAKE[p])
	var take1: int = mini(w[1], PHASE_W1_TAKE[p])
	w[0] -= take0
	w[1] -= take1
	var taken: int = take0 + take1
	var give_total: int = PHASE_W2_GIVE[p] + PHASE_W3_GIVE[p]
	if taken > 0 and give_total > 0:
		w[2] += taken * PHASE_W2_GIVE[p] / give_total
		w[3] += taken - taken * PHASE_W2_GIVE[p] / give_total
	return w


func _process(delta: float) -> void:
	_t += delta
	if _t < phase_interval(current_phase()):
		return
	_t = 0.0
	_try_spawn()


func _roll_horde_size() -> int:
	var weights: Array[int] = phase_horde_weights(current_phase())
	return _roll_size_with(weights)


## 가중치 배열에서 호드 크기(1~4)를 뽑는다. 테스트·페이즈 공용.
func _roll_size_with(weights: Array[int]) -> int:
	var total := 0
	for w in weights:
		total += w
	if total <= 0:
		return 1
	var roll := randi() % total
	for i in weights.size():
		roll -= weights[i]
		if roll < 0:
			return i + 1
	return 1


func _try_spawn() -> void:
	var player: Node3D = get_tree().get_first_node_in_group("player")
	if player == null:
		return
	var alive := _prune_far(player)
	var phase := current_phase()
	var cap: int = phase_max(phase)
	var size := _roll_horde_size()
	var center := Vector3.ZERO
	var center_ok := false
	for attempt in CENTER_TRIES:
		var ang := randf() * TAU
		var d := randf_range(min_dist, max_dist)
		var cand: Vector3 = player.global_position + Vector3(cos(ang) * d, 0.0, sin(ang) * d)
		cand.y = player.global_position.y
		if is_spawn_free(cand):
			center = cand
			center_ok = true
			break
	if not center_ok:
		return
	for i in size:
		if alive.size() >= cap and not _pop_farthest(alive, player):
			return
		var pos := Vector3.ZERO
		var pos_ok := false
		for attempt in MEMBER_TRIES:
			var offset := Vector3.ZERO
			if i > 0:
				offset = Vector3(randf_range(-1.0, 1.0), 0.0, randf_range(-1.0, 1.0)).normalized() * randf_range(0.8, horde_spread)
			var cand_m: Vector3 = center + offset
			cand_m.y = player.global_position.y
			if is_spawn_free(cand_m):
				pos = cand_m
				pos_ok = true
				break
		if not pos_ok:
			continue
		var z := ZOMBIE_SCENE.instantiate()
		z.variant_index = randi_range(-1, Zombie.VARIANT_SCENES.size() - 1)
		if visibility_dist > 0.0:
			z.visibility_dist = visibility_dist
		get_parent().add_child(z)
		z.global_position = pos
		alive.append(z)


## 스폰 후보 지점이 건물·차량(world 레이어)과 겹치지 않는지 검사한다.
## 물리 월드가 없으면(테스트 초기 등) 안전 측으로 true를 돌려준다.
func is_spawn_free(pos: Vector3) -> bool:
	var player: Node3D = get_tree().get_first_node_in_group("player")
	if player == null:
		return true
	var space: PhysicsDirectSpaceState3D = player.get_world_3d().direct_space_state
	if _probe_shape == null:
		_probe_shape = SphereShape3D.new()
		_probe_shape.radius = SPAWN_CLEAR_RADIUS
	var q: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
	q.shape = _probe_shape
	q.transform = Transform3D(Basis(), pos + Vector3.UP * SPAWN_PROBE_HEIGHT)
	# 건물·차량은 world 레이어(1)를 공유하므로 마스크 1로 검사한다.
	q.collision_mask = 1
	return space.intersect_shape(q).is_empty()


## 플레이어에서 멀어진 좀비를 보상 없이 제거하고 살아남은 목록을 돌려준다.
func _prune_far(player: Node3D) -> Array:
	var keep: Array = []
	for z in get_tree().get_nodes_in_group("zombies"):
		if not is_instance_valid(z) or z.is_queued_for_deletion():
			continue
		if z.global_position.distance_to(player.global_position) > despawn_dist:
			z.queue_free()
		else:
			keep.append(z)
	return keep


## 상한 도달 시 가장 먼 좀비 한 마리를 비워 교체 스폰 자리를 만든다.
func _pop_farthest(alive: Array, player: Node3D) -> bool:
	var farthest: Node3D = null
	var best := -1.0
	for z in alive:
		if not is_instance_valid(z) or z.is_queued_for_deletion():
			continue
		var d: float = z.global_position.distance_to(player.global_position)
		if d > best:
			best = d
			farthest = z
	if farthest == null:
		return false
	farthest.queue_free()
	alive.erase(farthest)
	return true
