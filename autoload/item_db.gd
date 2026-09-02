extends Node

const ITEM_DIR := "res://resources/items/"

var _items: Dictionary = {}


func _ready() -> void:
	reload_items()


func reload_items() -> void:
	_items.clear()
	if not DirAccess.dir_exists_absolute(ITEM_DIR):
		return
	for f in DirAccess.get_files_at(ITEM_DIR):
		## 익스포트(웹 포함)에서는 파일명이 .tres.remap으로 저장되므로 원래 경로로 복원한다.
		var base := f.trim_suffix(".remap") if f.ends_with(".remap") else f
		if not base.ends_with(".tres") and not base.ends_with(".res"):
			continue
		var res = load(ITEM_DIR + base)
		if res != null and "id" in res:
			_items[res.id] = res


func get_item(id: String):
	if _items.has(id):
		return _items[id]
	return null


func all_items() -> Array:
	return _items.values()
