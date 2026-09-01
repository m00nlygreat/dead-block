class_name PickupModels
extends RefCounted

const SCENES := {
	"water": preload("res://assets/survival-kit/Models/GLB format/bottle.glb"),
	"drink_soda": preload("res://assets/food-kit/Models/GLB format/soda-can.glb"),
	"drink_booze": preload("res://assets/food-kit/Models/GLB format/wine-red.glb"),
	"food_canned": preload("res://assets/food-kit/Models/GLB format/can.glb"),
	"food_choco": preload("res://assets/food-kit/Models/GLB format/candy-bar.glb"),
	"scrap_metal": preload("res://assets/car-kit/Models/GLB format/debris-plate-a.glb"),
	"weapon_bat": preload("res://scenes/items/bat_model.tscn"),
	"weapon_kitchen_knife": preload("res://assets/food-kit/Models/GLB format/cooking-knife.glb"),
	"weapon_9mm": preload("res://scenes/items/pistol_model.tscn"),
}

const SCALES := {
	"water": 1.5,
	"drink_soda": 2.2,
	"drink_booze": 1.6,
	"food_canned": 2.2,
	"food_choco": 2.0,
	"scrap_metal": 1.3,
	"weapon_bat": 1.35,
	"weapon_kitchen_knife": 3.0,
	"weapon_9mm": 2.2,
}

const TILTS := {
	"weapon_bat": 90.0,
}


static func get_scene(id: String) -> PackedScene:
	return SCENES.get(id)


static func get_scale(id: String) -> float:
	return float(SCALES.get(id, 1.0))


static func get_tilt(id: String) -> float:
	return float(TILTS.get(id, 0.0))


static func has_model(id: String) -> bool:
	return SCENES.has(id)
