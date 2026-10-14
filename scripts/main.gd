extends Node3D
## Game controller: sets up rendering, camera, HUD and input, builds a World, runs waves,
## spawns blobs, handles bombs/shots/blasts, pickups, lives, respawn and game over.

const World := preload("res://scripts/world.gd")
const Fx := preload("res://scripts/fx.gd")
const Sfx := preload("res://scripts/sfx.gd")
const Player := preload("res://scripts/player.gd")
const Spitter := preload("res://scripts/spitter.gd")
const Gunner := preload("res://scripts/gunner.gd")
const Flyer := preload("res://scripts/flyer.gd")
const Brute := preload("res://scripts/brute.gd")
const Boss := preload("res://scripts/boss.gd")
const Bomb := preload("res://scripts/bomb.gd")
const Projectile := preload("res://scripts/projectile.gd")
const Pickup := preload("res://scripts/pickup.gd")
const HealthBar := preload("res://scripts/health_bar.gd")

const MAX_ALIVE := 8
const BOMB_RANGE := 9.0
const KILL_Y := -4.0
const CAM_DIST := 19.8
const CAM_HEIGHT := 14.0
const AIM_DOTS := 16
const SAVE_PATH := "user://save.cfg"

var world: Node3D
var fx: Node3D
var sfx: Node
var player: Blob
var boss: Blob
var camera: Camera3D
var rng := RandomNumberGenerator.new()

# camera rig
var cam_target := Vector3.ZERO
var cam_yaw := 45.0
var cam_yaw_goal := 45.0
var cam_zoom := 15.0
var cam_zoom_goal := 15.0
var shake := 0.0

# game state
var state := "play"
var wave := 0
var plan: Array[String] = []
var spawn_timer := 0.0
var wave_break := 0.0
var kills := 0
var coins := 0
var lives := 3
var run_time := 0.0
var best_wave := 0
var _lmb_was := false

# HUD
var bar_layer: CanvasLayer
var hud: Label
var help: Label
var banner: Label
var slots: Array[ColorRect] = []
var boss_box: Control
var boss_fill: ColorRect
var boss_name: Label
var over_panel: ColorRect
var over_title: Label
var over_stats: Label

# aim preview
var aim_dots: Array[MeshInstance3D] = []
var aim_ring: MeshInstance3D
var aim_mat: StandardMaterial3D

# screenshot test mode
var _shot_path := ""
var _shot_frame := 95
var _frame := 0


func _ready() -> void:
	rng.randomize()
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--screenshot="):
			_shot_path = a.trim_prefix("--screenshot=")
		elif a.begins_with("--shotframe="):
			_shot_frame = int(a.trim_prefix("--shotframe="))
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) == OK:
		best_wave = cfg.get_value("stats", "best_wave", 0)
	fx = Fx.new()
	fx.main = self
	add_child(fx)
	sfx = Sfx.new()
	add_child(sfx)
	_setup_input()
	_setup_world()
	_setup_hud()
	_setup_aim()
	new_game()


# ---------- setup ----------

func _setup_input() -> void:
	_bind("move_left", [KEY_A, KEY_LEFT])
	_bind("move_right", [KEY_D, KEY_RIGHT])
	_bind("move_up", [KEY_W, KEY_UP])
	_bind("move_down", [KEY_S, KEY_DOWN])
	_bind("jump", [KEY_SPACE])
	_bind("grab", [KEY_SHIFT])
	_bind("rotate_left", [KEY_Q])
	_bind("rotate_right", [KEY_E])
	_bind("weapon_1", [KEY_1])
	_bind("weapon_2", [KEY_2])
	_bind("weapon_3", [KEY_3])
	_bind("help", [KEY_H])
	_bind("restart", [KEY_R])


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
	pm.size = Vector2(400, 400)
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


