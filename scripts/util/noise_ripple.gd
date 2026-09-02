class_name NoiseRipple
extends MeshInstance3D

const DURATION := 0.45
const SEGMENTS := 48
const RING_THICKNESS := 0.4
const WALL_HEIGHT := 0.7
const GROUND_Y := 0.05
const COLOR := Color(0.75, 0.85, 1.0)

var _t := 0.0
var _max_radius := 5.0
var _active := false
var _im := ImmediateMesh.new()


func _ready() -> void:
	mesh = _im
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.vertex_color_use_as_albedo = true
	mat.no_depth_test = true
	mat.render_priority = 10
	material_override = mat
	visible = false


func start(radius: float) -> void:
	_max_radius = radius
	_t = 0.0
	_active = true
	visible = true
	_rebuild(0.0)


func _process(delta: float) -> void:
	if not _active:
		return
	_t += delta
	if _t >= DURATION:
		_active = false
		visible = false
		queue_free()
		return
	_rebuild(_t)


func _rebuild(t: float) -> void:
	var progress := t / DURATION
	var radius := _max_radius * progress
	var alpha := clampf(1.0 - progress, 0.0, 1.0) * 0.7
	_im.clear_surfaces()
	if radius < 0.01:
		return
	var inner := maxf(radius - RING_THICKNESS * (1.0 - progress * 0.5), 0.0)

	# 지면에 깔리는 원형 링 + 원주를 따라 세운 반투명 벽(경사 탑다운 카메라에서 원형 윤곽이 보이도록)
	_im.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	for i in SEGMENTS + 1:
		var angle := TAU * float(i % SEGMENTS) / SEGMENTS
		var cx := cos(angle)
		var cz := sin(angle)
		# 지면 링
		_im.surface_set_color(Color(COLOR.r, COLOR.g, COLOR.b, alpha * 0.25))
		_im.surface_add_vertex(Vector3(cx * inner, GROUND_Y, cz * inner))
		_im.surface_set_color(Color(COLOR.r, COLOR.g, COLOR.b, alpha * 0.5))
		_im.surface_add_vertex(Vector3(cx * radius, GROUND_Y, cz * radius))
	_im.surface_end()

	# 원주 수직 벽
	_im.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	for i in SEGMENTS + 1:
		var angle := TAU * float(i % SEGMENTS) / SEGMENTS
		var cx := cos(angle)
		var cz := sin(angle)
		_im.surface_set_color(Color(COLOR.r, COLOR.g, COLOR.b, alpha * 0.15))
		_im.surface_add_vertex(Vector3(cx * radius, GROUND_Y, cz * radius))
		_im.surface_set_color(Color(COLOR.r, COLOR.g, COLOR.b, alpha * 0.55))
		_im.surface_add_vertex(Vector3(cx * radius, GROUND_Y + WALL_HEIGHT * (1.0 - progress * 0.4), cz * radius))
	_im.surface_end()
