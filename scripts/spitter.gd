extends "res://scripts/enemy.gd"
## Squishes down and shivers to wind up, then spits a glob of goo in its own colour.
## A stun during the wind-up cancels it. Also used for summoned allies (team "player").

enum S { CHASE, WINDUP, RECOVER }

const WINDUP := 0.5

var state := S.CHASE
var st := 0.0
var damage := 12.0
var spit_range := 5.0


func interrupt() -> void:
	if state == S.WINDUP:
		state = S.CHASE


func think(delta: float) -> void:
	st -= delta
	match state:
		S.CHASE:
			var dist := chase(delta)
			if dist < spit_range and attack_cd <= 0.0 and on_ground():
				state = S.WINDUP
				st = WINDUP
				main.sfx.play("grr", global_position, voice)
		S.WINDUP:
			face_target()
			var k := 1.0 - st / WINDUP
			var shiver := sin(st * 60.0) * 0.04 * k
			squash = Vector3(1.0 + 0.4 * k + shiver, 1.0 - 0.45 * k, 1.0 + 0.4 * k - shiver)
			if st <= 0.0:
				if has_target():
					_spit()
				state = S.RECOVER
				st = 0.5
				squash = Vector3(0.7, 1.5, 0.7)
		S.RECOVER:
			if st <= 0.0:
				state = S.CHASE
				attack_cd = randf_range(1.6, 2.8)


func _spit() -> void:
	var start := global_position + facing * radius * 0.9 + Vector3.UP * 0.15
	var dist := Vector2(target.global_position.x - start.x, target.global_position.z - start.z).length()
	var t := clampf(0.3 + dist * 0.08, 0.35, 0.8)
	# Lead the target a little and miss a little, so dodging is possible.
	var aim: Vector3 = target.global_position + target.linear_velocity * t * 0.5
	aim += Vector3(randf_range(-0.4, 0.4), 0, randf_range(-0.4, 0.4))
	main.shoot(start, main.ballistic(start, aim, t, 14.0), color, team, damage, 14.0, 0.17, self, true, 2.5)
	main.sfx.play("blorp", global_position, voice)
	apply_central_impulse(-facing * 1.2 * mass)
