extends RefCounted
## Builds hats and glasses onto a blob's visual node. Used in game and on the menu podium.


static func dress(visual: Node3D, r: float, hat: String, glasses: String) -> void:
	for c in visual.get_children():
		if c.has_meta("cosmetic"):
			c.queue_free()
	var root := Node3D.new()
	root.set_meta("cosmetic", true)
	visual.add_child(root)
	var top := r * 0.82
	match hat:
		"cap":
			var dome := _mesh(root, _sphere(r * 0.62), Color("e63946"), Vector3(0, top - r * 0.12, 0))
			dome.scale = Vector3(1, 0.55, 1)
			_mesh(root, _box(Vector3(r * 0.9, r * 0.06, r * 0.6)), Color("e63946"), Vector3(0, top - r * 0.08, r * 0.55))
			_mesh(root, _sphere(r * 0.08), Color("ffffff"), Vector3(0, top + r * 0.2, 0))
		"party":
			var cone := _mesh(root, _cone(r * 0.32, r * 0.8), Color("ff4fa3"), Vector3(0, top + r * 0.32, 0))
			cone.rotation.z = 0.15
			_mesh(root, _torus(r * 0.22, r * 0.3), Color("ffe066"), Vector3(0, top + r * 0.05, 0))
			_mesh(root, _sphere(r * 0.12), Color("8ae3ff"), Vector3(-r * 0.11, top + r * 0.74, 0), true)
		"chef":
			_mesh(root, _cyl(r * 0.42, r * 0.42), Color("ffffff"), Vector3(0, top + r * 0.12, 0))
			var puff := _mesh(root, _sphere(r * 0.55), Color("ffffff"), Vector3(0, top + r * 0.48, 0))
			puff.scale = Vector3(1, 0.6, 1)
		"headphones":
			var band := _mesh(root, _torus(r * 0.86, r * 0.98), Color("2b2d42"), Vector3(0, r * 0.15, 0))
			band.rotation.z = PI / 2.0
			band.scale = Vector3(1, 1, 0.6)
			for s in [-1.0, 1.0]:
				var cup := _mesh(root, _cyl(r * 0.26, r * 0.18), Color("ef476f"), Vector3(s * r * 0.95, r * 0.1, 0))
				cup.rotation.z = PI / 2.0
		"horns":
			for s in [-1.0, 1.0]:
				var horn := _mesh(root, _cone(r * 0.14, r * 0.55), Color("fff3d6"), Vector3(s * r * 0.45, top + r * 0.05, 0))
				horn.rotation.z = -s * 0.6
		"cowboy":
			_mesh(root, _cyl(r * 0.95, r * 0.05), Color("9c6b3c"), Vector3(0, top - r * 0.02, 0))
			_mesh(root, _cyl(r * 0.45, r * 0.42), Color("9c6b3c"), Vector3(0, top + r * 0.2, 0))
			_mesh(root, _cyl(r * 0.46, r * 0.08), Color("3d2a17"), Vector3(0, top + r * 0.04, 0))
		"halo":
			var h := _mesh(root, _torus(r * 0.42, r * 0.52), Color("ffe066"), Vector3(0, top + r * 0.38, 0), true)
			h.set_meta("spin", 2.0)
		"crown":
			_mesh(root, _cyl(r * 0.42, r * 0.22), Color("ffd34d"), Vector3(0, top + r * 0.05, 0), true)
			for i in 5:
				var a := TAU * i / 5.0
				_mesh(root, _cone(r * 0.09, r * 0.28), Color("ffd34d"), Vector3(cos(a) * r * 0.36, top + r * 0.28, sin(a) * r * 0.36), true)
			_mesh(root, _sphere(r * 0.08), Color("ff4d6d"), Vector3(0, top + r * 0.08, r * 0.42), true)
	var ey := r * 0.2
	var ez := r * 0.86
	match glasses:
		"shades":
			for s in [-1.0, 1.0]:
				_mesh(root, _box(Vector3(r * 0.38, r * 0.22, r * 0.06)), Color("111118"), Vector3(s * r * 0.38, ey, ez))
			_mesh(root, _box(Vector3(r * 0.4, r * 0.05, r * 0.05)), Color("111118"), Vector3(0, ey + r * 0.06, ez))
		"monocle":
			var m := _mesh(root, _torus(r * 0.15, r * 0.2), Color("ffd34d"), Vector3(r * 0.4, ey, ez), true)
			m.rotation.x = PI / 2.0
		"star":
			for s in [-1.0, 1.0]:
				var st := MeshInstance3D.new()
				var cm := CylinderMesh.new()
				cm.top_radius = r * 0.22
				cm.bottom_radius = r * 0.22
				cm.height = r * 0.05
				cm.radial_segments = 5
				st.mesh = cm
				st.material_override = _mat(Color("ff4fa3"), true)
				st.position = Vector3(s * r * 0.38, ey, ez)
				st.rotation.x = PI / 2.0
				root.add_child(st)


static func _mat(c: Color, glow := false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.35
	if glow:
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = 0.35
		m.metallic = 0.3
	return m


static func _mesh(parent: Node3D, mesh: Mesh, c: Color, pos: Vector3, glow := false) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = _mat(c, glow)
	mi.position = pos
	parent.add_child(mi)
	return mi


static func _sphere(r: float) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	return s


static func _box(size: Vector3) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = size
	return b


static func _cyl(r: float, h: float) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = r
	c.bottom_radius = r
	c.height = h
	return c


static func _cone(r: float, h: float) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = 0.0
	c.bottom_radius = r
	c.height = h
	return c


static func _torus(inner: float, outer: float) -> TorusMesh:
	var t := TorusMesh.new()
	t.inner_radius = inner
	t.outer_radius = outer
	return t
