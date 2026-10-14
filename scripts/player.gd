extends Blob
## The blob you control. Moves relative to the camera, faces the mouse, has stubby hands
## that hold the current weapon or grab things (Shift), climbs ladders, can be shielded.

const JUMP_SPEED := 7.5
const WEAPONS := ["BOMB", "BLASTER", "SPLATTER"]

var weapon := 1
var fire_cd := 0.0
var ladders := 0
var held: RigidBody3D
var aim_dir := Vector3(0, 0, 1)
var _coyote := 0.0
var _jump_buffer := 0.0
var _was_air := false
var _fall_speed := 0.0
var _grab_was := false
var _released: RigidBody3D
var _release_t := 0.0
var _rig: Node3D
var _hands: Array[MeshInstance3D] = []
var _hand_rest: Array[Vector3] = [Vector3(-0.5, -0.05, 0.12), Vector3(0.5, -0.05, 0.12)]
var _gun_root: Node3D
var _guns := {}
var _bubble: MeshInstance3D


func _ready() -> void:
	team = "player"
	face_locked = true
	super()
	_rig = Node3D.new()
	add_child(_rig)
	var hand_mat := StandardMaterial3D.new()
	hand_mat.albedo_color = color.darkened(0.1)
	hand_mat.roughness = 0.3
	for i in 2:
		var h := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.13
		sm.height = 0.26
		h.mesh = sm
		h.material_override = hand_mat
		h.position = _hand_rest[i]
		_rig.add_child(h)
		_hands.append(h)
	_gun_root = Node3D.new()
	_gun_root.position = Vector3(0.5, -0.02, 0.3)
	_rig.add_child(_gun_root)
	_guns[1] = _make_gun([[Vector3(0, 0, 0), Vector3(0.22, 0.22, 0.22), Color(0.13, 0.14, 0.22)]], true)
	_guns[2] = _make_gun([
		[Vector3(0, 0, 0.05), Vector3(0.12, 0.14, 0.42), Color("3b4a6b")],
		[Vector3(0, 0, 0.3), Vector3(0.07, 0.07, 0.12), Color("4de1ff")],
		[Vector3(0, -0.1, -0.05), Vector3(0.07, 0.12, 0.08), Color("2a3346")]], false)
	_guns[3] = _make_gun([
		[Vector3(-0.05, 0, 0.05), Vector3(0.08, 0.08, 0.5), Color("6b4a2b")],
		[Vector3(0.05, 0, 0.05), Vector3(0.08, 0.08, 0.5), Color("6b4a2b")],
		[Vector3(0, -0.06, -0.15), Vector3(0.16, 0.14, 0.2), Color("ffb347")]], false)
	_bubble = MeshInstance3D.new()
	var bs := SphereMesh.new()
	bs.radius = radius + 0.2
	bs.height = (radius + 0.2) * 2.0
	_bubble.mesh = bs
	var bm := StandardMaterial3D.new()
	bm.albedo_color = Color(0.5, 0.9, 1.0, 0.22)
	bm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	bm.rim_enabled = true
	bm.rim = 1.0
	bm.emission_enabled = true
	bm.emission = Color(0.4, 0.8, 1.0)
	bm.emission_energy_multiplier = 0.4
	_bubble.material_override = bm
	_bubble.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_bubble)
	select_weapon(1)


func _make_gun(pieces: Array, round_shape: bool) -> Node3D:
	var root := Node3D.new()
	for p in pieces:
		var mi := MeshInstance3D.new()
		if round_shape:
			var sm := SphereMesh.new()
			sm.radius = p[1].x
			sm.height = p[1].x * 2.0
			mi.mesh = sm
		else:
			var b := BoxMesh.new()
			b.size = p[1]
			mi.mesh = b
		var m := StandardMaterial3D.new()
		m.albedo_color = p[2]
		m.roughness = 0.35
		mi.material_override = m
		mi.position = p[0]
		root.add_child(mi)
	_gun_root.add_child(root)
	return root


