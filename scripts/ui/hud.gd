extends CanvasLayer

const SLOT_COUNT := 20
const HEAD_OFFSET := 2.15
const BAR_GAP := 6.0
const TOAST_HEAD_OFFSET := 2.6

var _player: Node = null
var _hp_connected := false
var _slot_labels: Array = []
var _hotbar_panels: Array = []
var _game_over := false
var _slot_sb_normal: StyleBoxFlat
var _slot_sb_selected: StyleBoxFlat
var _coin_label: Label
var _material_label: Label
var _kill_label: Label

var _floating_toasts: Array = []

@onready var _prompt: Label = $Root/Prompt
@onready var _bar: ProgressBar = $Root/SearchBar
@onready var _use_bar: ProgressBar = $Root/UseBar
@onready var _hp_bar: ProgressBar = $Root/HealthBar
@onready var _stamina_bar: ProgressBar = $Root/StaminaBar
@onready var _hunger_bar: ProgressBar = $Root/HungerBar
@onready var _thirst_bar: ProgressBar = $Root/ThirstBar
@onready var _weapon_label: Label = $Root/WeaponLabel
@onready var _weight_label: Label = $Root/WeightLabel
@onready var _panel: Panel = $Root/InvPanel
@onready var _grid: GridContainer = $Root/InvPanel/Grid
@onready var _hotbar: HBoxContainer = $Root/Hotbar
@onready var _go_root: ColorRect = $Root/GameOverRoot
@onready var _item_info_panel: Panel = $Root/ItemInfoPanel


func _ready() -> void:
	_slot_sb_normal = StyleBoxFlat.new()
	_slot_sb_normal.bg_color = Color(0.12, 0.12, 0.15, 0.85)
	_slot_sb_normal.set_corner_radius_all(6)
	_slot_sb_normal.set_border_width_all(2)
	_slot_sb_normal.border_color = Color(0.38, 0.38, 0.44)
	_slot_sb_selected = StyleBoxFlat.new()
	_slot_sb_selected.bg_color = Color(0.30, 0.24, 0.06, 0.95)
	_slot_sb_selected.set_corner_radius_all(6)
	_slot_sb_selected.set_border_width_all(3)
	_slot_sb_selected.border_color = Color(1.0, 0.85, 0.3)
	for i in SLOT_COUNT:
		var l := Label.new()
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.custom_minimum_size = Vector2(120, 34)
		_grid.add_child(l)
		_slot_labels.append(l)
	for i in InventoryManager.HOTBAR_SIZE:
		var p := Panel.new()
		p.custom_minimum_size = Vector2(60, 60)
		p.add_theme_stylebox_override("panel", _slot_sb_normal)
		var num := Label.new()
		num.text = str(i + 1)
		num.position = Vector2(4, 1)
		num.add_theme_font_size_override("font_size", 11)
		p.add_child(num)
		var name_label := Label.new()
		name_label.position = Vector2(2, 17)
		name_label.custom_minimum_size = Vector2(56, 20)
		name_label.clip_text = true
		name_label.add_theme_font_size_override("font_size", 12)
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		p.add_child(name_label)
		var count_label := Label.new()
		count_label.position = Vector2(30, 37)
		count_label.custom_minimum_size = Vector2(28, 14)
		count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		count_label.add_theme_font_size_override("font_size", 13)
		p.add_child(count_label)
		var dur_bar := ProgressBar.new()
		dur_bar.position = Vector2(3, 53)
		dur_bar.custom_minimum_size = Vector2(54, 5)
		dur_bar.show_percentage = false
		dur_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var bg := StyleBoxFlat.new()
		bg.bg_color = Color(0.1, 0.1, 0.1, 0.65)
		bg.set_corner_radius_all(2)
		dur_bar.add_theme_stylebox_override("background", bg)
		p.add_child(dur_bar)
		_hotbar.add_child(p)
		_hotbar_panels.append(p)
	InventoryManager.inventory_changed.connect(_refresh_inventory)
	InventoryManager.inventory_changed.connect(_refresh_materials)
	InventoryManager.item_gained.connect(_on_item_gained)
	InventoryManager.container_searched_empty.connect(_on_container_empty)
	InventoryManager.weapon_changed.connect(_refresh_weapon)
	InventoryManager.hotbar_changed.connect(_refresh_hotbar)
	InventoryManager.selected_changed.connect(func(_i: int) -> void: _refresh_hotbar())
	GameState.coins_changed.connect(_on_coins_changed)
	_coin_label = Label.new()
	_coin_label.position = Vector2(20, 14)
	_coin_label.add_theme_font_size_override("font_size", 28)
	_coin_label.self_modulate = Color(1.0, 0.85, 0.35)
	$Root.add_child(_coin_label)
	_material_label = Label.new()
	_material_label.anchor_top = 1.0
	_material_label.anchor_bottom = 1.0
	_material_label.offset_left = 20
	_material_label.offset_right = 900
	_material_label.offset_top = -222
	_material_label.offset_bottom = -192
	_material_label.add_theme_font_size_override("font_size", 18)
	_material_label.self_modulate = Color(0.8, 0.85, 1.0)
	$Root.add_child(_material_label)
	_add_bar_label(_hunger_bar, "허기")
	_add_bar_label(_thirst_bar, "갈증")
	_build_kill_display()
	UpgradeManager.kills_changed.connect(_on_kills_changed)
	GameState.coins_changed.connect(func(_c: int) -> void: _on_kills_changed(UpgradeManager.kills))
	_on_kills_changed(UpgradeManager.kills)
	_refresh_inventory()
	_refresh_weapon()
	_refresh_hotbar()
	_on_coins_changed(GameState.coins)
	_refresh_materials()
	_init_item_info_panel()


