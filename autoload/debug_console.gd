extends CanvasLayer

## 디버그 콘솔 — 게임 파라미터 지원.
## 활성화: `godot --debug-console --skip-menu` (엔진 소비 없이 그대로 전달됨)
## `/` 키로 콘솔 토글. 플래그명은 Godot 엔진이 소비하지 않는 이름을 사용한다.

var enabled := false
var _open := false
var _output: RichTextLabel
var _console_input: LineEdit
var _hint: Label
var _panel: PanelContainer
var _history: Array[String] = []
var _history_idx := -1
var _fps_label: Label
var _commands: Dictionary = {}
var _cmd_descs: Dictionary = {}


func _ready() -> void:
	layer = 100
	_check_debug_args()
	_build_ui()
	_register_commands()
	visible = false
	if enabled:
		_show_fps_badge()
	process_mode = Node.PROCESS_MODE_ALWAYS


func _check_debug_args() -> void:
	var all := OS.get_cmdline_args() + OS.get_cmdline_user_args()
	if "--debug-console" in all or "--console" in all or "--debug" in all:
		enabled = true


func _build_ui() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	_panel = PanelContainer.new()
	_panel.visible = false
	_panel.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_panel.offset_top = -340.0
	_panel.offset_bottom = -4.0
	_panel.offset_left = 4.0
	_panel.offset_right = -4.0
	var ps := StyleBoxFlat.new()
	ps.bg_color = Color(0.04, 0.04, 0.08, 0.92)
	ps.set_border_width_all(1)
	ps.border_color = Color(0.3, 0.6, 0.35, 0.7)
	ps.set_corner_radius_all(4)
	ps.set_content_margin_all(8)
	_panel.add_theme_stylebox_override("panel", ps)
	root.add_child(_panel)

	var vb := VBoxContainer.new()
	vb.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_panel.add_child(vb)

	_output = RichTextLabel.new()
	_output.bbcode_enabled = true
	_output.scroll_following = true
	_output.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_output.add_theme_color_override("default_color", Color(0.85, 0.88, 0.85))
	_output.add_theme_font_size_override("normal_font_size", 14)
	_output.text = _build_help_text()
	vb.add_child(_output)

	var sep := HSeparator.new()
	vb.add_child(sep)

	_console_input = LineEdit.new()
	_console_input.placeholder_text = "명령어 입력... (Tab: 자동완성, ↑↓: 히스토리)"
	_console_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var is2 := StyleBoxFlat.new()
	is2.bg_color = Color(0.08, 0.08, 0.14, 0.95)
	is2.set_border_width_all(1)
	is2.border_color = Color(0.3, 0.55, 0.35, 0.6)
	is2.set_corner_radius_all(3)
	is2.set_content_margin_all(6)
	_console_input.add_theme_stylebox_override("normal", is2)
	var ifs := StyleBoxFlat.new()
	ifs.bg_color = Color(0.12, 0.12, 0.2, 1.0)
	ifs.set_border_width_all(2)
	ifs.border_color = Color(0.4, 0.85, 0.45, 0.9)
	ifs.set_corner_radius_all(3)
	ifs.set_content_margin_all(6)
	_console_input.add_theme_stylebox_override("focus", ifs)
	_console_input.add_theme_color_override("font_color", Color(0.9, 0.92, 0.9))
	_console_input.add_theme_font_size_override("font_size", 15)
	vb.add_child(_console_input)

	_hint = Label.new()
	_hint.visible = false
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.offset_top = 8.0
	_hint.offset_bottom = 28.0
	_hint.offset_left = 200.0
	_hint.offset_right = -200.0
	_hint.add_theme_font_size_override("font_size", 13)
	_hint.add_theme_color_override("font_color", Color(0.7, 0.9, 0.7, 0.85))
	root.add_child(_hint)

	_fps_label = Label.new()
	_fps_label.visible = false
	_fps_label.anchor_left = 1.0
	_fps_label.anchor_top = 0.0
	_fps_label.anchor_right = 1.0
	_fps_label.offset_left = -140.0
	_fps_label.offset_top = 6.0
	_fps_label.offset_right = -8.0
	_fps_label.offset_bottom = 26.0
	_fps_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_fps_label.add_theme_font_size_override("font_size", 13)
	_fps_label.add_theme_color_override("font_color", Color(0.4, 0.9, 0.45, 0.75))
	root.add_child(_fps_label)

	_console_input.text_submitted.connect(_on_submit)
	_console_input.gui_input.connect(_on_input_gui)
	_console_input.text_changed.connect(_on_text_changed)


