extends RigidBody3D
## Drivable car in the Aliens Drive Me Crazy spirit. Each wheel is a raycast spring, grip
## and steering are arcade. Run blobs over, hop with Space, flip in the air with Space
## again, boost with Shift. Air time and flips pay out coins. F gets in and out.
## Styles: buggy, monster, tank (click fires the cannon), hover (floats over water).

const Profile := preload("res://scripts/profile.gd")
const K_SPRING := 20.0
const K_DAMP := 2.6

var main
var style := "buggy"
var color := Color("ff6b6b")
var top_speed := 14.0
var max_hp := 80.0
var hp := 80.0
var team := "player"
var dead := false
var radius := 1.0
var driver: Blob = null
var _mounts: Array[Vector3] = []
var _wheel_nodes: Array = []
var _wheel_r := 0.3
var _rest := 0.45
var _seat := Vector3(0, 0.55, -0.15)
var _turret: Node3D
var _prompt: Label3D
var _grounded := 0
var _steer := 0.0
var _air_t := 0.0
var _spin_acc := 0.0
var _flip_cd := 0.0
var _boost_cd := 0.0
var _gun_cd := 0.0
var _upside_t := 0.0
var _puff_t := 0.0
var _flash := 0.0
var _mats: Array[StandardMaterial3D] = []
var _was_jump := false
var _was_boost := false


## Builds the look of a car. Returns {root, wheels (pivot nodes, front pair first), turret}.
static func build_model(kind: String, c: Color) -> Dictionary:
	var root := Node3D.new()
	var wheels: Array = []
	var turret: Node3D = null
	var dark := Color("2b2b33")
	match kind:
		"buggy":
			_part(root, _box(Vector3(1.1, 0.3, 1.8)), c, Vector3(0, 0.1, 0))
			_part(root, _box(Vector3(1.0, 0.18, 0.5)), c.lightened(0.2), Vector3(0, 0.3, 0.6))
			for s in [-0.45, 0.45]:
				var bar := _part(root, _box(Vector3(0.07, 0.6, 0.07)), dark, Vector3(s, 0.5, -0.4))
				bar.rotation.x = 0.3
			_part(root, _box(Vector3(0.97, 0.07, 0.07)), dark, Vector3(0, 0.78, -0.3))
			for s in [-0.35, 0.35]:
				_part(root, _sphere(0.09), Color("fff3a0"), Vector3(s, 0.15, 0.92), true)
			wheels = _wheels(root, [Vector3(-0.62, -0.05, 0.72), Vector3(0.62, -0.05, 0.72), Vector3(-0.62, -0.05, -0.72), Vector3(0.62, -0.05, -0.72)], 0.3, 0.26)
		"monster":
			_part(root, _box(Vector3(1.25, 0.45, 2.0)), c, Vector3(0, 0.25, 0))
			_part(root, _box(Vector3(1.05, 0.4, 0.8)), c.lightened(0.25), Vector3(0, 0.62, -0.15))
			_part(root, _box(Vector3(1.0, 0.3, 0.05)), Color(0.6, 0.85, 1.0), Vector3(0, 0.65, 0.26))
			_part(root, _box(Vector3(1.3, 0.12, 0.2)), dark, Vector3(0, 0.08, 1.05))
			for s in [-0.4, 0.4]:
				_part(root, _sphere(0.1), Color("fff3a0"), Vector3(s, 0.32, 1.01), true)
			wheels = _wheels(root, [Vector3(-0.85, -0.1, 0.78), Vector3(0.85, -0.1, 0.78), Vector3(-0.85, -0.1, -0.78), Vector3(0.85, -0.1, -0.78)], 0.48, 0.42)
		"tank":
			_part(root, _box(Vector3(1.3, 0.45, 2.0)), c, Vector3(0, 0.15, 0))
			for s in [-0.72, 0.72]:
				_part(root, _box(Vector3(0.3, 0.45, 2.15)), dark, Vector3(s, -0.05, 0))
			turret = Node3D.new()
			turret.position = Vector3(0, 0.5, -0.1)
			root.add_child(turret)
			_part(turret, _cyl(0.42, 0.3), c.lightened(0.15), Vector3.ZERO)
			var barrel := _part(turret, _cyl(0.08, 1.0), dark, Vector3(0, 0.02, 0.6))
			barrel.rotation.x = PI / 2.0
			wheels = _wheels(root, [Vector3(-0.7, -0.05, 0.75), Vector3(0.7, -0.05, 0.75), Vector3(-0.7, -0.05, -0.75), Vector3(0.7, -0.05, -0.75)], 0.28, 0.2)
			for w in wheels:
				(w as Node3D).visible = false
		"hover":
			var disc := _part(root, _sphere(1.0), c, Vector3(0, 0.1, 0))
			disc.scale = Vector3(1, 0.28, 1)
			var dome := _part(root, _sphere(0.5), Color(0.6, 0.9, 1.0, 0.45), Vector3(0, 0.35, 0))
			dome.scale = Vector3(1, 0.8, 1)
			(dome.material_override as StandardMaterial3D).transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			var ring := _part(root, _torus(0.8, 0.95), Color("7dfcff"), Vector3(0, -0.05, 0), true)
			ring.set_meta("glow", true)
			for i in 6:
				var a := TAU * i / 6.0
				_part(root, _sphere(0.08), Color("fff3a0"), Vector3(cos(a) * 0.9, 0.12, sin(a) * 0.9), true)
			wheels = _wheels(root, [Vector3(-0.6, -0.05, 0.6), Vector3(0.6, -0.05, 0.6), Vector3(-0.6, -0.05, -0.6), Vector3(0.6, -0.05, -0.6)], 0.0, 0.0)
	return {"root": root, "wheels": wheels, "turret": turret}


