extends "res://scripts/world/loot_container.gd"

## 트렁크 수색용 차량. 차체 모델을 무작위로 고르고 충돌 박스를 실측 길이에 맞춘다.
const BODIES := [
	{"scene": preload("res://assets/car-kit/Models/GLB format/hatchback-sports.glb"), "length": 3.0},
	{"scene": preload("res://assets/car-kit/Models/GLB format/sedan.glb"), "length": 3.2},
	{"scene": preload("res://assets/car-kit/Models/GLB format/sedan-sports.glb"), "length": 3.2},
	{"scene": preload("res://assets/car-kit/Models/GLB format/suv.glb"), "length": 3.4},
	{"scene": preload("res://assets/car-kit/Models/GLB format/taxi.glb"), "length": 3.3},
	{"scene": preload("res://assets/car-kit/Models/GLB format/police.glb"), "length": 3.4},
	{"scene": preload("res://assets/car-kit/Models/GLB format/van.glb"), "length": 3.7},
	{"scene": preload("res://assets/car-kit/Models/GLB format/ambulance.glb"), "length": 3.6},
]

var last_body_index := -1


func _ready() -> void:
	super()
	_apply_random_body()


func _apply_random_body() -> void:
	last_body_index = randi() % BODIES.size()
	var pick: Dictionary = BODIES[last_body_index]
	var old := get_node_or_null("CarVisual")
	if old != null:
		remove_child(old)
		old.free()
	var inst: Node3D = (pick["scene"] as PackedScene).instantiate()
	inst.name = "CarVisual"
	add_child(inst)
	var shape_node: CollisionShape3D = $Shape
	shape_node.shape = shape_node.shape.duplicate()
	shape_node.shape.size = Vector3(1.7, 1.2, float(pick["length"]))
