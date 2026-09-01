class_name MagnetPickup
extends Area3D

## 코인·XP 젬 등 자석 픽업 공통 동작:
## 플레이어 자석 반경(PickupAttractor)에 들어오면 대상에게 비행해 수집된다.

const COLLECT_DIST := 0.7
const FLY_SPEED_START := 6.0
const FLY_ACCEL := 40.0

var _target: Node3D = null
var _fly_speed := FLY_SPEED_START
var _collected := false


## Player.PickupAttractor가 반경 진입을 감지하면 호출
func magnetize(target: Node3D) -> void:
	if _target != null:
		return
	_target = target
	_fly_speed = FLY_SPEED_START


## 접촉·흡수 어느 쪽이든 중복 없이 1회만 수집
func finish_collect() -> void:
	if _collected:
		return
	_collected = true
	_collect()
	queue_free()


func _physics_process(delta: float) -> void:
	if _collected or _target == null or not is_instance_valid(_target):
		return
	_fly_speed += FLY_ACCEL * delta
	var dst: Vector3 = _target.global_position + Vector3.UP * 0.6
	global_position = global_position.move_toward(dst, _fly_speed * delta)
	if global_position.distance_to(dst) <= COLLECT_DIST:
		finish_collect()


func _collect() -> void:
	pass
