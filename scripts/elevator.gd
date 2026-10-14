extends AnimatableBody3D
## A lift platform that rides between y_low and y_high, pausing at each end.

var y_low := 0.0
var y_high := 4.0
var speed := 1.6
var _wait := 1.0
var _up := true


func _ready() -> void:
	sync_to_physics = false
	position.y = y_low
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(1.4, 0.2, 1.6)
	col.shape = shape
	add_child(col)
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = shape.size
	mi.mesh = bm
	var m := StandardMaterial3D.new()
	m.albedo_color = Color("ffcf4a")
	m.roughness = 0.5
	mi.material_override = m
	add_child(mi)
	for i in 3:
		var stripe := MeshInstance3D.new()
		var sm := BoxMesh.new()
		sm.size = Vector3(1.41, 0.21, 0.14)
		stripe.mesh = sm
		var dm := StandardMaterial3D.new()
		dm.albedo_color = Color("2b2b33")
		stripe.material_override = dm
		stripe.position.z = -0.5 + i * 0.5
		add_child(stripe)


func _physics_process(delta: float) -> void:
	if _wait > 0.0:
		_wait -= delta
		return
	var goal := y_high if _up else y_low
	position.y = move_toward(position.y, goal, speed * delta)
	if is_equal_approx(position.y, goal):
		_up = not _up
		_wait = 1.8
