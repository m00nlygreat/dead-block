extends Node


func _ready() -> void:
	_run()


func _run() -> void:
	var w: Node = load("res://scenes/core/stage1.tscn").instantiate()
	add_child(w)
	for i in 30:
		await get_tree().physics_frame

	var player: Node3D = w.get_node("Player")
	print("PLAYER_POS: ", player.global_position)
	print("MODEL_LOCAL_Y: ", player.get_node("Model").position.y)

	var char_root: Node3D = player.get_node("Model/CharacterA/character-a")
	var leg: MeshInstance3D = char_root.get_node("root/leg-left")
	var leg_aabb: AABB = leg.mesh.get_aabb()
	print("LEG_GLOBAL_BOTTOM_Y: ", leg.to_global(leg_aabb.position).y)

	get_tree().quit(0)
