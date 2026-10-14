extends Blob
## The blob you control. Moves relative to the camera, faces the mouse, has stubby hands
## that punch, hold the current weapon, or grab things (Shift). Climbs ladders.
## Weapons have limited ammo; when a gun runs dry it is dropped and you're back to fists.
## F gets in or out of a nearby car. Jumping while running does a front flip.

const JUMP_SPEED := 7.5
const GUNS := {
	"fist": {"name": "FIST", "ammo": -1},
	"bomb": {"name": "BOMBS", "ammo": 6},
	"blaster": {"name": "BLASTER", "ammo": 30},
	"splatter": {"name": "SPLATTER", "ammo": 8},
	"crossbow": {"name": "CROSSBOW", "ammo": 8},
	"netgun": {"name": "NET GUN", "ammo": 5},
	"laser": {"name": "LASER", "ammo": 50},
	"rocket": {"name": "ROCKETS", "ammo": 4},
}
const MAX_SLOTS := 6
const THROW_RANGE := 8.0

var inventory: Array[Dictionary] = []
var slot := 0
var fire_cd := 0.0
var ladders := 0
var held: RigidBody3D
var aim_dir := Vector3(0, 0, 1)
var speed_t := 0.0
var magnet_t := 0.0
var jump_speed := JUMP_SPEED
var perk := ""
var vehicle: Node3D
var _air_jumps := 0
var _aim_point := Vector3.ZERO
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
var _beam: MeshInstance3D
var _punch_t := 0.0
var _combo := 0
var _combo_t := 0.0
var _laser_tick := 0.0


func _ready() -> void:
	team = "player"
	face_locked = true
	super()
	inventory = [{"id": "fist", "ammo": -1}, {"id": "bomb", "ammo": _ammo_for("bomb")}]
	var starter: String = main.profile.equip["gun"]
	if starter != "bomb" and GUNS.has(starter):
		inventory.append({"id": starter, "ammo": _ammo_for(starter)})
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
	for id in GUNS:
		_guns[id] = _make_gun(id)

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

	_beam = MeshInstance3D.new()
	var beam_mesh := BoxMesh.new()
	beam_mesh.size = Vector3(0.08, 0.08, 1.0)
	_beam.mesh = beam_mesh
	var beam_mat := StandardMaterial3D.new()
	beam_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	beam_mat.albedo_color = Color(1.0, 0.25, 0.35)
	_beam.material_override = beam_mat
	_beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_beam.top_level = true
	_beam.visible = false
	add_child(_beam)
	select_slot(0)


func _make_gun(id: String) -> Node3D:
	var pieces := []
	match id:
		"bomb":
			pieces = [["s", Vector3.ZERO, Vector3(0.22, 0, 0), Color(0.13, 0.14, 0.22)]]
		"blaster":
			pieces = [["b", Vector3(0, 0, 0.05), Vector3(0.12, 0.14, 0.42), Color("3b4a6b")], ["b", Vector3(0, 0, 0.3), Vector3(0.07, 0.07, 0.12), Color("4de1ff")]]
		"splatter":
			pieces = [["b", Vector3(-0.05, 0, 0.05), Vector3(0.08, 0.08, 0.5), Color("6b4a2b")], ["b", Vector3(0.05, 0, 0.05), Vector3(0.08, 0.08, 0.5), Color("6b4a2b")], ["b", Vector3(0, -0.06, -0.15), Vector3(0.16, 0.14, 0.2), Color("ffb347")]]
		"crossbow":
			pieces = [["b", Vector3(0, 0, 0.05), Vector3(0.08, 0.08, 0.5), Color("8b5e3c")], ["b", Vector3(0, 0, 0.25), Vector3(0.55, 0.04, 0.05), Color("5e3d24")], ["b", Vector3(0, 0.05, 0.12), Vector3(0.03, 0.03, 0.4), Color("e8d8b0")]]
		"netgun":
			pieces = [["b", Vector3(0, 0, 0.05), Vector3(0.16, 0.16, 0.4), Color("4c6b3a")], ["s", Vector3(0, 0, 0.28), Vector3(0.11, 0, 0), Color("b6ff8a")]]
		"laser":
			pieces = [["b", Vector3(0, 0, 0.05), Vector3(0.12, 0.12, 0.45), Color("eef2f7")], ["b", Vector3(0, 0, 0.3), Vector3(0.06, 0.06, 0.1), Color("ff4d6d")]]
		"rocket":
			pieces = [["b", Vector3(0, 0.03, 0.0), Vector3(0.17, 0.17, 0.65), Color("6b7a3a")], ["s", Vector3(0, 0.03, 0.34), Vector3(0.08, 0, 0), Color("ff5a3d")]]
	var root := Node3D.new()
	for p in pieces:
		var mi := MeshInstance3D.new()
		if p[0] == "s":
			var sm := SphereMesh.new()
			sm.radius = p[2].x
			sm.height = p[2].x * 2.0
			mi.mesh = sm
		else:
			var b := BoxMesh.new()
			b.size = p[2]
			mi.mesh = b
		var m := StandardMaterial3D.new()
		m.albedo_color = p[3]
		m.roughness = 0.35
		mi.material_override = m
		mi.position = p[1]
		root.add_child(mi)
	_gun_root.add_child(root)
	return root


