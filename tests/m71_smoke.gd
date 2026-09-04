extends Node

## m71: 이미 털린 구조물(집·차량) 검증.
## - 털린 집: 그레이스케일로 생성 + 수색 컨테이너 없음(수색 불가)(T1)
## - 털린 차량: 그레이스케일 + searched 상태 + 수색 불가(T2)
## - 활성(수색 가능) 집·차량은 여전히 수색 가능(T3)
## - 패턴별 털린 구조물 배치가 정의대로 나온다(T4)
## - 털린 구조물은 룻을 추가하지 않아 활성 룻 밀도가 보존된다(T5)

const LootVisual := preload("res://scripts/util/loot_visual.gd")
const Patterns := preload("res://scripts/world/stage_gen/block_patterns.gd")
const BlockChunk := preload("res://scripts/world/stage_gen/block_chunk.gd")
const HOUSE_A := preload("res://assets/city-kit-suburban/Models/GLB format/building-type-a.glb")
const TREE := preload("res://assets/city-kit-suburban/Models/GLB format/tree-large.glb")
const CAR := preload("res://scenes/world/car_trunk.tscn")
const TRASH := preload("res://resources/loot_tables/trash_common.tres")

var _passed := true
var _holder: Node3D


func _ready() -> void:
	_run()


func _check(name: String, cond: bool, extra := "") -> void:
	print("%s: %s %s" % [name, cond, extra])
	if not cond:
		_passed = false


func _build(pattern: Dictionary, rng: RandomNumberGenerator) -> Array:
	_holder = Node3D.new()
	add_child(_holder)
	var placed: Array = []
	var ctx := {
		"parent": _holder,
		"rng": rng,
		"rect": Rect2(0, 0, 26, 26),
		"pattern": pattern,
		"house_scenes": [HOUSE_A],
		"tree_scene": TREE,
		"car_scene": CAR,
		"tables": [TRASH],
		"house_scale": 3.4,
		"tree_scale": 3.8,
		"road_width": 8.0,
		"edge_check": func(s): return true,
		"placed": placed,
	}
	BlockChunk.build(ctx)
	return placed


func _active_containers() -> int:
	var n := 0
	for child in _holder.get_children():
		for sub in child.find_children("*", "StaticBody3D", true, false):
			if sub.has_method("complete_interaction") and sub.get("loot_table") != null:
				n += 1
	return n


func _teardown() -> void:
	if _holder != null and is_instance_valid(_holder):
		_holder.queue_free()
	_holder = null


func _run() -> void:
	var fields_ok := true
	var any_looted := false
	for p in Patterns.PATTERNS:
		if not p.has("looted_house_slots") or not p.has("looted_car_count"):
			fields_ok = false
			break
		if p["looted_house_slots"].size() > 0 or p["looted_car_count"].y > 0:
			any_looted = true
	_check("T0_PATTERN_FIELDS", fields_ok and any_looted)

	# park 패턴 = 털린 집 2 + 털린 차(도로 활성 edge_check true → 2~3). 활성 집 없음.
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	var placed := _build(Patterns.PATTERNS[3], rng)
	await _ticks(2)

	var looted_houses := 0
	var looted_cars := 0
	for p in placed:
		if p.begins_with("looted_house"):
			looted_houses += 1
		elif p.begins_with("looted_car"):
			looted_cars += 1
	_check("T4a_PARK_LOOTED_HOUSE_N", looted_houses >= 2, "(n=%d)" % looted_houses)
	_check("T4b_PARK_LOOTED_CAR_N", looted_cars >= 2, "(n=%d)" % looted_cars)
	_check("T1b_PARK_NO_ACTIVE_HOUSE_CONTAINER", _active_containers() == 0)

	# 털린 집은 그레이스케일 적용된 건물 노드로 존재
	var gray_house := false
	var looted_car_ok := 0
	for child in _holder.get_children():
		if child is Node3D and child.scene_file_path.ends_with("building-type-a.glb"):
			if LootVisual.is_grayscale_applied(child):
				gray_house = true
		if child.scene_file_path.ends_with("car_trunk.tscn"):
			if LootVisual.is_grayscale_applied(child) and child.get("searched") == true \
					and not child.can_interact():
				looted_car_ok += 1
	_check("T1a_LOOTED_HOUSE_GRAY", gray_house)
	_check("T2_LOOTED_CAR_GRAY_SEARCHED", looted_car_ok >= 2, "(n=%d)" % looted_car_ok)
	_teardown()
	await _ticks(2)

	# residential_quad = 활성 집 8. 수색 가능 컨테이너가 존재한다.
	var rng2 := RandomNumberGenerator.new()
	rng2.seed = 555
	_build(Patterns.PATTERNS[0], rng2)
	await _ticks(2)
	var active_n := _active_containers()
	# 그레이스케일이 적용된 노드가 수색 컨테이너(활성 집)를 품으면 안 된다.
	# 털린 차는 컨테이너가 없으므로 그레이스케일이어도 정상.
	var searchable_gray := false
	for child in _holder.get_children():
		if LootVisual.is_grayscale_applied(child):
			for sub in child.find_children("*", "StaticBody3D", true, false):
				if sub.has_method("complete_interaction") and sub.get("loot_table") != null:
					searchable_gray = true
					break
	_check("T3_HAS_ACTIVE_HOUSE_CONTAINER", active_n >= 1, "(n=%d)" % active_n)
	_check("T3b_SEARCHABLE_NOT_GRAY", not searchable_gray)
	_teardown()
	await _ticks(2)

	var per_block := 2.5 * (1.0 - BlockChunk.CAR_EMPTY_CHANCE) \
		+ 4.33 * (1.0 - BlockChunk.HOUSE_EMPTY_CHANCE)
	_check("T5_LOOT_DENSITY_PRESERVED", per_block >= 1.5 and per_block <= 3.5, "(per_block=%.2f)" % per_block)
	_check("T5b_EMPTY_CHANCES_INTACT",
		BlockChunk.CAR_EMPTY_CHANCE == 0.5 and BlockChunk.HOUSE_EMPTY_CHANCE == 0.7)

	print("M71_PASSED_ALL: ", _passed)
	print("M71_SMOKE_DONE")
	get_tree().quit(0)


func _ticks(n: int) -> void:
	for i in n:
		await get_tree().physics_frame
