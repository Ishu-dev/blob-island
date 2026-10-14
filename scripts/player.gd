extends Blob
## The blob you control. Movement is relative to the camera, so "up" goes up the screen.

const JUMP_SPEED := 7.5

var _coyote := 0.0
var _jump_buffer := 0.0
var _was_air := false
var _fall_speed := 0.0


func die() -> void:
	dead = true
	main.on_blob_died(self)


func _physics_process(delta: float) -> void:
	if dead:
		return
	var iv := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	move_dir = main.screen_to_world(iv)
	speed_mult = main.goo_slow(global_position)

	# Coyote time and jump buffering make jumps feel forgiving.
	var grounded := on_ground()
	_coyote = 0.12 if grounded else _coyote - delta
	_jump_buffer = 0.12 if Input.is_action_just_pressed("jump") else _jump_buffer - delta
	if _jump_buffer > 0.0 and _coyote > 0.0:
		apply_central_impulse(Vector3.UP * (JUMP_SPEED - linear_velocity.y) * mass)
		_jump_buffer = 0.0
		_coyote = 0.0
		squash = Vector3(0.7, 1.4, 0.7)
		main.dust(global_position + Vector3.DOWN * radius)

	if not grounded:
		_fall_speed = minf(_fall_speed, linear_velocity.y)
	elif _was_air and _fall_speed < -4.0:
		squash = Vector3(1.35, 0.65, 1.35)
		main.dust(global_position + Vector3.DOWN * radius)
	if grounded:
		_fall_speed = 0.0
	_was_air = not grounded
	super(delta)


func respawn(at: Vector3) -> void:
	hp = max_hp
	dead = false
	linear_velocity = Vector3.ZERO
	global_position = at
	freeze = false
	visual.visible = true
	squash = Vector3(0.5, 1.6, 0.5)
