class_name ItemData
extends Resource

enum Type { WEAPON, FOOD, MEDICAL, MATERIAL, KEY, VALUABLE }

@export var id := ""
@export var display_name := ""
@export var item_type: Type = Type.MATERIAL
@export var rarity := 0
@export var weight := 0.5
@export var max_stack := 10
@export_multiline var description := ""

@export_group("Weapon")
@export var damage := 0.0
@export var reach := 0.0
@export var arc_deg := 90.0
@export var max_targets := 1
@export var durability := 0
@export var attack_cooldown := 0.6

@export_group("Consumable")
@export var hunger_restore := 0.0
@export var thirst_restore := 0.0
@export var heal_amount := 0.0
@export var consume_time := 1.6


func is_weapon() -> bool:
	return damage > 0.0


func is_consumable() -> bool:
	if is_weapon():
		return false
	return hunger_restore > 0.0 or thirst_restore > 0.0 or heal_amount > 0.0


static func rarity_color(rarity: int) -> Color:
	match rarity:
		1: return Color(0.3, 0.8, 0.3)
		2: return Color(0.3, 0.5, 0.95)
		3: return Color(0.7, 0.4, 0.9)
		4: return Color(0.95, 0.6, 0.2)
	return Color(0.75, 0.75, 0.75)
