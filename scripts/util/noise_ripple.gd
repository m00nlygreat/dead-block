class_name NoiseRipple
extends MeshInstance3D

## 상시 유지되는 소음 차트: 플레이어 중심 반투명 채워진 원(디스크)의 반지름으로 현재 소음량을 표현한다.
## 고정된 단위 디스크 메시를 한 번 만들고 scale로 반지름을 제어해, 매 프레임 재생성 없이 깨지지 않게 한다.

const GROUND_Y := 0.15
const COLOR := Color(0.1, 0.1, 0.13)
const ALPHA := 0.3
const MAX_RADIUS := 30.0
const UP_RESPONSE := 8.0
const DOWN_RESPONSE := 4.0
const DECAY_RATE := 5.0

var _target_radius := 0.0
var _current_radius := 0.0


func _ready() -> void:
	# 단위 반지름(1m) 디스크를 한 번 생성
	var cyl := CylinderMesh.new()
	cyl.top_radius = 1.0
	cyl.bottom_radius = 1.0
	cyl.height = 0.02
	cyl.radial_segments = 96
	cyl.rings = 1
	mesh = cyl
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(COLOR.r, COLOR.g, COLOR.b, ALPHA)
	mat.no_depth_test = false
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.render_priority = 5
	material_override = mat
	position.y = GROUND_Y
	scale = Vector3(0.01, 1.0, 0.01)
	visible = true


## 소음 이벤트 반영: 해당 행동 반경까지 반지름 상승 (기존보다 큰 소음이 오면 확장, 작으면 유지)
func add_noise(radius: float) -> void:
	_target_radius = maxf(_target_radius, minf(radius, MAX_RADIUS))


func _process(delta: float) -> void:
	# 플레이어를 추적해 발치에 상시 유지
	var player := get_tree().get_first_node_in_group("player")
	if player is Node3D:
		global_position = Vector3(player.global_position.x, 0.0, player.global_position.z)
	# 목표 반지름은 시간이 지나면 감쇠 (소음이 멈추면 점점 줄어듦)
	_target_radius = maxf(_target_radius - DECAY_RATE * delta, 0.0)
	# 표시 반지름은 목표로 부드럽게 추적 (상승은 빠르게, 하강은 느리게)
	var k := 1.0 - exp(-(UP_RESPONSE if _target_radius >= _current_radius else DOWN_RESPONSE) * delta)
	_current_radius = lerpf(_current_radius, _target_radius, k)
	# scale로 반지름을 균일하게 확대/축소 (재생성 없이 매끈한 원 유지)
	scale.x = _current_radius
	scale.z = _current_radius
