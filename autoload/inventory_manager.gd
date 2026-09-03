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


func add_item(id: String, qty: int = 1, initial_durability := -1) -> int:
	var item = ItemDB.get_item(id)
	if item == null or qty <= 0:
		return 0
	## 원거리 무기: 이미 보유 중이면 새 슬롯 대신 장탄수를 최대치로 보충.
	if item.is_ranged and count_of(id) > 0:
		_refill_magazine(id)
		return qty
	var added := 0
	var is_wpn: bool = item.is_weapon()
	while added < qty:
		if total_weight() + item.weight > MAX_WEIGHT:
			break
		## 무기(장비)는 슬롯에 겹치지 않는다 — 내구도가 슬롯별로 독립돼야 하므로.
		var stack_idx := -1 if is_wpn else _find_stackable(id, item.max_stack)
		if stack_idx != -1:
			slots[stack_idx]["qty"] += 1
		else:
			var empty_idx := _first_empty()
			if empty_idx == -1:
				break
			var start_dur: int = item.durability
			if initial_durability >= 0:
				start_dur = mini(initial_durability, item.durability)
			slots[empty_idx] = {"id": id, "qty": 1, "durability": start_dur}
		added += 1
	if added > 0:
		inventory_changed.emit()
		item_gained.emit(id, added)
		_register_hotbar(id)
		_sync_equipped_with_selection()
	return added


func is_hotbar_item(item) -> bool:
	return item != null and (item.is_weapon() or item.is_consumable())


func get_material_ids() -> Array:
	var out: Array = []
	for s in slots:
		if s == null or out.has(s["id"]):
			continue
		var it = ItemDB.get_item(s["id"])
		if not is_hotbar_item(it):
			out.append(s["id"])
	return out


func _register_hotbar(id: String) -> void:
	if not is_hotbar_item(ItemDB.get_item(id)):
		return
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
	hotbar_changed.emit()


func equip(id: String) -> void:
	var item = ItemDB.get_item(id)
	if item == null or not item.is_weapon():
		return
	if count_of(id) <= 0:
		return
	equipped_weapon_id = id
	var slot_idx := _find_first_slot_of(id)
	if slot_idx != -1:
		equipped_durability = slots[slot_idx]["durability"]
	else:
		equipped_durability = item.durability
	weapon_changed.emit()


func unequip() -> void:
	if equipped_weapon_id == "":
		return
	equipped_weapon_id = ""
	equipped_durability = 0
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
	var slot_idx := _find_first_slot_of(equipped_weapon_id)
	if slot_idx != -1:
		slots[slot_idx]["durability"] = equipped_durability
	if equipped_durability <= 0:
		if item.is_ranged:
			## 원거리 무기는 0발이 돼도 파손되지 않고 유지(장전 대기).
			equipped_durability = 0
			if slot_idx != -1:
				slots[slot_idx]["durability"] = 0
			weapon_changed.emit()
		else:
			remove_one_of(equipped_weapon_id)
			if count_of(equipped_weapon_id) > 0:
				var new_idx := _find_first_slot_of(equipped_weapon_id)
				if new_idx != -1:
					slots[new_idx]["durability"] = item.durability
				equipped_durability = item.durability
	else:
		weapon_changed.emit()


## 원거리 무기의 장탄수(내구도)를 최대치로 보충. 이미 보유 시 새 슬롯 없음.
func _refill_magazine(id: String) -> void:
	if not count_of(id):
		return
	var item = ItemDB.get_item(id)
	if item == null or not item.is_ranged:
		return
	var slot_idx := _find_first_slot_of(id)
	if slot_idx != -1:
		slots[slot_idx]["durability"] = item.durability
	if equipped_weapon_id == id:
		equipped_durability = item.durability
	_register_hotbar(id)
	inventory_changed.emit()
	weapon_changed.emit()
	hotbar_changed.emit()


## 공개: 보유 중인 원거리 무기의 장탄수를 최대치로 보충(상점 구매 등).
func refill_magazine(id: String) -> void:
	_refill_magazine(id)


func use_durability(id: String) -> void:
	var item = ItemDB.get_item(id)
	if item == null or count_of(id) <= 0:
		return
	if item.durability <= 0:
		remove_one_of(id)
		return
	var slot_idx := _find_first_slot_of(id)
	if slot_idx == -1:
		return
	var cur: int = slots[slot_idx]["durability"] - 1
	if cur <= 0:
		remove_one_of(id)
		if count_of(id) > 0:
			var new_idx := _find_first_slot_of(id)
			if new_idx != -1:
				slots[new_idx]["durability"] = item.durability
	else:
		slots[slot_idx]["durability"] = cur
	hotbar_changed.emit()


func get_current_durability(id: String) -> int:
	var item = ItemDB.get_item(id)
	if item == null or item.durability <= 0:
		return -1
	if equipped_weapon_id == id:
		return equipped_durability
	var slot_idx := _find_first_slot_of(id)
	if slot_idx != -1:
		return slots[slot_idx]["durability"]
	return item.durability


func remove_one_of(id: String) -> void:
	for i in MAX_SLOTS:
		var s = slots[i]
		if s != null and s["id"] == id:
			remove_at(i, 1)
			_unregister_if_empty(id)
			break
	if id == equipped_weapon_id and count_of(id) <= 0:
		unequip()


func set_selected(index: int) -> void:
	selected_slot = clampi(index, 0, HOTBAR_SIZE - 1)
	selected_changed.emit(selected_slot)
	_sync_equipped_with_selection()


func _sync_equipped_with_selection() -> void:
	var id := get_selected_id()
	if id != "":
		var item = ItemDB.get_item(id)
		if item != null and item.is_weapon() and count_of(id) > 0:
			if equipped_weapon_id != id:
				equip(id)
			return
	unequip()


func cycle_selected(dir: int) -> void:
	set_selected(wrapi(selected_slot + dir, 0, HOTBAR_SIZE))


func get_selected_id() -> String:
	var id = quick_slots[selected_slot]
	return id if id != null else ""


func drop_selected_data() -> Dictionary:
	var id := get_selected_id()
	if id == "" or count_of(id) <= 0:
		return {}
	var left := get_current_durability(id)
	remove_one_of(id)
	return {"id": id, "qty": 1, "durability": left}


func drop_selected() -> String:
	return String(drop_selected_data().get("id", ""))


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
	inventory_changed.emit()
	weapon_changed.emit()
	hotbar_changed.emit()
	selected_changed.emit(selected_slot)


func _find_first_slot_of(id: String) -> int:
	for i in MAX_SLOTS:
		var s = slots[i]
		if s != null and s["id"] == id:
			return i
	return -1


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
