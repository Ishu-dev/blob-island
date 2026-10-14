extends Node3D
## A glob of enemy goo. Flies on a ballistic arc, wobbles and stretches along its path,
## drips a trail, and splats into a puddle (which slows the player) on impact.

const GRAVITY := 14.0

var main
var color := Color("f2789a")
var shooter: Node3D
var damage := 12.0
var vel := Vector3.ZERO
var _mesh: MeshInstance3D
var _t := 0.0
var _drip := 0.0


func _ready() -> void:
	_mesh = MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.17
	sm.height = 0.34
	_mesh.mesh = sm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color.lightened(0.1)
	mat.roughness = 0.05
	mat.rim_enabled = true
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 0.3
	_mesh.material_override = mat
	_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_mesh)


func _physics_process(delta: float) -> void:
	_t += delta
	var from := global_position
	vel.y -= GRAVITY * delta
	var to := from + vel * delta

	var q := PhysicsRayQueryParameters3D.create(from, to + vel.normalized() * 0.15)
	if is_instance_valid(shooter):
		q.exclude = [shooter.get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if not hit.is_empty():
		var at: Vector3 = hit["position"]
		var normal: Vector3 = hit["normal"]
		var body: Object = hit["collider"]
		if body == main.player:
			var push := Vector3(vel.x, 0, vel.z).normalized() * 2.5
			main.player.take_damage(damage, push)
		main.spawn_splat(at, color, 0.9, normal)
		main.burst(at, color, 8)
		queue_free()
		return
	global_position = to
	if to.y < -3.0:
		queue_free()
		return

	# Liquid look: stretch along velocity, jiggle across it.
	var dir := vel.normalized()
	var up := Vector3.UP if absf(dir.y) < 0.98 else Vector3.RIGHT
	var stretch := 1.0 + clampf(vel.length() * 0.05, 0.0, 0.5)
	var wob := sin(_t * 35.0) * 0.12
	_mesh.basis = Basis.looking_at(dir, up) * Basis.from_scale(Vector3(1.0 - wob, 1.0 + wob, stretch) / sqrt(stretch))

	_drip -= delta
	if _drip <= 0.0:
		_drip = 0.03
		main.droplet(global_position, color, vel * 0.1, 0.06)