static func _wheels(root: Node3D, spots: Array, r: float, w: float) -> Array:
	var out := []
	for p in spots:
		var pivot := Node3D.new()
		pivot.position = p
		pivot.set_meta("mount", p)
		root.add_child(pivot)
		if r > 0.0:
			var spin := Node3D.new()
			pivot.add_child(spin)
			var tire := _part(spin, _cyl(r, w), Color("26262e"), Vector3.ZERO)
			tire.rotation.z = PI / 2.0
			var hub := _part(spin, _cyl(r * 0.45, w + 0.02), Color("d9dde3"), Vector3.ZERO)
			hub.rotation.z = PI / 2.0
			_part(spin, _box(Vector3(w + 0.03, r * 0.25, r * 1.4)), Color("d9dde3"), Vector3.ZERO)
		out.append(pivot)
	return out


static func _part(parent: Node3D, mesh: Mesh, c: Color, pos: Vector3, glow := false) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.35
	m.emission_enabled = true
	m.emission = c if glow else Color(1, 1, 1)
	m.emission_energy_multiplier = 0.6 if glow else 0.0
	mi.material_override = m
	mi.position = pos
	parent.add_child(mi)
	return mi


static func _box(s: Vector3) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = s
	return b


static func _sphere(r: float) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	return s


static func _cyl(r: float, h: float) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = r
	c.bottom_radius = r
	c.height = h
	return c


static func _torus(a: float, b: float) -> TorusMesh:
	var t := TorusMesh.new()
	t.inner_radius = a
	t.outer_radius = b
	return t


