extends Node

signal noise_emitted(position: Vector3, radius: float, priority: int)

var listeners: Array = []


func register(listener: Node) -> void:
	if not listeners.has(listener):
		listeners.append(listener)


func unregister(listener: Node) -> void:
	listeners.erase(listener)


func emit_noise(position: Vector3, radius: float, priority: int = 0) -> void:
	for l in listeners.duplicate():
		if is_instance_valid(l) and l.has_method("on_noise"):
			if position.distance_to(l.global_position) <= radius:
				l.on_noise(position, priority)
	noise_emitted.emit(position, radius, priority)
