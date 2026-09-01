extends CanvasLayer

## 안전가옥 = 업그레이드 화면. 물리 건물이 아니라 처치 마일스톤
## (KILLS_PER_SPAWN 배수) 도달 약 1초 후에 열리는 상점 화면이다.
## 지연은 마지막 격파 좀비의 코인 회수 시간을 확보하기 위한 것이다.
## 화면은 3분할: 좌 업그레이드 카드(세로) / 중 구매(코인) / 우 제작(재료).
## 떠나기 버튼·ESC로 닫으면 게임이 재개된다.

const CARD_SIZE := Vector2(480.0, 180.0)
const CARD_FONT_SIZE := 16
const DESC_CHARS_PER_LINE := 22
const OPEN_DELAY := 1.0
## 안전가옥 개방 시 주변 좀비를 바깥으로 밀어내는 원형 파동 반경·세기
const WAVE_RADIUS := 8.0
const WAVE_KNOCKBACK := 12.0

const SHOP_PRICES := {"bandage": 5, "water": 5}
const CRAFT_RECIPES := {
	"weapon_blade": {"scrap_metal": 2, "cloth": 1},
	"bandage": {"cloth": 2},
}

var _choices: Array[UpgradeData] = []
var _open_timer: Timer

@onready var _cards: VBoxContainer = $Root/Columns/LeftCol/Cards
@onready var _coins_label: Label = $Root/CoinsLabel
@onready var _leave_button: Button = $Root/LeaveButton
@onready var _buy_buttons: Dictionary = {
	"bandage": $Root/Columns/CenterCol/BuyBandage as Button,
	"water": $Root/Columns/CenterCol/BuyWater as Button,
}
@onready var _craft_buttons: Dictionary = {
	"weapon_blade": $Root/Columns/RightCol/CraftBlade as Button,
	"bandage": $Root/Columns/RightCol/CraftBandage as Button,
}
var _card_buttons: Array[Button] = []


func _ready() -> void:
	add_to_group("upgrade_ui")
	visible = false
	for i in UpgradeManager.CHOICE_COUNT:
		var b := Button.new()
		b.custom_minimum_size = CARD_SIZE
		b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		b.add_theme_font_size_override("font_size", CARD_FONT_SIZE)
		b.pressed.connect(_on_card_pressed.bind(i))
		_cards.add_child(b)
		_card_buttons.append(b)
	for id in _buy_buttons:
		var bb: Button = _buy_buttons[id]
		bb.pressed.connect(_on_buy_pressed.bind(id))
	for id in _craft_buttons:
		var cb: Button = _craft_buttons[id]
		cb.pressed.connect(_on_craft_pressed.bind(id))
	GameState.coins_changed.connect(func(_t: int): _refresh_if_visible())
	InventoryManager.inventory_changed.connect(func(): _refresh_if_visible())
	_open_timer = Timer.new()
	_open_timer.one_shot = true
	_open_timer.wait_time = OPEN_DELAY
	_open_timer.timeout.connect(_try_open_pending)
	add_child(_open_timer)
	_leave_button.pressed.connect(_close)
	UpgradeManager.kills_changed.connect(_on_kills_changed)


func _on_kills_changed(kills: int) -> void:
	if kills <= 0:
		_open_timer.stop()
		return
	if kills % UpgradeManager.KILLS_PER_SPAWN == 0:
		_open_timer.start()


func _try_open_pending() -> void:
	var p: Node = get_tree().get_first_node_in_group("player")
	if p == null:
		return
	var hp_v = p.get("hp")
	if hp_v != null and hp_v <= 0.0:
		return
	if UpgradeManager.kills <= 0 \
			or UpgradeManager.kills % UpgradeManager.KILLS_PER_SPAWN != 0:
		return
	try_open()


func try_open() -> bool:
	if visible:
		return false
	_choices = UpgradeManager.draw_choices()
	if _choices.is_empty():
		return false
	get_tree().paused = true
	visible = true
	_refresh()
	_emit_safehouse_wave()
	return true


