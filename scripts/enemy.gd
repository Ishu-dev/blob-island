extends Blob
## Shared brain for enemies and allies: pick the nearest blob on the other team, chase it,
## hop over terraces and obstacles, grumble now and then. Subclasses add an attack in think().

var target: Blob
var stun := 0.0
var attack_cd := 1.5
var hop_cd := 1.0
var hop_power := 6.0
var keep_distance := 1.0
var lifetime := -1.0
var _retarget := 0.0
var _grumble := 3.0
var _stuck := 0.0


func _ready() -> void:
	face_locked = true
	super()
	add_to_group("enemy" if team == "enemy" else "ally")
	if radius < 0.6:
		add_to_group("grabbable")
	_grumble = randf_range(1.0, 5.0)


func stunned(seconds: float) -> void:
	stun = maxf(stun, seconds)
	interrupt()


## Called when a stun lands; attacks that can be cancelled override this.
func interrupt() -> void:
	pass


func has_target() -> bool:
	return is_instance_valid(target) and not target.dead


func _pick_target() -> Blob:
	var best: Blob = null
	var best_d := 30.0
	for n in get_tree().get_nodes_in_group("actor"):
		var b := n as Blob
		if b == null or b.dead or b.team == team:
			continue
		var d := b.global_position.distance_to(global_position)
		if d < best_d:
			best = b
			best_d = d
	return best


func _physics_process(delta: float) -> void:
	if dead:
		return
	stun -= delta
	attack_cd -= delta
	hop_cd -= delta
	_retarget -= delta
	_grumble -= delta
	if lifetime > 0.0:
		lifetime -= delta
		if lifetime <= 0.0:
			die()
			return
	if _retarget <= 0.0 or not has_target():
		target = _pick_target()
		_retarget = 0.6
	move_dir = Vector3.ZERO
	if stun <= 0.0:
		think(delta)
	if _grumble <= 0.0:
		_grumble = randf_range(3.0, 7.0)
		main.sfx.play("grumble%d" % randi_range(0, 2), global_position, voice)
	super(delta)


func flat_to_target() -> Vector3:
	var d := target.global_position - global_position
	d.y = 0.0
	return d


func face_target() -> void:
	if has_target():
		var d := flat_to_target()
		if d.length() > 0.01:
			facing = d.normalized()


func think(delta: float) -> void:
	chase(delta)


## Moves toward the target while keeping some distance, hopping when blocked. Returns distance.
func chase(delta: float) -> float:
	if not has_target():
		return INF
	var to := flat_to_target()
	var dist := to.length()
	if dist > 0.01:
		facing = to / dist
	if dist > keep_distance:
		move_dir = facing
	elif dist < keep_distance * 0.6:
		move_dir = -facing
	hop(delta)
	return dist


func hop(delta: float) -> void:
	var flat_speed := Vector2(linear_velocity.x, linear_velocity.z).length()
	if move_dir != Vector3.ZERO and flat_speed < 0.7:
		_stuck += delta
	else:
		_stuck = 0.0
	if hop_cd <= 0.0 and (_stuck > 0.3 or randf() < delta * 0.35) and on_ground():
		apply_central_impulse((Vector3.UP * hop_power + move_dir * 1.5) * mass)
		squash = Vector3(0.75, 1.35, 0.75)
		hop_cd = randf_range(0.9, 2.2)
		_stuck = 0.0