func _label(size: int, outline := 6) -> Label:
	var l := Label.new()
	var ls := LabelSettings.new()
	ls.font_size = size
	ls.outline_size = outline
	ls.outline_color = Color(0, 0, 0, 0.6)
	l.label_settings = ls
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _setup_hud() -> void:
	bar_layer = CanvasLayer.new()
	add_child(bar_layer)
	var layer := CanvasLayer.new()
	layer.layer = 2
	add_child(layer)

	hud = _label(22)
	hud.position = Vector2(20, 14)
	layer.add_child(hud)
	help = _label(15, 4)
	help.text = "WASD move   Space jump / climb   Mouse aim   Left click fire   1 2 3 weapons\nShift hold to grab, release or click to throw   Right-drag or Q/E rotate   Scroll zoom   H hide help   R restart"
	layer.add_child(help)

	banner = _label(64, 14)
	banner.label_settings.outline_color = Color(0.1, 0.05, 0.2, 0.8)
	banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner.modulate.a = 0.0
	layer.add_child(banner)

	var names := ["1  BOMB", "2  BLASTER", "3  SPLATTER"]
	for i in 3:
		var slot := ColorRect.new()
		slot.size = Vector2(130, 38)
		slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var l := _label(17, 4)
		l.text = names[i]
		l.size = slot.size
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		slot.add_child(l)
		layer.add_child(slot)
		slots.append(slot)

	boss_box = Control.new()
	boss_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	boss_box.visible = false
	layer.add_child(boss_box)
	var bg := ColorRect.new()
	bg.color = Color(0.05, 0.03, 0.1, 0.7)
	bg.size = Vector2(504, 22)
	bg.position = Vector2(-2, 28)
	boss_box.add_child(bg)
	boss_fill = ColorRect.new()
	boss_fill.color = Color("c04dff")
	boss_fill.size = Vector2(500, 18)
	boss_fill.position = Vector2(0, 30)
	boss_box.add_child(boss_fill)
	boss_name = _label(22)
	boss_name.text = "KING GLOOP"
	boss_name.size = Vector2(500, 26)
	boss_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	boss_box.add_child(boss_name)

	over_panel = ColorRect.new()
	over_panel.color = Color(0.05, 0.02, 0.1, 0.6)
	over_panel.visible = false
	over_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(over_panel)
	over_title = _label(96, 18)
	over_title.text = "GAME OVER"
	over_title.label_settings.font_color = Color("ff6b6b")
	over_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	over_panel.add_child(over_title)
	over_stats = _label(26)
	over_stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	over_panel.add_child(over_stats)


func _layout_hud() -> void:
	var vs := get_viewport().get_visible_rect().size
	help.position = Vector2(20, 48)
	banner.size = Vector2(vs.x, 90)
	banner.position = Vector2(0, vs.y * 0.3)
	banner.pivot_offset = banner.size / 2.0
	for i in 3:
		slots[i].position = Vector2(vs.x / 2.0 - 205 + i * 140, vs.y - 60)
	boss_box.position = Vector2(vs.x / 2.0 - 250, 16)
	over_panel.size = vs
	over_title.size = Vector2(vs.x, 120)
	over_title.position = Vector2(0, vs.y * 0.25)
	over_title.pivot_offset = over_title.size / 2.0
	over_stats.size = Vector2(vs.x, 160)
	over_stats.position = Vector2(0, vs.y * 0.25 + 140)


func _setup_aim() -> void:
	aim_mat = StandardMaterial3D.new()
	aim_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	aim_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	aim_mat.albedo_color = Color(1, 1, 1, 0.75)
	aim_mat.no_depth_test = true
	for i in AIM_DOTS:
		var d := MeshInstance3D.new()
		d.mesh = fx.unit_sphere
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


# ---------- game flow ----------