func _ready() -> void:
	add_to_group("vehicle")
	var stats: Dictionary = main.profile.car_stats(style)
	color = Color(stats["color"])
	top_speed = stats["speed"]
	max_hp = stats["hp"]
	hp = max_hp
	mass = stats["mass"]
	gravity_scale = 1.6
	angular_damp = 0.8
	linear_damp = 0.05
	center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	center_of_mass = Vector3(0, -0.35, 0)
	continuous_cd = true
	contact_monitor = true
	max_contacts_reported = 4
	body_entered.connect(_on_hit)
	var pm := PhysicsMaterial.new()
	pm.friction = 0.6
	pm.bounce = 0.1
	physics_material_override = pm

	var col := CollisionShape3D.new()
	match style:
		"monster":
			_wheel_r = 0.48
			_rest = 0.55
			_seat = Vector3(0, 0.95, -0.2)
			col.shape = _box_shape(Vector3(1.25, 0.6, 2.0))
			col.position.y = 0.3
			radius = 1.2
		"tank":
			_wheel_r = 0.28
			_rest = 0.4
			_seat = Vector3(0, 0.95, -0.55)
			col.shape = _box_shape(Vector3(1.5, 0.5, 2.1))
			col.position.y = 0.15
		"hover":
			_wheel_r = 0.0
			_rest = 0.95
			_seat = Vector3(0, 0.55, 0)
			var cs := CylinderShape3D.new()
			cs.radius = 0.95
			cs.height = 0.35
			col.shape = cs
			col.position.y = 0.1
		_:
			col.shape = _box_shape(Vector3(1.1, 0.35, 1.8))
			col.position.y = 0.1
	add_child(col)

	var model := build_model(style, color)
	add_child(model["root"])
	_wheel_nodes = model["wheels"]
	_turret = model["turret"]
	for w in _wheel_nodes:
		_mounts.append((w as Node3D).get_meta("mount"))
	for mi in (model["root"] as Node3D).find_children("*", "MeshInstance3D", true, false):
		var m := (mi as MeshInstance3D).material_override as StandardMaterial3D
		if m.emission_energy_multiplier == 0.0:
			_mats.append(m)

	_prompt = Label3D.new()
	_prompt.text = "F: DRIVE"
	_prompt.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_prompt.font_size = 34
	_prompt.outline_size = 10
	_prompt.pixel_size = 0.01
	_prompt.modulate = Color("fff3a0")
	_prompt.position.y = 1.7
	_prompt.top_level = false
	_prompt.visible = false
	add_child(_prompt)


func _box_shape(s: Vector3) -> BoxShape3D:
	var b := BoxShape3D.new()
	b.size = s
	return b


func seat_position() -> Vector3:
	return global_transform * _seat


func enter(b: Blob) -> void:
	driver = b
	add_collision_exception_with(b)
	b.add_collision_exception_with(self)
	main.sfx.play("horn", global_position, 1.3, -4.0)
	main.fx.float_text(global_position + Vector3.UP * 1.5, "VROOM!", Color("fff3a0"), 50)


func eject() -> void:
	if driver == null:
		return
	var b := driver
	driver = null
	if is_instance_valid(b):
		b.global_position = global_position + global_basis.x * 1.6 + Vector3.UP * 0.8
		var self_ref := self
		get_tree().create_timer(0.5).timeout.connect(func() -> void:
			if is_instance_valid(b) and is_instance_valid(self_ref):
				b.remove_collision_exception_with(self_ref)
				self_ref.remove_collision_exception_with(b))


func take_damage(amount: float, push := Vector3.ZERO) -> void:
	if dead:
		return
	hp -= amount
	_flash = 1.0
	if push != Vector3.ZERO:
		apply_central_impulse(push * mass * 0.3)
	main.fx.float_text(global_position + Vector3.UP * 1.2, str(roundi(amount)), Color("ffb0b0"), 36)
	if hp <= 0.0:
		_explode()


func _explode() -> void:
	dead = true
	var d := driver
	if d and d.has_method("leave_vehicle"):
		d.leave_vehicle()
	main.blast(global_position, 3.5, 14.0, 45.0, "player", 8.0, self)
	main.fx.explosion(global_position, 3.5)
	main.sfx.play("boom", global_position, 0.7)
	main.shake = maxf(main.shake, 1.0)
	main.vehicle_destroyed(self)
	queue_free()


func _on_hit(other: Node) -> void:
	var speed := linear_velocity.length()
	if other is Blob and not (other as Blob).dead and other != driver and speed > 3.0:
		var o := other as Blob
		var push := linear_velocity * 0.7 + Vector3.UP * 7.0
		if o.team == "enemy":
			o.take_damage(speed * 4.0 * mass / 5.0, push)
			o.ragdoll(1.8)
			o.trick("barrel", 0.5, 2.0)
			main.fx.float_text(o.global_position + Vector3.UP * 1.2, ["SPLAT!", "ROADKILL!", "BOINK!", "WHEEE!"][randi() % 4], Color("ffe066"), 52)
			main.sfx.play("punch", global_position, 0.7)
			main.shake = maxf(main.shake, 0.45)
		else:
			o.apply_central_impulse(push * 0.3 * o.mass)
	elif other is RigidBody3D and speed > 3.0:
		(other as RigidBody3D).apply_central_impulse(linear_velocity * 0.4 * (other as RigidBody3D).mass)
		if other.has_method("blast_hit") and speed > 7.0:
			other.blast_hit()
	elif other.has_method("shatter") and speed > 4.0:
		other.shatter()


