extends Node

signal scrap_changed(new_scrap: int)

const SAVE_PATH := "user://savegame.cfg"

var scrap: int = 0
var unlocked_perks: Array[String] = []
var best_extraction_value: int = 0
var run_active: bool = false


func add_scrap(amount: int) -> void:
	scrap += amount
	scrap_changed.emit(scrap)


func spend_scrap(amount: int) -> bool:
	if scrap < amount:
		return false
	scrap -= amount
	scrap_changed.emit(scrap)
	return true


func save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("meta", "scrap", scrap)
	cfg.set_value("meta", "unlocked_perks", unlocked_perks)
	cfg.set_value("meta", "best_extraction_value", best_extraction_value)
	cfg.save(SAVE_PATH)


func load_save() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return
	scrap = cfg.get_value("meta", "scrap", 0)
	unlocked_perks = cfg.get_value("meta", "unlocked_perks", [])
	best_extraction_value = cfg.get_value("meta", "best_extraction_value", 0)
