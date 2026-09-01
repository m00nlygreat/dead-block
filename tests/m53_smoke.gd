extends Node

const PICKUP_SCENE := preload("res://scenes/items/item_pickup.tscn")
const CAR_SCENE := preload("res://scenes/world/car_trunk.tscn")
const ZOMBIE_SCENE := preload("res://scenes/zombie/zombie.tscn")
const TRASH_LOOT := preload("res://resources/loot_tables/trash_common.tres")

const MODELED_ITEMS := [
	"water", "drink_soda", "drink_booze", "food_canned", "food_choco",
	"scrap_metal", "weapon_bat",
]


func _ready() -> void:
	_run()


func _ticks(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _run() -> void:
	var w := Node3D.new()
	add_child(w)

	var all_mapped := true
	for id in MODELED_ITEMS:
		if not PickupModels.has_model(id) or PickupModels.get_scene(id) == null:
			all_mapped = false
	print("T1_PICKUP_MODELS_MAPPED: ", all_mapped, " (%d ids)" % MODELED_ITEMS.size())

	var pk := PICKUP_SCENE.instantiate()
	pk.item_id = "water"
	w.add_child(pk)
	await _ticks(2)
	var vis := pk.get_node_or_null("Visual")
	print("T2_PICKUP_USES_MODEL: ", vis != null and not pk.get_node("Mesh").visible
		and vis.get_child_count() > 0)

	var pk2 := PICKUP_SCENE.instantiate()
	pk2.item_id = "painkiller"
	w.add_child(pk2)
	await _ticks(2)
	var mesh2: MeshInstance3D = pk2.get_node("Mesh")
	print("T3_FALLBACK_TINTED_BOX: ", pk2.get_node_or_null("Visual") == null
		and mesh2.visible and mesh2.material_override != null)

	var trash_ids: Array = []
	for e in TRASH_LOOT.entries:
		trash_ids.append(e.item_id)
	var removed_gone := not trash_ids.has("weapon_axe") \
		and not trash_ids.has("weapon_shovel") \
		and not trash_ids.has("weapon_hammer") \
		and not trash_ids.has("weapon_pickaxe")
	print("T4_TRASH_HAS_NO_REMOVED_WEAPONS: ", removed_gone)

	var bodies_seen := {}
	var len_ok := true
	for i in 16:
		var car := CAR_SCENE.instantiate()
		car.loot_table = TRASH_LOOT
		w.add_child(car)
		car.global_position = Vector3(-6.0 + i * 1.2, 0, -6)
		bodies_seen[car.last_body_index] = true
		var sz: Vector3 = car.get_node("Shape").shape.size
		if sz.z < 2.8 or sz.z > 3.9 or sz.x < 1.5:
			len_ok = false
		var meshes := car.find_children("*", "MeshInstance3D", true, false)
		if meshes.is_empty():
			len_ok = false
	print("T9_CAR_BODIES_VARY_AND_FIT: ", bodies_seen.size() >= 4 and len_ok,
		" (distinct=%d)" % bodies_seen.size())

	var z := ZOMBIE_SCENE.instantiate()
	z.variant_index = 0
	w.add_child(z)
	z.global_position = Vector3(0, 0.5, 0)
	await _ticks(3)
	var ap := z.find_child("AnimationPlayer", true, false)
	var model_children: int = z.get_node("Model").get_child_count()
	print("T10_ZOMBIE_VARIANT_ANIMS: ", ap != null and ap.has_animation("idle")
		and ap.has_animation("walk") and model_children == 1)

	var z2 := ZOMBIE_SCENE.instantiate()
	z2.variant_index = -1
	w.add_child(z2)
	z2.global_position = Vector3(2, 0.5, 0)
	await _ticks(2)
	print("T11_ZOMBIE_DEFAULT_KEPT: ", z2.get_node("Model").get_child_count() == 1)

	InventoryManager.reset_run()
	print("M53_SMOKE_DONE")
	get_tree().quit(0)
