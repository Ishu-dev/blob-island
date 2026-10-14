extends "res://scripts/enemy.gd"
## Keeps its distance, aims (the gun glows), then fires a three-round burst.

enum S { CHASE, AIM, FIRE, RECOVER }

const AIM_TIME := 0.6

var state := S.CHASE
var st := 0.0
var shots := 0
var _gun: Node3D
var _tip_mat: StandardMaterial3D


func _ready() -> void:
	keep_distance = 5.0
	super()
	_gun = Node3D.new()
	_gun.position = Vector3(radius * 0.95, -radius * 0.05, radius * 0.25)
	visual.add_child(_gun)
	var body := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.12, 0.13, 0.5)
	body.mesh = bm
	var m := StandardMaterial3D.new()
	m.albedo_color = Color("3a3f4d")
	body.material_override = m
	_gun.add_child(body)
	var tip := MeshInstance3D.new()
	var tm := BoxMesh.new()
	tm.size = Vector3(0.09, 0.09, 0.1)
	tip.mesh = tm
	_tip_mat = StandardMaterial3D.new()
	_tip_mat.albedo_color = Color("ffcc66")
	_tip_mat.emission_enabled = true
	_tip_mat.emission = Color("ff8a3d")
	_tip_mat.emission_energy_multiplier = 0.0
	tip.material_override = _tip_mat
	tip.position.z = 0.28
	_gun.add_child(tip)


func interrupt() -> void:
	if state == S.AIM or state == S.FIRE:
		state = S.CHASE
		_tip_mat.emission_energy_multiplier = 0.0


func think(delta: float) -> void:
	st -= delta
	match state:
		S.CHASE:
			var dist := chase(delta)
			if dist < 8.0 and attack_cd <= 0.0:
				state = S.AIM
				st = AIM_TIME
				main.sfx.play("grr", global_position, voice)
		S.AIM:
			face_target()
			var k := 1.0 - st / AIM_TIME
			_tip_mat.emission_energy_multiplier = k * 4.0
			_gun.position.x = radius * 0.95 + sin(st * 70.0) * 0.02 * k
			if st <= 0.0:
				state = S.FIRE
				shots = 3
				st = 0.0
		S.FIRE:
			face_target()
			if st <= 0.0 and shots > 0 and has_target():
				_fire()
				shots -= 1
				st = 0.13
			if shots == 0 or not has_target():
				state = S.RECOVER
				st = 0.4
				_tip_mat.emission_energy_multiplier = 0.0
		S.RECOVER:
			if st <= 0.0:
				state = S.CHASE
				attack_cd = randf_range(2.0, 3.2)


func _fire() -> void:
	var muzzle := _gun.global_position + facing * 0.3
	var aim: Vector3 = target.global_position + Vector3.UP * 0.1
	var dir := (aim - muzzle).normalized().rotated(Vector3.UP, randf_range(-0.08, 0.08))
	main.shoot(muzzle, dir * 13.0, Color("ffcc66"), team, 7.0, 1.0, 0.08, self, false, 1.5)
	main.sfx.play("pew", global_position, 0.7)
	squash = Vector3(1.1, 0.9, 1.1)
	apply_central_impulse(-facing * 0.6 * mass)
