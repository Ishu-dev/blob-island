extends Node3D
## Builds the whole prototype in code: random island, light, sea, camera rig, HUD,
## waves of enemies, mouse-aimed bomb throwing, and all the juice (particles, splats, text).

const Player := preload("res://scripts/player.gd")
const Enemy := preload("res://scripts/enemy.gd")
const Bomb := preload("res://scripts/bomb.gd")
const HealthBar := preload("res://scripts/health_bar.gd")

const ISLAND_SIZE := 22
const STEP := 0.35          # height of one terrace level
const BASE := -1.0          # tile bottoms sit below the sea
const MAX_ALIVE := 6
const BOMB_COOLDOWN := 0.6
const BOMB_RANGE := 9.0
const KILL_Y := -4.0
const CAM_DIST := 19.8
const CAM_HEIGHT := 14.0
const AIM_DOTS := 16

var rng := RandomNumberGenerator.new()
var land_tiles: Array[Vector3] = []   # top-centre of every land tile
var spawn_point := Vector3.ZERO
var island_root: Node3D
var player: Blob
var camera: Camera3D
var hud: Label
var banner: Label
var bar_layer: CanvasLayer
var mats := {}

# camera rig
var cam_target := Vector3.ZERO
var cam_yaw := 45.0
var cam_yaw_goal := 45.0
var cam_zoom := 15.0
var cam_zoom_goal := 15.0
var shake := 0.0

# game state
var wave := 0
var to_spawn := 0
var spawn_timer := 0.0
var wave_break := 0.0
var bomb_timer := 0.0
var kills := 0
var lives := 3

# fx
var parts: Array[Dictionary] = []
var puddles: Array[Dictionary] = []
var drop_mats := {}
var unit_sphere := SphereMesh.new()
var aim_dots: Array[MeshInstance3D] = []
var aim_ring: MeshInstance3D
var aim_mat: StandardMaterial3D

# screenshot test mode
var _shot_path := ""
var _shot_frame := 95
var _frame := 0


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--screenshot="):
			_shot_path = a.trim_prefix("--screenshot=")
		elif a.begins_with("--shotframe="):
			_shot_frame = int(a.trim_prefix("--shotframe="))
	unit_sphere.radius = 0.5
	unit_sphere.height = 1.0
	unit_sphere.radial_segments = 12
	unit_sphere.rings = 6
	_setup_input()
	_setup_world()
	_setup_aim()
	new_island()


# ---------- setup ----------

func _setup_input() -> void:
	_bind("move_left", [KEY_A, KEY_LEFT])
	_bind("move_right", [KEY_D, KEY_RIGHT])
	_bind("move_up", [KEY_W, KEY_UP])
	_bind("move_down", [KEY_S, KEY_DOWN])
	_bind("jump", [KEY_SPACE])
	_bind("throw_key", [KEY_F])
	_bind("rotate_left", [KEY_Q])
	_bind("rotate_right", [KEY_E])
	_bind("new_island", [KEY_R])


func _bind(action: String, keys: Array) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	for k in keys:
		var ev := InputEventKey.new()
		ev.physical_keycode = k
		InputMap.action_add_event(action, ev)