func select_weapon(n: int) -> void:
	weapon = n
	for k in _guns:
		_guns[k].visible = k == n
	_gun_root.scale = Vector3.ONE * 1.4
	main.sfx.play("click", null, 1.0 + n * 0.1)


func bounce(vy: float) -> void:
	linear_velocity = Vector3(linear_velocity.x, vy, linear_velocity.z)
	squash = Vector3(0.65, 1.45, 0.65)


func die() -> void:
	dead = true
	_drop_held()
	main.on_blob_died(self)


func respawn(at: Vector3) -> void:
	hp = max_hp
	dead = false
	linear_velocity = Vector3.ZERO
	global_position = at
	freeze = false
	visible = true
	shield_time = 2.0
	squash = Vector3(0.5, 1.6, 0.5)


func _physics_process(delta: float) -> void:
	if dead:
		return
	var iv := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	move_dir = main.screen_to_world(iv)
	speed_mult = main.fx.goo_slow(global_position)
	facing = aim_dir

	# Coyote time and jump buffering make jumps feel forgiving.
	var grounded := on_ground()
	_coyote = 0.12 if grounded else _coyote - delta
	_jump_buffer = 0.12 if Input.is_action_just_pressed("jump") else _jump_buffer - delta
	if _jump_buffer > 0.0 and _coyote > 0.0:
		apply_central_impulse(Vector3.UP * (JUMP_SPEED - linear_velocity.y) * mass)
		_jump_buffer = 0.0
		_coyote = 0.0
		squash = Vector3(0.7, 1.4, 0.7)
		main.fx.dust(global_position + Vector3.DOWN * radius)
		main.sfx.play("jump", global_position)

	if not grounded:
		_fall_speed = minf(_fall_speed, linear_velocity.y)
	elif _was_air and _fall_speed < -4.0:
		squash = Vector3(1.35, 0.65, 1.35)
		main.fx.dust(global_position + Vector3.DOWN * radius)
	if grounded:
		_fall_speed = 0.0
	_was_air = not grounded

	# Ladders: hold any direction or Space to climb, let go to slide down.
	var climbing := ladders > 0 and (Input.is_action_pressed("jump") or move_dir.length() > 0.1)
	gravity_scale = 0.0 if climbing else 1.6
	if climbing:
		linear_velocity.y = 3.2

	_update_grab(delta)
	super(delta)


func _process(delta: float) -> void:
	super(delta)
	if dead:
		return
	_rig.rotation.y = lerp_angle(_rig.rotation.y, atan2(aim_dir.x, aim_dir.z), 15.0 * delta)
	_rig.scale = visual.scale
	_gun_root.scale = _gun_root.scale.lerp(Vector3.ONE, 12.0 * delta)
	_gun_root.position = _gun_root.position.lerp(Vector3(0.5, -0.02, 0.3), 12.0 * delta)
	_gun_root.visible = held == null
	# Hands reach for whatever is held, otherwise rest at the sides (right hand on the gun).
	for i in 2:
		var goal := _hand_rest[i]
		if held and is_instance_valid(held):
			var side := Vector3(-0.28 if i == 0 else 0.28, 0, 0)
			goal = _rig.to_local(held.global_position) + side
		elif i == 1:
			goal = _gun_root.position + Vector3(0, -0.04, -0.12)
		_hands[i].position = _hands[i].position.lerp(goal, 14.0 * delta)
	_bubble.visible = shield_time > 0.0 and (shield_time > 2.0 or fmod(shield_time, 0.25) < 0.15)
	_bubble.scale = Vector3.ONE * (1.0 + sin(_t * 6.0) * 0.04)


