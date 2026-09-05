class_name Zombie
extends CharacterBody3D

signal died(zombie: Zombie)

const COIN_SCENE := preload("res://scenes/items/coin_pickup.tscn")
## 재활용 업그레이드 습득 시 스크랩 드롭 확률
const SALVAGE_CHANCE := 0.1
## 외형 변형 후보(플레이어 character-a, 기본값 character-c 제외)
const VARIANT_SCENES := [
	preload("res://assets/blocky-characters/Models/GLB format/character-d.glb"),
	preload("res://assets/blocky-characters/Models/GLB format/character-e.glb"),
	preload("res://assets/blocky-characters/Models/GLB format/character-f.glb"),
	preload("res://assets/blocky-characters/Models/GLB format/character-g.glb"),
	preload("res://assets/blocky-characters/Models/GLB format/character-i.glb"),
	preload("res://assets/blocky-characters/Models/GLB format/character-k.glb"),
]

enum State { IDLE, WANDER, CHASE, ATTACK, DEAD }

const PERCEPTION_INTERVAL := 0.2

@export var max_hp := 60.0
@export var wander_speed := 1.2
@export var chase_speed := 3.3
@export var attack_range := 1.35
@export var attack_cooldown := 1.1
@export var attack_damage := 10.0
@export var vision_radius := 10.0
@export var fov_deg := 100.0
@export var model_yaw_offset := PI
## 플레이어로부터 이 거리보다 먼 좀비는 물리/AI 연산과 렌더링을 낮춘다(데이터·상태는 유지).
## stage1 스폰러가 이 값을 좁혀 실제 게임에서 활성화한다. 기본은 무한이라 기본 동작(항상 활성)과 동일.
@export var visibility_dist := 1e9
## -1이면 기본 외형(character-c), 0 이상이면 VARIANT_SCENES 인덱스
@export var variant_index := -1

## 나무 수관 통과 시 이동 감속 배율
const TREE_SLOW_MULT := 0.45
## 추적 우회: 전방 장애물(건물·차량, world 레이어) 감지 거리
const AVOID_DIST := 2.2
const AVOID_MASK := 1
## 뭉침 방지: 이 반경 내 다른 좀비를 밀어낸다
const SEPARATION_RADIUS := 1.6
## 정체 감지: 이 시간 동안 이 거리 미만으로 움직이면 측면 우회 개시
const STUCK_TIME := 0.5
const STUCK_DIST := 0.3
const DETOUR_TIME := 0.9
const DETOUR_ANGLE := 75.0
## 조향 스무딩: 프레임당 최대 회전각. 후보 뒤집힘에 velocity가 즉시
## 반전돼 덜덜거리는 것을 막는다.
const STEER_MAX_TURN_DEG := 240.0
## WANDER 목표가 벽 안에 박혔을 때 무한 박치기 방지용 타임아웃
const WANDER_TIMEOUT := 6.0
## 분리·수관 감속 조회 캐시 주기. 매 물리 프레임 전수 스캔하면
## 좀비 수 제곱으로 그룹 조회·배열 할당이 늘어나 싱글스레드 웹에서
## 메모리·프레임을 압박하므로 짧게 캐시한다(판정 지연 ≤0.25초).
const SEP_CACHE_INTERVAL := 0.2
const TREE_CACHE_INTERVAL := 0.25

var hp := 60.0
var state: int = State.IDLE

var _player: Node = null
var _current_anim := ""
var _move_point := Vector3.ZERO
var _has_move_point := false
var _idle_time := 0.0
var _attack_cd := 0.0
var _attack_windup := 0.0
var _perception_t := 0.0
var _knockback := Vector3.ZERO
var _stagger_t := 0.0
var _lock_anim_t := 0.0
var _dead := false
## 우회 상태: 양수면 측면 우회 중(초), 부호는 우회 방향
var _detour_t := 0.0
var _detour_sign := 1.0
var _stuck_t := 0.0
var _stuck_pos := Vector3.ZERO
var _stuck_init := false
## 조향 히스테리시스: 막힌 동안 유지하는 회피 쪽(0=없음, ±1)
var _avoid_sign := 0.0
## 스무딩된 실제 이동 방향. 프레임 뒤집힘을 흡수한다.
var _steer_dir := Vector3.ZERO
var _wander_t := 0.0
var _sep_cache := Vector3.ZERO
var _sep_t := 0.0
var _tree_slow := false
var _tree_t := 0.0
var _tree_pos := Vector3(1e9, 0.0, 0.0)