func _build_kill_display() -> void:
	_kill_label = Label.new()
	_kill_label.anchor_left = 0.5
	_kill_label.anchor_right = 0.5
	_kill_label.offset_left = -320.0
	_kill_label.offset_right = 320.0
	_kill_label.offset_top = 12.0
	_kill_label.offset_bottom = 44.0
	_kill_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_kill_label.add_theme_font_size_override("font_size", 24)
	$Root.add_child(_kill_label)


func _init_item_info_panel() -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.08, 0.1, 0.9)
	sb.set_corner_radius_all(8)
	sb.set_border_width_all(2)
	sb.border_color = Color(0.3, 0.3, 0.35)
	_item_info_panel.add_theme_stylebox_override("panel", sb)
	_item_info_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var name_label := Label.new()
	name_label.name = "NameLabel"
	name_label.position = Vector2(10, 8)
	name_label.custom_minimum_size = Vector2(260, 24)
	name_label.add_theme_font_size_override("font_size", 18)
	_item_info_panel.add_child(name_label)

	var type_label := Label.new()
	type_label.name = "TypeLabel"
	type_label.position = Vector2(10, 34)
	type_label.custom_minimum_size = Vector2(260, 18)
	type_label.add_theme_font_size_override("font_size", 13)
	type_label.self_modulate = Color(0.7, 0.75, 0.85)
	_item_info_panel.add_child(type_label)

	var desc_label := Label.new()
	desc_label.name = "DescLabel"
	desc_label.position = Vector2(10, 56)
	desc_label.custom_minimum_size = Vector2(260, 60)
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_label.add_theme_font_size_override("font_size", 13)
	desc_label.self_modulate = Color(0.8, 0.8, 0.85)
	_item_info_panel.add_child(desc_label)

	var qty_label := Label.new()
	qty_label.name = "QtyLabel"
	qty_label.position = Vector2(10, 120)
	qty_label.custom_minimum_size = Vector2(260, 18)
	qty_label.add_theme_font_size_override("font_size", 14)
	_item_info_panel.add_child(qty_label)

	var dur_label := Label.new()
	dur_label.name = "DurLabel"
	dur_label.position = Vector2(10, 140)
	dur_label.custom_minimum_size = Vector2(260, 18)
	dur_label.add_theme_font_size_override("font_size", 14)
	_item_info_panel.add_child(dur_label)

	InventoryManager.selected_changed.connect(func(_i: int) -> void: _refresh_item_info())


func _on_kills_changed(kills: int) -> void:
	if _kill_label == null:
		return
	var to_next: int = UpgradeManager.KILLS_PER_SPAWN \
		- (kills % UpgradeManager.KILLS_PER_SPAWN)
	_kill_label.text = "처치 %d · 다음 안전가옥 %d킬" % [kills, to_next]


func _on_coins_changed(total: int) -> void:
	if _coin_label != null:
		_coin_label.text = "코인 %d" % total


func _refresh_materials() -> void:
	var parts: Array[String] = []
	for id in InventoryManager.get_material_ids():
		var item = ItemDB.get_item(id)
		if item != null:
			parts.append("%s ×%d" % [item.display_name, InventoryManager.count_of(id)])
	if parts.size() > 0:
		_material_label.text = "재료: " + "  ".join(parts)
	else:
		_material_label.text = ""


