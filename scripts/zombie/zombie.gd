class_name Zombie
extends CharacterBody3D

signal died(zombie: Zombie)

const COIN_SCENE := preload("res://scenes/items/coin_pickup.tscn")

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
var _lock_anim_t := 0.0
var _dead := false

var _anim: AnimationPlayer

@onready var _model: Node3D = $Model


func _ready() -> void:
	add_to_group("zombies")
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
	_attack_cd -= delta
	if _attack_windup > 0.0:
		_attack_windup -= delta
		if _attack_windup <= 0.0:
			_do_attack_hit()
	_lock_anim_t -= delta
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
				_steer(_move_point, wander_speed, delta)
		State.CHASE:
			var p: Node3D = _get_player()
			if p == null:
				state = State.IDLE
			elif global_position.distance_to(p.global_position) < attack_range:
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
				if global_position.distance_to(p.global_position) > attack_range + 0.6:
					state = State.CHASE

	move_and_slide()
	_update_anim()


func on_noise(pos: Vector3, _priority: int) -> void:
	if _dead or state == State.CHASE or state == State.ATTACK:
		return
	_move_point = pos + Vector3(randf_range(-0.5, 0.5), 0, randf_range(-0.5, 0.5))
	_has_move_point = true
	state = State.WANDER


func take_damage(amount: float, from_pos: Vector3) -> void:
	if _dead:
		return
	hp -= amount
	HitFlash.flash(self)
	var kb := global_position - from_pos
	kb.y = 0.0
	if kb.length() > 0.01:
		_knockback = kb.normalized() * 5.0
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
	var dir := target - global_position
	dir.y = 0.0
	dir = dir.normalized()
	_face_towards(target, delta)
	velocity = dir * speed + _knockback


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


func _get_player() -> Node:
	if _player != null and is_instance_valid(_player):
		return _player
	return get_tree().get_first_node_in_group("player")


func _do_attack_hit() -> void:
	var p: Node3D = _get_player()
	if p == null or not is_instance_valid(p):
		return
	if global_position.distance_to(p.global_position) <= attack_range + 0.5:
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
