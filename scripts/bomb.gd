extends RigidBody3D
## Thrown bomb. Tumbles through the air, its fuse burns down with sparks and a glow,
## it swells and blinks near the end, then blasts nearby blobs (and other bombs).

const RADIUS := 3.0
const FORCE := 13.0
const DAMAGE := 55.0
const FUSE := 1.5
const WICK_SEGS := 6

var main
var thrower: Node3D
var fuse := FUSE
var _visual: Node3D
var _mat: StandardMaterial3D
var _wick: Array[MeshInstance3D] = []
var _wick_pts: Array[Vector3] = []
var _spark: Node3D
var _spark_core: MeshInstance3D
var _light: OmniLight3D


func _ready() -> void:
	add_to_group("bomb")
	mass = 0.6
	continuous_cd = true
	angular_damp = 1.0
	var pm := PhysicsMaterial.new()
	pm.bounce = 0.3
	pm.friction = 1.0
	physics_material_override = pm

	var col := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = 0.24
	col.shape = shape
	add_child(col)

	_visual = Node3D.new()
	add_child(_visual)

	var shell := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.24
	sm.height = 0.48
	shell.mesh = sm
	_mat = StandardMaterial3D.new()
	_mat.albedo_color = Color(0.13, 0.14, 0.22)
	_mat.roughness = 0.25
	_mat.rim_enabled = true
	_mat.emission_enabled = true
	_mat.emission = Color(1.0, 0.25, 0.15)
	_mat.emission_energy_multiplier = 0.0
	shell.material_override = _mat
	_visual.add_child(shell)

	var cap := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.07
	cm.bottom_radius = 0.09
	cm.height = 0.1
	cap.mesh = cm
	var cap_mat := StandardMaterial3D.new()
	cap_mat.albedo_color = Color(0.85, 0.7, 0.35)
	cap_mat.metallic = 0.6
	cap_mat.roughness = 0.3
	cap.material_override = cap_mat
	cap.position.y = 0.25
	_visual.add_child(cap)

	# Curved wick made of short rope segments along a bent path.
	var rope := StandardMaterial3D.new()
	rope.albedo_color = Color(0.9, 0.82, 0.62)
	for i in WICK_SEGS + 1:
		var t := float(i) / WICK_SEGS
		_wick_pts.append(Vector3(sin(t * 1.8) * 0.13, 0.29 + t * 0.2, 0.0))
	for i in WICK_SEGS:
		var a := _wick_pts[i]
		var b := _wick_pts[i + 1]
		var seg := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.018
		cyl.bottom_radius = 0.018
		cyl.height = a.distance_to(b) + 0.01
		seg.mesh = cyl
		seg.material_override = rope
		seg.position = (a + b) * 0.5
		seg.basis = Basis(Quaternion(Vector3.UP, (b - a).normalized()))
		_visual.add_child(seg)
		_wick.append(seg)

	# Spark at the burning tip: glowing core, light, and a particle spray.
	_spark = Node3D.new()
	_visual.add_child(_spark)
	_spark_core = MeshInstance3D.new()
	var core := SphereMesh.new()
	core.radius = 0.045
	core.height = 0.09
	_spark_core.mesh = core
	var core_mat := StandardMaterial3D.new()
	core_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	core_mat.albedo_color = Color(1.0, 0.95, 0.6)
	_spark_core.material_override = core_mat
	_spark.add_child(_spark_core)

	_light = OmniLight3D.new()
	_light.light_color = Color(1.0, 0.6, 0.2)
	_light.omni_range = 1.8
	_spark.add_child(_light)

	var sparks := CPUParticles3D.new()
	sparks.amount = 28
	sparks.lifetime = 0.35
	sparks.local_coords = false
	sparks.direction = Vector3.UP
	sparks.spread = 80.0
	sparks.initial_velocity_min = 1.0
	sparks.initial_velocity_max = 2.6
	sparks.gravity = Vector3(0, -5, 0)
	sparks.scale_amount_min = 0.5
	sparks.scale_amount_max = 1.0
	var pmesh := SphereMesh.new()
	pmesh.radius = 0.02
	pmesh.height = 0.04
	var pmat := StandardMaterial3D.new()
	pmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	pmat.vertex_color_use_as_albedo = true
	pmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	pmesh.material = pmat
	sparks.mesh = pmesh
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1.0, 0.95, 0.6))
	ramp.set_color(1, Color(1.0, 0.3, 0.1, 0.0))
	sparks.color_ramp = ramp
	_spark.add_child(sparks)


func _process(delta: float) -> void:
	fuse -= delta
	var left := clampf(fuse / FUSE, 0.0, 1.0)

	# Burn the wick down: hide used segments, slide the spark to the current tip.
	var tip := left * WICK_SEGS
	var whole := floori(tip)
	for i in WICK_SEGS:
		_wick[i].visible = i < ceili(tip)
	var lo := _wick_pts[clampi(whole, 0, WICK_SEGS)]
	var hi := _wick_pts[clampi(whole + 1, 0, WICK_SEGS)]
	_spark.position = lo.lerp(hi, tip - whole)
	_spark_core.scale = Vector3.ONE * randf_range(0.7, 1.5)
	_light.light_energy = randf_range(1.0, 2.2)

	# Last half second: swell and blink faster and faster.
	if fuse < 0.6:
		var urgency := 1.0 - fuse / 0.6
		var lit := fposmod(fuse * (8.0 + urgency * 20.0), 1.0) < 0.5
		_mat.emission_energy_multiplier = 2.0 if lit else 0.0
		_visual.scale = Vector3.ONE * (1.0 + urgency * 0.25 + (0.05 if lit else 0.0))
	if fuse <= 0.0:
		explode()


func explode() -> void:
	main.blast(global_position, RADIUS, FORCE, DAMAGE, "player", 6.0, self)
	main.fx.explosion(global_position, RADIUS)
	main.sfx.play("boom", global_position)
	main.shake = maxf(main.shake, 0.7)
	queue_free()
