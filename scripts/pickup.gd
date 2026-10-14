extends Node3D
## Coins, power-ups and the roof chest. Dropped ones pop out on an arc and land; coins are
## pulled toward you when you get close.

const KINDS_POWER := ["heart", "shield", "allies"]

var main
var kind := "coin"
var vel := Vector3.ZERO
var settled := true
var _t := 0.0
var _visual: Node3D


func _ready() -> void:
	add_to_group("pickup")
	_t = randf() * 5.0
	_visual = Node3D.new()
	add_child(_visual)
	match kind:
		"coin":
			var c := _part(CylinderMesh.new(), Color("ffd34d"), Vector3(0.22, 0.06, 0.22), Vector3.ZERO, true)
			c.rotation.x = PI / 2.0
		"heart":
			_part(SphereMesh.new(), Color("ff5d7a"), Vector3(0.16, 0, 0), Vector3(-0.1, 0.08, 0), true)
			_part(SphereMesh.new(), Color("ff5d7a"), Vector3(0.16, 0, 0), Vector3(0.1, 0.08, 0), true)
			var tip := _part(CylinderMesh.new(), Color("ff5d7a"), Vector3(0.25, 0.3, 0), Vector3(0, -0.1, 0), true)
			(tip.mesh as CylinderMesh).bottom_radius = 0.0
		"shield":
			_part(SphereMesh.new(), Color(0.5, 0.9, 1.0, 0.5), Vector3(0.28, 0, 0), Vector3.ZERO, true)
			_part(SphereMesh.new(), Color(1, 1, 1), Vector3(0.1, 0, 0), Vector3.ZERO, true)
		"allies":
			_part(SphereMesh.new(), Color("6ee7c8"), Vector3(0.24, 0, 0), Vector3.ZERO, true)
			for sx in [-0.08, 0.08]:
				_part(SphereMesh.new(), Color(0.1, 0.1, 0.15), Vector3(0.05, 0, 0), Vector3(sx, 0.06, 0.2), false)
		"chest":
			_part(BoxMesh.new(), Color("9a5b2e"), Vector3(0.8, 0.45, 0.55), Vector3.ZERO, false)
			_part(BoxMesh.new(), Color("ffd34d"), Vector3(0.84, 0.12, 0.59), Vector3(0, 0.25, 0), true)
			_part(BoxMesh.new(), Color("ffd34d"), Vector3(0.14, 0.18, 0.04), Vector3(0, 0.08, 0.29), true)
	if kind != "coin" and kind != "chest":
		var l := Label3D.new()
		l.text = kind.to_upper()
		l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		l.font_size = 28
		l.outline_size = 8
		l.pixel_size = 0.01
		l.position.y = 0.55
		add_child(l)


func _part(mesh: PrimitiveMesh, c: Color, size: Vector3, pos: Vector3, glow: bool) -> MeshInstance3D:
	if mesh is SphereMesh:
		(mesh as SphereMesh).radius = size.x
		(mesh as SphereMesh).height = size.x * 2.0
	elif mesh is CylinderMesh:
		(mesh as CylinderMesh).top_radius = size.x
		(mesh as CylinderMesh).bottom_radius = size.x
		(mesh as CylinderMesh).height = size.y
	elif mesh is BoxMesh:
		(mesh as BoxMesh).size = size
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.25
	m.metallic = 0.4 if c == Color("ffd34d") else 0.0
	if c.a < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if glow:
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = 0.25
	mi.material_override = m
	mi.position = pos
	_visual.add_child(mi)
	return mi


func _process(delta: float) -> void:
	_t += delta
	if not settled:
		vel.y -= 14.0 * delta
		var from := global_position
		var to := from + vel * delta
		var q := PhysicsRayQueryParameters3D.create(from, to + Vector3.DOWN * 0.3)
		q.collide_with_bodies = true
		var hit := get_world_3d().direct_space_state.intersect_ray(q)
		if not hit.is_empty() and vel.y < 0.0 and not (hit["collider"] is RigidBody3D):
			var p: Vector3 = hit["position"]
			global_position = p + Vector3.UP * 0.35
			settled = true
		else:
			global_position = to
			if to.y < -5.0:
				queue_free()
				return
	if kind == "chest":
		_visual.rotation.y += delta * 0.6
	else:
		_visual.rotation.y += delta * 3.0
		_visual.position.y = sin(_t * 3.0) * 0.08

	var p = main.player
	if not is_instance_valid(p) or p.dead:
		return
	var d: Vector3 = p.global_position - global_position
	var dist := d.length()
	if settled and kind == "coin" and dist < 2.8:
		global_position += d.normalized() * minf(dist, (12.0 - dist * 3.0) * delta)
	if dist < (1.0 if kind == "chest" else 0.75):
		main.collect(self)
		queue_free()