func weapon_id() -> String:
	return inventory[slot]["id"]


func select_slot(i: int) -> void:
	if i < 0 or i >= inventory.size():
		return
	slot = i
	var id := weapon_id()
	for k in _guns:
		_guns[k].visible = k == id
	_gun_root.scale = Vector3.ONE * 1.4
	main.sfx.play("click", null, 1.0 + i * 0.1)


func _ammo_for(id: String) -> int:
	var base: int = GUNS[id]["ammo"]
	return base if base < 0 else int(round(base * main.profile.ammo_mult(id)))


func _dmg(id: String, base: float) -> float:
	return base * main.profile.gun_mult(id)


func give_weapon(id: String, ammo := -2) -> void:
	if ammo == -2:
		ammo = _ammo_for(id)
	for i in inventory.size():
		if inventory[i]["id"] == id:
			inventory[i]["ammo"] += ammo
			select_slot(i)
			return
	if inventory.size() >= MAX_SLOTS:
		inventory.remove_at(inventory.size() - 1)
	inventory.append({"id": id, "ammo": ammo})
	select_slot(inventory.size() - 1)


func _use_ammo(n := 1) -> void:
	var item := inventory[slot]
	if item["ammo"] < 0:
		return
	item["ammo"] -= n
	if item["ammo"] <= 0:
		# Out of ammo: toss the empty gun away and fall back to fists.
		main.fx.particle(_gun_root.global_position, Vector3(randf_range(-2, 2), 4.0, randf_range(-2, 2)), 0.3, 1.0, main.fx.mat(Color("6b7385")), 14.0, false, main.fx.unit_box)
		main.fx.float_text(global_position + Vector3.UP, "OUT OF AMMO", Color("ffb0b0"), 34)
		inventory.remove_at(slot)
		select_slot(0)


func bounce(vy: float) -> void:
	linear_velocity = Vector3(linear_velocity.x, vy, linear_velocity.z)
	squash = Vector3(0.65, 1.45, 0.65)


func die() -> void:
	leave_vehicle()
	dead = true
	_drop_held()
	_beam.visible = false
	main.on_blob_died(self)


func respawn(at: Vector3) -> void:
	hp = max_hp
	dead = false
	rag_t = 0.0
	lock_rotation = true
	rotation = Vector3.ZERO
	linear_velocity = Vector3.ZERO
	global_position = at
	freeze = false
	visible = true
	shield_time = 2.0
	squash = Vector3(0.5, 1.6, 0.5)
	trick("spin", 0.6, 1.0)


func enter_vehicle(v: Node3D) -> void:
	_drop_held()
	vehicle = v
	v.enter(self)
	freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
	freeze = true
	prints = false
	ladders = 0
	trick("flip", 0.45, 1.0)


func leave_vehicle() -> void:
	if vehicle == null:
		return
	var v := vehicle
	vehicle = null
	if is_instance_valid(v):
		v.eject()
	freeze = false
	prints = true
	linear_velocity = Vector3(0, 5.0, 0)
	trick("flip", 0.5, 1.0)


