extends Node

const PLAYER_SCENE := preload("res://scenes/player/player.tscn")
const HUD_SCENE := preload("res://scenes/ui/hud.tscn")


func _ready() -> void:
	_run()


func _ticks(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _run() -> void:
	var w := Node3D.new()
	add_child(w)
	var player := PLAYER_SCENE.instantiate()
	w.add_child(player)
	var hud := HUD_SCENE.instantiate()
	w.add_child(hud)
	await _ticks(5)

	InventoryManager.add_item("scrap_metal", 3)
	print("T1_MATERIAL_NOT_ON_HOTBAR: ", InventoryManager.count_of("scrap_metal") == 3 and not InventoryManager.quick_slots.has("scrap_metal"))
	print("T2_MATERIAL_LISTED: ", InventoryManager.get_material_ids().has("scrap_metal"))

	InventoryManager.add_item("gold_watch")
	InventoryManager.add_item("battery")
	var mats := InventoryManager.get_material_ids()
	print("T3_VALUABLE_AND_KEYLESS_EXCLUDED: ", mats.has("gold_watch") and mats.has("battery") and not InventoryManager.quick_slots.has("gold_watch"))

	InventoryManager.add_item("water")
	InventoryManager.add_item("weapon_bat")
	await _ticks(3)
	print("T4_USABLES_STILL_ON_HOTBAR: ", InventoryManager.quick_slots.has("water") and InventoryManager.quick_slots.has("weapon_bat"))

	print("T5_WEIGHT_STILL_COUNTS: ", InventoryManager.total_weight() > 1.0)
	await _ticks(3)
	print("T6_HUD_MATERIAL_LINE: ", hud._material_label.text.contains("고철") and hud._material_label.text.contains("금시계"))
	print("T7_HUD_COIN_ZERO: ", hud._coin_label.text.contains("0"))

	print("M50_SMOKE_DONE")
	get_tree().quit(0)
