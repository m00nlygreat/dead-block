extends Node

const PLAYER_SCENE := preload("res://scenes/player/player.tscn")
const HUD_SCENE := preload("res://scenes/ui/hud.tscn")
const ZOMBIE_SCENE := preload("res://scenes/zombie/zombie.tscn")


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


func _spawn_zombie(w: Node3D, player: Node3D, dist: float) -> Zombie:
	var z: Zombie = ZOMBIE_SCENE.instantiate()
	w.add_child(z)
	z.global_position = player.global_position + Vector3(dist, 0.0, 0.0)
	return z


func _coin_nodes(w: Node3D) -> Array:
	var out: Array = []
	for c in w.get_children():
		if c.is_in_group("coins"):
			out.append(c)
	return out


func _run() -> void:
	var w := Node3D.new()
	add_child(w)
	_floor(w)
	var player := PLAYER_SCENE.instantiate()
	w.add_child(player)
	var hud := HUD_SCENE.instantiate()
	w.add_child(hud)
	await _ticks(5)
	GameState.reset_run_state()

	var z1 := _spawn_zombie(w, player, 2.0)
	await _ticks(3)
	z1.take_damage(9999.0, z1.global_position + Vector3(0.1, 0, 0))
	await _ticks(6)
	print("T1_ZOMBIE_DEAD_DROPS_COIN: ", z1.state == z1.State.DEAD and _coin_nodes(w).size() == 1)

	var coin: Node3D = _coin_nodes(w)[0]
	player.global_position = coin.global_position
	await _ticks(6)
	print("T2_TOUCH_SCORES_AND_FREES: ", GameState.coins == 1 and _coin_nodes(w).size() == 0)

	var z2 := _spawn_zombie(w, player, -2.5)
	await _ticks(3)
	z2.take_damage(9999.0, z2.global_position + Vector3(-0.1, 0, 0))
	await _ticks(6)
	var coin2: Node3D = _coin_nodes(w)[0]
	player.global_position = coin2.global_position
	await _ticks(6)
	print("T3_SECOND_KILL_STACKS_SCORE: ", GameState.coins == 2)
	print("T4_HUD_SHOWS_COINS: ", hud._coin_label != null and hud._coin_label.text.contains("2"))

	print("M49_SMOKE_DONE")
	get_tree().quit(0)
