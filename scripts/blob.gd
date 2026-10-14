class_name Blob
extends RigidBody3D
## Shared body for every blob: physics sphere, health, hit flash, squishy visual, eyes.
## Set radius/color/accel/max_speed/max_hp/main before add_child(). Subclasses set move_dir.

var radius := 0.45
var color := Color("8fd3ff")
var accel := 20.0
var max_speed := 6.0
var speed_mult := 1.0
var max_hp := 100.0
var hp := 100.0
var main
var move_dir := Vector3.ZERO
var facing := Vector3(0, 0, 1)
var squash := Vector3.ONE   # extra scale set by jumps and attacks, eased back to 1
var dead := false
var visual: Node3D
var _body_mat: StandardMaterial3D
var _flash := 0.0
var _t := 0.0


func _ready() -> void:
	add_to_group("actor")
	hp = max_hp
	lock_rotation = true
	linear_damp = 1.2
	gravity_scale = 1.6
	continuous_cd = true
	var pm := PhysicsMaterial.new()
	pm.friction = 0.4
	pm.bounce = 0.3
	physics_material_override = pm
	var col := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = radius
	col.shape = shape
	add_child(col)
	_build_visual()
	_t = randf() * 10.0


func _build_visual() -> void:
	visual = Node3D.new()
	add_child(visual)
	var body := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = radius
	sm.height = radius * 1.8
	body.mesh = sm
	_body_mat = StandardMaterial3D.new()
	_body_mat.albedo_color = color
	_body_mat.roughness = 0.3
	_body_mat.rim_enabled = true
	_body_mat.rim = 0.4
	_body_mat.emission_enabled = true
	_body_mat.emission = Color(1, 1, 1)
	_body_mat.emission_energy_multiplier = 0.0
	body.material_override = _body_mat
	visual.add_child(body)

	var white := StandardMaterial3D.new()
	white.albedo_color = Color(1, 1, 1)
	var black := StandardMaterial3D.new()
	black.albedo_color = Color(0.08, 0.08, 0.12)
	for side in [-1.0, 1.0]:
		var eye := MeshInstance3D.new()
		var em := SphereMesh.new()
		em.radius = radius * 0.26
		em.height = radius * 0.52
		eye.mesh = em
		eye.material_override = white
		eye.position = Vector3(side * radius * 0.4, radius * 0.2, radius * 0.68)
		visual.add_child(eye)
		var pupil := MeshInstance3D.new()
		var pm := SphereMesh.new()
		pm.radius = radius * 0.15
		pm.height = radius * 0.3
		pupil.mesh = pm
		pupil.material_override = black
		pupil.position = eye.position + Vector3(0, 0, radius * 0.17)
		visual.add_child(pupil)


func on_ground() -> bool:
	var q := PhysicsRayQueryParameters3D.create(global_position, global_position + Vector3.DOWN * (radius + 0.15))
	q.exclude = [get_rid()]
	return not get_world_3d().direct_space_state.intersect_ray(q).is_empty()


func take_damage(amount: float, push: Vector3 = Vector3.ZERO) -> void:
	if dead:
		return
	hp = maxf(hp - amount, 0.0)
	_flash = 1.0
	squash = Vector3(1.3, 0.7, 1.3)
	if push != Vector3.ZERO:
		apply_central_impulse(push * mass)
	main.float_text(global_position + Vector3.UP * (radius + 0.5), str(roundi(amount)), Color("ff4d5e") if is_in_group("player") else color)
	if hp <= 0.0:
		die()


func die() -> void:
	dead = true
	main.on_blob_died(self)
	set_deferred("freeze", true)
	collision_layer = 0
	var tw := create_tween()
	tw.tween_property(visual, "scale", Vector3(1.6, 0.35, 1.6), 0.12)
	tw.tween_callback(func() -> void:
		main.spawn_splat(global_position + Vector3.DOWN * radius * 0.8, color, 1.5)
		main.burst(global_position, color, 16))
	tw.tween_property(visual, "scale", Vector3.ZERO, 0.08)
	tw.tween_callback(queue_free)


func _process(delta: float) -> void:
	_flash = maxf(_flash - delta * 5.0, 0.0)
	_body_mat.emission_energy_multiplier = _flash * 1.5


func _physics_process(delta: float) -> void:
	if dead:
		return
	var flat_v := Vector3(linear_velocity.x, 0, linear_velocity.z)
	var moving := move_dir.length() > 0.01
	if moving:
		facing = move_dir.normalized()
		if flat_v.dot(facing) < max_speed * speed_mult:
			apply_central_force(facing * accel * mass * speed_mult)

	# Cosmetic only: turn toward facing, squash with speed, stretch when airborne.
	_t += delta
	squash = squash.lerp(Vector3.ONE, 8.0 * delta)
	visual.rotation.y = lerp_angle(visual.rotation.y, atan2(facing.x, facing.z), 12.0 * delta)
	var sp := clampf(flat_v.length() / 10.0, 0.0, 0.2)
	var bob := sin(_t * 9.0) * (0.05 if moving else 0.02)
	var vy := clampf(linear_velocity.y / 12.0, -0.25, 0.25)
	var wide := 1.0 + sp - vy * 0.5 - bob
	visual.scale = Vector3(wide, 1.0 - sp + vy + bob, wide) * squash
