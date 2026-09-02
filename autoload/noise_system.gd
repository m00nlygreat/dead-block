extends Node

signal noise_emitted(position: Vector3, radius: float, priority: int)

const WALK_NOISE_RADIUS := 6.0
const SPRINT_NOISE_RADIUS := 10.0
const MELEE_NOISE_RADIUS := 5.0
const GUN_NOISE_RADIUS := 15.0

var listeners: Array = []


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
	_spawn_ripple(pos, radius)


func emit_walk_noise(pos: Vector3, sprinting: bool) -> void:
	var radius := SPRINT_NOISE_RADIUS if sprinting else WALK_NOISE_RADIUS
	emit_noise(pos, radius, 0)


func emit_melee_noise(pos: Vector3) -> void:
	emit_noise(pos, MELEE_NOISE_RADIUS, 0)


func emit_gun_noise(pos: Vector3) -> void:
	emit_noise(pos, GUN_NOISE_RADIUS, 1)


func _spawn_ripple(pos: Vector3, radius: float) -> void:
	var scene := get_tree().current_scene
	if scene == null:
		return
	var ripple := NoiseRipple.new()
	ripple.position = Vector3(pos.x, 0.0, pos.z)
	ripple.start(radius)
	scene.add_child(ripple)