func new_game() -> void:
	Engine.time_scale = 1.0
	for group in ["actor", "bomb", "projectile", "pickup"]:
		for n in get_tree().get_nodes_in_group(group):
			n.queue_free()
	for c in bar_layer.get_children():
		c.queue_free()
	fx.clear()
	if world:
		world.queue_free()
	world = World.new()
	world.main = self
	add_child(world)
	world.build(rng.randi())

	state = "play"
	wave = 0
	plan.clear()
	kills = 0
	coins = 0
	lives = 3
	run_time = 0.0
	boss = null
	wave_break = 3.0
	over_panel.visible = false
	cam_zoom_goal = 15.0

	for spot in world.coin_spots:
		drop_pickup("coin", spot)
	drop_pickup("chest", world.chest_point)

	player = Player.new()
	player.main = self
	player.color = Color("8fd3ff")
	player.radius = 0.45
	player.max_hp = 100.0
	player.add_to_group("player")
	add_child(player)
	player.global_position = world.spawn_point
	player.freeze = true
	player.visible = false
	player.dead = true
	cam_target = Vector3(world.spawn_point.x, 0, world.spawn_point.z)
	_add_bar(player, Color("5ee07a"), 56.0)
	_respawn_player()


func _respawn_player() -> void:
	if state != "play" or not is_instance_valid(player):
		return
	player.global_position = world.spawn_point
	sfx.play("respawn")
	fx.gather(world.spawn_point, player.color, 1.1, _finish_respawn)


func _finish_respawn() -> void:
	if state != "play" or not is_instance_valid(player):
		return
	player.respawn(world.spawn_point)
	fx.burst(world.spawn_point, player.color, 12)
	fx.ring(world.spawn_point + Vector3.DOWN * 0.4, Color(1, 1, 1, 0.8), 2.0, 0.35)


func on_blob_died(b: Blob) -> void:
	if b == player:
		lives -= 1
		fx.splat(player.global_position + Vector3.DOWN * 0.4, player.color, 1.6)
		fx.burst(player.global_position, player.color, 22)
		sfx.play("splat", player.global_position)
		player.visible = false
		player.set_deferred("freeze", true)
		shake = 0.9
		if lives <= 0:
			_game_over()
		else:
			get_tree().create_timer(1.0).timeout.connect(_respawn_player)
		return
	if b.team == "enemy":
		kills += 1
		shake = maxf(shake, 0.3)
		for i in b.loot:
			_pop_pickup("coin", b.global_position)
		if b == boss:
			boss = null
			show_banner("BOSS DEFEATED!", Color("ffd34d"))
			for i in 3:
				_pop_pickup(KINDS_POWER_RANDOM(), b.global_position)
		elif rng.randf() < 0.12:
			_pop_pickup(KINDS_POWER_RANDOM(), b.global_position)


func KINDS_POWER_RANDOM() -> String:
	return ["heart", "heart", "shield", "allies"][rng.randi() % 4]


func _game_over() -> void:
	state = "over"
	sfx.play("gameover")
	Engine.time_scale = 0.35
	cam_zoom_goal = 8.0
	if wave > best_wave:
		best_wave = wave
		var cfg := ConfigFile.new()
		cfg.set_value("stats", "best_wave", best_wave)
		cfg.save(SAVE_PATH)
	get_tree().create_timer(0.6).timeout.connect(_show_game_over)


func _show_game_over() -> void:
	Engine.time_scale = 1.0
	over_panel.visible = true
	over_panel.modulate.a = 0.0
	over_stats.text = "Wave %d     Kills %d     Coins %d     Time %s\nBest wave %d\n\nPress R or click to play again" % [wave, kills, coins, _clock(), best_wave]
	over_title.scale = Vector2(0.3, 0.3)
	var tw := create_tween()
	tw.tween_property(over_panel, "modulate:a", 1.0, 0.4)
	tw.parallel().tween_property(over_title, "scale", Vector2.ONE, 0.6).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


func _clock() -> String:
	return "%02d:%02d" % [int(run_time) / 60, int(run_time) % 60]


# ---------- waves ----------

func _make_plan(n: int) -> Array[String]:
	var p: Array[String] = []
	if n % 5 == 0:
		p.append("boss")
		p.append("spitter")
		p.append("spitter")
		return p
	for i in 1 + n:
		p.append("spitter")
	if n >= 2:
		for i in n - 1:
			p.append("flyer")
		for i in n / 2:
			p.append("gunner")
	if n >= 3:
		for i in (n - 1) / 2:
			p.append("brute")
	p.shuffle()
	return p