## Called every frame by main with the mouse state.
func weapon_update(delta: float, aim_point: Vector3, pressed: bool, just: bool) -> void:
	fire_cd -= delta
	var flat := Vector3(aim_point.x - global_position.x, 0, aim_point.z - global_position.z)
	if flat.length() > 0.15:
		aim_dir = flat.normalized()
	if dead:
		return
	if held:
		if just:
			_throw_held()
		return
	match weapon:
		1:
			if just and fire_cd <= 0.0:
				main.throw_bomb_at(aim_point)
				fire_cd = 0.6
				_kick(0.1)
		2:
			if pressed and fire_cd <= 0.0:
				_shoot(aim_point, 1, 6.0, 20.0, 6.0, 0.8, Color("4de1ff"), 0.08, 1.0)
				fire_cd = 0.09
				main.sfx.play("pew", global_position, 1.0)
				_kick(0.06)
		3:
			if just and fire_cd <= 0.0:
				_shoot(aim_point, 7, 34.0, 16.0, 7.0, 2.2, Color("ffb347"), 0.1, 3.0)
				fire_cd = 0.75
				apply_central_impulse(-aim_dir * 2.0 * mass)
				main.sfx.play("shotgun", global_position)
				main.shake = maxf(main.shake, 0.3)
				_kick(0.2)


func _kick(amount: float) -> void:
	_gun_root.position -= Vector3(0, 0, amount)


func _shoot(aim_point: Vector3, count: int, spread: float, speed: float, dmg: float, knock: float, c: Color, size: float, grav: float) -> void:
	var muzzle := _gun_root.global_position + aim_dir * 0.35
	var d := (aim_point + Vector3.UP * 0.4 - muzzle).normalized()
	d.y = clampf(d.y, -0.35, 0.35)
	d = d.normalized()
	for i in count:
		var a := 0.0
		if count > 1:
			a = lerpf(-spread, spread, float(i) / (count - 1)) * 0.5 + randf_range(-3.0, 3.0)
		else:
			a = randf_range(-spread, spread) * 0.5
		var v := d.rotated(Vector3.UP, deg_to_rad(a)) * speed * randf_range(0.9, 1.1)
		main.shoot(muzzle, v, c, "player", dmg, grav, size, self, false, knock)
	main.fx.burst(muzzle, c, 3)


# ---------- grabbing ----------

func _update_grab(delta: float) -> void:
	if _released:
		_release_t -= delta
		if _release_t <= 0.0:
			if is_instance_valid(_released):
				remove_collision_exception_with(_released)
			_released = null
	var g := Input.is_action_pressed("grab")
	if g and not _grab_was and held == null:
		held = _find_grabbable()
		if held:
			add_collision_exception_with(held)
			main.sfx.play("pop", global_position, 1.6)
	if held and (not is_instance_valid(held) or (held is Blob and (held as Blob).dead)):
		held = null
	if held:
		var hold_pt := global_position + Vector3.UP * 1.05 + aim_dir * 0.15
		held.linear_velocity = (hold_pt - held.global_position) * 14.0
		held.angular_velocity *= 0.8
		if held.has_method("stunned"):
			held.stunned(0.3)
		if not g:
			_throw_held()
	_grab_was = g


func _find_grabbable() -> RigidBody3D:
	var best: RigidBody3D = null
	var best_d := 1.7
	for n in get_tree().get_nodes_in_group("grabbable"):
		var rb := n as RigidBody3D
		if rb == null or rb == self or (rb is Blob and (rb as Blob).dead):
			continue
		var d := rb.global_position.distance_to(global_position)
		if d < best_d:
			best = rb
			best_d = d
	return best


func _throw_held() -> void:
	if held == null:
		return
	held.linear_velocity = aim_dir * 9.0 + Vector3.UP * 4.5 + Vector3(linear_velocity.x, 0, linear_velocity.z) * 0.5
	if held.has_method("stunned"):
		held.stunned(1.2)
	if held.has_method("thrown"):
		held.thrown()
	_released = held
	_release_t = 0.3
	held = null
	squash = Vector3(1.25, 0.8, 1.25)
	main.sfx.play("throw", global_position)


func _drop_held() -> void:
	if held and is_instance_valid(held):
		remove_collision_exception_with(held)
	held = null
