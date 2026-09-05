class_name SwingTrail
extends MeshInstance3D

## 근접 휘두름 궤적/사거리 표시.
## 휘두르는 동안 부채꼴 필(궤적)이 쓸리듯 펼쳐지고, 사거리 경계(바깥 호 +
## 양쪽 측면선)를 밝은 선으로 그려 실제 판정 범위(reach/arc)를 드러낸다.
## StandardMaterial3D(unshaded) + ImmediateMesh만 사용 — 웹(Compatibility) 호환.

const SWEEP_TIME := 0.13
const FADE_TIME := 0.24
const STEPS := 20
const INNER_FRAC := 0.4
const INNER_Y := 0.1
const OUTER_Y := 0.45
## 필 바깥쪽 끝 알파 비율(안쪽 대비) — 사거리가 탑다운에서도 보이도록 진하게.
const EDGE_KEEP := 0.45

var _active := false
var _t := 0.0
var _reach := 2.0
var _arc := 90.0
var _color := Color.WHITE
var _mesh := ImmediateMesh.new()


func _ready() -> void:
	set_mesh(_mesh)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.vertex_color_use_as_albedo = true
	# 탑다운 카메라가 뒷면을 보므로 양면 렌더링이 필수.
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	# 바닥·벽에 가려지지 않고 사거리가 항상 보이도록 깊이 테스트를 끈다.
	mat.no_depth_test = true
	material_override = mat
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	visible = false


func _process(delta: float) -> void:
	if not _active:
		return
	_t += delta
	if _t >= SWEEP_TIME + FADE_TIME:
		_active = false
		visible = false
		return
	_rebuild(_t)


func is_playing() -> bool:
	return _active


func play(reach: float, arc_deg: float, color: Color) -> void:
	_reach = reach
	_arc = arc_deg
	_color = color
	_t = 0.0
	_active = true
	visible = true
	_rebuild(0.0)


func _slice_dir(f: float) -> Vector3:
	var half := deg_to_rad(_arc * 0.5)
	var ang := lerpf(half, -half, f)
	return Vector3(sin(ang), 0.0, -cos(ang))


func _fade_at(f: float, t: float) -> float:
	var age := t - f * SWEEP_TIME
	return 1.0 - clampf(age / FADE_TIME, 0.0, 1.0)


func _rebuild(t: float) -> void:
	_mesh.clear_surfaces()
	# 드러난 조각 수 — 처음부터 최소 2조각(시작 변 가시)으로 사각형 퇴화 방지.
	var revealed := 0
	for i in STEPS + 1:
		var f := float(i) / STEPS
		if f * SWEEP_TIME <= t:
			revealed += 1
		else:
			break
	revealed = maxi(revealed, 2)
	revealed = mini(revealed, STEPS + 1)
	# --- 표면 0: 부채꼴 필(궤적) ---
	_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	for i in revealed:
		var f := float(i) / STEPS
		var fade := _fade_at(f, t)
		var dir := _slice_dir(f)
		var center_boost := 1.0 - absf(f - 0.5) * 2.0
		var a_center: float = (center_boost * 0.85 + 0.15) * fade
		var c := Color(_color.r, _color.g, _color.b, a_center)
		_mesh.surface_set_color(c)
		_mesh.surface_add_vertex(dir * (_reach * INNER_FRAC) + Vector3.UP * INNER_Y)
		var ce := Color(_color.r, _color.g, _color.b, a_center * EDGE_KEEP)
		_mesh.surface_set_color(ce)
		_mesh.surface_add_vertex(dir * _reach + Vector3.UP * OUTER_Y)
	_mesh.surface_end()
	# --- 표면 1: 사거리 바깥 호(밝은 테두리) ---
	_mesh.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
	for i in revealed:
		var f := float(i) / STEPS
		var fade := _fade_at(f, t)
		var c := Color(_color.r, _color.g, _color.b, 0.9 * fade)
		_mesh.surface_set_color(c)
		_mesh.surface_add_vertex(_slice_dir(f) * _reach + Vector3.UP * (OUTER_Y + 0.02))
	_mesh.surface_end()
	# --- 표면 2: 양쪽 측면선(호의 양 끝 = 휘두름 각도 경계) ---
	_mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	for k in [0, revealed - 1]:
		var f := float(k) / STEPS
		var fade := _fade_at(f, t)
		var c := Color(_color.r, _color.g, _color.b, 0.9 * fade)
		var dir := _slice_dir(f)
		_mesh.surface_set_color(c)
		_mesh.surface_add_vertex(dir * (_reach * INNER_FRAC) + Vector3.UP * INNER_Y)
		_mesh.surface_set_color(c)
		_mesh.surface_add_vertex(dir * _reach + Vector3.UP * (OUTER_Y + 0.02))
	_mesh.surface_end()
