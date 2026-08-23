class_name LootTable
extends Resource

@export var entries: Array[LootEntry] = []
@export var roll_count_min := 1
@export var roll_count_max := 2


func roll() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if entries.is_empty():
		return out
	var n := randi_range(roll_count_min, roll_count_max)
	for i in n:
		var total := 0.0
		for e in entries:
			total += e.weight
		var pick := randf() * total
		for e in entries:
			pick -= e.weight
			if pick <= 0.0:
				out.append({
					"id": e.item_id,
					"qty": randi_range(e.qty_min, e.qty_max),
				})
				break
	return out
