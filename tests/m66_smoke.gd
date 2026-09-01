extends Node

## m66: 제작템 스폰 비중 검증.
## trash_common 룻 테이블에서
## - 제작 재료(scrap_metal·cloth) 총 weight가
##   소모품(food/water/drink) 총 weight보다 크고
## - 소모품 총 weight가 무기(weapon_*) 총 weight보다 크며
## - 제작 재료 총 weight가 무기 총 weight보다 충분히 커야 한다
## (제작템 우대 · 소모품/무기 감소 반영).

const LOOT := preload("res://resources/loot_tables/trash_common.tres")

const CRAFT_IDS := ["scrap_metal", "cloth"]
const CONSUMABLE_IDS := [
	"food_canned", "food_choco", "water",
	"drink_soda", "drink_booze", "bandage", "painkiller",
]
const WEAPON_PREFIX := "weapon_"


func _total_for(items: Array) -> float:
	var t := 0.0
	for e in LOOT.entries:
		if e.item_id in items:
			t += e.weight
	return t


func _total_weapons() -> float:
	var t := 0.0
	for e in LOOT.entries:
		if e.item_id.begins_with(WEAPON_PREFIX):
			t += e.weight
	return t


func _ready() -> void:
	var craft := _total_for(CRAFT_IDS)
	var consumable := _total_for(CONSUMABLE_IDS)
	var weapon := _total_weapons()
	print("CRAFT=%.1f CONSUMABLE=%.1f WEAPON=%.1f" % [craft, consumable, weapon])

	print("T1_CRAFT_GT_CONSUMABLE: ",
		craft > consumable,
		" (craft=%.1f consumable=%.1f)" % [craft, consumable])
	print("T2_CONSUMABLE_GT_WEAPON: ",
		consumable > weapon,
		" (consumable=%.1f weapon=%.1f)" % [consumable, weapon])
	print("T3_CRAFT_GT_WEAPON_SIGNIFICANTLY: ",
		craft > weapon * 5.0,
		" (craft=%.1f weapon=%.1f)" % [craft, weapon])
	print("T4_NO_CONSUMABLE_OR_WEAPON_DOMINANCE: ",
		craft > consumable + weapon,
		" (craft=%.1f sum=%.1f)" % [craft, consumable + weapon])
	print("M66_SMOKE_DONE")
	get_tree().quit(0)