func _add_bar_label(bar: ProgressBar, txt: String) -> void:
	var l := Label.new()
	l.text = txt
	l.position = Vector2(6, 3)
	l.add_theme_font_size_override("font_size", 13)
	bar.add_child(l)


func _refresh_weapon() -> void:
	var item = InventoryManager.get_equipped_item()
	if item == null:
		_weapon_label.text = "[ 주먹 ]"
		return
	_weapon_label.text = "%s  %d/%d" % [item.display_name, InventoryManager.equipped_durability, item.durability]


func _refresh_hotbar() -> void:
	for i in InventoryManager.HOTBAR_SIZE:
		var p: Panel = _hotbar_panels[i]
		if i == InventoryManager.selected_slot:
			p.add_theme_stylebox_override("panel", _slot_sb_selected)
		else:
			p.add_theme_stylebox_override("panel", _slot_sb_normal)
		var name_label: Label = p.get_child(1)
		var count_label: Label = p.get_child(2)
		var dur_bar: ProgressBar = p.get_child(3)
		var id = InventoryManager.quick_slots[i]
		if id == null:
			_set_slot_empty(name_label, count_label, dur_bar)
			continue
		var item = ItemDB.get_item(id)
		if item == null:
			name_label.text = id
			name_label.self_modulate = Color.WHITE
			count_label.visible = false
			dur_bar.visible = false
			continue
		name_label.text = item.display_name
		name_label.self_modulate = Color(0.55, 1.0, 0.55) if item.is_consumable() else Color.WHITE
		var cnt: int = InventoryManager.count_of(id)
		count_label.text = "×%d" % cnt
		count_label.visible = cnt > 1
		var max_dur: int = item.durability
		if max_dur > 0:
			var cur := InventoryManager.get_current_durability(id)
			dur_bar.max_value = max_dur
			dur_bar.value = cur
			dur_bar.visible = true
			var ratio := float(cur) / float(max_dur)
			var fill := StyleBoxFlat.new()
			fill.set_corner_radius_all(2)
			if ratio <= 0.25:
				fill.bg_color = Color(1.0, 0.35, 0.3)
			elif ratio <= 0.55:
				fill.bg_color = Color(1.0, 0.7, 0.25)
			else:
				fill.bg_color = Color(0.4, 0.9, 0.45)
			dur_bar.add_theme_stylebox_override("fill", fill)
		else:
			dur_bar.visible = false
	_refresh_item_info()


func _set_slot_empty(name_label: Label, count_label: Label, dur_bar: ProgressBar) -> void:
	name_label.text = ""
	name_label.self_modulate = Color.WHITE
	count_label.visible = false
	dur_bar.visible = false


func _refresh_item_info() -> void:
	var id = InventoryManager.get_selected_id()
	if id == null:
		_item_info_panel.visible = false
		return
	var item = ItemDB.get_item(id)
	if item == null:
		_item_info_panel.visible = false
		return
	_item_info_panel.visible = true
	var name_label: Label = _item_info_panel.get_node("NameLabel")
	var type_label: Label = _item_info_panel.get_node("TypeLabel")
	var desc_label: Label = _item_info_panel.get_node("DescLabel")
	var qty_label: Label = _item_info_panel.get_node("QtyLabel")
	var dur_label: Label = _item_info_panel.get_node("DurLabel")
	name_label.text = item.display_name
	name_label.self_modulate = ItemData.rarity_color(item.rarity)
	var type_text := ""
	if item.is_weapon():
		type_text = "무기"
	elif item.is_consumable():
		type_text = "소비품"
	else:
		match item.item_type:
			ItemData.Type.MATERIAL:
				type_text = "재료"
			ItemData.Type.KEY:
				type_text = "키 아이템"
			ItemData.Type.VALUABLE:
				type_text = "가치품"
			_:
				type_text = ""
	type_label.text = type_text
	desc_label.text = item.description
	var cnt: int = InventoryManager.count_of(id)
	qty_label.text = "수량: %d" % cnt
	var max_dur: int = item.durability
	if max_dur > 0:
		var cur := InventoryManager.get_current_durability(id)
		dur_label.text = "내구도: %d / %d" % [cur, max_dur]
		dur_label.visible = true
	else:
		dur_label.visible = false


