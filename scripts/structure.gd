extends StaticBody3D
## Things you build with coins. Turrets shoot, lasers burn, barracks spawn allies, spike
## traps stab whatever walks over them, net traps catch the first enemy that steps in.
## Enemies treat turrets, lasers and barracks as targets and will attack them.

const STATS := {
	"turret": {"name": "TURRET", "cost": 15, "hp": 120.0},
	"laser": {"name": "LASER", "cost": 30, "hp": 100.0},
	"barracks": {"name": "BARRACKS", "cost": 25, "hp": 200.0},
	"spikes": {"name": "SPIKES", "cost": 8, "hp": 9999.0},
	"net": {"name": "NET TRAP", "cost": 10, "hp": 9999.0},
}

var main
var kind := "turret"
var team := "player"
var hp := 100.0
var max_hp := 100.0
var dead := false
var radius := 0.5
var linear_velocity := Vector3.ZERO
var _cd := 0.5
var _head: Node3D
var _beam: MeshInstance3D
var _crystal_mat: StandardMaterial3D
var _spikes: Node3D
var _allies: Array = []
var _flash := 0.0
var _mats: Array[StandardMaterial3D] = []


func _ready() -> void:
	add_to_group("structure")
	max_hp = STATS[kind]["hp"]
	hp = max_hp
	if kind in ["turret", "laser", "barracks"]:
		add_to_group("target_structure")
		var col := CollisionShape3D.new()
		var shape := CylinderShape3D.new()
		shape.radius = 0.4
		shape.height = 1.0
		col.shape = shape
		col.position.y = 0.5
		add_child(col)
	match kind:
		"turret":
			_part(CylinderMesh.new(), Vector3(0.4, 0.5, 0), Vector3(0, 0.25, 0), Color("6b7385"))
			_head = Node3D.new()
			_head.position.y = 0.65
			add_child(_head)
			_part(SphereMesh.new(), Vector3(0.3, 0, 0), Vector3.ZERO, Color("8fd3ff"), _head)
			_part(BoxMesh.new(), Vector3(0.1, 0.1, 0.5), Vector3(0, 0, 0.3), Color("3b4a6b"), _head)
		"laser":
			_part(CylinderMesh.new(), Vector3(0.25, 1.1, 0), Vector3(0, 0.55, 0), Color("dfe6ee"))
			var crystal := _part(SphereMesh.new(), Vector3(0.22, 0, 0), Vector3(0, 1.25, 0), Color("ff4d6d"))
			crystal.scale = Vector3(0.8, 1.4, 0.8)
			_crystal_mat = crystal.material_override
			_crystal_mat.emission_enabled = true
			_crystal_mat.emission = Color("ff4d6d")
			_crystal_mat.emission_energy_multiplier = 1.0
			_beam = MeshInstance3D.new()
			var bm := BoxMesh.new()
			bm.size = Vector3(0.07, 0.07, 1.0)
			_beam.mesh = bm
			var beam_mat := StandardMaterial3D.new()
			beam_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			beam_mat.albedo_color = Color(1.0, 0.3, 0.4)
			_beam.material_override = beam_mat
			_beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			_beam.top_level = true
			_beam.visible = false
			add_child(_beam)
		"barracks":
			_part(BoxMesh.new(), Vector3(0.9, 0.6, 0.8), Vector3(0, 0.3, 0), Color("c9a27a"))
			var roof := _part(CylinderMesh.new(), Vector3(0.0, 0.45, 0), Vector3(0, 0.82, 0), Color("6ee7c8"))
			(roof.mesh as CylinderMesh).bottom_radius = 0.65
			(roof.mesh as CylinderMesh).radial_segments = 4
			_part(BoxMesh.new(), Vector3(0.3, 0.4, 0.05), Vector3(0, 0.2, 0.41), Color("5e3d24"))
		"spikes":
			_part(BoxMesh.new(), Vector3(0.9, 0.06, 0.9), Vector3(0, 0.03, 0), Color("6b7385"))
			_spikes = Node3D.new()
			_spikes.position.y = -0.15
			add_child(_spikes)
			for ix in 3:
				for iz in 3:
					var s := _part(CylinderMesh.new(), Vector3(0.0, 0.3, 0), Vector3(-0.28 + ix * 0.28, 0.15, -0.28 + iz * 0.28), Color("dfe6ee"), _spikes)
					(s.mesh as CylinderMesh).bottom_radius = 0.07
		"net":
			_part(BoxMesh.new(), Vector3(0.9, 0.04, 0.9), Vector3(0, 0.02, 0), Color("4c6b3a"))
			for i in 3:
				var ring := MeshInstance3D.new()
				var tm := TorusMesh.new()
				tm.inner_radius = 0.12 + i * 0.12
				tm.outer_radius = 0.15 + i * 0.12
				ring.mesh = tm
				ring.material_override = _mat(Color("2f4a24"))
				ring.position.y = 0.05
				add_child(ring)