func _physics_process(delta: float) -> void:
	if dead:
		return
	speed_t -= delta
	magnet_t -= delta
	if perk == "regen" and hp < max_hp:
		hp = minf(hp + 3.0 * delta, max_hp)
	if Input.is_action_just_pressed("drive"):
		if vehicle:
			leave_vehicle()
		else:
			var v := _nearest_vehicle()
			if v:
				enter_vehicle(v)
	if vehicle:
		if not is_instance_valid(vehicle):
			vehicle = null
			freeze = false
			prints = true
		else:
			move_dir = Vector3.ZERO
			super(delta)
			return
	var iv := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	move_dir = main.screen_to_world(iv)
	speed_mult = main.fx.goo_slow(global_position) * (1.7 if speed_t > 0.0 else 1.0)
	facing = aim_dir

	# Coyote time and jump buffering make jumps feel forgiving.
	var grounded := on_ground()
	_coyote = 0.12 if grounded else _coyote - delta
	_jump_buffer = 0.12 if Input.is_action_just_pressed("jump") else _jump_buffer - delta
	if grounded:
		_air_jumps = 1 if perk == "double_jump" else 0
	if _jump_buffer > 0.0 and _coyote > 0.0 and rag_t <= 0.0:
		apply_central_impulse(Vector3.UP * (jump_speed - linear_velocity.y) * mass)
		_jump_buffer = 0.0
		_coyote = 0.0
		squash = Vector3(0.7, 1.4, 0.7)
		main.fx.dust(global_position + Vector3.DOWN * radius)
		main.sfx.play("jump", global_position)
		if Vector2(linear_velocity.x, linear_velocity.z).length() > 3.5:
			trick("flip", 0.5, 1.0)
	elif _jump_buffer > 0.0 and _air_jumps > 0 and ladders == 0 and rag_t <= 0.0:
		_air_jumps -= 1
		_jump_buffer = 0.0
		apply_central_impulse(Vector3.UP * (jump_speed * 0.9 - linear_velocity.y) * mass)
		trick("flip", 0.4, 1.0)
		main.fx.ring(global_position + Vector3.DOWN * radius, Color(1, 1, 1, 0.8), 1.0, 0.25)
		main.sfx.play("jump", global_position, 1.3)

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
	_punch_t -= delta
	_combo_t -= delta
	_rig.rotation.y = lerp_angle(_rig.rotation.y, atan2(aim_dir.x, aim_dir.z) - rotation.y, 15.0 * delta)
	_rig.rotation.x = visual.rotation.x
	_rig.rotation.z = visual.rotation.z
	_rig.scale = visual.scale
	_gun_root.scale = _gun_root.scale.lerp(Vector3.ONE, 12.0 * delta)
	_gun_root.position = _gun_root.position.lerp(Vector3(0.5, -0.02, 0.3), 12.0 * delta)
	_gun_root.visible = held == null
	# Hands: punch forward, reach for what's held, otherwise rest (right hand on the gun).
	for i in 2:
		var goal := _hand_rest[i]
		if held and is_instance_valid(held):
			var side := Vector3(-0.28 if i == 0 else 0.28, 0, 0)
			goal = _rig.to_local(held.global_position) + side
		elif _punch_t > 0.0 and i == (_combo % 2):
			goal = Vector3(0.15 if i == 1 else -0.15, 0.05, 0.85)
		elif i == 1 and weapon_id() != "fist":
			goal = _gun_root.position + Vector3(0, -0.04, -0.12)
		_hands[i].position = _hands[i].position.lerp(goal, 22.0 * delta)
	_bubble.visible = shield_time > 0.0 and (shield_time > 2.0 or fmod(shield_time, 0.25) < 0.15)
	_bubble.scale = Vector3.ONE * (1.0 + sin(_t * 6.0) * 0.04)


