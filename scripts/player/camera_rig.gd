extends Node3D

@export_range(-90.0, 30.0, 0.5) var pitch_deg := -50.0

@export var target_path: NodePath
@export var follow_smoothing := 6.0
@export var min_distance := 8.0
@export var max_distance := 22.0
@export var zoom_step := 1.5

var _distance := 15.0
var _applied_distance := 15.0

@onready var _cam: Camera3D = $Camera3D


func _ready() -> void:
	rotation.y = 0.0


func _process(delta: float) -> void:
	if not target_path.is_empty():
		var t := get_node_or_null(target_path)
		if t is Node3D:
			var k := 1.0 - exp(-follow_smoothing * delta)
			global_position = global_position.lerp(t.global_position, k)

	_applied_distance = lerpf(_applied_distance, _distance, 1.0 - exp(-8.0 * delta))
	var pitch := deg_to_rad(pitch_deg)
	_cam.position = Vector3(0.0, -sin(pitch), cos(pitch)) * _applied_distance
	_cam.rotation.x = pitch