var _anim: AnimationPlayer

@onready var _model: Node3D = $Model


func _apply_variant() -> void:
	if variant_index < 0 or variant_index >= VARIANT_SCENES.size():
		return
	for ch in _model.get_children():
		_model.remove_child(ch)
		ch.free()
	var inst: Node3D = VARIANT_SCENES[variant_index].instantiate()
	_model.add_child(inst)


func _ready() -> void:
	add_to_group("zombies")
	_apply_variant()
	hp = max_hp
	_model.rotation.y = model_yaw_offset
	_anim = find_child("AnimationPlayer", true, false)
	if _anim != null:
		for a in ["idle", "walk"]:
			if _anim.has_animation(a):
				_anim.get_animation(a).loop_mode = Animation.LOOP_LINEAR
	_play("idle")
	NoiseSystem.register(self)


func _exit_tree() -> void:
	NoiseSystem.unregister(self)


func _physics_process(delta: float) -> void:
	if _dead:
		return
	# 플레이어 기반 반경 밖 좀비는 물리/AI 연산과 렌더링을 낮춘다(데이터·상태는 유지).
	# 플레이어가 가까워지면 자동으로 재개된다. 카메라·플레이어가 없으면(스모크 테스트) 항상 활성.
	if not _refocus_visibility():
		return
	_attack_cd -= delta
	_lock_anim_t -= delta
	if _stagger_t > 0.0:
		_stagger_t -= delta
		_knockback = _knockback.move_toward(Vector3.ZERO, 14.0 * delta)
		velocity = _knockback
		move_and_slide()
		return
	if _attack_windup > 0.0:
		_attack_windup -= delta
		if _attack_windup <= 0.0:
			_do_attack_hit()
	_perception_t -= delta
	if _perception_t <= 0.0:
		_perception_t = PERCEPTION_INTERVAL
		_perceive()
	_knockback = _knockback.move_toward(Vector3.ZERO, 14.0 * delta)

	match state:
		State.IDLE:
			velocity = _knockback
			_idle_time += delta
			if _idle_time > 3.0:
				_idle_time = 0.0
				_pick_wander_point()
				state = State.WANDER
		State.WANDER:
			if not _has_move_point or global_position.distance_to(_move_point) < 0.5:
				_has_move_point = false
				state = State.IDLE
			else:
				_wander_t += delta
				# 목표가 벽 안에 박혔으면(타임아웃·정체) 새 목표를 뽑는다.
				if _wander_t > WANDER_TIMEOUT or (_detour_t > 0.0 and _wander_t > 1.0):
					_pick_wander_point()
				_steer(_move_point, wander_speed, delta)
		State.CHASE:
			var p: Node3D = _get_player()
			if p == null:
				state = State.IDLE
			elif global_position.distance_to(p.global_position) < attack_range \
					and not _los_blocked_to(p.global_position):
				state = State.ATTACK
			else:
				_steer(p.global_position, chase_speed, delta)
		State.ATTACK:
			var p: Node3D = _get_player()
			if p == null:
				state = State.IDLE
			else:
				_face_towards(p.global_position, delta)
				velocity = _knockback
				if _attack_cd <= 0.0 and _lock_anim_t <= 0.0:
					_attack_cd = attack_cooldown
					_attack_windup = 0.25
					_play_oneshot("attack-melee-right")
				# 벽越し면 공격 자세로 굳지 말고 돌아간다.
				if global_position.distance_to(p.global_position) > attack_range + 0.6 \
						or _los_blocked_to(p.global_position):
					state = State.CHASE

	move_and_slide()
	_update_anim()


func on_noise(pos: Vector3, _priority: int) -> void:
	if _dead or state == State.CHASE or state == State.ATTACK:
		return
	_move_point = pos + Vector3(randf_range(-0.5, 0.5), 0, randf_range(-0.5, 0.5))
	_has_move_point = true
	_wander_t = 0.0
	state = State.WANDER