## Called every frame by main with the mouse state.
func weapon_update(delta: float, aim_point: Vector3, pressed: bool, just: bool) -> void:
	fire_cd -= delta
	_aim_point = aim_point
	var flat := Vector3(aim_point.x - global_position.x, 0, aim_point.z - global_position.z)
	if flat.length() > 0.15:
		aim_dir = flat.normalized()
	_beam.visible = false
	if dead or rag_t > 0.0:
		return
	if held:
		if just:
			_throw_held()
		return
	if vehicle and is_instance_valid(vehicle) and vehicle.get("_turret"):
		return
	var id := weapon_id()
	match id:
		"fist":
			if just and fire_cd <= 0.0:
				_punch()
		"bomb":
			if just and fire_cd <= 0.0:
				main.throw_bomb_at(aim_point)
				fire_cd = 0.6
				_kick(0.1)
				_use_ammo()
		"blaster":
			if pressed and fire_cd <= 0.0:
				_shoot(aim_point, 1, 6.0, 20.0, _dmg(id, 6.0), 0.8, Color("4de1ff"), 0.08, 1.0, "bullet")
				fire_cd = 0.09
				main.sfx.play("pew", global_position)
				_kick(0.06)
				_use_ammo()
		"splatter":
			if just and fire_cd <= 0.0:
				_shoot(aim_point, 7, 34.0, 16.0, _dmg(id, 7.0), 2.2, Color("ffb347"), 0.1, 3.0, "bullet")
				fire_cd = 0.75
				apply_central_impulse(-aim_dir * 2.0 * mass)
				main.sfx.play("shotgun", global_position)
				main.shake = maxf(main.shake, 0.3)
				_kick(0.2)
				_use_ammo()
		"crossbow":
			if just and fire_cd <= 0.0:
				_shoot(aim_point, 1, 0.0, 28.0, _dmg(id, 30.0), 3.0, Color("e8d8b0"), 0.06, 1.0, "bolt")
				fire_cd = 0.6
				main.sfx.play("twang", global_position)
				_kick(0.12)
				_use_ammo()
		"netgun":
			if just and fire_cd <= 0.0:
				_shoot(aim_point, 1, 0.0, 13.0, _dmg(id, 2.0), 0.5, Color("b6ff8a"), 0.12, 5.0, "net")
				fire_cd = 0.8
				main.sfx.play("net", global_position)
				_kick(0.12)
				_use_ammo()
		"laser":
			if pressed:
				_fire_laser(delta)
		"rocket":
			if just and fire_cd <= 0.0:
				_shoot(aim_point, 1, 0.0, 14.0, _dmg(id, 45.0), 0.0, Color("ff5a3d"), 0.1, 0.5, "rocket")
				fire_cd = 1.0
				apply_central_impulse(-aim_dir * 3.0 * mass)
				main.sfx.play("rocket", global_position)
				main.shake = maxf(main.shake, 0.4)
				_kick(0.25)
				_use_ammo()


func _kick(amount: float) -> void:
	_gun_root.position -= Vector3(0, 0, amount)


func _shoot(aim_point: Vector3, count: int, spread: float, speed: float, dmg: float, knock: float, c: Color, size: float, grav: float, kind: String) -> void:
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
		var v := d.rotated(Vector3.UP, deg_to_rad(a)) * speed * randf_range(0.95, 1.05)
		main.shoot(muzzle, v, c, "player", dmg, grav, size, self, false, knock, kind)
	main.fx.burst(muzzle, c, 3)