func _physics_process(delta: float) -> void:
	if dead:
		return
	_flip_cd -= delta
	_boost_cd -= delta
	_gun_cd -= delta
	var up := global_basis.y
	var fwd := global_basis.z
	var right := global_basis.x
	var space := get_world_3d().direct_space_state

	# Suspension: one spring per wheel.
	_grounded = 0
	for i in _mounts.size():
		var mount_g := global_transform * _mounts[i]
		var reach := _rest + _wheel_r
		var q := PhysicsRayQueryParameters3D.create(mount_g, mount_g - up * reach)
		var ex: Array[RID] = [get_rid()]
		if driver:
			ex.append(driver.get_rid())
		q.exclude = ex
		var hit := space.intersect_ray(q)
		if not hit.is_empty() and hit["collider"] is RigidBody3D and not (hit["collider"] as RigidBody3D).freeze:
			ex.append((hit["collider"] as RigidBody3D).get_rid())
			q.exclude = ex
			hit = space.intersect_ray(q)
		var dist := -1.0
		if not hit.is_empty():
			dist = mount_g.distance_to(hit["position"])
		elif style == "hover" and up.y > 0.5:
			# The UFO also floats on the sea.
			var sea_d := (mount_g.y + 0.05) / up.y
			if sea_d < reach:
				dist = sea_d
		var wheel := _wheel_nodes[i] as Node3D
		if dist >= 0.0:
			_grounded += 1
			var comp := reach - dist
			var point_v := linear_velocity + angular_velocity.cross(mount_g - global_position)
			var f := (comp * K_SPRING - point_v.dot(up) * K_DAMP) * mass
			apply_force(up * maxf(f, 0.0), mount_g - global_position)
			wheel.position = _mounts[i] - Vector3.UP * (dist - _wheel_r)
		else:
			wheel.position = wheel.position.lerp(_mounts[i] - Vector3.UP * _rest, 10.0 * delta)

	var speed_f := linear_velocity.dot(fwd)
	var on := _grounded >= 2
	var throttle := 0.0
	var want_yaw := 0.0
	var jump := false
	var boost := false
	if driver and driver == main.player and main.state == "play":
		var iv := Input.get_vector("move_left", "move_right", "move_up", "move_down")
		var want: Vector3 = main.screen_to_world(iv)
		jump = Input.is_action_pressed("jump")
		boost = Input.is_action_pressed("grab")
		if want.length() > 0.1:
			var wn := want.normalized()
			var flat_f := Vector3(fwd.x, 0, fwd.z).normalized()
			var d := flat_f.dot(wn)
			var side := flat_f.cross(wn).y
			var ang := atan2(-side, d)
			want_yaw = clampf(ang * 3.0, -3.2, 3.2)
			throttle = want.length() if d > -0.4 else -0.6
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and _turret and _gun_cd <= 0.0 and main.get_viewport().gui_get_hovered_control() == null:
			_fire_cannon(main.mouse_world())

	if on:
		# Grip: kill most sideways sliding (less for the floaty UFO).
		var grip := 2.5 if style == "hover" else 7.0
		var v_side := linear_velocity.dot(right)
		apply_central_force(-right * v_side * grip * mass * (_grounded / 4.0))
		if throttle != 0.0 and absf(speed_f) < top_speed:
			apply_central_force(fwd * throttle * 20.0 * mass)
		elif throttle == 0.0:
			apply_central_force(-fwd * speed_f * 1.2 * mass)
		var yaw_rate := want_yaw * clampf(absf(speed_f) / 3.0 + 0.35, 0.35, 1.0)
		var cur := angular_velocity.dot(up)
		angular_velocity += up * (yaw_rate - cur) * minf(1.0, 10.0 * delta)
		_steer = lerpf(_steer, clampf(want_yaw * 0.25, -0.5, 0.5), 10.0 * delta)
		if jump and not _was_jump:
			apply_central_impulse(Vector3.UP * 6.5 * mass)
			main.sfx.play("spring", global_position, 0.8)
			main.fx.dust(global_position + Vector3.DOWN * 0.4)
	else:
		# Air: Space again does a front flip.
		if jump and not _was_jump and _flip_cd <= 0.0:
			angular_velocity += right * 9.0
			_flip_cd = 0.6
			main.sfx.play("jump", global_position, 0.7)
	if boost and not _was_boost and _boost_cd <= 0.0:
		_boost_cd = 2.0
		apply_central_impulse(fwd * 9.0 * mass)
		main.sfx.play("rocket", global_position, 1.4, -4.0)
		for i in 8:
			main.fx.particle(global_position - fwd * 1.1, -fwd * randf_range(3, 6) + Vector3(randf_range(-1, 1), randf_range(0, 1), randf_range(-1, 1)), 0.18, 0.4, main.fx.mat(Color("ffb347"), true), 0.0)
	_was_jump = jump
	_was_boost = boost

	# Air time and flip stunts pay out on landing.
	if _grounded == 0:
		_air_t += delta
		_spin_acc += Vector2(angular_velocity.dot(right), angular_velocity.dot(fwd)).length() * delta
	else:
		if _air_t > 0.6 and _grounded >= 3 and driver:
			main.on_stunt(self, _air_t, int((_spin_acc + 0.8) / TAU))
		_air_t = 0.0
		_spin_acc = 0.0

	# Landed on its back or side: after a moment, pop upright.
	if up.y < 0.3 and linear_velocity.length() < 2.0:
		_upside_t += delta
		if _upside_t > 1.0:
			_upside_t = 0.0
			global_rotation = Vector3(0, global_rotation.y, 0)
			global_position += Vector3.UP * 1.2
			angular_velocity = Vector3.ZERO
			main.fx.puff(global_position)
	else:
		_upside_t = 0.0

	if driver and is_instance_valid(driver):
		driver.global_position = seat_position()
		driver.facing = Vector3(fwd.x, 0, fwd.z).normalized()

	# Wheels spin and the front pair steers.
	for i in _wheel_nodes.size():
		var w := _wheel_nodes[i] as Node3D
		if w.get_child_count() > 0:
			(w.get_child(0) as Node3D).rotation.x += speed_f / maxf(_wheel_r, 0.1) * delta
		if i < 2:
			w.rotation.y = _steer