## 안전가옥 파동: 플레이어 중심에서 바깥으로 원형 넉백. 살아있는 좀비만.
func apply_wave_knockback(dir: Vector3, speed: float) -> void:
	if _dead:
		return
	dir.y = 0.0
	if dir.length() <= 0.01:
		return
	_knockback = dir.normalized() * speed


func take_damage(amount: float, from_pos: Vector3,
		knockback_speed := 0.0, stagger_time := 0.0) -> void:
	if _dead:
		return
	hp -= amount
	HitFlash.flash(self)
	var kb := global_position - from_pos
	kb.y = 0.0
	if knockback_speed > 0.0 and kb.length() > 0.01:
		_knockback = kb.normalized() * knockback_speed
	if stagger_time > _stagger_t:
		_stagger_t = stagger_time
		_attack_windup = 0.0
	var p: Node3D = _get_player()
	if p != null:
		_player = p
		state = State.CHASE
	if hp <= 0.0:
		_die()


func _die() -> void:
	_dead = true
	state = State.DEAD
	set_deferred("collision_layer", 0)
	set_deferred("collision_mask", 0)
	velocity = Vector3.ZERO
	died.emit(self)
	_drop_coin()
	UpgradeManager.add_kill()
	if UpgradeManager.upgrade_level("up_salvage") > 0 and randf() < SALVAGE_CHANCE:
		GameState.add_scrap(1)
	if _anim != null and _anim.has_animation("die"):
		_current_anim = ""
		_play("die")
	var t := get_tree().create_timer(1.8)
	t.timeout.connect(queue_free)


func _drop_coin() -> void:
	var coin := COIN_SCENE.instantiate()
	coin.position = global_position + Vector3(randf_range(-0.4, 0.4), 0.2, randf_range(-0.4, 0.4))
	get_parent().add_child.call_deferred(coin)


func _perceive() -> void:
	var p: Node3D = _get_player()
	if p == null:
		return
	var to := p.global_position - global_position
	to.y = 0.0
	var d := to.length()
	var aggro := state == State.CHASE or state == State.ATTACK

	if aggro:
		if d > vision_radius * 1.6:
			state = State.IDLE
		return

	if d <= vision_radius and (d < 2.0 or _in_fov(to)):
		if _los_clear(p):
			_player = p
			state = State.CHASE


func _in_fov(to_normalized_target: Vector3) -> bool:
	var fwd := -global_transform.basis.z
	fwd.y = 0.0
	fwd = fwd.normalized()
	var to := to_normalized_target.normalized()
	return fwd.dot(to) >= cos(deg_to_rad(fov_deg * 0.5))


func _los_clear(p: Node3D) -> bool:
	var space := get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(
		global_position + Vector3.UP * 0.9,
		p.global_position + Vector3.UP * 0.9,
		1
	)
	q.exclude = [get_rid()]
	return space.intersect_ray(q).is_empty()


func _steer(target: Vector3, speed: float, delta: float) -> void:
	var to := target - global_position
	to.y = 0.0
	var dist := to.length()
	if dist < 0.05:
		velocity = _knockback
		return
	var dir: Vector3 = to / dist
	_update_stuck(delta, dist)
	# 정체 중이면 목표 방향을 측면으로 틀어 건물·차량 옆으로 빠져나간다.
	if _detour_t > 0.0:
		_detour_t -= delta
		dir = dir.rotated(Vector3.UP, deg_to_rad(DETOUR_ANGLE) * _detour_sign)
	# 전방 world 장애물이 막고 있으면 우회 각도 중 뚫린 방향을 쓴다.
	# 막힌 동안은 같은 쪽을 유지(히스테리시스)해 좌우 뒤집힘을 막는다.
	dir = _avoid_obstacle(dir)
	# 뭉친 좀비를 옆으로 밀어 겹침·정체를 푼다. 전수 스캔이라 짧게 캐시한다.
	_sep_t -= delta
	if _sep_t <= 0.0:
		_sep_t = SEP_CACHE_INTERVAL
		_sep_cache = _separation_vector()
	var desired: Vector3 = dir + _sep_cache * 0.8
	if desired.length() < 0.01:
		desired = dir
	desired = desired.normalized()
	# 급반전 방지: 지속 조향 방향을 프레임당 제한각만큼만 틀어 덜덜거림을 막는다.
	_steer_dir = _smooth_turn(_steer_dir, desired, delta)
	_face_towards(global_position + _steer_dir, delta)
	# 수관 감속 존 전수 스캔이라 짧게 캐시한다. 위치가 크게 바뀌면
	#(텔레포트·스폰 직후 등) 타이머와 무관하게 즉시 다시 검사한다.
	_tree_t -= delta
	if _tree_t <= 0.0 or global_position.distance_to(_tree_pos) > 0.5:
		_tree_t = TREE_CACHE_INTERVAL
		_tree_pos = global_position
		_tree_slow = TreeZone.slows(self)
	var mult := TREE_SLOW_MULT if _tree_slow else 1.0
	velocity = _steer_dir * speed * mult + _knockback


