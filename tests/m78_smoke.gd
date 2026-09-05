extends Node

const ZOMBIE_SCENE := preload("res://scenes/zombie/zombie.tscn")


func _ready() -> void:
	_run()


func _ticks(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _run() -> void:
	var w := Node3D.new()
	add_child(w)

	# T1: 좀비 7종(기본 l + 변형 6종) 전부 좀비 스킨인지 (시민/로봇 혼입 금지)
	var banned: Array = ["character-a", "character-b", "character-c", "character-d",
		"character-e", "character-f", "character-g", "character-h", "character-i",
		"character-j", "character-k", "character-m", "character-n", "character-p",
		"character-q", "character-r"]
	var paths_ok: bool = true
	for p in Zombie.VARIANT_SCENES:
		var ps: String = (p as PackedScene).resource_path
		for b in banned:
			if ps.find(b) >= 0:
				paths_ok = false
	var base_ps: String = (load("res://scenes/zombie/zombie.tscn") as PackedScene).resource_path
	print("T1_ZOMBIE_SKINS_ONLY: ", paths_ok and Zombie.VARIANT_SCENES.size() == 6,
		" (variants=", Zombie.VARIANT_SCENES.size(), ")")

	# T2: 기본 외형(-1) 로드 + idle/walk 보유 + 모델 1개
	var z0: Zombie = ZOMBIE_SCENE.instantiate()
	z0.variant_index = -1
	w.add_child(z0)
	z0.global_position = Vector3(0, 0.5, 0)
	await _ticks(3)
	var ap0: AnimationPlayer = z0.find_child("AnimationPlayer", true, false) as AnimationPlayer
	var t2: bool = ap0 != null and ap0.has_animation("idle") and ap0.has_animation("walk") \
		and z0.get_node("Model").get_child_count() == 1
	print("T2_DEFAULT_L_ANIMS: ", t2)
	z0.queue_free()
	await _ticks(2)

	# T3~T8: 변형 0~5 전부 로드 + 4종 애니메이션 보유 + 모델 1개
	var all_ok: bool = true
	for vi in range(Zombie.VARIANT_SCENES.size()):
		var z: Zombie = ZOMBIE_SCENE.instantiate()
		z.variant_index = vi
		w.add_child(z)
		z.global_position = Vector3(float(vi) * 2.0, 0.5, 0)
		await _ticks(3)
		var ap: AnimationPlayer = z.find_child("AnimationPlayer", true, false) as AnimationPlayer
		var ok: bool = ap != null and ap.has_animation("idle") and ap.has_animation("walk") \
			and ap.has_animation("attack-melee-right") and ap.has_animation("die") \
			and z.get_node("Model").get_child_count() == 1
		print("T%d_VARIANT_%d_ANIMS: " % [3 + vi, vi], ok)
		if not ok:
			all_ok = false
		z.queue_free()
		await _ticks(2)
	print("T9_ALL_VARIANTS_OK: ", all_ok)

	InventoryManager.reset_run()
	print("M78_SMOKE_DONE")
	get_tree().quit(0)
