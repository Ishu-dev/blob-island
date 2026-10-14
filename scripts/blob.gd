class_name Blob
extends RigidBody3D
## Shared body for every blob: physics sphere, health, team, hit flash, squishy visual,
## eyes, optional grumpy brows and sharp teeth, liquid footprints.
## Set the vars below before add_child(). Subclasses set move_dir and facing.

var radius := 0.45
var color := Color("8fd3ff")
var accel := 20.0
var max_speed := 6.0
var speed_mult := 1.0
var max_hp := 100.0
var hp := 100.0
var team := "enemy"
var teeth := 0
var voice := 1.0
var loot := 1
var prints := true
var face_locked := false
var main
var move_dir := Vector3.ZERO
var facing := Vector3(0, 0, 1)
var squash := Vector3.ONE   # extra scale set by jumps and attacks, eased back to 1
var shield_time := 0.0
var dead := false
var visual: Node3D
var _body_mat: StandardMaterial3D
var _flash := 0.0
var _t := 0.0
var _last_print := Vector3.ZERO
var _print_side := 1.0
var rag_t := 0.0
var net_t := 0.0
var _righting := 0.0
var _crash_cd := 0.0
var _net: Node3D


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
	contact_monitor = true
	max_contacts_reported = 3
	body_entered.connect(_on_body_hit)


## Physics tumble: rotation unlocks and the blob spins and bounces until t runs out.
func ragdoll(t: float) -> void:
	if dead or mass > 5.0:
		return
	rag_t = maxf(rag_t, t)
	lock_rotation = false
	angular_velocity = Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)).normalized() * randf_range(6.0, 12.0)
	if "stun" in self:
		set("stun", maxf(get("stun"), t))


## Caught in a net: can't move for t seconds and can be picked up (Shift) and thrown.
func netted(t: float) -> void:
	if dead or mass > 10.0:
		return
	net_t = t
	linear_damp = 6.0
	if "stun" in self:
		set("stun", maxf(get("stun"), t))
	if radius < 1.0:
		add_to_group("grabbable")
	if _net == null:
		_net = Node3D.new()
		add_child(_net)
		var m := StandardMaterial3D.new()
		m.albedo_color = Color("3d5c2a")
		m.roughness = 0.9
		for i in 4:
			var ring := MeshInstance3D.new()
			var tm := TorusMesh.new()
			tm.inner_radius = radius * 1.05
			tm.outer_radius = radius * 1.12
			ring.mesh = tm
			ring.material_override = m
			ring.rotation = Vector3(PI / 2.0, i * PI / 4.0, 0)
			_net.add_child(ring)
		var band := MeshInstance3D.new()
		var bm := TorusMesh.new()
		bm.inner_radius = radius * 1.05
		bm.outer_radius = radius * 1.12
		band.mesh = bm
		band.material_override = m
		_net.add_child(band)


## Bowling: a tumbling blob that slams into another blob hurts both; into a wall, itself.
func _on_body_hit(other: Node) -> void:
	if dead or rag_t <= 0.0 or _crash_cd > 0.0:
		return
	var speed := linear_velocity.length()
	if speed < 4.5:
		return
	_crash_cd = 0.3
	if other is Blob and not (other as Blob).dead:
		var o := other as Blob
		var push := linear_velocity.normalized() * speed * 0.6 + Vector3.UP * 3.0
		o.take_damage(minf(speed * 2.0, 22.0), push)
		o.ragdoll(0.8)
		main.fx.float_text(o.global_position + Vector3.UP, "BONK!", Color("ffe066"), 40)
		main.sfx.play("punch", global_position, 0.9)
	elif speed > 7.0 and other is StaticBody3D:
		take_damage(minf(speed, 14.0))
		squash = Vector3(1.5, 0.5, 1.5)
		main.fx.splat(global_position, color, radius * 1.5)


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
		var eye := _sphere(radius * 0.26, white, Vector3(side * radius * 0.4, radius * 0.2, radius * 0.68))
		_sphere(radius * 0.15, black, eye.position + Vector3(0, 0, radius * 0.17))
		if team == "enemy":
			# Grumpy brows slanting down toward the middle.
			var brow := MeshInstance3D.new()
			var bm := BoxMesh.new()
			bm.size = Vector3(radius * 0.42, radius * 0.09, radius * 0.08)
			brow.mesh = bm
			brow.material_override = black
			brow.position = Vector3(side * radius * 0.36, radius * 0.5, radius * 0.72)
			brow.rotation.z = side * 0.45
			visual.add_child(brow)

	if teeth > 0:
		var mouth := _sphere(radius * 0.5, black, Vector3(0, -radius * 0.2, radius * 0.72))
		mouth.scale = Vector3(1.0, 0.32, 0.35)
		var count := clampi(teeth + randi_range(-1, 1), 1, 8)
		for i in count:
			var tooth := MeshInstance3D.new()
			var cone := CylinderMesh.new()
			var w := radius * randf_range(0.06, 0.1)
			cone.top_radius = w
			cone.bottom_radius = 0.0
			cone.height = radius * randf_range(0.12, 0.22)
			cone.radial_segments = 6
			tooth.mesh = cone
			tooth.material_override = white
			var x := lerpf(-0.28, 0.28, (i + 0.5) / count) + randf_range(-0.04, 0.04)
			tooth.position = Vector3(x * radius, -radius * 0.14 - cone.height * 0.4, radius * 0.86)
			tooth.rotation.z = randf_range(-0.35, 0.35)
			visual.add_child(tooth)