func _setup_world() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.13, 0.42, 0.52)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.75, 0.82, 0.95)
	env.ambient_light_energy = 0.55
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.25
	env.ssao_enabled = true
	env.glow_enabled = true
	env.glow_intensity = 0.6
	env.glow_hdr_threshold = 1.2
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, -30, 0)
	sun.light_energy = 1.15
	sun.light_color = Color(1.0, 0.96, 0.88)
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 60.0
	add_child(sun)

	var sea := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(300, 300)
	sea.mesh = pm
	var sea_mat := StandardMaterial3D.new()
	sea_mat.albedo_color = Color(0.2, 0.62, 0.72, 0.85)
	sea_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sea_mat.roughness = 0.15
	sea.material_override = sea_mat
	sea.position.y = -0.15
	add_child(sea)

	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = cam_zoom
	camera.near = 0.1
	camera.far = 200.0
	add_child(camera)

	bar_layer = CanvasLayer.new()
	add_child(bar_layer)
	var layer := CanvasLayer.new()
	layer.layer = 2
	add_child(layer)
	hud = Label.new()
	var ls := LabelSettings.new()
	ls.font_size = 20
	ls.outline_size = 6
	ls.outline_color = Color(0, 0, 0, 0.6)
	hud.label_settings = ls
	hud.position = Vector2(20, 16)
	layer.add_child(hud)

	banner = Label.new()
	var bs := LabelSettings.new()
	bs.font_size = 64
	bs.outline_size = 14
	bs.outline_color = Color(0.1, 0.05, 0.2, 0.8)
	banner.label_settings = bs
	banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner.size = Vector2(1280, 90)
	banner.position = Vector2(0, 230)
	banner.pivot_offset = Vector2(640, 45)
	banner.modulate.a = 0.0
	layer.add_child(banner)

	for key in ["grass_a", "grass_b", "grass_hi", "sand", "dirt", "trunk", "leaf", "rock"]:
		mats[key] = StandardMaterial3D.new()
	mats["grass_a"].albedo_color = Color("7cc35a")
	mats["grass_b"].albedo_color = Color("6cb44f")
	mats["grass_hi"].albedo_color = Color("93d16a")
	mats["sand"].albedo_color = Color("e6c47f")
	mats["dirt"].albedo_color = Color("a8703f")
	mats["trunk"].albedo_color = Color("8a5a35")
	mats["leaf"].albedo_color = Color("3f9a55")
	mats["rock"].albedo_color = Color("9aa3ad")
	for m in mats.values():
		m.roughness = 0.9


func _setup_aim() -> void:
	aim_mat = StandardMaterial3D.new()
	aim_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	aim_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	aim_mat.albedo_color = Color(1, 1, 1, 0.75)
	aim_mat.no_depth_test = true
	for i in AIM_DOTS:
		var d := MeshInstance3D.new()
		d.mesh = unit_sphere
		d.material_override = aim_mat
		d.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		d.scale = Vector3.ONE * 0.09
		add_child(d)
		aim_dots.append(d)
	aim_ring = MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.42
	tm.outer_radius = 0.5
	aim_ring.mesh = tm
	aim_ring.material_override = aim_mat
	aim_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(aim_ring)


# ---------- island generation ----------

func new_island() -> void:
	if island_root:
		island_root.queue_free()
	for group in ["actor", "bomb"]:
		for n in get_tree().get_nodes_in_group(group):
			n.queue_free()
	for p in puddles:
		(p["node"] as Node).queue_free()
	puddles.clear()
	kills = 0
	lives = 3
	wave = 0
	to_spawn = 0
	wave_break = 1.2

	island_root = Node3D.new()
	add_child(island_root)
	rng.randomize()
	var noise := FastNoiseLite.new()
	noise.seed = rng.randi()
	noise.frequency = 0.09

	# Height field: noise plus a radial falloff so it reads as an island.
	var levels := {}
	var half := ISLAND_SIZE / 2.0
	for x in ISLAND_SIZE:
		for z in ISLAND_SIZE:
			var dx := (x - half + 0.5) / half
			var dz := (z - half + 0.5) / half
			var h := (1.0 - sqrt(dx * dx + dz * dz)) * 1.1 + noise.get_noise_2d(x, z) * 0.5
			if h > 0.3:
				levels[Vector2i(x, z)] = clampi(int((h - 0.3) / 0.25), 0, 3)

	# Keep only the landmass connected to the centre, so there are no unreachable islets.
	var start := Vector2i(ISLAND_SIZE / 2, ISLAND_SIZE / 2)
	var keep := {}
	var queue: Array[Vector2i] = [start]
	keep[start] = true
	while not queue.is_empty():
		var c: Vector2i = queue.pop_back()
		for o in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = c + o
			if levels.has(n) and not keep.has(n):
				keep[n] = true
				queue.append(n)

	land_tiles.clear()
	for cell in keep.keys():
		var level: int = levels[cell]
		var wx: float = cell.x - half + 0.5
		var wz: float = cell.y - half + 0.5
		var top := level * STEP
		_make_tile(wx, wz, top, level, (cell.x + cell.y) % 2 == 0)
		land_tiles.append(Vector3(wx, top, wz))
		if cell == start:
			spawn_point = Vector3(wx, top + 1.2, wz)
		elif level >= 1 and rng.randf() < 0.07 and Vector2(wx, wz).length() > 2.5:
			_make_tree(Vector3(wx, top, wz))
		elif rng.randf() < 0.04:
			_make_rock(Vector3(wx, top, wz))

	_spawn_player()


