extends Node

const PLAYER_SCENE := preload("res://scenes/player/player.tscn")
const ZOMBIE_SCENE := preload("res://scenes/zombie/zombie.tscn")
const BAT_TRES := preload("res://resources/items/weapon_bat.tres")

## 무기별 기대값 (item_data.gd / .tres와 동기 유지)
const EXPECT := {
	"weapon_bat": [3.0, 0.25],
}


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


func _spawn_zombie(w: Node3D, pos: Vector3) -> Zombie:
	var z: Zombie = ZOMBIE_SCENE.instantiate()
	w.add_child(z)
	z.global_position = pos
	return z


func _check_tres_values() -> bool:
	for tres in [BAT_TRES]:
		var e: Array = EXPECT[tres.id]
		if not is_equal_approx(tres.knockback, e[0]) or not is_equal_approx(tres.stagger_time, e[1]):
			print("  MISMATCH: ", tres.id, " kb=", tres.knockback, " st=", tres.stagger_time)
			return false
	return true


func _run() -> void:
	var w := Node3D.new()
	add_child(w)
	_floor(w)
	var player := PLAYER_SCENE.instantiate()
	w.add_child(player)
	player.global_position = Vector3.ZERO
	await _ticks(5)
	GameState.reset_run_state()

	print("T1_TRES_KNOCKBACK_STAGGER_VALUES: ", _check_tres_values())

	var z_fist := _spawn_zombie(w, Vector3(2.0, 0.5, 0.0))
	await _ticks(3)
	z_fist.take_damage(10.0, player.global_position)
	var fist_kb_ok: bool = z_fist._knockback == Vector3.ZERO and z_fist._stagger_t <= 0.0
	z_fist.queue_free()
	await _ticks(2)

	var z_bat := _spawn_zombie(w, Vector3(-2.0, 0.5, 0.0))
	await _ticks(3)
	z_bat.take_damage(10.0, player.global_position,
		BAT_TRES.knockback, BAT_TRES.stagger_time)
	var kb_len := z_bat._knockback.length()
	var away_dir: Vector3 = z_bat.global_position - player.global_position
	away_dir.y = 0.0
	var kb_away := z_bat._knockback.normalized().dot(away_dir.normalized()) > 0.99
	var stagger_set: bool = absf(z_bat._stagger_t - BAT_TRES.stagger_time) < 0.01
	print("T2_BAT_APPLIES_KB_AND_STAGGER: ",
		kb_len > 0.0 and is_equal_approx(kb_len, BAT_TRES.knockback)
		and kb_away and stagger_set,
		" (kb=%.2f away=%s st=%.2f)" % [kb_len, str(kb_away), z_bat._stagger_t])

	var pos_before := z_bat.global_position
	var state_before: int = z_bat.state
	await _ticks(6)
	var moved := z_bat.global_position - pos_before
	var stagger_active := z_bat._stagger_t > 0.0
	print("T3_STAGGER_LOCKS_FSM: ", stagger_active and z_bat.state == state_before
		and moved.length() > 0.05,
		" (active=%s state_same=%s moved=%.2f)" % [
			str(stagger_active), str(z_bat.state == state_before), moved.length()])
	await _ticks(30)

	var z_atk := _spawn_zombie(w, Vector3(1.0, 0.5, 0.0))
	z_atk.state = z_atk.State.ATTACK
	z_atk._attack_cd = 0.0
	await _ticks(3)
	z_atk.take_damage(5.0, player.global_position,
		BAT_TRES.knockback, BAT_TRES.stagger_time)
	print("T4_STAGGER_CANCELS_ATTACK_WINDUP: ",
		z_atk._attack_windup == 0.0 and z_atk._stagger_t > 0.0)

	print("M55_SMOKE_DONE")
	get_tree().quit(0)
