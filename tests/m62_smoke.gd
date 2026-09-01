extends Node

## m62: 안전가옥 카드 슬롯·레이아웃 규칙 검증.
## 구매한 카드는 해당 슬롯이 빈 칸이 되고(재추첨 없음, 같은 카드 재구매 불가),
## 남은 카드는 제자리에 유지된다. 카드 3장은 좌측 열에 세로(수직) 배치되며
## 폭은 고정 상한을 넘지 않고 가로 중앙 정렬된다.

const PLAYER_SCENE := preload("res://scenes/player/player.tscn")
const UPGRADE_UI_SCENE := preload("res://scenes/ui/upgrade_ui.tscn")

const CARD_W := 480.0


func _ready() -> void:
	_run()


func _ticks(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _ids(choices) -> Array:
	var out: Array = []
	for u in choices:
		out.append("<빈칸>" if u == null else u.id)
	return out


func _run() -> void:
	var w := Node3D.new()
	add_child(w)
	var floor_body := StaticBody3D.new()
	floor_body.collision_layer = 1
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(600, 1, 600)
	cs.shape = bs
	cs.position.y = -0.5
	floor_body.add_child(cs)
	w.add_child(floor_body)

	var player := PLAYER_SCENE.instantiate()
	w.add_child(player)
	player.global_position = Vector3.ZERO

	var ui := UPGRADE_UI_SCENE.instantiate()
	add_child(ui)
	await _ticks(5)
	GameState.reset_run_state()
	UpgradeManager.reset_run()
	await _ticks(2)

	GameState.add_coins(9999)
	seed(7)
	var opened: bool = ui.try_open()
	print("T1_OPEN_3_CARDS: ", opened and ui._choices.size() == 3,
		" (cards=%s)" % str(_ids(ui._choices)))

	if not opened or ui._choices.size() != 3:
		get_tree().quit(1)
		return

	var ids_before := _ids(ui._choices)
	var c0: int = GameState.coins
	ui._on_card_pressed(0)
	var expected := ["<빈칸>", ids_before[1], ids_before[2]]
	print("T2_PURCHASED_SLOT_EMPTIED: ",
		ui._choices[0] == null and str(_ids(ui._choices)) == str(expected),
		" (set=%s)" % str(_ids(ui._choices)))

	var coins_after_buy1: int = GameState.coins
	var first_lv: int = UpgradeManager.upgrade_level(ids_before[0])
	ui._on_card_pressed(0)
	print("T3_EMPTY_SLOT_NOT_REBUYABLE: ",
		GameState.coins == coins_after_buy1
		and UpgradeManager.upgrade_level(ids_before[0]) == first_lv,
		" (coins=%d lv=%d)" % [GameState.coins, first_lv])

	var b0: Button = ui._card_buttons[0]
	print("T4_EMPTY_SLOT_BLANKED: ", b0.disabled and b0.modulate.a == 0.0,
		" (disabled=%s alpha=%.1f)" % [str(b0.disabled), b0.modulate.a])

	ui._on_card_pressed(1)
	print("T5_REMAINING_CARD_BUYABLE: ",
		ui._choices[1] == null and GameState.coins < coins_after_buy1,
		" (set=%s)" % str(_ids(ui._choices)))

	await _ticks(3)
	var cards: Control = ui.get_node("Root/Columns/LeftCol/Cards")
	var widths_ok := true
	for b in ui._card_buttons:
		if b.size.x > CARD_W + 0.5:
			widths_ok = false
	var stacked_y: bool = ui._card_buttons[0].position.y < ui._card_buttons[1].position.y \
		and ui._card_buttons[1].position.y < ui._card_buttons[2].position.y
	var aligned := true
	for b in ui._card_buttons:
		var b_center: float = b.position.x + b.size.x * 0.5
		if absf(b_center - cards.size.x * 0.5) >= 1.0:
			aligned = false
	print("T6_WIDTH_CAPPED_STACKED_CENTERED: ", widths_ok and stacked_y and aligned,
		" (w=%d/%d/%d y=%.0f/%.0f/%.0f)" % [
			int(ui._card_buttons[0].size.x), int(ui._card_buttons[1].size.x),
			int(ui._card_buttons[2].size.x),
			ui._card_buttons[0].position.y, ui._card_buttons[1].position.y,
			ui._card_buttons[2].position.y])

	ui._close()
	await _ticks(2)
	print("T7_CLOSE_RESUMES: ", not ui.visible and not get_tree().paused,
		" (visible=%s paused=%s)" % [str(ui.visible), str(get_tree().paused)])

	UpgradeManager.reset_run()
	print("M62_SMOKE_DONE")
	get_tree().quit(0)