## 현재 조향 방향을 목표 쪽으로 프레임당 제한각만큼만 회전시킨다.
func _smooth_turn(current: Vector3, desired: Vector3, delta: float) -> Vector3:
	var c: Vector3 = current
	c.y = 0.0
	var d: Vector3 = desired
	d.y = 0.0
	if d.length() < 0.01:
		return c
	d = d.normalized()
	if c.length() < 0.01:
		return d
	c = c.normalized()
	var max_turn := deg_to_rad(STEER_MAX_TURN_DEG) * delta
	var ang := c.angle_to(d)
	if ang <= max_turn:
		return d
	var s := signf(c.cross(d).y)
	if s == 0.0:
		s = 1.0
	return c.rotated(Vector3.UP, max_turn * s)


## 정체 추적: 거의 못 움직였는데 목표가 멀면 측면 우회를 예약한다.
func _update_stuck(delta: float, dist_to_target: float) -> void:
	if not _stuck_init:
		_stuck_init = true
		_stuck_pos = global_position
		_stuck_t = 0.0
		return
	_stuck_t += delta
	if _stuck_t < STUCK_TIME:
		return
	var moved: float = Vector2(
		global_position.x - _stuck_pos.x, global_position.z - _stuck_pos.z).length()
	_stuck_pos = global_position
	_stuck_t = 0.0
	if moved < STUCK_DIST and dist_to_target > 1.0 and _detour_t <= 0.0:
		_detour_sign = _freer_side()
		_detour_t = DETOUR_TIME


## 좌·우 중 레이캐스트가 더 멀리 뚫리는 쪽을 우회 방향으로 고른다.
func _freer_side() -> float:
	# 호출 시점의 진행 방향 기준이 없으므로 현재 forward를 쓴다.
	var fwd := -global_transform.basis.z
	fwd.y = 0.0
	if fwd.length() < 0.01:
		return 1.0 if randf() < 0.5 else -1.0
	fwd = fwd.normalized()
	var l_dir: Vector3 = fwd.rotated(Vector3.UP, deg_to_rad(DETOUR_ANGLE))
	var r_dir: Vector3 = fwd.rotated(Vector3.UP, -deg_to_rad(DETOUR_ANGLE))
	var l_d := _ray_dist(l_dir, AVOID_DIST)
	var r_d := _ray_dist(r_dir, AVOID_DIST)
	if l_d > r_d:
		return 1.0
	if r_d > l_d:
		return -1.0
	return 1.0 if randf() < 0.5 else -1.0


## 직진 방향이 막혔으면 후보 각도 중 처음으로 뚫린 방향을 돌려준다.
## 막힌 동안은 같은 쪽을 유지(히스테리시스)하고, 뚫리면 리셋한다.
func _avoid_obstacle(dir: Vector3) -> Vector3:
	if not _ray_blocked(dir, AVOID_DIST):
		_avoid_sign = 0.0
		return dir
	var steps := [30.0, 60.0, 90.0, 120.0, 150.0]
	var signs: Array = []
	if _detour_t > 0.0:
		signs = [_detour_sign, -_detour_sign]
	elif _avoid_sign != 0.0:
		signs = [_avoid_sign, -_avoid_sign]
	else:
		signs = [1.0, -1.0]
	for s in signs:
		for a in steps:
			var cand: Vector3 = dir.rotated(Vector3.UP, deg_to_rad(float(a) * float(s)))
			if not _ray_blocked(cand, AVOID_DIST):
				_avoid_sign = float(s)
				return cand
	var cand180: Vector3 = dir.rotated(Vector3.UP, PI)
	if not _ray_blocked(cand180, AVOID_DIST):
		return cand180
	return dir