func _sphere(r: float, m: Material, pos: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = r
	sm.height = r * 2.0
	mi.mesh = sm
	mi.material_override = m
	mi.position = pos
	visual.add_child(mi)
	return mi


func ground_hit() -> Dictionary:
	var q := PhysicsRayQueryParameters3D.create(global_position, global_position + Vector3.DOWN * (radius + 0.15))
	q.exclude = [get_rid()]
	return get_world_3d().direct_space_state.intersect_ray(q)


func on_ground() -> bool:
	return not ground_hit().is_empty()


func take_damage(amount: float, push: Vector3 = Vector3.ZERO) -> void:
	if dead:
		return
	if shield_time > 0.0:
		main.fx.ring(global_position, Color(0.5, 0.9, 1.0, 0.8), radius * 2.5, 0.25)
		apply_central_impulse(push * 0.3 * mass)
		return
	hp = maxf(hp - amount, 0.0)
	_flash = 1.0
	squash = Vector3(1.3, 0.7, 1.3)
	if push != Vector3.ZERO:
		apply_central_impulse(push * mass)
	var tc := Color("ff4d5e") if team == "player" else color
	main.fx.float_text(global_position + Vector3.UP * (radius + 0.5), str(roundi(amount)), tc)
	main.sfx.play("hurt" if team == "player" else "ow", global_position, voice)
	if hp <= 0.0:
		die()


func die() -> void:
	dead = true
	main.on_blob_died(self)
	set_deferred("freeze", true)
	collision_layer = 0
	main.sfx.play("pop", global_position, voice)
	var tw := create_tween()
	tw.tween_property(visual, "scale", Vector3(1.6, 0.35, 1.6), 0.12)
	tw.tween_callback(func() -> void:
		main.fx.splat(global_position + Vector3.DOWN * radius * 0.8, color, radius * 3.2)
		main.fx.burst(global_position, color, 16))
	tw.tween_property(visual, "scale", Vector3.ZERO, 0.08)
	tw.tween_callback(queue_free)


func _process(delta: float) -> void:
	_crash_cd -= delta
	if net_t > 0.0:
		net_t -= delta
		if _net:
			_net.scale = Vector3.ONE * (1.0 + sin(_t * 20.0) * 0.03)
		if net_t <= 0.0:
			linear_damp = 1.2
			if _net:
				_net.queue_free()
				_net = null
			if radius >= 0.6:
				remove_from_group("grabbable")
	_flash = maxf(_flash - delta * 5.0, 0.0)
	_body_mat.emission_energy_multiplier = _flash * 1.5
	shield_time = maxf(shield_time - delta, 0.0)


func _physics_process(delta: float) -> void:
	if dead:
		return
	if rag_t > 0.0:
		rag_t -= delta
		if rag_t <= 0.0:
			lock_rotation = true
			angular_velocity = Vector3.ZERO
			_righting = 0.35
	elif _righting > 0.0:
		_righting -= delta
		rotation = rotation.lerp(Vector3.ZERO, 14.0 * delta)
		if _righting <= 0.0:
			rotation = Vector3.ZERO
	var flat_v := Vector3(linear_velocity.x, 0, linear_velocity.z)
	var moving := move_dir.length() > 0.01 and rag_t <= 0.0 and net_t <= 0.0
	if moving:
		var dir := move_dir.normalized()
		if not face_locked:
			facing = dir
		if flat_v.dot(dir) < max_speed * speed_mult:
			apply_central_force(dir * accel * mass * speed_mult)

	# Liquid footprints, alternating left and right, that evaporate after a second or two.
	if prints and global_position.distance_to(_last_print) > radius * 1.2:
		var hit := ground_hit()
		if not hit.is_empty():
			var side := Vector3(facing.z, 0, -facing.x) * radius * 0.35 * _print_side
			var at: Vector3 = hit["position"]
			main.fx.footprint(at + side, color, radius * 0.7)
			_print_side = -_print_side
		_last_print = global_position

	# Cosmetic only: turn toward facing, squash with speed, stretch when airborne.
	_t += delta
	squash = squash.lerp(Vector3.ONE, 8.0 * delta)
	visual.rotation.y = lerp_angle(visual.rotation.y, atan2(facing.x, facing.z), 12.0 * delta)
	var sp := clampf(flat_v.length() / 10.0, 0.0, 0.2)
	var bob := sin(_t * 9.0) * (0.05 if moving else 0.02)
	var vy := clampf(linear_velocity.y / 12.0, -0.25, 0.25)
	var wide := 1.0 + sp - vy * 0.5 - bob
	visual.scale = Vector3(wide, 1.0 - sp + vy + bob, wide) * squash