func _make_tile(x: float, z: float, top: float, level: int, checker: bool) -> void:
	var tile := StaticBody3D.new()
	tile.position = Vector3(x, (top + BASE) / 2.0, z)
	var height := top - BASE
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(1, height, 1)
	col.shape = shape
	tile.add_child(col)

	var cap_h := 0.14
	var body := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(1, height - cap_h, 1)
	body.mesh = bm
	body.material_override = mats["dirt"]
	body.position.y = -cap_h / 2.0
	tile.add_child(body)

	var cap := MeshInstance3D.new()
	var cm := BoxMesh.new()
	cm.size = Vector3(1, cap_h, 1)
	cap.mesh = cm
	if level == 0:
		cap.material_override = mats["sand"]
	elif level >= 3:
		cap.material_override = mats["grass_hi"]
	else:
		cap.material_override = mats["grass_a"] if checker else mats["grass_b"]
	cap.position.y = height / 2.0 - cap_h / 2.0
	tile.add_child(cap)
	island_root.add_child(tile)


func _make_tree(at: Vector3) -> void:
	var tree := StaticBody3D.new()
	tree.position = at
	var col := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = 0.25
	shape.height = 1.6
	col.shape = shape
	col.position.y = 0.8
	tree.add_child(col)

	var trunk := MeshInstance3D.new()
	var tm := CylinderMesh.new()
	tm.top_radius = 0.1
	tm.bottom_radius = 0.14
	tm.height = 0.6
	trunk.mesh = tm
	trunk.material_override = mats["trunk"]
	trunk.position.y = 0.3
	tree.add_child(trunk)

	for i in 2:
		var cone := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.0
		cm.bottom_radius = 0.55 - i * 0.15
		cm.height = 0.8
		cone.mesh = cm
		cone.material_override = mats["leaf"]
		cone.position.y = 0.85 + i * 0.45
		tree.add_child(cone)
	island_root.add_child(tree)


func _make_rock(at: Vector3) -> void:
	var rock := StaticBody3D.new()
	var s := rng.randf_range(0.25, 0.4)
	rock.position = at + Vector3(rng.randf_range(-0.2, 0.2), s * 0.5, rng.randf_range(-0.2, 0.2))
	rock.rotation.y = rng.randf() * TAU
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(s * 1.4, s, s * 1.2)
	col.shape = shape
	rock.add_child(col)
	var mesh := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = shape.size
	mesh.mesh = bm
	mesh.material_override = mats["rock"]
	rock.add_child(mesh)
	island_root.add_child(rock)


# ---------- actors ----------

func _spawn_player() -> void:
	player = Player.new()
	player.main = self
	player.color = Color("8fd3ff")
	player.radius = 0.45
	player.max_hp = 100.0
	player.add_to_group("player")
	add_child(player)
	player.global_position = spawn_point
	cam_target = Vector3(spawn_point.x, 0, spawn_point.z)
	_add_bar(player, Color("5ee07a"), 56.0)


func _spawn_enemy() -> void:
	var far: Array[Vector3] = []
	for t in land_tiles:
		if Vector2(t.x - player.global_position.x, t.z - player.global_position.z).length() > 6.0:
			far.append(t)
	if far.is_empty():
		far = land_tiles
	var e := Enemy.new()
	e.main = self
	e.color = Color("f2789a")
	e.radius = 0.38
	e.accel = 13.0
	e.max_speed = 3.2 + wave * 0.15
	e.max_hp = 45.0 + wave * 5.0
	e.target = player
	add_child(e)
	# Drop in from the sky so spawns are visible and readable.
	e.global_position = far[rng.randi() % far.size()] + Vector3.UP * 6.0
	_add_bar(e, Color("ff5d73"), 40.0)


func _add_bar(b: Blob, c: Color, w: float) -> void:
	var bar := HealthBar.new()
	bar.target = b
	bar.camera = camera
	bar.fill_color = c
	bar.bar_width = w
	bar_layer.add_child(bar)