func _run_waves(delta: float) -> void:
	var alive := 0
	for e in get_tree().get_nodes_in_group("enemy"):
		if not e.dead:
			alive += 1
	if wave_break > 0.0:
		wave_break -= delta
		if wave_break <= 0.0:
			wave += 1
			plan = _make_plan(wave)
			spawn_timer = 0.5
			if wave % 5 == 0:
				show_banner("BOSS: KING GLOOP", Color("ff7bd5"))
			else:
				show_banner("WAVE %d" % wave, Color("ffd36b"))
			sfx.play("wave")
		return
	spawn_timer -= delta
	if not plan.is_empty() and spawn_timer <= 0.0 and alive < MAX_ALIVE:
		var kind: String = plan.pop_back()
		var spot := _far_tile()
		var height := 3.0 if kind == "flyer" else (12.0 if kind == "boss" else 6.0)
		spawn_enemy(kind, spot + Vector3.UP * height)
		spawn_timer = 1.0
	elif plan.is_empty() and alive == 0 and wave > 0:
		show_banner("WAVE CLEARED", Color("8dffb0"))
		wave_break = 4.0
		# Refill some coins and the roof chest between waves.
		for i in 8:
			drop_pickup("coin", world.land_tiles[rng.randi() % world.land_tiles.size()] + Vector3.UP * 0.45)
		var has_chest := false
		for p in get_tree().get_nodes_in_group("pickup"):
			if p.kind == "chest":
				has_chest = true
		if not has_chest:
			drop_pickup("chest", world.chest_point)


func _far_tile() -> Vector3:
	var tiles: Array[Vector3] = world.land_tiles
	for i in 40:
		var t := tiles[rng.randi() % tiles.size()]
		if Vector2(t.x - player.global_position.x, t.z - player.global_position.z).length() > 9.0:
			return t
	return tiles[rng.randi() % tiles.size()]


func spawn_enemy(kind: String, pos: Vector3):
	var e
	match kind:
		"spitter":
			e = Spitter.new()
			e.color = Color("f2789a")
			e.radius = 0.38
			e.max_hp = 40.0 + wave * 4.0
			e.max_speed = 3.0 + wave * 0.1
			e.accel = 13.0
			e.teeth = 3
		"gunner":
			e = Gunner.new()
			e.color = Color("ff9f43")
			e.radius = 0.4
			e.max_hp = 45.0 + wave * 4.0
			e.max_speed = 2.8
			e.accel = 12.0
			e.teeth = 2
			e.voice = 0.85
		"flyer":
			e = Flyer.new()
			e.color = Color("ffd166")
			e.radius = 0.3
			e.max_hp = 12.0
			e.max_speed = 3.2
			e.accel = 10.0
			e.teeth = 2
			e.voice = 1.6
		"brute":
			e = Brute.new()
			e.color = Color("9b6bff")
			e.radius = 0.8
			e.max_hp = 200.0 + wave * 10.0
			e.max_speed = 1.4
			e.accel = 7.0
			e.teeth = 5
			e.voice = 0.6
			e.loot = 5
			e.mass = 4.0
		"boss":
			e = Boss.new()
			e.color = Color("c04dff")
			e.radius = 1.4
			e.max_hp = 900.0 + wave * 40.0
			e.max_speed = 1.8
			e.accel = 6.0
			e.teeth = 7
			e.voice = 0.45
			e.loot = 30
			e.mass = 12.0
		"ally":
			e = Spitter.new()
			e.team = "player"
			e.color = Color("6ee7c8")
			e.radius = 0.36
			e.max_hp = 60.0
			e.max_speed = 3.6
			e.accel = 14.0
			e.teeth = 1
			e.voice = 1.5
			e.loot = 0
			e.lifetime = 25.0
	e.main = self
	add_child(e)
	e.global_position = pos
	if kind == "boss":
		boss = e
	elif kind == "ally":
		_add_bar(e, Color("6ee7c8"), 36.0)
	else:
		_add_bar(e, Color("ff5d73"), 60.0 if kind == "brute" else 40.0)
	return e


