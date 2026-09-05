class_name HitFlash
extends Object

static var _mat: StandardMaterial3D


static func flash(root: Node, duration := 0.12) -> void:
	if _mat == null:
		_mat = StandardMaterial3D.new()
		_mat.albedo_color = Color(1.0, 0.18, 0.18)
		_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	var meshes: Array = root.find_children("*", "MeshInstance3D", true, false)
	var targets: Array = []
	var originals: Dictionary = {}
	for mi in meshes:
		if mi.mesh != null and mi.mesh.get_surface_count() > 0:
			targets.append(mi)
			for i in mi.mesh.get_surface_count():
				var orig: Material = mi.get_surface_override_material(i)
				if orig == null:
					orig = mi.mesh.surface_get_material(i)
				originals[mi] = originals.get(mi, [])
				originals[mi].append(orig)
	if targets.is_empty():
		return

	for mi in targets:
		for i in mi.mesh.get_surface_count():
			mi.set_surface_override_material(i, _mat)

	var t := root.get_tree().create_timer(duration)
	t.timeout.connect(func() -> void:
		for mi in targets:
			if not is_instance_valid(mi):
				continue
			for i in mi.mesh.get_surface_count():
				var orig_mat: Material = null
				if originals.has(mi) and originals[mi].size() > i:
					orig_mat = originals[mi][i]
				mi.set_surface_override_material(i, orig_mat)
	)
