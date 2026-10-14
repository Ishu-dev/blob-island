extends AnimatableBody3D
## A little train that crosses the island every so often. The rails glow red and the horn
## sounds before it comes. Anything on the tracks gets sent flying.

const SPEED := 16.0
const SPAN := 46.0
const LENGTH := 8.0

var main
var rail_mat: StandardMaterial3D
var _state := "wait"
var _timer := 8.0
var _dir := 1.0
var _hit := {}
var _smoke := 0.0
var _chimney: Node3D


func _ready() -> void:
	sync_to_physics = false
	position.x = -SPAN
	_car(0.0, 2.6, Color("e5484d"), true)
	_car(-2.8, 2.4, Color("ffc94d"), false)
	_car(-5.4, 2.4, Color("4dabf7"), false)


func _car(x: float, length: float, c: Color, engine: bool) -> void:
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(length, 1.3, 1.5)
	col.shape = shape
	col.position = Vector3(x, 0.85, 0)
	add_child(col)
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.4
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color("2b2b33")
	var glass := StandardMaterial3D.new()
	glass.albedo_color = Color("bfe9ff")
	glass.emission_enabled = true
	glass.emission = Color("bfe9ff")
	glass.emission_energy_multiplier = 0.3
	_mesh(BoxMesh.new(), Vector3(length, 0.9, 1.4), Vector3(x, 0.75, 0), m)
	_mesh(BoxMesh.new(), Vector3(length - 0.2, 0.12, 1.5), Vector3(x, 1.25, 0), dark)
	for wx in [-length * 0.25, length * 0.25]:
		_mesh(BoxMesh.new(), Vector3(0.5, 0.3, 1.42), Vector3(x + wx, 0.95, 0), glass)
	for wx in [-length * 0.32, length * 0.32]:
		for wz in [-0.72, 0.72]:
			var w := _mesh(CylinderMesh.new(), Vector3(0.25, 0.1, 0.25), Vector3(x + wx, 0.28, wz), dark)
			w.rotation.x = PI / 2.0
	if engine:
		_mesh(BoxMesh.new(), Vector3(0.9, 0.6, 1.3), Vector3(x - 0.7, 1.55, 0), m)
		_chimney = _mesh(CylinderMesh.new(), Vector3(0.18, 0.5, 0.18), Vector3(x + 0.8, 1.55, 0), dark)
		var lamp := StandardMaterial3D.new()
		lamp.albedo_color = Color("fff3a0")
		lamp.emission_enabled = true
		lamp.emission = Color("fff3a0")
		lamp.emission_energy_multiplier = 2.0
		_mesh(SphereMesh.new(), Vector3(0.2, 0.2, 0.2), Vector3(x + length / 2.0, 0.9, 0), lamp)


func _mesh(mesh: PrimitiveMesh, size: Vector3, pos: Vector3, m: Material) -> MeshInstance3D:
	if mesh is BoxMesh:
		(mesh as BoxMesh).size = size
	elif mesh is CylinderMesh:
		var cm := mesh as CylinderMesh
		cm.top_radius = size.x
		cm.bottom_radius = size.x
		cm.height = size.y
	elif mesh is SphereMesh:
		var sm := mesh as SphereMesh
		sm.radius = size.x
		sm.height = size.x * 2.0
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = m
	mi.position = pos
	add_child(mi)
	return mi


func _physics_process(delta: float) -> void:
	match _state:
		"wait":
			_timer -= delta
			if _timer <= 0.0:
				_dir = -_dir
				position.x = -_dir * SPAN
				rotation.y = 0.0 if _dir > 0.0 else PI
				_state = "warn"
				_timer = 2.5
				main.sfx.play("horn", null, 1.0, -4.0)
		"warn":
			_timer -= delta
			rail_mat.emission_energy_multiplier = 2.5 if fmod(_timer, 0.4) < 0.2 else 0.0
			if _timer <= 0.0:
				_state = "run"
				_hit.clear()
				rail_mat.emission_energy_multiplier = 0.0
				main.sfx.play("horn", null, 1.0, -2.0)
		"run":
			position.x += _dir * SPEED * delta
			_fling()
			_smoke -= delta
			if _smoke <= 0.0 and _chimney:
				_smoke = 0.08
				main.fx.puff(_chimney.global_position + Vector3.UP * 0.3)
			if absf(position.x) > SPAN and signf(position.x) == _dir:
				_state = "wait"
				_timer = randf_range(14.0, 22.0)


func _fling() -> void:
	# The engine leads in the travel direction; cars trail behind it.
	var front := position.x + _dir * 1.3
	var back := position.x - _dir * (LENGTH - 1.3)
	var lo := minf(front, back) - 0.4
	var hi := maxf(front, back) + 0.4
	for group in ["actor", "prop"]:
		for n in get_tree().get_nodes_in_group(group):
			var rb := n as RigidBody3D
			if rb == null or _hit.has(rb.get_instance_id()):
				continue
			var p := rb.global_position
			if p.x < lo or p.x > hi or absf(p.z - position.z) > 1.2 or p.y > position.y + 2.2:
				continue
			_hit[rb.get_instance_id()] = true
			var side := signf(p.z - position.z)
			if side == 0.0:
				side = 1.0
			rb.apply_central_impulse(Vector3(_dir * 9.0, 8.0, side * 9.0) * rb.mass)
			if rb is Blob:
				(rb as Blob).take_damage(35.0)
			main.fx.burst(p, Color(1, 1, 1), 8)
			main.sfx.play("slam", p, 1.4)
			main.shake = maxf(main.shake, 0.6)