func on_blob_died(b: Blob) -> void:
	if b == player:
		lives -= 1
		spawn_splat(player.global_position + Vector3.DOWN * 0.4, player.color, 1.6)
		burst(player.global_position, player.color, 20)
		player.visual.visible = false
		player.set_deferred("freeze", true)
		shake = 0.8
		if lives <= 0:
			show_banner("GAME OVER", Color("ff6b6b"))
			get_tree().create_timer(2.0).timeout.connect(new_island)
		else:
			get_tree().create_timer(1.2).timeout.connect(func() -> void:
				if is_instance_valid(player):
					player.respawn(spawn_point))
	else:
		kills += 1
		shake = maxf(shake, 0.3)


# ---------- bombs and aiming ----------

## Velocity that carries a projectile from start to target in time t under gravity g.
func ballistic(start: Vector3, target: Vector3, t: float, g: float) -> Vector3:
	var v := (target - start) / t
	v.y += 0.5 * g * t
	return v


func _throw_origin() -> Vector3:
	return player.global_position + Vector3.UP * 0.6


## Where the bomb will land, clamped to throwing range. Close targets give short lobs.
func _aim_target(raw: Vector3) -> Vector3:
	var start := _throw_origin()
	var flat := Vector3(raw.x - start.x, 0, raw.z - start.z)
	if flat.length() > BOMB_RANGE:
		flat = flat.normalized() * BOMB_RANGE
	return Vector3(start.x + flat.x, raw.y + 0.25, start.z + flat.z)


func _flight_time(start: Vector3, target: Vector3) -> float:
	var dist := Vector2(target.x - start.x, target.z - start.z).length()
	return clampf(0.35 + dist * 0.07, 0.4, 1.0)