func _add_bar(b: Blob, c: Color, w: float) -> void:
	var bar := HealthBar.new()
	bar.target = b
	bar.camera = camera
	bar.fill_color = c
	bar.bar_width = w
	bar_layer.add_child(bar)


# ---------- pickups ----------

func drop_pickup(kind: String, at: Vector3) -> Node3D:
	var p := Pickup.new()
	p.main = self
	p.kind = kind
	add_child(p)
	p.global_position = at
	return p


func _pop_pickup(kind: String, at: Vector3) -> void:
	var p := drop_pickup(kind, at + Vector3.UP * 0.4)
	p.settled = false
	p.vel = Vector3(rng.randf_range(-2.5, 2.5), rng.randf_range(4.0, 6.0), rng.randf_range(-2.5, 2.5))


func collect(p: Node3D) -> void:
	var at := p.global_position
	match p.kind:
		"coin":
			coins += 1
			sfx.play("coin", null, 1.0 + fmod(coins * 0.05, 0.5))
			fx.float_text(at + Vector3.UP * 0.4, "+1", Color("ffd34d"), 34)
		"heart":
			player.hp = minf(player.hp + 35.0, player.max_hp)
			sfx.play("powerup")
			fx.float_text(at + Vector3.UP * 0.5, "+35 HP", Color("5ee07a"))
		"shield":
			player.shield_time = 8.0
			sfx.play("powerup")
			fx.float_text(at + Vector3.UP * 0.5, "SHIELD!", Color("8ae3ff"))
		"allies":
			sfx.play("powerup")
			fx.float_text(at + Vector3.UP * 0.5, "ALLIES!", Color("6ee7c8"))
			for i in 3:
				var a := TAU * i / 3.0
				var spot := player.global_position + Vector3(cos(a) * 1.8, 0.3, sin(a) * 1.8)
				fx.gather(spot, Color("6ee7c8"), 0.8, func() -> void:
					if state == "play":
						spawn_enemy("ally", spot))
		"chest":
			sfx.play("powerup", null, 0.8)
			fx.float_text(at + Vector3.UP * 0.6, "TREASURE!", Color("ffd34d"), 56)
			for i in 10:
				_pop_pickup("coin", at)
			_pop_pickup(KINDS_POWER_RANDOM(), at)
	fx.ring(at, Color(1, 1, 0.8, 0.8), 0.8, 0.25)


# ---------- combat ----------

## Velocity that carries a projectile from start to target in time t under gravity g.
func ballistic(start: Vector3, target: Vector3, t: float, g: float) -> Vector3:
	var v := (target - start) / t
	v.y += 0.5 * g * t
	return v


func shoot(from: Vector3, vel: Vector3, c: Color, team: String, damage: float, gravity: float, size: float, shooter: Node3D, splat: bool, knock: float) -> void:
	var p := Projectile.new()
	p.main = self
	p.color = c
	p.team = team
	p.damage = damage
	p.gravity = gravity
	p.size = size
	p.shooter = shooter
	p.splat = splat
	p.knock = knock
	add_child(p)
	p.global_position = from
	p.vel = vel


## Radial blast used by bombs, barrels and ground slams. Same-team blobs take 30% damage.
func blast(at: Vector3, radius: float, force: float, damage: float, team: String, up := 6.0, source: Node = null) -> void:
	for n in get_tree().get_nodes_in_group("actor"):
		var b := n as Blob
		if b == null or b.dead or b == source:
			continue
		var d := b.global_position - at
		var dist := d.length()
		if dist > radius:
			continue
		var falloff := 1.0 - dist / radius
		var flat := Vector3(d.x, 0, d.z)
		var dir: Vector3 = flat.normalized() if flat.length() > 0.05 else Vector3.ZERO
		var push := (dir * force + Vector3.UP * up) * falloff
		var dmg := damage * (0.35 + 0.65 * falloff)
		if b.team == team:
			dmg *= 0.3
		if b.has_method("stunned"):
			b.stunned(1.2)
		b.take_damage(dmg, push)
	for n in get_tree().get_nodes_in_group("prop"):
		var rb := n as RigidBody3D
		if rb == source:
			continue
		var d := rb.global_position - at
		if d.length() < radius:
			var f := 1.0 - d.length() / radius
			rb.apply_central_impulse((d.normalized() * force * 0.6 + Vector3.UP * up * 0.6) * f * rb.mass)
			rb.blast_hit()
	for n in get_tree().get_nodes_in_group("bomb"):
		if n == source:
			continue
		var d: Vector3 = n.global_position - at
		if d.length() < radius:
			n.apply_central_impulse((d.normalized() * 4.0 + Vector3.UP * 3.0) * n.mass)
			n.fuse = minf(n.fuse, 0.25)
	for n in get_tree().get_nodes_in_group("glass"):
		if (n as Node3D).global_position.distance_to(at) < radius:
			n.shatter()


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


