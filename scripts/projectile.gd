extends Node3D
## Any flying shot. Kinds:
##   goo    - enemy spit; wobbles, drips, splats into a slowing puddle
##   bullet - small fast pellet
##   bolt   - crossbow bolt; pierces up to 3 blobs, sticks into walls
##   net    - spinning net; catches the blob it hits
##   rocket - explodes on impact, trails smoke
## Damages blobs and structures of the other team, breaks glass, pushes props.

var main
var kind := "goo"
var color := Color("f2789a")
var team := "enemy"
var shooter: Node3D
var damage := 12.0
var gravity := 14.0
var size := 0.17
var splat := true
var knock := 2.5
var vel := Vector3.ZERO
var _mesh: MeshInstance3D
var _t := 0.0
var _trail := 0.0
var _life := 4.0
var _pierce := 3
var _exclude: Array[RID] = []


func _ready() -> void:
	add_to_group("projectile")
	if is_instance_valid(shooter) and shooter is CollisionObject3D:
		_exclude.append((shooter as CollisionObject3D).get_rid())
	_mesh = MeshInstance3D.new()
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color.lightened(0.1)
	mat.roughness = 0.1
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 0.3 if kind == "goo" else 1.2
	match kind:
		"bolt":
			var bm := BoxMesh.new()
			bm.size = Vector3(0.05, 0.05, 0.55)
			_mesh.mesh = bm
		"net":
			var tm := TorusMesh.new()
			tm.inner_radius = 0.18
			tm.outer_radius = 0.26
			_mesh.mesh = tm
			mat.emission_energy_multiplier = 0.4
		"rocket":
			var cm := CylinderMesh.new()
			cm.top_radius = 0.08
			cm.bottom_radius = 0.1
			cm.height = 0.45
			_mesh.mesh = cm
			mat.albedo_color = Color("6b7a3a")
			mat.emission_energy_multiplier = 0.0
		_:
			var sm := SphereMesh.new()
			sm.radius = size
			sm.height = size * 2.0
			sm.radial_segments = 12
			sm.rings = 6
			_mesh.mesh = sm
			mat.rim_enabled = true
	_mesh.material_override = mat
	_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_mesh)


func _physics_process(delta: float) -> void:
	_t += delta
	_life -= delta
	var from := global_position
	vel.y -= gravity * delta
	var to := from + vel * delta

	var q := PhysicsRayQueryParameters3D.create(from, to + vel.normalized() * maxf(size, 0.1))
	q.exclude = _exclude
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if not hit.is_empty():
		var body: Object = hit["collider"]
		var friendly: bool = body.get("team") == team
		if friendly and body is CollisionObject3D:
			_exclude.append((body as CollisionObject3D).get_rid())
		elif not friendly and _impact(hit, body):
			queue_free()
			return
	global_position = to
	if to.y < -3.0 or _life <= 0.0:
		queue_free()
		return

	var dir := vel.normalized()
	var up := Vector3.UP if absf(dir.y) < 0.98 else Vector3.RIGHT
	match kind:
		"bolt", "bullet":
			_mesh.basis = Basis.looking_at(dir, up) * Basis.from_scale(Vector3(1, 1, 1.0 + clampf(vel.length() * 0.04, 0.0, 1.0)))
		"rocket":
			_mesh.basis = Basis.looking_at(dir, up) * Basis(Vector3.RIGHT, PI / 2.0)
			_trail -= delta
			if _trail <= 0.0:
				_trail = 0.03
				main.fx.puff(global_position - dir * 0.3)
		"net":
			_mesh.basis = Basis.looking_at(dir, up) * Basis(Vector3.RIGHT, PI / 2.0).rotated(Vector3.UP, _t * 12.0)
			_mesh.scale = Vector3.ONE * minf(1.0 + _t * 3.0, 2.2)
		_:
			# Liquid look: stretch along velocity, jiggle across it.
			var stretch := 1.0 + clampf(vel.length() * 0.05, 0.0, 0.8)
			var wob := sin(_t * 35.0) * 0.12
			_mesh.basis = Basis.looking_at(dir, up) * Basis.from_scale(Vector3(1.0 - wob, 1.0 + wob, stretch) / sqrt(stretch))
			if kind == "goo":
				_trail -= delta
				if _trail <= 0.0:
					_trail = 0.03
					main.fx.droplet(global_position, color, vel * 0.1, size * 0.35)


## Returns true when the projectile is used up.
func _impact(hit: Dictionary, body: Object) -> bool:
	var at: Vector3 = hit["position"]
	var normal: Vector3 = hit["normal"]
	var push := Vector3(vel.x, 0, vel.z).normalized() * knock
	match kind:
		"rocket":
			main.blast(at, 2.8, 13.0, 45.0, team, 6.0, null)
			main.fx.explosion(at, 2.8)
			main.sfx.play("boom", at, 1.1)
			main.shake = maxf(main.shake, 0.7)
			return true
		"net":
			if body is Blob:
				(body as Blob).netted(6.0)
				(body as Blob).take_damage(damage)
				main.fx.float_text(at + Vector3.UP, "NETTED!", Color("b6ff8a"))
			main.sfx.play("net", at, 0.8)
			main.fx.burst(at, color, 6)
			return true
	if body.has_method("take_damage"):
		body.take_damage(damage, push)
	elif body is RigidBody3D:
		(body as RigidBody3D).apply_central_impulse(push * 0.5)
		if body.has_method("blast_hit") and damage >= 6.0:
			body.blast_hit()
	elif body.has_method("shatter"):
		body.shatter()
	if kind == "bolt":
		if body is Blob and _pierce > 0:
			_pierce -= 1
			_exclude.append((body as CollisionObject3D).get_rid())
			main.fx.burst(at, Color("ff6b6b"), 5)
			return false
		if body is StaticBody3D:
			# leave the bolt stuck in the wall for a few seconds
			var stuck := MeshInstance3D.new()
			stuck.mesh = _mesh.mesh
			stuck.material_override = _mesh.material_override
			main.fx.add_child(stuck)
			stuck.global_position = at - vel.normalized() * 0.2
			stuck.global_basis = _mesh.global_basis
			var tw := stuck.create_tween()
			tw.tween_interval(4.0)
			tw.tween_callback(stuck.queue_free)
		return true
	if kind == "goo":
		main.fx.splat(at, color, size * 5.5, normal)
		main.fx.burst(at, color, 8)
		main.sfx.play("splat", at)
	else:
		main.fx.burst(at, color, 4)
	return true