func mouse_world() -> Vector3:
	var mp := get_viewport().get_mouse_position()
	var from := camera.project_ray_origin(mp)
	var dir := camera.project_ray_normal(mp)
	var q := PhysicsRayQueryParameters3D.create(from, from + dir * 200.0)
	if is_instance_valid(player):
		q.exclude = [player.get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if not hit.is_empty():
		return hit["position"]
	var on_plane = Plane(Vector3.UP, 0.0).intersects_ray(from, dir)
	return on_plane if on_plane != null else player.global_position


func throw_bomb_at(raw: Vector3) -> void:
	if bomb_timer > 0.0 or not is_instance_valid(player) or player.dead:
		return
	bomb_timer = BOMB_COOLDOWN
	var start := _throw_origin()
	var target := _aim_target(raw)
	var t := _flight_time(start, target)
	var b := Bomb.new()
	b.main = self
	b.thrower = player
	add_child(b)
	b.global_position = start
	b.linear_velocity = ballistic(start, target, t, 9.8)
	# Tumble forward like a BombSquad bomb, with a little random wobble.
	var dir := Vector3(target.x - start.x, 0, target.z - start.z).normalized()
	if dir.length() > 0.01:
		player.facing = dir
		b.angular_velocity = Vector3.UP.cross(dir) * 10.0 + Vector3(rng.randf_range(-2, 2), rng.randf_range(-3, 3), 0)
	player.squash = Vector3(1.25, 0.75, 1.25)


func _update_aim() -> void:
	var visible_aim := is_instance_valid(player) and not player.dead and _shot_path == ""
	aim_ring.visible = visible_aim
	for d in aim_dots:
		d.visible = visible_aim
	if not visible_aim:
		return
	var start := _throw_origin()
	var target := _aim_target(mouse_world())
	var t := _flight_time(start, target)
	var v := ballistic(start, target, t, 9.8)
	for i in AIM_DOTS:
		var s := t * float(i + 1) / AIM_DOTS
		aim_dots[i].global_position = start + v * s + Vector3.DOWN * 4.9 * s * s
	aim_ring.global_position = target + Vector3.DOWN * 0.2
	var can_throw := bomb_timer <= 0.0
	aim_mat.albedo_color = Color(1, 1, 1, 0.75) if can_throw else Color(1, 0.5, 0.5, 0.35)
	aim_ring.scale = Vector3.ONE * (1.0 + 0.08 * sin(Time.get_ticks_msec() * 0.008))


# ---------- fx ----------

func _drop_mat(c: Color) -> StandardMaterial3D:
	var key := c.to_html()
	if not drop_mats.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = c
		m.roughness = 0.1
		drop_mats[key] = m
	return drop_mats[key]


func _particle(pos: Vector3, vel: Vector3, size: float, life: float, mat: Material, gravity := 14.0, grow := false) -> void:
	var n := MeshInstance3D.new()
	n.mesh = unit_sphere
	n.material_override = mat
	n.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	n.scale = Vector3.ONE * size
	add_child(n)
	n.global_position = pos
	parts.append({"node": n, "vel": vel, "life": life, "max": life, "size": size, "g": gravity, "grow": grow})


func droplet(pos: Vector3, c: Color, vel: Vector3, size: float) -> void:
	_particle(pos, vel, size, 0.4, _drop_mat(c))


func burst(pos: Vector3, c: Color, count: int) -> void:
	for i in count:
		var v := Vector3(rng.randf_range(-1, 1), rng.randf_range(0.6, 1.6), rng.randf_range(-1, 1)) * rng.randf_range(2.0, 4.5)
		_particle(pos, v, rng.randf_range(0.08, 0.18), rng.randf_range(0.35, 0.6), _drop_mat(c))


func dust(pos: Vector3) -> void:
	for i in 6:
		var a := TAU * i / 6.0
		_particle(pos, Vector3(cos(a), 0.3, sin(a)) * 1.6, 0.16, 0.35, _drop_mat(Color(0.95, 0.92, 0.85)), 0.0, true)


func spawn_splat(at: Vector3, c: Color, size: float, normal := Vector3.UP) -> void:
	if normal.y < 0.6:
		return   # hit a wall or a blob's side; the droplet burst is enough
	var root := Node3D.new()
	add_child(root)
	root.global_position = at + Vector3.UP * 0.02
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(c.r, c.g, c.b, 0.9)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.roughness = 0.05
	mat.rim_enabled = true
	# A few overlapping flat discs make an uneven puddle shape.
	for i in 4:
		var disc := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.5
		cm.bottom_radius = 0.5
		cm.height = 0.03
		cm.radial_segments = 16
		disc.mesh = cm
		disc.material_override = mat
		disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var r := 0.0 if i == 0 else rng.randf_range(0.2, 0.35) * size
		var a := rng.randf() * TAU
		disc.position = Vector3(cos(a) * r, 0.005 * i, sin(a) * r)
		var s := size * (0.9 if i == 0 else rng.randf_range(0.35, 0.55))
		disc.scale = Vector3(s, 1, s * rng.randf_range(0.75, 1.0))
		root.add_child(disc)
	root.scale = Vector3(0.1, 1, 0.1)
	var tw := create_tween()
	tw.tween_property(root, "scale", Vector3.ONE, 0.35).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	tw.tween_interval(3.0)
	tw.tween_property(root, "scale", Vector3(0.05, 1, 0.05), 0.8).set_ease(Tween.EASE_IN)
	tw.tween_callback(root.queue_free)
	puddles.append({"node": root, "pos": at, "r": size * 0.45, "until": Time.get_ticks_msec() + 4000})


## Speed multiplier for a blob standing at pos: goo puddles slow you down.
func goo_slow(pos: Vector3) -> float:
	var now := Time.get_ticks_msec()
	for p in puddles:
		if p["until"] < now:
			continue
		var c: Vector3 = p["pos"]
		if absf(pos.y - c.y) < 0.8 and Vector2(pos.x - c.x, pos.z - c.z).length() < p["r"]:
			return 0.5
	return 1.0


func explosion(at: Vector3, radius: float) -> void:
	# Flash ball
	var flash := MeshInstance3D.new()
	flash.mesh = unit_sphere
	var fm := StandardMaterial3D.new()
	fm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fm.albedo_color = Color(1.0, 0.85, 0.45, 0.95)
	flash.material_override = fm
	flash.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	flash.scale = Vector3.ONE * 0.3
	add_child(flash)
	flash.global_position = at
	var tw := create_tween().set_parallel()
	tw.tween_property(flash, "scale", Vector3.ONE * radius * 1.3, 0.22).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(fm, "albedo_color", Color(1.0, 0.45, 0.2, 0.0), 0.3)
	tw.chain().tween_callback(flash.queue_free)

	# Shockwave ring along the ground
	var ring := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.85
	tm.outer_radius = 1.0
	ring.mesh = tm
	var rm := StandardMaterial3D.new()
	rm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	rm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	rm.albedo_color = Color(1, 1, 1, 0.8)
	ring.material_override = rm
	ring.scale = Vector3(0.3, 0.2, 0.3)
	add_child(ring)
	ring.global_position = at
	var tw2 := create_tween().set_parallel()
	tw2.tween_property(ring, "scale", Vector3(radius, 0.2, radius), 0.3).set_ease(Tween.EASE_OUT)
	tw2.tween_property(rm, "albedo_color:a", 0.0, 0.3)
	tw2.chain().tween_callback(ring.queue_free)

	# Light flash
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.7, 0.3)
	light.omni_range = radius * 2.5
	light.light_energy = 6.0
	add_child(light)
	light.global_position = at + Vector3.UP * 0.5
	var tw3 := create_tween()
	tw3.tween_property(light, "light_energy", 0.0, 0.35)
	tw3.tween_callback(light.queue_free)

	# Sparks, debris and smoke
	var spark_mat := StandardMaterial3D.new()
	spark_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	spark_mat.albedo_color = Color(1.0, 0.75, 0.3)
	for i in 14:
		var v := Vector3(rng.randf_range(-1, 1), rng.randf_range(0.5, 1.5), rng.randf_range(-1, 1)).normalized() * rng.randf_range(5, 9)
		_particle(at, v, rng.randf_range(0.06, 0.12), rng.randf_range(0.3, 0.5), spark_mat)
	for i in 8:
		var v := Vector3(rng.randf_range(-1, 1), rng.randf_range(0.8, 1.8), rng.randf_range(-1, 1)) * 3.5
		_particle(at, v, rng.randf_range(0.1, 0.18), 0.7, _drop_mat(Color(0.25, 0.22, 0.3)))
	for i in 7:
		var v := Vector3(rng.randf_range(-1, 1), rng.randf_range(0.8, 1.4), rng.randf_range(-1, 1)) * 1.2
		_particle(at + v * 0.2, v, rng.randf_range(0.4, 0.6), rng.randf_range(0.6, 0.9), _drop_mat(Color(0.82, 0.8, 0.86)), -0.5, true)
	shake = maxf(shake, 0.7)