func _fire_cannon(at: Vector3) -> void:
	_gun_cd = 0.9
	var muzzle := _turret.global_position + _turret.global_basis.z * 1.1
	var dir := at + Vector3.UP * 0.4 - muzzle
	dir.y = clampf(dir.y, -2.0, 2.0)
	main.shoot(muzzle, dir.normalized() * 18.0, Color("ff5a3d"), "player", 55.0 * main.profile.level_of("car", style) * 0.25 + 40.0, 0.0, 0.1, self, false, 0.0, "rocket")
	apply_central_impulse(-dir.normalized() * 2.0 * mass)
	main.sfx.play("rocket", muzzle)
	main.shake = maxf(main.shake, 0.4)


func _process(delta: float) -> void:
	_flash = maxf(_flash - delta * 5.0, 0.0)
	for m in _mats:
		m.emission_energy_multiplier = _flash * 1.2
	var p = main.player
	_prompt.visible = driver == null and is_instance_valid(p) and not p.dead and p.global_position.distance_to(global_position) < 2.6
	if _turret and driver == main.player:
		var at: Vector3 = main.mouse_world()
		var local := to_local(at)
		_turret.rotation.y = lerp_angle(_turret.rotation.y, atan2(local.x, local.z), 10.0 * delta)
	# Exhaust puffs while driving.
	if driver and _grounded > 0 and linear_velocity.length() > 2.0:
		_puff_t -= delta
		if _puff_t <= 0.0:
			_puff_t = 0.12
			main.fx.particle(global_transform * Vector3(0.3, 0.2, -1.0), -global_basis.z + Vector3.UP, 0.12, 0.5, main.fx.mat(Color(0.85, 0.85, 0.9, 0.8)), -1.0, true)
	if global_position.y < -6.0:
		_explode()
