extends Node

signal noise_emitted(position: Vector3, radius: float, priority: int)

const WALK_NOISE_RADIUS := 3.0
const SPRINT_NOISE_RADIUS := 6.0
const MELEE_NOISE_RADIUS := 5.0
const GUN_NOISE_RADIUS := 15.0

var listeners: Array = []
var _chart: NoiseRipple = null


func register(listener: Node) -> void:
	if not listeners.has(listener):
		listeners.append(listener)


func unregister(listener: Node) -> void:
	listeners.erase(listener)


func emit_noise(pos: Vector3, radius: float, priority: int = 0) -> void:
	for l in listeners.duplicate():
		if is_instance_valid(l) and l.has_method("on_noise"):
			if pos.distance_to(l.global_position) <= radius:
				l.on_noise(pos, priority)
	noise_emitted.emit(pos, radius, priority)
	_chart_add(radius)


func emit_walk_noise(pos: Vector3, sprinting: bool, sneaking := false) -> void:
	var radius := SPRINT_NOISE_RADIUS if sprinting else WALK_NOISE_RADIUS
	if sneaking:
		radius *= 0.65
	emit_noise(pos, radius, 0)


func emit_melee_noise(pos: Vector3, sneaking := false) -> void:
	var radius := MELEE_NOISE_RADIUS
	if sneaking:
		radius *= 0.65
	emit_noise(pos, radius, 0)


func emit_gun_noise(pos: Vector3) -> void:
	emit_noise(pos, GUN_NOISE_RADIUS, 1)


func _chart_add(radius: float) -> void:
	var scene := get_tree().current_scene
	if scene == null:
		return
	if _chart == null or not is_instance_valid(_chart):
		_chart = NoiseRipple.new()
		scene.add_child(_chart)
	if is_instance_valid(_chart):
		_chart.add_noise(radius)
