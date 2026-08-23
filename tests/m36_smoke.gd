extends Node

const ZOMBIE_SCENE := preload("res://scenes/zombie/zombie.tscn")
const PLAYER_SCENE := preload("res://scenes/player/player.tscn")


func _ready() -> void:
	_run()


func _ticks(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


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

	print("T9_CLIP_REGISTERED: ", player._anim.has_animation(BatSwing.CLIP_NAME))

	InventoryManager.add_item("weapon_bat", 1)
	player.global_position = Vector3.ZERO
	player.rotation.y = -PI * 0.5
	await _ticks(3)

	var z: Zombie = ZOMBIE_SCENE.instantiate()
	w.add_child(z)
	z.global_position = Vector3(1.6, 0, 0)
	await _ticks(5)

	Input.action_press("attack")
	await _ticks(2)
	Input.action_release("attack")
	await _ticks(10)
	var mid_anim: String = player._anim.current_animation
	print("T10_SWING_CLIP_PLAYED: ", mid_anim == BatSwing.CLIP_NAME, " (", mid_anim, ")")

	await _ticks(40)
	print("T11_BAT_HIT_LANDED: ", z.hp < z.max_hp)
	print("T12_HAND_ATTACHED: ", player._weapon_visual != null and player._hand != null)

	print("M36_SMOKE_DONE")
	get_tree().quit(0)