func float_text(at: Vector3, text: String, c: Color) -> void:
	var l := Label3D.new()
	l.text = text
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.font_size = 44
	l.outline_size = 12
	l.pixel_size = 0.012
	l.modulate = c.lightened(0.3)
	l.outline_modulate = Color(0.1, 0.05, 0.15)
	add_child(l)
	l.global_position = at + Vector3(rng.randf_range(-0.2, 0.2), 0, rng.randf_range(-0.2, 0.2))
	l.scale = Vector3.ONE * 0.4
	var tw := create_tween().set_parallel()
	tw.tween_property(l, "scale", Vector3.ONE, 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "global_position", l.global_position + Vector3.UP * 0.9, 0.7)
	tw.tween_property(l, "modulate:a", 0.0, 0.3).set_delay(0.4)
	tw.tween_property(l, "outline_modulate:a", 0.0, 0.3).set_delay(0.4)
	tw.chain().tween_callback(l.queue_free)


func show_banner(text: String, c: Color) -> void:
	banner.text = text
	banner.label_settings.font_color = c
	banner.scale = Vector2(0.4, 0.4)
	banner.modulate.a = 1.0
	var tw := create_tween()
	tw.tween_property(banner, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(1.1)
	tw.tween_property(banner, "modulate:a", 0.0, 0.4)


func _update_parts(delta: float) -> void:
	for i in range(parts.size() - 1, -1, -1):
		var p := parts[i]
		var node: MeshInstance3D = p["node"]
		p["life"] -= delta
		if p["life"] <= 0.0:
			node.queue_free()
			parts.remove_at(i)
			continue
		var vel: Vector3 = p["vel"]
		vel.y -= p["g"] * delta
		vel *= 1.0 - 1.5 * delta
		p["vel"] = vel
		node.global_position += vel * delta
		var k: float = p["life"] / p["max"]
		var s: float = p["size"]
		if p["grow"]:
			node.scale = Vector3.ONE * s * (1.0 + (1.0 - k) * 1.5) * minf(1.0, k * 3.0)
		else:
			node.scale = Vector3.ONE * s * minf(1.0, k * 2.0)


# ---------- input and loop ----------

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			throw_bomb_at(mouse_world())
		elif mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			cam_zoom_goal = clampf(cam_zoom_goal - 1.0, 8.0, 24.0)
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			cam_zoom_goal = clampf(cam_zoom_goal + 1.0, 8.0, 24.0)
	elif event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		if mm.button_mask & MOUSE_BUTTON_MASK_RIGHT:
			cam_yaw_goal -= mm.relative.x * 0.35
	elif event is InputEventMagnifyGesture:
		var mg := event as InputEventMagnifyGesture
		cam_zoom_goal = clampf(cam_zoom_goal / mg.factor, 8.0, 24.0)


func _process(delta: float) -> void:
	if Input.is_action_just_pressed("new_island"):
		new_island()
		return
	if Input.is_action_just_pressed("rotate_left"):
		cam_yaw_goal -= 45.0
	if Input.is_action_just_pressed("rotate_right"):
		cam_yaw_goal += 45.0
	if Input.is_action_just_pressed("throw_key") and is_instance_valid(player):
		throw_bomb_at(player.global_position + player.facing * 4.0)

	bomb_timer -= delta
	_run_waves(delta)
	_check_falls()
	_update_parts(delta)
	_update_camera(delta)
	_update_aim()

	hud.text = "Wave %d    Kills %d    Lives %d\nWASD move   Space jump   Left click bomb   F bomb ahead\nRight-drag or Q/E rotate   Scroll zoom   R new island" % [wave, kills, lives]

	if _shot_path != "":
		_shot_tick()


func _run_waves(delta: float) -> void:
	var alive := get_tree().get_nodes_in_group("enemy").filter(func(e) -> bool: return not e.dead).size()
	if wave_break > 0.0:
		wave_break -= delta
		if wave_break <= 0.0:
			wave += 1
			to_spawn = 2 + wave * 2
			spawn_timer = 0.5
			show_banner("WAVE %d" % wave, Color("ffd36b"))
		return
	spawn_timer -= delta
	if to_spawn > 0 and spawn_timer <= 0.0 and alive < MAX_ALIVE:
		_spawn_enemy()
		to_spawn -= 1
		spawn_timer = 1.1
	elif to_spawn == 0 and alive == 0 and wave > 0:
		show_banner("WAVE CLEARED", Color("8dffb0"))
		wave_break = 3.0


func _check_falls() -> void:
	for n in get_tree().get_nodes_in_group("actor"):
		var b := n as Blob
		if b.dead or b.global_position.y > KILL_Y:
			continue
		if b == player:
			b.hp = 0.0
			b.die()
		else:
			b.dead = true
			kills += 1
			b.queue_free()
	for n in get_tree().get_nodes_in_group("bomb"):
		if (n as Node3D).global_position.y < KILL_Y:
			n.queue_free()


func _update_camera(delta: float) -> void:
	if is_instance_valid(player) and not player.dead:
		var p := player.global_position
		cam_target = cam_target.lerp(Vector3(p.x, 0, p.z), 4.0 * delta)
	cam_yaw = lerpf(cam_yaw, cam_yaw_goal, 8.0 * delta)
	cam_zoom = lerpf(cam_zoom, cam_zoom_goal, 8.0 * delta)
	camera.size = cam_zoom
	var yaw := deg_to_rad(cam_yaw)
	var offset := Vector3(sin(yaw) * CAM_DIST, CAM_HEIGHT, cos(yaw) * CAM_DIST)
	var jitter := Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * shake * 0.25
	shake = maxf(shake - delta * 2.0, 0.0)
	camera.look_at_from_position(cam_target + offset + jitter, cam_target + jitter * 0.5)


# Converts a 2D input vector into a world direction aligned with the camera view.
func screen_to_world(iv: Vector2) -> Vector3:
	var right := camera.global_basis.x
	right.y = 0.0
	var fwd := -camera.global_basis.z
	fwd.y = 0.0
	return right.normalized() * iv.x - fwd.normalized() * iv.y


# ---------- screenshot test mode ----------

func _shot_tick() -> void:
	_frame += 1
	# Lob bombs at the nearest enemy so the capture shows aiming and blasts.
	if _frame % 45 == 0:
		var best: Node3D = null
		for e in get_tree().get_nodes_in_group("enemy"):
			if best == null or (e as Node3D).global_position.distance_to(player.global_position) < best.global_position.distance_to(player.global_position):
				best = e
		if best:
			throw_bomb_at(best.global_position)
	if _frame == _shot_frame:
		_save_shot()


func _save_shot() -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(_shot_path)
	get_tree().quit()
