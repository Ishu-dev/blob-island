extends "res://scripts/enemy.gd"
## Big, slow and heavy. Rears up (a red ring warns where it will land), then slams the
## ground: the ground cracks and everything nearby gets thrown far away.

enum S { CHASE, WINDUP, SLAM }

var state := S.CHASE
var st := 0.0
var slam_radius := 4.0
var slam_damage := 28.0
var windup_time := 0.9


func _ready() -> void:
	hop_power = 5.0
	super()
	remove_from_group("grabbable")


func stunned(seconds: float) -> void:
	stun = maxf(stun, seconds * 0.25)   # too heavy to be stunned for long


func think(delta: float) -> void:
	st -= delta
	match state:
		S.CHASE:
			var dist := chase(delta)
			if dist < slam_radius * 0.6 and attack_cd <= 0.0 and on_ground():
				start_windup()
		S.WINDUP:
			face_target()
			var k := 1.0 - st / windup_time
			squash = Vector3(1.0 - 0.25 * k, 1.0 + 0.55 * k, 1.0 - 0.25 * k)
			if st <= 0.0:
				slam()
		S.SLAM:
			if st <= 0.0:
				state = S.CHASE
				attack_cd = randf_range(2.5, 3.5)


func start_windup() -> void:
	state = S.WINDUP
	st = windup_time
	main.fx.warn_ring(global_position + Vector3.DOWN * (radius - 0.05), slam_radius, windup_time)
	main.sfx.play("grr", global_position, voice)


func slam() -> void:
	state = S.SLAM
	st = 0.8
	squash = Vector3(1.6, 0.45, 1.6)
	var at := global_position + Vector3.DOWN * radius
	main.blast(at, slam_radius, 15.0, slam_damage, team, 9.0, self)
	main.fx.crack(at, slam_radius)
	main.sfx.play("slam", at, voice)
	main.shake = maxf(main.shake, 1.0)
