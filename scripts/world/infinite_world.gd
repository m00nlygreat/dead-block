extends Node3D

const HOUSE_SCENES := [
	preload("res://assets/city-kit-suburban/Models/GLB format/building-type-a.glb"),
	preload("res://assets/city-kit-suburban/Models/GLB format/building-type-b.glb"),
	preload("res://assets/city-kit-suburban/Models/GLB format/building-type-c.glb"),
	preload("res://assets/city-kit-suburban/Models/GLB format/building-type-d.glb"),
	preload("res://assets/city-kit-suburban/Models/GLB format/building-type-e.glb"),
	preload("res://assets/city-kit-suburban/Models/GLB format/building-type-f.glb"),
]
const TREE_SCENE := preload("res://assets/city-kit-suburban/Models/GLB format/tree-large.glb")
const CAR_SCENE := preload("res://scenes/world/car_trunk.tscn")
const TABLES := [
	preload("res://resources/loot_tables/trash_common.tres"),
	preload("res://resources/loot_tables/med_cabinet.tres"),
]
const RoadChunk := preload("res://scripts/world/stage_gen/road_chunk.gd")
const BlockChunk := preload("res://scripts/world/stage_gen/block_chunk.gd")
const Patterns := preload("res://scripts/world/stage_gen/block_patterns.gd")

@export var seed_value := 0
@export var block_size := 26.0
@export var road_width := 8.0
@export var load_radius := 2
@export var house_scale := 3.4
@export var tree_scale := 3.8
@export var edge_prob := 0.72

var _run_seed: int = 0
var _step: float = 34.0
var _loaded: Dictionary = {}
var _pattern_cache: Dictionary = {}
var _player: Node3D = null
var _t := 0.0
var _mats: Dictionary = {}
var _floor_body: StaticBody3D
var _ground_mi: MeshInstance3D


func _ready() -> void:
	_run_seed = seed_value if seed_value != 0 else int(randi())
	_step = block_size + road_width
	_mats = {
		"asphalt": StandardMaterial3D.new(),
		"cross": StandardMaterial3D.new(),
		"dash": StandardMaterial3D.new(),
	}
	_mats["asphalt"].albedo_color = Color(0.3, 0.31, 0.32)
	_mats["asphalt"].roughness = 1.0
	_mats["cross"].albedo_color = Color(0.33, 0.34, 0.35)
	_mats["cross"].roughness = 1.0
	_mats["dash"].albedo_color = Color(0.85, 0.85, 0.8)
	_mats["dash"].roughness = 1.0
	_floor_body = StaticBody3D.new()
	_floor_body.collision_layer = 1
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(_step * 14.0, 1.0, _step * 14.0)
	cs.shape = bs
	_floor_body.add_child(cs)
	add_child(_floor_body)
	_floor_body.global_position = Vector3(0, -0.5, 0)
	_ground_mi = MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(_step * 14.0, _step * 14.0)
	_ground_mi.mesh = pm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.22, 0.23, 0.24)
	mat.roughness = 1.0
	_ground_mi.material_override = mat
	add_child(_ground_mi)


func _process(delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Node3D
		if _player == null:
			return
		_update_stream()
		return
	_t += delta
	if _t >= 0.25:
		_t = 0.0
		_update_stream()


func _update_stream() -> void:
	var px: float = _player.global_position.x
	var pz: float = _player.global_position.z
	_floor_body.global_position = Vector3(px, -0.5, pz)
	_ground_mi.global_position = Vector3(px, 0, pz)
	var cbx := floori(px / _step)
	var cbz := floori(pz / _step)
	var r := load_radius
	var want := {}
	for dx in range(-r, r + 2):
		for dz in range(-r, r + 2):
			want["j_%d_%d" % [cbx + dx, cbz + dz]] = true
			want["e_h_%d_%d" % [cbx + dx, cbz + dz]] = true
			want["e_v_%d_%d" % [cbx + dx, cbz + dz]] = true
	for bx in range(cbx - r, cbx + r + 1):
		for bz in range(cbz - r, cbz + r + 1):
			want["b_%d_%d" % [bx, bz]] = true
	for key in _loaded.keys():
		if not want.has(key):
			var node: Node3D = _loaded[key]
			node.queue_free()
			_loaded.erase(key)
	for key in want:
		if not _loaded.has(key):
			var node := _build_for_key(key)
			if node != null:
				_loaded[key] = node


func _build_for_key(key: String) -> Node3D:
	var parts: PackedStringArray = key.split("_")
	var kind: String = parts[0]
	if kind == "b":
		return _build_block(int(parts[1]), int(parts[2]))
	if kind == "j":
		return _build_junction(int(parts[1]), int(parts[2]))
	if kind == "e":
		return _build_edge(parts[1], int(parts[2]), int(parts[3]))
	return null


func _edge_active(axis: String, i: int, j: int) -> bool:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%s|%s|%d|%d" % [_run_seed, axis, i, j])
	return rng.randf() < edge_prob


func _side_active(bx: int, bz: int, side: int) -> bool:
	match side:
		0:
			return _edge_active("h", bx, bz)
		1:
			return _edge_active("v", bx + 1, bz)
		2:
			return _edge_active("h", bx, bz + 1)
		3:
			return _edge_active("v", bx, bz)
	return false


func _block_rng(bx: int, bz: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%s|b|%d|%d" % [_run_seed, bx, bz])
	return rng


func _build_block(bx: int, bz: int) -> Node3D:
	var container := Node3D.new()
	add_child(container)
	var cache_key := "%d_%d" % [bx, bz]
	if not _pattern_cache.has(cache_key):
		_pattern_cache[cache_key] = Patterns.pick(_block_rng(bx, bz))
	var rect := Rect2(bx * _step + road_width * 0.5, bz * _step + road_width * 0.5, block_size, block_size)
	var ctx := {
		"parent": container,
		"rng": _block_rng(bx, bz),
		"rect": rect,
		"pattern": _pattern_cache[cache_key],
		"house_scenes": HOUSE_SCENES,
		"tree_scene": TREE_SCENE,
		"car_scene": CAR_SCENE,
		"tables": TABLES,
		"house_scale": house_scale,
		"tree_scale": tree_scale,
		"road_width": road_width,
		"edge_check": func(side: int) -> bool: return _side_active(bx, bz, side),
		"placed": [],
	}
	BlockChunk.build(ctx)
	return container


func _build_junction(i: int, j: int) -> Node3D:
	var any := _edge_active("h", i - 1, j) or _edge_active("h", i, j) or _edge_active("v", i, j - 1) or _edge_active("v", i, j)
	if not any:
		return null
	var container := Node3D.new()
	add_child(container)
	RoadChunk.build_junction(container, _mats, Vector2(i * _step, j * _step), road_width)
	return container


func _build_edge(axis: String, i: int, j: int) -> Node3D:
	if not _edge_active(axis, i, j):
		return null
	var container := Node3D.new()
	add_child(container)
	if axis == "h":
		RoadChunk.build_straight(container, _mats, Vector3((i + 0.5) * _step, 0, j * _step), true, _step, road_width)
	else:
		RoadChunk.build_straight(container, _mats, Vector3(i * _step, 0, (j + 0.5) * _step), false, _step, road_width)
	return container


func loaded_count() -> int:
	return _loaded.size()


func loaded_keys() -> Array:
	return _loaded.keys()


func run_seed() -> int:
	return _run_seed