func throw_bomb_at(raw: Vector3) -> void:
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
		b.angular_velocity = Vector3.UP.cross(dir) * 10.0 + Vector3(rng.randf_range(-2, 2), rng.randf_range(-3, 3), 0)
	player.squash = Vector3(1.25, 0.75, 1.25)
	sfx.play("throw", start)


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


func _update_aim(aim_point: Vector3) -> void:
	var show_it := is_instance_valid(player) and not player.dead and state == "play" and player.held == null
	aim_ring.visible = show_it
	for d in aim_dots:
		d.visible = show_it
	if not show_it:
		return
	var ready_now: bool = player.fire_cd <= 0.0
	aim_mat.albedo_color = Color(1, 1, 1, 0.75) if ready_now else Color(1, 0.5, 0.5, 0.35)
	aim_ring.scale = Vector3.ONE * (1.0 + 0.08 * sin(Time.get_ticks_msec() * 0.008))
	if player.weapon == 1:
		var start := _throw_origin()
		var target := _aim_target(aim_point)
		var t := _flight_time(start, target)
		var v := ballistic(start, target, t, 9.8)
		for i in AIM_DOTS:
			var s := t * float(i + 1) / AIM_DOTS
			aim_dots[i].global_position = start + v * s + Vector3.DOWN * 4.9 * s * s
		aim_ring.global_position = target + Vector3.DOWN * 0.2
	else:
		# Guns: a short dotted line from the gun toward the cursor.
		var start := player.global_position + Vector3.UP * 0.1
		var dir := Vector3(aim_point.x - start.x, 0, aim_point.z - start.z).normalized()
		for i in AIM_DOTS:
			aim_dots[i].visible = i < 8
			aim_dots[i].global_position = start + dir * (0.9 + i * 0.6)
		aim_ring.global_position = aim_point + Vector3.UP * 0.05