## 목표 지점까지 world 레이어(건물·차량)가 가로막고 있는지.
## ATTACK 진입·유지·타격 판정에 써서 벽越し 공격 고착을 막는다.
func _los_blocked_to(point: Vector3) -> bool:
	var to: Vector3 = point - global_position
	to.y = 0.0
	var dist := to.length()
	if dist < 0.1:
		return false
	return _ray_dist(to / dist, dist) < dist - 0.05


func _ray_blocked(dir: Vector3, dist: float) -> bool:
	return _ray_dist(dir, dist) < dist - 0.01


## 진행 방향으로 world 레이어 장애물까지의 거리(없으면 dist 반환).
func _ray_dist(dir: Vector3, dist: float) -> float:
	var d: Vector3 = dir
	d.y = 0.0
	if d.length() < 0.01:
		return dist
	d = d.normalized()
	var space := get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(
		global_position + Vector3.UP * 0.9,
		global_position + Vector3.UP * 0.9 + d * dist,
		AVOID_MASK
	)
	q.exclude = [get_rid()]
	var hit := space.intersect_ray(q)
	if hit.is_empty():
		return dist
	var p: Vector3 = hit["position"]
	var flat := Vector2(p.x - global_position.x, p.z - global_position.z).length()
	return flat


## 주변 좀비와 겹치지 않도록 밀어내는 벡터(정규화 전 가중합).
func _separation_vector() -> Vector3:
	var out := Vector3.ZERO
	for other in get_tree().get_nodes_in_group("zombies"):
		if other == self or not (other is Node3D):
			continue
		var o := other as Node3D
		if not is_instance_valid(o):
			continue
		var diff: Vector3 = global_position - o.global_position
		diff.y = 0.0
		var d := diff.length()
		if d < 0.01 or d > SEPARATION_RADIUS:
			continue
		out += diff.normalized() * (1.0 - d / SEPARATION_RADIUS)
	return out


func _face_towards(point: Vector3, delta: float) -> void:
	var d := point - global_position
	d.y = 0.0
	if d.length() < 0.05:
		return
	var target_yaw := atan2(-d.x, -d.z)
	rotation.y = lerp_angle(rotation.y, target_yaw, 1.0 - exp(-10.0 * delta))


func _pick_wander_point() -> void:
	var r := randf_range(2.0, 6.0)
	var ang := randf() * TAU
	_move_point = global_position + Vector3(cos(ang) * r, 0, sin(ang) * r)
	_has_move_point = true
	_wander_t = 0.0


func _get_player() -> Node:
	if _player != null and is_instance_valid(_player):
		return _player
	return get_tree().get_first_node_in_group("player")


## 플레이어 기반 반경 밖이면 물리/AI를 스킵하고 모델을 숨긴다(데이터·상태는 유지).
## stage1 스폰러가 visibility_dist를 좁혔을 때만 동작하고, 기본(무한)은 항상 활성화해 회귀를 막는다.
## 반환 true면 물리/AI를 계속 진행하고, false면 이 프레임은 생략한다.
func _refocus_visibility() -> bool:
	var p: Node3D = _get_player()
	if p == null:
		return true
	var inside := global_position.distance_to(p.global_position) <= visibility_dist
	_model.visible = inside
	return inside


func _do_attack_hit() -> void:
	var p: Node3D = _get_player()
	if p == null or not is_instance_valid(p):
		return
	if global_position.distance_to(p.global_position) <= attack_range + 0.5 \
			and not _los_blocked_to(p.global_position):
		p.take_damage(attack_damage)


func _update_anim() -> void:
	if _anim == null or _lock_anim_t > 0.0:
		return
	match state:
		State.IDLE:
			_play("idle")
		State.DEAD:
			pass
		_:
			_play("walk")


func _play(name: String) -> void:
	if _current_anim == name or _anim == null or not _anim.has_animation(name):
		return
	_current_anim = name
	_anim.play(name, 0.2)


func _play_oneshot(name: String) -> void:
	if _anim == null or not _anim.has_animation(name):
		return
	_current_anim = name
	_lock_anim_t = _anim.get_animation(name).length
	_anim.play(name, 0.1)
