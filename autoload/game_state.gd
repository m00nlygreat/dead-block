extends Node

signal scrap_changed(new_scrap: int)

const SAVE_PATH := "user://savegame.cfg"

var scrap: int = 0
var unlocked_perks: Array[String] = []
var best_extraction_value: int = 0
var run_active: bool = false

signal coins_changed(total: int)
var coins: int = 0

## 원거리 디스폰으로 놓친(미수집) 코인 누적 — 런 단위 기록용
signal missed_coins_changed(total: int)
var missed_coins: int = 0


func add_coins(amount: int) -> void:
	coins += amount
	coins_changed.emit(coins)


func add_missed_coins(amount: int) -> void:
	missed_coins += amount
	missed_coins_changed.emit(missed_coins)


func spend_coins(amount: int) -> bool:
	if coins < amount:
		return false
	coins -= amount
	coins_changed.emit(coins)
	return true


func reset_run_state() -> void:
	if coins != 0:
		coins = 0
		coins_changed.emit(coins)
	if missed_coins != 0:
		missed_coins = 0
		missed_coins_changed.emit(missed_coins)


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