func show_banner(text: String, c: Color) -> void:
	banner.text = text
	banner.label_settings.font_color = c
	banner.scale = Vector2(0.4, 0.4)
	banner.modulate.a = 1.0
	var tw := create_tween()
	tw.tween_property(banner, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(1.1)
	tw.tween_property(banner, "modulate:a", 0.0, 0.4)


# ---------- input and loop ----------

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			cam_zoom_goal = clampf(cam_zoom_goal - 1.0, 8.0, 26.0)
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			cam_zoom_goal = clampf(cam_zoom_goal + 1.0, 8.0, 26.0)
		elif mb.button_index == MOUSE_BUTTON_LEFT and state == "over" and over_panel.visible:
			new_game()
	elif event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		if mm.button_mask & MOUSE_BUTTON_MASK_RIGHT:
			cam_yaw_goal -= mm.relative.x * 0.35
	elif event is InputEventMagnifyGesture:
		var mg := event as InputEventMagnifyGesture
		cam_zoom_goal = clampf(cam_zoom_goal / mg.factor, 8.0, 26.0)


func _process(delta: float) -> void:
	_layout_hud()
	if Input.is_action_just_pressed("restart"):
		new_game()
		return
	if Input.is_action_just_pressed("help"):
		help.visible = not help.visible
	if Input.is_action_just_pressed("rotate_left"):
		cam_yaw_goal -= 45.0
	if Input.is_action_just_pressed("rotate_right"):
		cam_yaw_goal += 45.0
	for i in 3:
		if Input.is_action_just_pressed("weapon_%d" % (i + 1)) and is_instance_valid(player):
			player.select_weapon(i + 1)

	var aim_point := mouse_world() if is_instance_valid(player) else Vector3.ZERO
	var lmb := Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and _shot_path == ""
	if state == "play" and is_instance_valid(player):
		player.weapon_update(delta, aim_point, lmb, lmb and not _lmb_was)
		run_time += delta
		_run_waves(delta)
	_lmb_was = lmb
	_check_falls()
	_update_camera(delta)
	_update_aim(aim_point)
	if is_instance_valid(player):
		sfx.listener = player.global_position
		world.update_xray(player.global_position if not player.dead else world.spawn_point, camera.global_position)
	_update_hud()
	if _shot_path != "":
		_shot_tick()


func _update_hud() -> void:
	var extra := ""
	if is_instance_valid(player) and player.shield_time > 0.0:
		extra = "    SHIELD %ds" % ceili(player.shield_time)
	hud.text = "Wave %d    Kills %d    Coins %d    Time %s    Lives %d%s" % [wave, kills, coins, _clock(), maxi(lives, 0), extra]
	for i in 3:
		var active: bool = is_instance_valid(player) and player.weapon == i + 1
		slots[i].color = Color(1.0, 0.85, 0.3, 0.85) if active else Color(0.08, 0.06, 0.15, 0.6)
	boss_box.visible = is_instance_valid(boss) and not boss.dead
	if boss_box.visible:
		boss_fill.size.x = 500.0 * clampf(boss.hp / boss.max_hp, 0.0, 1.0)


func _check_falls() -> void:
	for n in get_tree().get_nodes_in_group("actor"):
		var b := n as Blob
		if b.dead or b.global_position.y > KILL_Y:
			continue
		if b == player:
			b.hp = 0.0
			b.die()
		else:
			if b.team == "enemy":
				kills += 1
			if b == boss:
				boss = null
			b.dead = true
			b.queue_free()
	for n in get_tree().get_nodes_in_group("bomb"):
		if (n as Node3D).global_position.y < KILL_Y:
			n.queue_free()


func _update_camera(delta: float) -> void:
	if is_instance_valid(player) and not player.dead:
		var p := player.global_position
		cam_target = cam_target.lerp(Vector3(p.x, p.y * 0.5, p.z), 4.0 * delta)
	cam_yaw = lerpf(cam_yaw, cam_yaw_goal, 8.0 * delta)
	cam_zoom = lerpf(cam_zoom, cam_zoom_goal, 6.0 * delta)
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
# Extra args: --screenshot=PATH --shotframe=N [--wave=N] [--weapon=N] [--at=building]

func _shot_tick() -> void:
	_frame += 1
	if _frame == 90:
		for a in OS.get_cmdline_user_args():
			if a.begins_with("--wave="):
				wave_break = 0.01
				wave = int(a.trim_prefix("--wave=")) - 1
			elif a.begins_with("--weapon="):
				player.select_weapon(int(a.trim_prefix("--weapon=")))
			elif a == "--gameover":
				lives = 1
				player.shield_time = 0.0
				player.take_damage(999.0)
			elif a == "--at=building":
				var c: Vector3 = world.buildings[0]["center"]
				player.global_position = c + Vector3(-1.0, 0.6, 1.0)
				cam_target = Vector3(c.x, 0, c.z)
	if _frame % 30 == 0 and state == "play" and not player.dead:
		var best: Node3D = null
		for e in get_tree().get_nodes_in_group("enemy"):
			if best == null or (e as Node3D).global_position.distance_to(player.global_position) < best.global_position.distance_to(player.global_position):
				best = e
		if best:
			player.weapon_update(0.0, best.global_position, true, true)
	if _frame == _shot_frame:
		_save_shot()


func _save_shot() -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(_shot_path)
	get_tree().quit()
