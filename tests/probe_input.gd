extends SceneTree


func _initialize() -> void:
	var log_path := "user://probe_input.log"
	var f := FileAccess.open(log_path, FileAccess.WRITE)
	var i := 0
	var pressed_reported := false
	var notified := {"count": 0}
	process_frame.connect(func() -> void:
		i += 1
		if i == 5:
			Input.action_press("move_up")
			Input.action_press("sprint")
		if i >= 6 and i <= 10:
			f.store_line("f%d up=%s sprint=%s vec=%s" % [i,
				str(Input.is_action_pressed("move_up")),
				str(Input.is_action_pressed("sprint")),
				str(Input.get_vector("move_left", "move_right", "move_up", "move_down"))])
		if i == 12:
			Input.release_pressed_events()
		if i == 14:
			f.store_line("after_release f%d up=%s sprint=%s" % [i,
				str(Input.is_action_pressed("move_up")),
				str(Input.is_action_pressed("sprint"))])
			f.flush()
		if i > 16:
			if not pressed_reported:
				pressed_reported = true
				print("PROBE_DONE notified=", notified["count"])
				f.store_line("done")
				f.flush()
			quit(0)
	)
