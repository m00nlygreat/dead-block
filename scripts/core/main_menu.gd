extends Control

const STAGE_PATH := "res://scenes/core/stage1.tscn"


func _ready() -> void:
	$StartButton.pressed.connect(_start_game)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept"):
		_start_game()


func _start_game() -> void:
	set_process_unhandled_input(false)
	InventoryManager.reset_run()
	GameState.reset_run_state()
	GameState.run_active = true
	get_tree().change_scene_to_file(STAGE_PATH)
