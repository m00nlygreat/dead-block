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
const RoadNetwork := preload("res://scripts/world/stage_gen/road_network.gd")
const RoadChunk := preload("res://scripts/world/stage_gen/road_chunk.gd")
const BlockChunk := preload("res://scripts/world/stage_gen/block_chunk.gd")
const Patterns := preload("res://scripts/world/stage_gen/block_patterns.gd")

@export var seed_value := 0
@export var blocks := 3
@export var block_size := 26.0
@export var road_width := 8.0
@export var world_extent := 200.0
@export var house_scale := 3.4
@export var tree_scale := 3.8
@export var road_loop_prob := 0.22

var _rng := RandomNumberGenerator.new()
var _network := {}
var _placed: Array = []
var _edge_keys: Array = []


func _ready() -> void:
	_rng.seed = seed_value if seed_value != 0 else randi()
	_build()


func _total() -> float:
	return blocks * block_size + (blocks + 1) * road_width


func _half() -> float:
	return _total() * 0.5


func _node_pos(i: int, j: int) -> Vector2:
	var c := -_half() + road_width * 0.5
	return Vector2(c + i * (block_size + road_width), c + j * (block_size + road_width))


func _block_rect(bx: int, bz: int) -> Rect2:
	var x0 := -_half() + road_width + bx * (block_size + road_width)
	var z0 := -_half() + road_width + bz * (block_size + road_width)
	return Rect2(x0, z0, block_size, block_size)


func _build() -> void:
	_placed.clear()
	_edge_keys.clear()
	_add_collision_floor()
	_add_ground()
	_network = RoadNetwork.generate(_rng, blocks, road_loop_prob)
	_build_roads()
	for bx in blocks:
		for bz in blocks:
			var pattern := Patterns.pick(_rng)
			var ctx := {
				"parent": self,
				"rng": _rng,
				"rect": _block_rect(bx, bz),
				"pattern": pattern,
				"house_scenes": HOUSE_SCENES,
				"tree_scene": TREE_SCENE,
				"car_scene": CAR_SCENE,
				"tables": TABLES,
				"house_scale": house_scale,
				"tree_scale": tree_scale,
				"road_width": road_width,
				"edge_check": func(s: int) -> bool: return RoadNetwork.block_has_edge(_network, bx, bz, s),
				"placed": _placed,
			}
			BlockChunk.build(ctx)
	_add_boundary()


func _build_roads() -> void:
	var mats := {
		"asphalt": StandardMaterial3D.new(),
		"cross": StandardMaterial3D.new(),
		"dash": StandardMaterial3D.new(),
	}
	mats["asphalt"].albedo_color = Color(0.3, 0.31, 0.32)
	mats["asphalt"].roughness = 1.0
	mats["cross"].albedo_color = Color(0.33, 0.34, 0.35)
	mats["cross"].roughness = 1.0
	mats["dash"].albedo_color = Color(0.85, 0.85, 0.8)
	mats["dash"].roughness = 1.0
	var step := block_size + road_width
	for k in _network["edges"]:
		_edge_keys.append(k)
		var parts: PackedStringArray = String(k).split("_")
		var i := int(parts[1])
		var j := int(parts[2])
		var p := _node_pos(i, j)
		if k.begins_with("h"):
			RoadChunk.build_straight(self, mats, Vector3(p.x, 0, p.y), true, step, road_width)
		else:
			RoadChunk.build_straight(self, mats, Vector3(p.x, 0, p.y), false, step, road_width)
	for i in blocks + 1:
		for j in blocks + 1:
			if int(_network["masks"][RoadNetwork.node_key(i, j)]) == 0:
				continue
			var np := _node_pos(i, j)
			RoadChunk.build_junction(self, mats, Vector2(np.x, np.y), road_width)


func get_signature() -> String:
	var lines: Array = []
	lines.append_array(_placed)
	lines.append_array(_edge_keys)
	lines.sort()
	return "\n".join(lines)


func get_road_network() -> Dictionary:
	return _network


func _add_collision_floor() -> void:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(world_extent, 1.0, world_extent)
	cs.shape = bs
	body.add_child(cs)
	add_child(body)
	body.global_position = Vector3(0, -0.5, 0)


func _add_ground() -> void:
	var mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(world_extent, world_extent)
	mi.mesh = pm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.22, 0.23, 0.24)
	mat.roughness = 1.0
	mi.material_override = mat
	add_child(mi)


func _add_boundary() -> void:
	var half: float = _world_half()
	for r in [[Vector3(0, half, 0), Vector3(world_extent, 8, 1)], [Vector3(0, -half, 0), Vector3(world_extent, 8, 1)], [Vector3(half, 0, 0), Vector3(1, 8, world_extent)], [Vector3(-half, 0, 0), Vector3(1, 8, world_extent)]]:
		var body := StaticBody3D.new()
		body.collision_layer = 1
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = r[1]
		cs.shape = bs
		body.add_child(cs)
		add_child(body)
		body.global_position = r[0] + Vector3(0, 4, 0)


func _world_half() -> float:
	return world_extent * 0.5
