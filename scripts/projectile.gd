extends Node3D
## Any flying shot: enemy goo globs, gun pellets, boss volleys. Flies on an arc, stretches
## and wobbles like liquid, damages blobs of the other team, breaks glass, pushes props,
## and (for goo) splats into a puddle that slows you down.

var main
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
var _drip := 0.0
var _life := 4.0


func _ready() -> void:
	add_to_group("projectile")
	_mesh = MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = size
	sm.height = size * 2.0
	sm.radial_segments = 12
	sm.rings = 6
	_mesh.mesh = sm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color.lightened(0.1)
	mat.roughness = 0.05
	mat.rim_enabled = true
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 0.3 if splat else 1.5
	_mesh.material_override = mat
	_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_mesh)


func _physics_process(delta: float) -> void:
	_t += delta
	_life -= delta
	var from := global_position
	vel.y -= gravity * delta
	var to := from + vel * delta

	var q := PhysicsRayQueryParameters3D.create(from, to + vel.normalized() * size)
	if is_instance_valid(shooter):
		q.exclude = [shooter.get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if not hit.is_empty():
		var body: Object = hit["collider"]
		var friendly: bool = body is Blob and (body as Blob).team == team
		if not friendly:
			_impact(hit, body)
			return
	global_position = to
	if to.y < -3.0 or _life <= 0.0:
		queue_free()
		return

	# Liquid look: stretch along velocity, jiggle across it.
	var dir := vel.normalized()
	var up := Vector3.UP if absf(dir.y) < 0.98 else Vector3.RIGHT
	var stretch := 1.0 + clampf(vel.length() * 0.05, 0.0, 0.8)
	var wob := sin(_t * 35.0) * 0.12
	_mesh.basis = Basis.looking_at(dir, up) * Basis.from_scale(Vector3(1.0 - wob, 1.0 + wob, stretch) / sqrt(stretch))

	if splat:
		_drip -= delta
		if _drip <= 0.0:
			_drip = 0.03
			main.fx.droplet(global_position, color, vel * 0.1, size * 0.35)


func _impact(hit: Dictionary, body: Object) -> void:
	var at: Vector3 = hit["position"]
	var normal: Vector3 = hit["normal"]
	var push := Vector3(vel.x, 0, vel.z).normalized() * knock
	if body is Blob:
		(body as Blob).take_damage(damage, push)
	elif body is RigidBody3D:
		(body as RigidBody3D).apply_central_impulse(push * 0.5)
		if body.has_method("blast_hit") and damage >= 6.0:
			body.blast_hit()
	elif body.has_method("shatter"):
		body.shatter()
	if splat:
		main.fx.splat(at, color, size * 5.5, normal)
		main.fx.burst(at, color, 8)
		main.sfx.play("splat", at)
	else:
		main.fx.burst(at, color, 4)
	queue_free()
