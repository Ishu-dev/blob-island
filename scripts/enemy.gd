extends Blob
## Chases the player, squishes down to wind up, then spits a glob of goo.
## A bomb blast stuns it and cancels a wind-up.

const Goo := preload("res://scripts/goo.gd")

enum State { CHASE, WINDUP, RECOVER }

const RANGE := 5.0
const WINDUP_TIME := 0.5
const GOO_DAMAGE := 12.0

var target: Blob
var stun := 0.0
var state := State.CHASE
var state_t := 0.0
var attack_cd := 1.5


func _ready() -> void:
	super()
	add_to_group("enemy")


func stunned(seconds: float) -> void:
	stun = seconds
	if state == State.WINDUP:
		state = State.CHASE


func _physics_process(delta: float) -> void:
	if dead:
		return
	stun -= delta
	attack_cd -= delta
	state_t -= delta
	move_dir = Vector3.ZERO
	var has_target := is_instance_valid(target) and not target.dead
	var to_target := Vector3.ZERO
	if has_target:
		to_target = target.global_position - global_position
		to_target.y = 0.0

	match state:
		State.CHASE:
			if stun <= 0.0 and has_target:
				var dist := to_target.length()
				if dist > 0.01:
					facing = to_target.normalized()
				if dist < RANGE and attack_cd <= 0.0 and on_ground():
					state = State.WINDUP
					state_t = WINDUP_TIME
				elif dist > 1.0:
					move_dir = to_target.normalized()
		State.WINDUP:
			if has_target and to_target.length() > 0.01:
				facing = to_target.normalized()
			var k := 1.0 - state_t / WINDUP_TIME
			var shiver := sin(state_t * 60.0) * 0.04 * k
			squash = Vector3(1.0 + 0.4 * k + shiver, 1.0 - 0.45 * k, 1.0 + 0.4 * k - shiver)
			if state_t <= 0.0:
				if has_target:
					_spit()
				state = State.RECOVER
				state_t = 0.5
				squash = Vector3(0.7, 1.5, 0.7)
		State.RECOVER:
			if state_t <= 0.0:
				state = State.CHASE
				attack_cd = randf_range(1.6, 2.8)
	super(delta)


func _spit() -> void:
	var start := global_position + facing * radius * 0.9 + Vector3.UP * 0.15
	var dist := Vector2(target.global_position.x - start.x, target.global_position.z - start.z).length()
	var t := clampf(0.3 + dist * 0.08, 0.35, 0.8)
	# Lead the target a little and miss a little, so dodging is possible.
	var aim := target.global_position + target.linear_velocity * t * 0.5
	aim += Vector3(randf_range(-0.4, 0.4), 0, randf_range(-0.4, 0.4))
	var g := Goo.new()
	g.main = main
	g.color = color
	g.shooter = self
	g.damage = GOO_DAMAGE
	main.add_child(g)
	g.global_position = start
	g.vel = main.ballistic(start, aim, t, Goo.GRAVITY)
	apply_central_impulse(-facing * 1.2 * mass)
