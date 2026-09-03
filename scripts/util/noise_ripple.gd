class_name NoiseRipple
extends MeshInstance3D

## 상시 유지되는 소음 차트: 플레이어 중심 반투명 채워진 원(디스크)의 반지름으로 현재 소음량을 표현한다.

const SEGMENTS := 48
const GROUND_Y := 0.04
const COLOR := Color(1.0, 1.0, 1.0)
const MAX_RADIUS := 30.0
const UP_RESPONSE := 8.0
const DOWN_RESPONSE := 4.0
const DECAY_RATE := 5.0

var _target_radius := 0.0
var _current_radius := 0.0
var _im := ImmediateMesh.new()


func _ready() -> void:
	mesh = _im
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.vertex_color_use_as_albedo = true
	mat.no_depth_test = false
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.render_priority = 5
	material_override = mat
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
	_rebuild()


## 테두리 없는 반투명 채워진 원: 발치 중심 디스크. 양면 렌더링으로 어떤 시점에서도 풀 원으로 보인다.
func _rebuild() -> void:
	_im.clear_surfaces()
	if _current_radius < 0.01:
		return
	_im.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in SEGMENTS:
		var a0 := TAU * float(i) / SEGMENTS
		var a1 := TAU * float(i + 1) / SEGMENTS
		_im.surface_set_color(Color(COLOR.r, COLOR.g, COLOR.b, 0.055))
		_im.surface_add_vertex(Vector3(0.0, GROUND_Y, 0.0))
		_im.surface_set_color(Color(COLOR.r, COLOR.g, COLOR.b, 0.055))
		_im.surface_add_vertex(Vector3(cos(a0) * _current_radius, GROUND_Y, sin(a0) * _current_radius))
		_im.surface_set_color(Color(COLOR.r, COLOR.g, COLOR.b, 0.055))
		_im.surface_add_vertex(Vector3(cos(a1) * _current_radius, GROUND_Y, sin(a1) * _current_radius))
	_im.surface_end()
