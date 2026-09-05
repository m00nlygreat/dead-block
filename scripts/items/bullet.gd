class_name Bullet
extends Area3D

const LIFETIME := 0.8
const TRAIL_FADE_TIME := 0.4
const COLLISION_MASK := 5
const ZOMBIE_MASK := 4
const HIT_RADIUS := 0.35
const TRAIL_COLOR := Color(0.78, 0.78, 0.82, 1.0)
const TRAIL_HALF_WIDTH := 0.03

var _damage := 25.0
var _base_speed := 30.0
var _headshot_chance := 0.0
var _knockback := 0.0
var _stagger := 0.0
var _dir := Vector3.FORWARD
var _perp := Vector3.RIGHT
var _is_collidable := true
var _lifetime := LIFETIME
var _start_pos := Vector3.ZERO
var _trail: ImmediateMesh
var _trail_mat: StandardMaterial3D
var _core: MeshInstance3D
var _light: OmniLight3D
var _hit_shape: SphereShape3D
var _points: Array = []
var _fading := false
var _fade_t := 0.0
var _fade_total := 0


func setup(start_pos: Vector3, dir: Vector3, speed: float, damage: float,
		headshot_chance: float, knockback: float, stagger: float,
		max_range: float) -> void:
	_start_pos = start_pos
	_dir = dir.normalized()
	_perp = Vector3(_dir.z, 0.0, -_dir.x).normalized()
	_base_speed = speed
	_damage = damage
	_headshot_chance = headshot_chance
	_knockback = knockback
	_stagger = stagger
	if max_range > 0.0:
		_lifetime = minf(max_range / maxf(speed, 1.0), 1.5)


func _ready() -> void:
	global_position = _start_pos
	_hit_shape = SphereShape3D.new()
	_hit_shape.radius = HIT_RADIUS
	_trail = ImmediateMesh.new()
	_trail_mat = StandardMaterial3D.new()
	_trail_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_trail_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_trail_mat.vertex_color_use_as_albedo = true
	_trail_mat.no_depth_test = true
	# 수평 리본은 위/아래 한쪽에서만 정면이 되므로 양면 렌더링이 필수다.
	_trail_mat.cull_mode = BaseMaterial3D.CULL_DISABLED

	var mi := MeshInstance3D.new()
	# 궤적 정점은 월드 좌표로 저장되므로 부모(총알) 이동의 영향을 받지 않아야 한다.
	mi.top_level = true
	mi.mesh = _trail
	mi.material_override = _trail_mat
	add_child(mi)

	var core := MeshInstance3D.new()
	_core = core
	var core_mesh := SphereMesh.new()
	core_mesh.radius = 0.06
	core_mesh.height = 0.12
	core_mesh.radial_segments = 8
	core_mesh.rings = 4
	var core_mat := StandardMaterial3D.new()
	core_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	core_mat.albedo_color = Color(1.0, 0.85, 0.35)
	core_mat.emission_enabled = true
	core_mat.emission = Color(1.0, 0.85, 0.35)
	core_mat.emission_energy_multiplier = 2.0
	core.mesh = core_mesh
	core.material_override = core_mat
	add_child(core)

	var light := OmniLight3D.new()
	_light = light
	light.light_color = Color(1.0, 0.8, 0.35)
	light.light_energy = 2.0
	light.omni_range = 3.0
	light.visible = true
	add_child(light)

	_points.append(global_position)
	body_entered.connect(_on_body_entered)
	var timer := get_tree().create_timer(_lifetime)
	timer.timeout.connect(_die_naturally)


func _physics_process(delta: float) -> void:
	if _fading:
		_fade_step(delta)
		return
	var from := global_position
	var to := from + _dir * _base_speed * delta
	global_position = to
	_points.append(global_position)
	_rebuild_trail()
	_check_sweep(from, to)


func _check_sweep(from: Vector3, to: Vector3) -> void:
	if not _is_collidable:
		return
	var space := get_world_3d().direct_space_state
	var motion := to - from
	# 좀비 피격 판정 확대: 구체 캐스트로 먼저 검사한다.
	var shape_params := PhysicsShapeQueryParameters3D.new()
	shape_params.shape = _hit_shape
	shape_params.collision_mask = ZOMBIE_MASK
	shape_params.transform = Transform3D(Basis(), from)
	shape_params.motion = motion
	var fractions: PackedFloat32Array = space.cast_motion(shape_params)
	if fractions[1] < 1.0:
		var contact := from + motion * fractions[1]
		shape_params.transform = Transform3D(Basis(), contact)
		shape_params.motion = Vector3.ZERO
		var rest := space.intersect_shape(shape_params, 1)
		if not rest.is_empty():
			var zbody: Object = rest[0].get("collider")
			if zbody != null and zbody.is_in_group("zombies"):
				global_position = contact
				_handle_zombie_hit(zbody)
				return
	var query := PhysicsRayQueryParameters3D.create(from, to, COLLISION_MASK)
	var hit := space.intersect_ray(query)
	if hit.is_empty():
		return
	global_position = hit["position"]
	var body: Object = hit.get("collider")
	if body != null and body.is_in_group("zombies"):
		_handle_zombie_hit(body)
	else:
		_die_naturally()


func _on_body_entered(body: Node) -> void:
	if not _is_collidable:
		return
	if body.is_in_group("player"):
		return
	if body.is_in_group("zombies") and body.has_method("take_damage"):
		_handle_zombie_hit(body)
		return
	_die_naturally()


func _handle_zombie_hit(zombie: Node) -> void:
	if not _is_collidable:
		return
	_is_collidable = false
	if _headshot_chance > 0.0 and randf() < _headshot_chance:
		zombie.set("hp", 0.0)
		if zombie.has_method("take_damage"):
			zombie.take_damage(1.0, global_position, _knockback, _stagger)
	else:
		zombie.take_damage(_damage, global_position, _knockback, _stagger)
	_fade_out()


func _die_naturally() -> void:
	if not _is_collidable:
		return
	_is_collidable = false
	_fade_out()


func _fade_out() -> void:
	if _fading:
		return
	_fading = true
	_fade_t = 0.0
	_fade_total = _points.size()
	_core.visible = false
	_light.visible = false


func _fade_step(delta: float) -> void:
	_fade_t += delta
	var frac: float = clampf(1.0 - _fade_t / TRAIL_FADE_TIME, 0.0, 1.0)
	var keep: int = int(ceil(float(_fade_total) * frac))
	while _points.size() > keep:
		_points.pop_front()
	if _points.size() < 2:
		queue_free()
		return
	_rebuild_trail()


func _rebuild_trail() -> void:
	_trail.clear_surfaces()
	if _points.size() < 2:
		return
	_trail.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	var n: int = _points.size()
	for i in n:
		var p: Vector3 = _points[i]
		var alpha := lerpf(1.0, 0.0, float(i) / float(n - 1))
		var a := alpha * 0.85
		_trail.surface_set_color(Color(TRAIL_COLOR.r, TRAIL_COLOR.g, TRAIL_COLOR.b, a))
		_trail.surface_add_vertex(p + _perp * TRAIL_HALF_WIDTH)
		_trail.surface_set_color(Color(TRAIL_COLOR.r, TRAIL_COLOR.g, TRAIL_COLOR.b, a * 0.4))
		_trail.surface_add_vertex(p - _perp * TRAIL_HALF_WIDTH)
	_trail.surface_end()