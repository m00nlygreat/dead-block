class_name SwingTrail
extends MeshInstance3D

const SWEEP_TIME := 0.13
const FADE_TIME := 0.24
const STEPS := 20

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
	mat.no_depth_test = true
	material_override = mat
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


func play(reach: float, arc_deg: float, color: Color) -> void:
	_reach = reach
	_arc = arc_deg
	_color = color
	_t = 0.0
	_active = true
	visible = true
	_rebuild(0.0)


func _rebuild(t: float) -> void:
	var sweep_f := clampf(t / SWEEP_TIME, 0.0, 1.0)
	_mesh.clear_surfaces()
	_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	var half := deg_to_rad(_arc * 0.5)
	var last_center_a := 0.0
	var drawn := false
	for i in STEPS + 1:
		var f := float(i) / STEPS
		var spawn_time := f * SWEEP_TIME
		if spawn_time > t:
			break
		var age := t - spawn_time
		var fade := 1.0 - clampf(age / FADE_TIME, 0.0, 1.0)
		var ang := lerpf(half, -half, f)
		var dir := Vector3(sin(ang), 0.0, -cos(ang))
		var center_boost := 1.0 - absf(f - 0.5) * 2.0
		last_center_a = ((center_boost * 0.85 + 0.15) * fade)
		var c := Color(_color.r, _color.g, _color.b, last_center_a)
		_mesh.surface_set_color(Color(c.r, c.g, c.b, c.a))
		_mesh.surface_add_vertex(dir * (_reach * 0.4) + Vector3.UP * 0.1)
		_mesh.surface_set_color(Color(c.r, c.g, c.b, c.a * 0.2))
		_mesh.surface_add_vertex(dir * _reach + Vector3.UP * 0.45)
		drawn = true
	if drawn:
		_mesh.surface_end()
	else:
		_mesh.clear_surfaces()