func _process(_delta: float) -> void:
	if _game_over:
		if Input.is_action_just_pressed("ui_accept") or Input.is_action_just_pressed("attack"):
			_restart()
		return

	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player")
	if _player == null:
		return

	if not _hp_connected and _player.has_signal("hp_changed"):
		_hp_connected = true
		_player.hp_changed.connect(_on_hp_changed)
		_player.died.connect(_on_player_died)
		_on_hp_changed(_player.hp, _player.max_hp)

	_stamina_bar.max_value = _player.max_stamina
	_stamina_bar.value = _player.stamina
	_hunger_bar.max_value = _player.max_hunger
	_hunger_bar.value = _player.hunger
	_thirst_bar.max_value = _player.max_thirst
	_thirst_bar.value = _player.thirst

	var target = _player.get_interact_target()
	if _player.is_consuming():
		_prompt.text = "사용 중: %s" % _player.get_consume_name()
	elif target != null and not _player.is_searching():
		_prompt.text = "[E 홀드] %s" % target.interact_label()
	elif _player.is_searching():
		_prompt.text = "수색 중..."
	elif _player.get_selected_consumable() != null:
		_prompt.text = "[E 홀드] %s 사용" % _player.get_selected_consumable().display_name
	else:
		_prompt.text = ""
	_bar.visible = _player.is_searching()
	if _bar.visible:
		_place_above_head(_bar)
		_bar.value = _player.get_search_ratio()
	_use_bar.visible = _player.is_consuming()
	if _use_bar.visible:
		_place_above_head(_use_bar)
		_use_bar.value = _player.get_consume_ratio()

	_place_prompt_below_feet()
	_update_floating_toasts()

	if Input.is_action_just_pressed("inventory"):
		_panel.visible = not _panel.visible
		_refresh_inventory()


func _place_above_head(bar: Control) -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null or _player == null:
		bar.visible = false
		return
	var head_screen: Vector2 = cam.unproject_position(_player.global_position + Vector3.UP * HEAD_OFFSET)
	bar.position = head_screen + Vector2(-bar.size.x * 0.5, -bar.size.y - BAR_GAP)


func _place_prompt_below_feet() -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null or _player == null:
		return
	var foot_screen: Vector2 = cam.unproject_position(_player.global_position)
	_prompt.position = foot_screen + Vector2(-_prompt.size.x * 0.5, BAR_GAP)


func _update_floating_toasts() -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null or _player == null:
		return
	var head_screen: Vector2 = cam.unproject_position(_player.global_position + Vector3.UP * TOAST_HEAD_OFFSET)
	for i in _floating_toasts.size():
		var toast: Label = _floating_toasts[i]
		if is_instance_valid(toast):
			toast.position = head_screen + Vector2(-toast.size.x * 0.5, -toast.size.y - BAR_GAP - i * (toast.size.y + BAR_GAP))


func _on_player_died() -> void:
	_game_over = true
	_go_root.visible = true


func _restart() -> void:
	_game_over = false
	_go_root.visible = false
	_hp_connected = false
	_player = null
	InventoryManager.reset_run()
	GameState.reset_run_state()
	UpgradeManager.reset_run()
	get_tree().reload_current_scene()


func _on_hp_changed(hp: float, max_hp: float) -> void:
	_hp_bar.max_value = max_hp
	_hp_bar.value = hp


func _refresh_inventory() -> void:
	_weight_label.text = "%.1f / %.0f kg" % [InventoryManager.total_weight(), InventoryManager.MAX_WEIGHT]
	for i in InventoryManager.MAX_SLOTS:
		var l: Label = _slot_labels[i]
		var s = InventoryManager.slots[i]
		if s == null:
			l.text = ""
			l.self_modulate = Color.WHITE
			continue
		var item = ItemDB.get_item(s["id"])
		var item_name: String = s["id"]
		if item != null:
			item_name = item.display_name
			l.self_modulate = ItemData.rarity_color(item.rarity)
		l.text = "%s ×%d" % [item_name, s["qty"]]


func _on_item_gained(id: String, qty: int) -> void:
	var item = ItemDB.get_item(id)
	var display: String = id if item == null else item.display_name
	_show_floating_toast("+ %s ×%d" % [display, qty], ItemData.rarity_color(item.rarity) if item != null else Color.WHITE)


func _on_container_empty() -> void:
	_show_floating_toast("비어있음", Color(0.6, 0.6, 0.65))


func _show_floating_toast(text: String, color: Color) -> void:
	var toast := Label.new()
	toast.text = text
	toast.add_theme_font_size_override("font_size", 20)
	toast.self_modulate = color
	toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	$Root.add_child(toast)
	_floating_toasts.append(toast)
	var tw := create_tween()
	tw.tween_interval(1.6)
	tw.tween_property(toast, "modulate:a", 0.0, 0.5)
	tw.tween_callback(func() -> void:
		_floating_toasts.erase(toast)
		if is_instance_valid(toast):
			toast.queue_free()
	)
