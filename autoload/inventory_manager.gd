extends Node

signal inventory_changed
signal item_gained(id: String, qty: int)
signal weapon_changed
signal hotbar_changed
signal selected_changed(index: int)

const MAX_SLOTS := 20
const MAX_WEIGHT := 40.0
const HOTBAR_SIZE := 8

var slots: Array = []
var quick_slots: Array = []
var equipped_weapon_id := ""
var equipped_durability := 0
var selected_slot := 0
var durabilities := {}


func _ready() -> void:
	slots.resize(MAX_SLOTS)
	quick_slots.resize(HOTBAR_SIZE)


func total_weight() -> float:
	var w := 0.0
	for s in slots:
		if s == null:
			continue
		var item = ItemDB.get_item(s["id"])
		if item != null:
			w += item.weight * s["qty"]
	return w


func add_item(id: String, qty: int = 1) -> int:
	var item = ItemDB.get_item(id)
	if item == null or qty <= 0:
		return 0
	var added := 0
	while added < qty:
		if total_weight() + item.weight > MAX_WEIGHT:
			break
		var stack_idx := _find_stackable(id, item.max_stack)
		if stack_idx != -1:
			slots[stack_idx]["qty"] += 1
		else:
			var empty_idx := _first_empty()
			if empty_idx == -1:
				break
			slots[empty_idx] = {"id": id, "qty": 1}
		added += 1
	if added > 0:
		inventory_changed.emit()
		item_gained.emit(id, added)
		_register_hotbar(id)
		if not durabilities.has(id):
			durabilities[id] = item.durability
		if item.is_weapon() and equipped_weapon_id == "":
			equip(id)
	return added


func _register_hotbar(id: String) -> void:
	if count_of(id) <= 0 or quick_slots.has(id):
		return
	for i in HOTBAR_SIZE:
		if quick_slots[i] == null:
			quick_slots[i] = id
			hotbar_changed.emit()
			return


func _unregister_if_empty(id: String) -> void:
	if count_of(id) > 0 or not quick_slots.has(id):
		return
	for i in HOTBAR_SIZE:
		if quick_slots[i] == id:
			quick_slots[i] = null
	durabilities.erase(id)
	hotbar_changed.emit()


func equip(id: String) -> void:
	var item = ItemDB.get_item(id)
	if item == null or not item.is_weapon():
		return
	if count_of(id) <= 0:
		return
	equipped_weapon_id = id
	equipped_durability = item.durability
	weapon_changed.emit()


func get_equipped_item():
	if equipped_weapon_id == "":
		return null
	return ItemDB.get_item(equipped_weapon_id)


func weapon_used() -> void:
	var item = get_equipped_item()
	if item == null:
		return
	equipped_durability -= 1
	if equipped_durability <= 0:
		remove_one_of(equipped_weapon_id)
		equipped_weapon_id = ""
		equipped_durability = 0
	weapon_changed.emit()


func use_durability(id: String) -> void:
	var item = ItemDB.get_item(id)
	if item == null or count_of(id) <= 0:
		return
	if item.durability <= 0:
		remove_one_of(id)
		return
	if not durabilities.has(id):
		durabilities[id] = item.durability
	var cur: int = int(durabilities[id]) - 1
	if cur <= 0:
		remove_one_of(id)
		if count_of(id) > 0:
			durabilities[id] = item.durability
		else:
			durabilities.erase(id)
	else:
		durabilities[id] = cur
	hotbar_changed.emit()


func get_current_durability(id: String) -> int:
	var item = ItemDB.get_item(id)
	if item == null or item.durability <= 0:
		return -1
	if item.is_weapon():
		return equipped_durability if equipped_weapon_id == id else item.durability
	if not durabilities.has(id):
		return item.durability
	return int(durabilities[id])


func remove_one_of(id: String) -> void:
	for i in MAX_SLOTS:
		var s = slots[i]
		if s != null and s["id"] == id:
			remove_at(i, 1)
			_unregister_if_empty(id)
			return


func set_selected(index: int) -> void:
	selected_slot = clampi(index, 0, HOTBAR_SIZE - 1)
	selected_changed.emit(selected_slot)
	var id = quick_slots[selected_slot]
	if id != null:
		var item = ItemDB.get_item(id)
		if item != null and item.is_weapon() and equipped_weapon_id != id:
			equip(id)


func cycle_selected(dir: int) -> void:
	set_selected(wrapi(selected_slot + dir, 0, HOTBAR_SIZE))


func get_selected_id() -> String:
	var id = quick_slots[selected_slot]
	return id if id != null else ""


func drop_selected() -> String:
	var id := get_selected_id()
	if id == "" or count_of(id) <= 0:
		return ""
	remove_one_of(id)
	return id


func remove_at(index: int, qty: int = 1) -> void:
	var s = slots[index]
	if s == null:
		return
	s["qty"] -= qty
	if s["qty"] <= 0:
		slots[index] = null
	inventory_changed.emit()


func count_of(id: String) -> int:
	var n := 0
	for s in slots:
		if s != null and s["id"] == id:
			n += s["qty"]
	return n


func clear_run_inventory() -> void:
	reset_run()


func reset_run() -> void:
	for i in MAX_SLOTS:
		slots[i] = null
	for i in HOTBAR_SIZE:
		quick_slots[i] = null
	equipped_weapon_id = ""
	equipped_durability = 0
	selected_slot = 0
	durabilities.clear()
	inventory_changed.emit()
	weapon_changed.emit()
	hotbar_changed.emit()
	selected_changed.emit(selected_slot)


func _find_stackable(id: String, max_stack: int) -> int:
	if max_stack <= 1:
		return -1
	for i in MAX_SLOTS:
		var s = slots[i]
		if s != null and s["id"] == id and s["qty"] < max_stack:
			return i
	return -1


func _first_empty() -> int:
	for i in MAX_SLOTS:
		if slots[i] == null:
			return i
	return -1
