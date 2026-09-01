extends RefCounted

## 수색 완료 컨테이너(차량/집)를 그레이스케일로 표시하는 공용 도우미.
## 각 메시 표면을 오버라이드 재질로 교체하므로 공용 GLB 리소스는 오염되지 않는다.

const GRAY_SHADER := preload("res://resources/shaders/search_grayscale.gdshader")


static func apply_grayscale(root: Node3D) -> void:
	for mi in root.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		if m.mesh == null or m.mesh.get_surface_count() == 0:
			continue
		for s in m.mesh.get_surface_count():
			var base: Material = m.mesh.surface_get_material(s)
			if base is StandardMaterial3D:
				var sm := base as StandardMaterial3D
				var rep := ShaderMaterial.new()
				rep.shader = GRAY_SHADER
				rep.set_shader_parameter("albedo_tex", sm.albedo_texture)
				rep.set_shader_parameter("base_color", sm.albedo_color)
				m.set_surface_override_material(s, rep)


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