func _fire_laser(delta: float) -> void:
	var muzzle := _gun_root.global_position + aim_dir * 0.4
	var to := muzzle + aim_dir * 12.0
	var q := PhysicsRayQueryParameters3D.create(muzzle, to)
	q.exclude = [get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	var body: Object = null
	if not hit.is_empty():
		to = hit["position"]
		body = hit["collider"]
	_beam.visible = true
	_beam.global_position = (muzzle + to) / 2.0
	if muzzle.distance_to(to) > 0.05:
		_beam.look_at(to, Vector3.UP)
	_beam.scale = Vector3(1.0 + randf() * 0.5, 1.0 + randf() * 0.5, muzzle.distance_to(to))
	_laser_tick -= delta
	if _laser_tick <= 0.0:
		_laser_tick = 0.1
		main.sfx.play("laser", global_position, 1.0, -8.0)
		main.fx.burst(to, Color(1.0, 0.4, 0.5), 2)
		if body and body.has_method("take_damage") and body.get("team") != team:
			body.take_damage(_dmg("laser", 4.0))
		elif body and body.has_method("shatter"):
			body.shatter()
		_use_ammo()


func _punch() -> void:
	_combo = _combo + 1 if _combo_t > 0.0 else 1
	_combo_t = 0.8
	var big := _combo >= 3
	if big:
		_combo = 0
	fire_cd = 0.3
	_punch_t = 0.15
	apply_central_impulse(aim_dir * 2.5 * mass)
	main.sfx.play("punch", global_position, 0.8 if big else 1.0)
	var hit_any := false
	for group in ["actor", "prop"]:
		for n in get_tree().get_nodes_in_group(group):
			var rb := n as RigidBody3D
			if rb == null or rb == self:
				continue
			if rb is Blob and ((rb as Blob).dead or (rb as Blob).team == team):
				continue
			var d := rb.global_position - global_position
			var reach: float = radius + 0.9 + ((rb as Blob).radius if rb is Blob else 0.35)
			if Vector2(d.x, d.z).length() > reach or absf(d.y) > 1.2 or d.normalized().dot(aim_dir) < 0.3:
				continue
			hit_any = true
			var strong := 1.6 if perk == "punch" else 1.0
			var push := (aim_dir * (14.0 if big else 9.0) + Vector3.UP * (8.0 if big else 4.0)) * sqrt(strong)
			if rb is Blob:
				var b := rb as Blob
				b.take_damage((25.0 if big else 14.0) * strong, push)
				b.ragdoll(1.6 if big else 0.9)
				if big:
					b.trick("barrel", 0.6, 2.0)
			else:
				rb.apply_central_impulse(push * rb.mass * 0.6)
	for g in get_tree().get_nodes_in_group("glass"):
		if (g as Node3D).global_position.distance_to(global_position + aim_dir * 0.8) < 1.0:
			g.shatter()
	if hit_any:
		main.fx.burst(global_position + aim_dir * 0.9, Color(1, 1, 1), 8)
		main.shake = maxf(main.shake, 0.5 if big else 0.25)
		if big:
			main.fx.float_text(global_position + aim_dir + Vector3.UP, "POW!", Color("ffe066"), 60)
			trick("spin", 0.35, 1.0)


# ---------- grabbing ----------

func _update_grab(delta: float) -> void:
	if _released:
		_release_t -= delta
		if _release_t <= 0.0:
			if is_instance_valid(_released):
				remove_collision_exception_with(_released)
			_released = null
	var g := Input.is_action_pressed("grab") and vehicle == null
	if g and not _grab_was and held == null and rag_t <= 0.0:
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


## Where a held thing will land: the cursor, clamped to throwing range.
func throw_target() -> Vector3:
	var start := held.global_position if held else global_position
	var flat := Vector3(_aim_point.x - start.x, 0, _aim_point.z - start.z)
	if flat.length() > THROW_RANGE:
		flat = flat.normalized() * THROW_RANGE
	return Vector3(start.x + flat.x, _aim_point.y + 0.4, start.z + flat.z)


func throw_time() -> float:
	var start := held.global_position if held else global_position
	var t := throw_target()
	return clampf(0.35 + Vector2(t.x - start.x, t.z - start.z).length() * 0.06, 0.4, 0.95)


func _throw_held() -> void:
	if held == null:
		return
	# A lob that lands on the cursor. Damping is switched off for the flight so it arrives.
	var g := 9.8 * held.gravity_scale
	var flight := throw_time()
	held.linear_velocity = main.ballistic(held.global_position, throw_target(), flight, g)
	var rb := held
	var damp := rb.linear_damp
	rb.linear_damp = 0.0
	get_tree().create_timer(flight + 0.1).timeout.connect(func() -> void:
		if is_instance_valid(rb):
			rb.linear_damp = 6.0 if rb is Blob and (rb as Blob).net_t > 0.0 else damp)
	if held is Blob:
		(held as Blob).ragdoll(1.2)
	if held.has_method("thrown"):
		held.thrown()
	_released = held
	_release_t = 0.3
	held = null
	squash = Vector3(1.25, 0.8, 1.25)
	main.sfx.play("throw", global_position)


func _nearest_vehicle() -> Node3D:
	var best: Node3D = null
	var best_d := 2.6
	for v in get_tree().get_nodes_in_group("vehicle"):
		if v.dead or v.driver != null:
			continue
		var d: float = (v as Node3D).global_position.distance_to(global_position)
		if d < best_d:
			best = v
			best_d = d
	return best


func _drop_held() -> void:
	if held and is_instance_valid(held):
		remove_collision_exception_with(held)
	held = null
