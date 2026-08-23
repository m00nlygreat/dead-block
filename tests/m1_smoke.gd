extends Node

const PLAYER_SCENE := preload("res://scenes/player/player.tscn")
const CAMERA_RIG_SCENE := preload("res://scenes/player/camera_rig.tscn")


func _ready() -> void:
	_run()


func _ticks(n: int) -> void:
	for i in n:
		await get_tree().process_frame


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

	var player := PLAYER_SCENE.instantiate()
	w.add_child(player)
	var rig: Node3D = CAMERA_RIG_SCENE.instantiate()
	rig.target_path = NodePath("../Player")
	w.add_child(rig)
	await _ticks(10)

	var cam: Camera3D = rig.get_node("Camera3D")

	print("ANIM_FOUND: ", player._anim != null)
	if player._anim != null:
		print("IDLE_LOOPED: ", player._anim.get_animation("idle").loop_mode == Animation.LOOP_LINEAR)
		print("CURRENT_ANIM: ", player._anim.current_animation)
	print("CAM_PITCH_DEG: ", snappedf(rad_to_deg(cam.rotation.x), 0.01))
	print("CAM_IS_CURRENT: ", w.get_viewport().get_camera_3d() == cam)
	print("CAM_POS_Y: ", snappedf(cam.global_position.y, 0.01))

	rig.global_position = Vector3(20, 0, 20)
	await _ticks(90)
	print("RIG_FOLLOWED_XZ: ", rig.global_position.distance_to(player.global_position) < 2.0)

	Input.action_press("move_up")
	await _ticks(45)
	print("MOVED_Z_NEG: ", player.global_position.z < -1.0)
	print("WALK_ANIM: ", player._anim.current_animation)
	print("SPEED: ", snappedf(player.velocity.length(), 0.1))

	Input.action_press("sprint")
	await _ticks(45)
	print("SPRINT_SPEED: ", snappedf(player.velocity.length(), 0.1))
	print("SPRINT_ANIM: ", player._anim.current_animation)

	Input.action_release("sprint")
	Input.action_release("move_up")
	await _ticks(45)
	print("STOPPED: ", player.velocity.length() < 0.5)
	print("IDLE_AGAIN: ", player._anim.current_animation)
	get_tree().quit(0)
