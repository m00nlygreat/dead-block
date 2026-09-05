extends RefCounted

## 수색 완료 컨테이너(차량/집)를 그레이스케일로 표시하는 공용 도우미.
## 각 메시 표면을 오버라이드 재질로 교체하므로 공용 GLB 리소스는 오염되지 않는다.

const GRAY_SHADER := preload("res://resources/shaders/search_grayscale.gdshader")

# 같은 GLB를 쓰는 집·차량은 베이스 색·텍스처가 같으므로 그레이 재질을 공유한다.
# (표면마다 ShaderMaterial.new()를 하면 털린 구조물 수백 개 분량이
# 청크 스트리밍마다 쌓여 웹 메모리를 압박한다.)
static var _gray_cache: Dictionary = {}


static func _gray_for(tex: Texture2D, col: Color) -> ShaderMaterial:
	var tex_id := 0
	if tex != null:
		tex_id = tex.get_instance_id()
	var key := "%d|%s" % [tex_id, col.to_html()]
	if not _gray_cache.has(key):
		var rep := ShaderMaterial.new()
		rep.shader = GRAY_SHADER
		rep.set_shader_parameter("albedo_tex", tex)
		rep.set_shader_parameter("base_color", col)
		_gray_cache[key] = rep
	return _gray_cache[key]


static func apply_grayscale(root: Node3D) -> void:
	for mi in root.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		if m.mesh == null or m.mesh.get_surface_count() == 0:
			continue
		for s in m.mesh.get_surface_count():
			var base: Material = m.mesh.surface_get_material(s)
			if base is StandardMaterial3D:
				var sm := base as StandardMaterial3D
				m.set_surface_override_material(s, _gray_for(sm.albedo_texture, sm.albedo_color))


## root 서브트리에 그레이스케일 오버라이드가 적용됐는지 검사(테스트용).
static func is_grayscale_applied(root: Node3D) -> bool:
	for mi in root.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		if m.mesh == null:
			continue
		for s in m.mesh.get_surface_count():
			if m.get_surface_override_material(s) is ShaderMaterial:
				return true
	return false