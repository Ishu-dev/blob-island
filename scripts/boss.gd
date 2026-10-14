extends "res://scripts/brute.gd"
## KING GLOOP. Cycles through four moves: ground slam, goo volley, summon minions, and a
## leap that lands on you. Gets faster below half health. Arrives by falling from the sky.

var current := ""
var leaping := true
var _air := true


func _ready() -> void:
	super()
	slam_radius = 6.0
	slam_damage = 35.0
	windup_time = 1.0
	_crown()


func _crown() -> void:
	var gold := StandardMaterial3D.new()
	gold.albedo_color = Color("ffd34d")
	gold.metallic = 0.7
	gold.roughness = 0.25
	var crown := Node3D.new()
	crown.position = Vector3(0, radius * 0.78, 0)
	visual.add_child(crown)
	var band := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = radius * 0.45
	cm.bottom_radius = radius * 0.5
	cm.height = radius * 0.22
	band.mesh = cm
	band.material_override = gold
	crown.add_child(band)
	for i in 5:
		var a := TAU * i / 5.0
		var spike := MeshInstance3D.new()
		var sm := CylinderMesh.new()
		sm.top_radius = 0.0
		sm.bottom_radius = radius * 0.1
		sm.height = radius * 0.3
		spike.mesh = sm
		spike.material_override = gold
		spike.position = Vector3(cos(a) * radius * 0.45, radius * 0.24, sin(a) * radius * 0.45)
		crown.add_child(spike)
	var gem := MeshInstance3D.new()
	var gm := SphereMesh.new()
	gm.radius = radius * 0.08
	gm.height = radius * 0.16
	gem.mesh = gm
	var red := StandardMaterial3D.new()
	red.albedo_color = Color("ff3b6b")
	red.emission_enabled = true
	red.emission = Color("ff3b6b")
	gem.material_override = red
	gem.position = Vector3(0, 0, radius * 0.48)
	crown.add_child(gem)


func stunned(_seconds: float) -> void:
	pass   # bosses shrug off stuns


func think(delta: float) -> void:
	st -= delta
	if leaping:
		var g := on_ground()
		if not g:
			_air = true
		elif _air and linear_velocity.y <= 0.5:
			leaping = false
			_air = false
			slam()
		return
	match state:
		S.CHASE:
			var dist := chase(delta)
			if attack_cd <= 0.0 and on_ground() and has_target():
				_choose(dist)
		S.WINDUP:
			face_target()
			var k := 1.0 - st / windup_time
			if current == "slam":
				squash = Vector3(1.0 - 0.25 * k, 1.0 + 0.5 * k, 1.0 - 0.25 * k)
			else:
				squash = Vector3(1.0 + 0.3 * k, 1.0 - 0.35 * k, 1.0 + 0.3 * k)
			if st <= 0.0:
				match current:
					"slam":
						slam()
					"volley":
						_volley()
					"summon":
						_summon()
					"leap":
						_leap()
		S.SLAM:
			if st <= 0.0:
				state = S.CHASE
				attack_cd = randf_range(1.6, 2.6) * (0.65 if hp < max_hp * 0.5 else 1.0)


func _choose(dist: float) -> void:
	var options := ["slam", "volley", "volley"]
	if dist > 5.0:
		options.append_array(["leap", "leap"])
	if get_tree().get_nodes_in_group("enemy").size() < 6:
		options.append("summon")
	current = options[randi() % options.size()]
	state = S.WINDUP
	st = windup_time
	main.sfx.play("grr", global_position, voice)
	if current == "slam":
		main.fx.warn_ring(global_position + Vector3.DOWN * (radius - 0.05), slam_radius, windup_time)
	elif current == "leap":
		main.fx.warn_ring(target.global_position + Vector3.DOWN * (target.radius - 0.05), slam_radius, windup_time + 1.1)


func _volley() -> void:
	state = S.SLAM
	st = 0.6
	squash = Vector3(0.75, 1.5, 0.75)
	var start := global_position + Vector3.UP * radius
	for i in 10:
		var aim := target.global_position + Vector3(randf_range(-3.5, 3.5), 0, randf_range(-3.5, 3.5))
		var t := randf_range(0.8, 1.2)
		main.shoot(start, main.ballistic(start, aim, t, 14.0), color, team, 14.0, 14.0, 0.24, self, true, 3.0)
	main.sfx.play("blorp", global_position, 0.5)


func _summon() -> void:
	state = S.SLAM
	st = 0.6
	squash = Vector3(0.7, 1.5, 0.7)
	for i in 3:
		var a := TAU * i / 3.0
		main.spawn_enemy("spitter", global_position + Vector3(cos(a) * 3.0, 4.0, sin(a) * 3.0))
	main.sfx.play("grumble0", global_position, 0.4)


func _leap() -> void:
	var t := 1.1
	linear_velocity = main.ballistic(global_position, target.global_position, t, 9.8 * gravity_scale)
	leaping = true
	_air = false
	state = S.SLAM
	st = 99.0
	squash = Vector3(0.7, 1.5, 0.7)
	main.sfx.play("jump", global_position, 0.4)