func _process(_delta: float) -> void:
	if enabled and _fps_label.visible:
		_fps_label.text = "FPS %d" % Engine.get_frames_per_second()


func _show_fps_badge() -> void:
	_fps_label.visible = true


func _input(event: InputEvent) -> void:
	if not enabled:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var k: int = event.keycode
		if _open:
			if k == KEY_ESCAPE:
				_close_console()
				get_viewport().set_input_as_handled()
			return
		if k == KEY_SLASH:
			_open_console()
			get_viewport().set_input_as_handled()


func _open_console() -> void:
	_open = true
	visible = true
	_panel.visible = true
	_console_input.text = ""
	_console_input.grab_focus.call_deferred()
	_output.scroll_to_line(_output.get_line_count())


func _close_console() -> void:
	_open = false
	_panel.visible = false
	_console_input.release_focus()


func _on_submit(text: String) -> void:
	var t := text.strip_edges()
	_console_input.text = ""
	if t.is_empty():
		return
	_history.append(t)
	_history_idx = _history.size()
	_print_line("> " + t, Color(0.95, 0.95, 0.95))
	_execute(t)


func _on_input_gui(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_TAB:
			_autocomplete()
			_console_input.accept_event()
		elif event.keycode == KEY_UP:
			_navigate_history(-1)
			_console_input.accept_event()
		elif event.keycode == KEY_DOWN:
			_navigate_history(1)
			_console_input.accept_event()


func _on_text_changed(_new_text: String) -> void:
	_hint.visible = false


func _navigate_history(dir: int) -> void:
	if _history.is_empty():
		return
	var new_idx := _history_idx + dir
	new_idx = clampi(new_idx, 0, _history.size())
	_history_idx = new_idx
	if new_idx < _history.size():
		_console_input.text = _history[new_idx]
	else:
		_console_input.text = ""
	_console_input.caret_column = _console_input.text.length()


func _autocomplete() -> void:
	var partial := _console_input.text.strip_edges()
	if partial.is_empty():
		_print_line("명령어: " + " ".join(_commands.keys()), Color(0.6, 0.85, 0.6))
		return
	var matches: Array[String] = []
	for cmd_name in _commands:
		if cmd_name.begins_with(partial):
			matches.append(cmd_name)
	if matches.size() == 1:
		_console_input.text = matches[0] + " "
		_console_input.caret_column = _console_input.text.length()
		_hint.visible = false
	elif matches.size() > 1:
		_print_line("후보: " + " ".join(matches), Color(0.6, 0.85, 0.6))
	else:
		_hint.text = "일치하는 명령어 없음"
		_hint.visible = true


func _execute(text: String) -> void:
	var parts := text.split(" ", false)
	if parts.is_empty():
		return
	var cmd := parts[0].to_lower()
	if not _commands.has(cmd):
		_print_line("알 수 없는 명령어: %s — help로 목록 확인" % cmd, Color(1.0, 0.5, 0.5))
		return
	var result: String = _commands[cmd].call(parts)
	if not result.is_empty():
		_print_line(result, Color(0.75, 0.9, 0.75))


func _print_line(text: String, color := Color.WHITE) -> void:
	var escaped := text.replace("[", "[lb]").replace("]", "[rb]")
	_output.append_text("[color=%s]%s[/color]\n" % [color.to_html(false), escaped])


func _build_help_text() -> String:
	var lines: PackedStringArray = [
		"╔══════════════════════════════════════╗",
		"║       DEAD BLOCK · 디버그 콘솔       ║",
		"╚══════════════════════════════════════╝",
		"",
		"도움말: help          자동완성: Tab",
		"히스토리: ↑ ↓         닫기: ESC",
		"",
	]
	for cmd_name in _commands:
		var desc: String = _cmd_descs.get(cmd_name, "")
		lines.append("  %-12s %s" % [cmd_name, desc])
	lines.append("")
	lines.append("══════════════════════════════════════")
	return "\n".join(lines)


func _register_commands() -> void:
	_cmd("help", "도움말 표시", _cmd_help)
	_cmd("clear", "출력 초기화", _cmd_clear)
	_cmd("fps", "FPS 정보 (현재/평균)", _cmd_fps)
	_cmd("pos", "플레이어 좌표", _cmd_pos)
	_cmd("hp", "체력 상태", _cmd_hp)
	_cmd("heal", "체력 회복 [수치]", _cmd_heal)
	_cmd("damage", "체력 감소 [수치]", _cmd_damage)
	_cmd("give", "아이템 지급 [id] [수량]", _cmd_give)
	_cmd("coins", "코인 추가 [수치]", _cmd_coins)
	_cmd("scrap", "스크랩 추가 [수치]", _cmd_scrap)
	_cmd("god", "무적 모드 토글", _cmd_god)
	_cmd("speed", "이동속도 배율 [배율]", _cmd_speed)
	_cmd("kills", "처치 수 설정 [수치]", _cmd_kills)
	_cmd("zombie", "좀비 스폰 [n]", _cmd_zombie)
	_cmd("scene", "씬 목록 / 재시작", _cmd_scene)
	_cmd("reload", "런 초기화 후 재시작", _cmd_reload)
	_cmd("physics", "물리 콜라이더 토글", _cmd_physics)
	_cmd("items", "아이템 DB 전체 목록", _cmd_items)


func _cmd(cmd_name: String, desc: String, callable: Callable) -> void:
	_commands[cmd_name] = callable
	_cmd_descs[cmd_name] = desc


# ─────────────────── 명령어 구현 ───────────────────

func _cmd_help(_args: Array) -> String:
	return _build_help_text()


func _cmd_clear(_args: Array) -> String:
	_output.clear()
	return ""


func _cmd_fps(_args: Array) -> String:
	var fps := Performance.get_monitor(Performance.TIME_FPS)
	var p_frame := Performance.get_monitor(Performance.TIME_PROCESS)
	return "FPS: %.0f  |  프레임 처리: %.2fms" % [fps, p_frame]


func _cmd_pos(_args: Array) -> String:
	var p := _find_player()
	if p == null:
		return "플레이어 없음"
	return "pos: (%.2f, %.2f, %.2f)" % [p.global_position.x, p.global_position.y, p.global_position.z]


func _cmd_hp(_args: Array) -> String:
	var p := _find_player()
	if p == null:
		return "플레이어 없음"
	return "HP %.0f/%.0f  스태미나 %.0f/%.0f  허기 %.0f/%.0f  갈증 %.0f/%.0f" % [
		p.hp, p.max_hp, p.stamina, p.max_stamina, p.hunger, p.max_hunger, p.thirst, p.max_thirst]


func _cmd_heal(args: Array) -> String:
	var p := _find_player()
	if p == null:
		return "플레이어 없음"
	var amount := 9999.0
	if args.size() > 1:
		amount = float(args[1])
	p.heal(amount)
	return "heal +%.0f → HP %.0f/%.0f" % [amount, p.hp, p.max_hp]


func _cmd_damage(args: Array) -> String:
	var p := _find_player()
	if p == null:
		return "플레이어 없음"
	var amount := 10.0
	if args.size() > 1:
		amount = float(args[1])
	p.take_damage(amount)
	return "damage -%.0f → HP %.0f/%.0f" % [amount, p.hp, p.max_hp]


func _cmd_give(args: Array) -> String:
	if args.size() < 2:
		return "사용법: give <item_id> [수량]\n아이템 ID는 items 명령어로 확인"
	var item_id: String = args[1]
	var qty := 1
	if args.size() > 2:
		qty = int(args[2])
	if qty <= 0:
		qty = 1
	var added := InventoryManager.add_item(item_id, qty)
	if added <= 0:
		return "지급 실패 (무게 초과 또는 ID 오류): %s" % item_id
	var item = ItemDB.get_item(item_id)
	var disp_name: String = item_id if item == null else item.display_name
	return "지급: %s ×%d (총 %d)" % [disp_name, added, InventoryManager.count_of(item_id)]


func _cmd_coins(args: Array) -> String:
	if args.size() < 2:
		return "현재 코인: %d" % GameState.coins
	var amount := int(args[1])
	GameState.add_coins(amount)
	return "코인 +%d → %d" % [amount, GameState.coins]


func _cmd_scrap(args: Array) -> String:
	if args.size() < 2:
		return "현재 스크랩: %d" % GameState.scrap
	var amount := int(args[1])
	GameState.add_scrap(amount)
	return "스크랩 +%d → %d" % [amount, GameState.scrap]


func _cmd_god(_args: Array) -> String:
	var p := _find_player()
	if p == null:
		return "플레이어 없음"
	var god_on: bool = p._invuln > 100.0
	p._invuln = 1.0e9 if not god_on else 0.0
	return "무적: %s" % ("ON" if not god_on else "OFF")


func _cmd_speed(args: Array) -> String:
	var p := _find_player()
	if p == null:
		return "플레이어 없음"
	if args.size() < 2:
		return "이동속도 배율: %.2f" % p.move_speed_mult
	var mult: float = float(args[1]) if String(args[1]).is_valid_float() else 1.0
	mult = clampf(mult, 0.1, 10.0)
	p.move_speed_mult = mult
	return "이동속도 배율 → %.2f" % mult


func _cmd_kills(args: Array) -> String:
	if args.size() < 2:
		return "현재 처치 수: %d" % UpgradeManager.kills
	var amount := int(args[1])
	UpgradeManager.kills = amount
	UpgradeManager.kills_changed.emit(amount)
	return "처치 수 → %d" % amount


func _cmd_zombie(args: Array) -> String:
	var p := _find_player()
	if p == null:
		return "플레이어 없음"
	var n := 1
	if args.size() > 1:
		n = maxi(int(args[1]), 1)
	n = mini(n, 10)
	var zsc: PackedScene = preload("res://scenes/zombie/zombie.tscn")
	var spawned := 0
	for i in n:
		var z := zsc.instantiate()
		z.variant_index = randi_range(-1, Zombie.VARIANT_SCENES.size() - 1)
		var ang := randf() * TAU
		var dist := randf_range(4.0, 8.0)
		z.global_position = p.global_position + Vector3(cos(ang) * dist, 0.0, sin(ang) * dist)
		p.get_parent().add_child(z)
		spawned += 1
	return "좀비 %d마리 스폰" % spawned


func _cmd_scene(args: Array) -> String:
	if args.size() > 1 and args[1] == "restart":
		get_tree().reload_current_scene()
		return "씬 재시작 중..."
	var result := "현재 씬: %s\n" % get_tree().current_scene.scene_file_path
	result += "사용법: scene restart"
	return result


func _cmd_reload(_args: Array) -> String:
	InventoryManager.reset_run()
	GameState.reset_run_state()
	UpgradeManager.reset_run()
	get_tree().reload_current_scene()
	return "런 초기화 후 재시작 중..."


func _cmd_physics(_args: Array) -> String:
	get_tree().debug_collisions_hint = not get_tree().debug_collisions_hint
	return "물리 콜라이더 표시: %s" % ("ON" if get_tree().debug_collisions_hint else "OFF")


func _cmd_items(_args: Array) -> String:
	var all := ItemDB.all_items()
	if all.is_empty():
		return "아이템 없음"
	var lines: PackedStringArray = ["아이템 DB (%d개):" % all.size(), ""]
	for item in all:
		var tags: PackedStringArray = []
		if item.is_weapon():
			tags.append("무기")
		if item.is_consumable():
			tags.append("소비")
		var tag_str := " [%s]" % ", ".join(tags) if tags.size() > 0 else ""
		lines.append("  %-28s %s  (중량 %.1f)" % [item.id, item.display_name + tag_str, item.weight])
	return "\n".join(lines)


func _find_player() -> Node:
	return get_tree().get_first_node_in_group("player")
