extends Node

const PLAYER_SCENE := preload("res://scenes/player/player.tscn")


func _ready() -> void:
	_run()


func _ticks(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _key(code: int, pressed: bool) -> void:
	var ev := InputEventKey.new()
	ev.physical_keycode = code as Key
	ev.keycode = code as Key
	ev.pressed = pressed
	Input.parse_input_event(ev)


func _run() -> void:
	var w := Node3D.new()
	add_child(w)

	var floor_body := StaticBody3D.new()
	floor_body.collision_layer = 1
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(300, 1, 300)
	cs.shape = bs
	cs.position.y = -0.5
	floor_body.add_child(cs)
	w.add_child(floor_body)

	var player := PLAYER_SCENE.instantiate()
	w.add_child(player)
	await _ticks(5)

	print("M42_T0_SCRIPT_ATTACHED: ", player.has_method("_release_all_actions"))

	_key(KEY_W, true)
	_key(KEY_SHIFT, true)
	await _ticks(40)
	var v_sprint: float = player.velocity.length()
	print("M42_T1_SPRINT_ACTIVE: ", v_sprint > 6.0, " (speed=%.2f)" % v_sprint)

	player._release_all_actions()
	await _ticks(2)
	var stuck := Input.is_action_pressed("sprint") or Input.is_action_pressed("move_up")
	var v_after: float = player.velocity.length()
	print("M42_T2_RELEASE_CLEARS_STUCK_SPRINT: ", not stuck and v_after < 0.5,
		" (stuck=%s speed=%.2f)" % [str(stuck), v_after])

	_key(KEY_W, true)
	_key(KEY_SHIFT, true)
	await _ticks(40)
	var v_resume: float = player.velocity.length()
	print("M42_T3_SPRINT_RESUMES_NORMALLY: ", v_resume > 6.0, " (speed=%.2f)" % v_resume)

	_key(KEY_SHIFT, false)
	await _ticks(30)
	var v_walk: float = player.velocity.length()
	print("M42_T4_RELEASE_SHIFT_TO_WALK: ", v_walk > 0.5 and v_walk < 6.0,
		" (speed=%.2f)" % v_walk)

	_key(KEY_W, false)
	await _ticks(10)
	print("M42_T5_FULL_STOP: ", player.velocity.length() < 0.1,
		" (speed=%.2f)" % player.velocity.length())

	print("M42_SMOKE_DONE")
	get_tree().quit(0)