## 안전가옥 개방 시 플레이어 중심 주변 좀비들을 원형으로 밀어낸다.
func _emit_safehouse_wave() -> void:
	var p := get_tree().get_first_node_in_group("player") as Node3D
	if p == null or not is_instance_valid(p):
		return
	var center: Vector3 = p.global_position
	for n in get_tree().get_nodes_in_group("zombies"):
		var z := n as Node3D
		if z == null or not is_instance_valid(z):
			continue
		var dir: Vector3 = z.global_position - center
		dir.y = 0.0
		if dir.length() <= WAVE_RADIUS and dir.length() > 0.01:
			z.call("apply_wave_knockback", dir, WAVE_KNOCKBACK)


func _cost_text(u: UpgradeData) -> int:
	return UpgradeManager.cost_of(u)


func _wrap_text(s: String, per_line: int) -> String:
	var out := ""
	var count := 0
	for ch in s:
		if ch == "\n":
			out += ch
			count = 0
			continue
		if count >= per_line:
			out += "\n"
			count = 0
		out += ch
		count += 1
	return out


func _refresh_if_visible() -> void:
	if visible:
		_refresh()


func _refresh() -> void:
	_coins_label.text = "보유 코인 %d" % GameState.coins
	for i in _card_buttons.size():
		var b: Button = _card_buttons[i]
		if i < _choices.size():
			var u := _choices[i]
			b.visible = true
			if u == null:
				b.disabled = true
				b.modulate = Color(1, 1, 1, 0)
				b.text = ""
				continue
			b.modulate = Color.WHITE
			var lv := UpgradeManager.upgrade_level(u.id)
			var desc := _wrap_text(u.description, DESC_CHARS_PER_LINE)
			if lv >= u.max_level:
				b.disabled = true
				b.text = "%s\nLv %d / %d · 만렙\n\n%s" % [
					u.display_name, lv, u.max_level, desc,
				]
			else:
				var affordable: bool = GameState.coins >= UpgradeManager.cost_of(u)
				b.disabled = not affordable
				b.text = "%s\nLv %d / %d · %d 코인\n\n%s%s" % [
					u.display_name, lv + 1,
					u.max_level, UpgradeManager.cost_of(u), desc,
					"" if affordable else "\n(코인 부족)",
				]
		else:
			b.visible = false
	_refresh_shop()


func _refresh_shop() -> void:
	for id in _buy_buttons:
		var b: Button = _buy_buttons[id]
		var item = ItemDB.get_item(id)
		var price: int = SHOP_PRICES[id]
		b.text = "%s · %d 코인\n보유 %d" % [
			item.display_name, price, InventoryManager.count_of(id),
		]
		b.disabled = GameState.coins < price
	for id in _craft_buttons:
		var b: Button = _craft_buttons[id]
		var recipe: Dictionary = CRAFT_RECIPES[id]
		var item = ItemDB.get_item(id)
		var parts: PackedStringArray = []
		var ok := true
		for mat_id in recipe:
			var have: int = InventoryManager.count_of(mat_id)
			var need: int = recipe[mat_id]
			ok = ok and have >= need
			parts.append("%s %d/%d" % [ItemDB.get_item(mat_id).display_name, have, need])
		b.text = "%s 제작\n%s" % [item.display_name, " + ".join(parts)]
		b.disabled = not ok


func _on_card_pressed(index: int) -> void:
	if index >= _choices.size() or _choices[index] == null:
		return
	if not UpgradeManager.purchase(_choices[index].id):
		return
	_choices[index] = null
	_refresh()


func _on_buy_pressed(id: String) -> void:
	if not visible:
		return
	var price: int = SHOP_PRICES[id]
	if not GameState.spend_coins(price):
		return
	## 인벤 슬롯·무게 초과로 못 넣으면 코인 환불
	if InventoryManager.add_item(id) == 0:
		GameState.add_coins(price)
	_refresh()


func _on_craft_pressed(result_id: String) -> void:
	if not visible:
		return
	var recipe: Dictionary = CRAFT_RECIPES[result_id]
	for mat_id in recipe:
		if InventoryManager.count_of(mat_id) < int(recipe[mat_id]):
			return
	for mat_id in recipe:
		for i in int(recipe[mat_id]):
			InventoryManager.remove_one_of(mat_id)
	## 인벤 슬롯·무게 초과로 못 넣으면 재료 환불
	if InventoryManager.add_item(result_id) == 0:
		for mat_id in recipe:
			InventoryManager.add_item(mat_id, int(recipe[mat_id]))
	_refresh()


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		_close()


func _close() -> void:
	if not visible:
		return
	get_tree().paused = false
	visible = false