func _mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.5
	m.emission_enabled = true
	m.emission = Color(1, 1, 1)
	m.emission_energy_multiplier = 0.0
	_mats.append(m)
	return m


func _part(mesh: PrimitiveMesh, size: Vector3, pos: Vector3, c: Color, parent: Node3D = null) -> MeshInstance3D:
	if mesh is BoxMesh:
		(mesh as BoxMesh).size = size
	elif mesh is CylinderMesh:
		(mesh as CylinderMesh).top_radius = size.x
		(mesh as CylinderMesh).bottom_radius = size.x
		(mesh as CylinderMesh).height = size.y
	elif mesh is SphereMesh:
		(mesh as SphereMesh).radius = size.x
		(mesh as SphereMesh).height = size.x * 2.0
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = _mat(c)
	mi.position = pos
	(parent if parent else self).add_child(mi)
	return mi


func stunned(_s: float) -> void:
	pass


func take_damage(amount: float, _push := Vector3.ZERO) -> void:
	if dead or max_hp > 9000.0:
		return
	hp -= amount
	_flash = 1.0
	main.fx.float_text(global_position + Vector3.UP * 1.3, str(roundi(amount)), Color("ffb0b0"), 34)
	if hp <= 0.0:
		dead = true
		main.fx.burst(global_position + Vector3.UP * 0.5, Color("9aa3ad"), 16)
		main.fx.dust(global_position)
		main.sfx.play("pop", global_position, 0.6)
		queue_free()


func _nearest_enemy(max_d: float):
	var best = null
	var best_d := max_d
	for e in get_tree().get_nodes_in_group("enemy"):
		if e.dead:
			continue
		var d: float = (e.global_position - global_position).length()
		if d < best_d:
			best = e
			best_d = d
	return best


func _process(delta: float) -> void:
	_flash = maxf(_flash - delta * 5.0, 0.0)
	for m in _mats:
		m.emission_energy_multiplier = _flash
	if dead:
		return
	_cd -= delta
	match kind:
		"turret":
			var e = _nearest_enemy(7.5)
			if e:
				var d: Vector3 = e.global_position - _head.global_position
				_head.rotation.y = lerp_angle(_head.rotation.y, atan2(d.x, d.z), 10.0 * delta)
				if _cd <= 0.0:
					_cd = 0.55
					var muzzle := _head.global_position + Vector3(sin(_head.rotation.y), 0, cos(_head.rotation.y)) * 0.55
					main.shoot(muzzle, (e.global_position - muzzle).normalized() * 16.0, Color("8fd3ff"), "player", 8.0, 1.0, 0.07, self, false, 1.0)
					main.sfx.play("pew", global_position, 1.3, -6.0)
		"laser":
			var e = _nearest_enemy(6.5)
			_beam.visible = e != null
			if e:
				var from := global_position + Vector3.UP * 1.25
				var to: Vector3 = e.global_position
				_beam.global_position = (from + to) / 2.0
				_beam.look_at(to, Vector3.UP if absf((to - from).normalized().y) < 0.98 else Vector3.RIGHT)
				_beam.scale = Vector3(1.0 + randf() * 0.6, 1.0 + randf() * 0.6, from.distance_to(to))
				_crystal_mat.emission_energy_multiplier = 2.0 + randf()
				if _cd <= 0.0:
					_cd = 0.2
					e.take_damage(6.0)
					main.fx.burst(to, Color(1.0, 0.4, 0.5), 2)
		"barracks":
			_allies = _allies.filter(func(a) -> bool: return is_instance_valid(a) and not a.dead)
			if _cd <= 0.0:
				_cd = 15.0
				if _allies.size() < 2:
					var spot := global_position + Vector3(0, 0.6, 0.9)
					var ally = main.spawn_enemy("ally", spot)
					ally.lifetime = -1.0
					_allies.append(ally)
					main.fx.dust(spot)
		"spikes":
			_spikes.position.y = lerpf(_spikes.position.y, -0.15, 6.0 * delta)
			if _cd <= 0.0:
				for e in get_tree().get_nodes_in_group("enemy"):
					var d: Vector3 = e.global_position - global_position
					if not e.dead and Vector2(d.x, d.z).length() < 0.6 and d.y < 1.0:
						_cd = 0.7
						_spikes.position.y = 0.05
						e.take_damage(18.0, Vector3.UP * 4.0)
						main.sfx.play("punch", global_position, 1.4)
						break
		"net":
			for e in get_tree().get_nodes_in_group("enemy"):
				var d: Vector3 = e.global_position - global_position
				if not e.dead and Vector2(d.x, d.z).length() < 0.6 and d.y < 1.0:
					e.netted(6.0)
					main.sfx.play("net", global_position)
					main.fx.float_text(global_position + Vector3.UP, "CAUGHT!", Color("b6ff8a"))
					queue_free()
					break
