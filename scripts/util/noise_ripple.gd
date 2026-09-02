class_name NoiseRipple
extends MeshInstance3D

const DURATION := 0.45
const SEGMENTS := 48
const RING_THICKNESS := 0.18
const Y_OFFSET := 0.08

var _t := 0.0
var _max_radius := 5.0
var _color := Color.WHITE
var _active := false
var _im := ImmediateMesh.new()


func _ready() -> void:
	mesh = _im
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.vertex_color_use_as_albedo = true
	mat.no_depth_test = false
	mat.render_priority = 10
	material_override = mat
	visible = false


func start(radius: float, color: Color) -> void:
	_max_radius = radius
	_color = color
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
	var alpha := clampf(1.0 - progress, 0.0, 1.0) * 0.55
	_im.clear_surfaces()
	if radius < 0.01:
		return
	var inner := radius - RING_THICKNESS * (1.0 - progress * 0.5)
	inner = maxf(inner, 0.0)
	_im.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	for i in SEGMENTS + 1:
		var angle := TAU * float(i % SEGMENTS) / SEGMENTS
		var cx := cos(angle)
		var cz := sin(angle)
		_im.surface_set_color(Color(_color.r, _color.g, _color.b, alpha * 0.3))
		_im.surface_add_vertex(Vector3(cx * inner, Y_OFFSET, cz * inner))
		_im.surface_set_color(Color(_color.r, _color.g, _color.b, alpha))
		_im.surface_add_vertex(Vector3(cx * radius, Y_OFFSET, cz * radius))
	_im.surface_end()
