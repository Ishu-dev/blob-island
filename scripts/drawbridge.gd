extends AnimatableBody3D
## One leaf of a drawbridge, hinged at `hinge` and pointing along `dir` when lowered.
## `goal` is the raise angle in degrees: 0 = flat, 78 = raised.

var hinge := Vector3.ZERO
var dir := Vector3(1, 0, 0)
var length := 4.0
var mat: Material
var angle := 78.0
var goal := 78.0


func _ready() -> void:
	sync_to_physics = false
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(length, 0.2, 2.2)
	col.shape = shape
	add_child(col)
	var deck := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = shape.size
	deck.mesh = bm
	deck.material_override = mat
	add_child(deck)
	# plank lines and side rails
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color("5e3d24")
	var planks := int(length / 0.5)
	for i in planks:
		var line := MeshInstance3D.new()
		var lm := BoxMesh.new()
		lm.size = Vector3(0.05, 0.21, 2.21)
		line.mesh = lm
		line.material_override = dark
		line.position.x = -length / 2.0 + (i + 0.5) * length / planks
		add_child(line)
	for z in [-1.05, 1.05]:
		var rail := MeshInstance3D.new()
		var rm := BoxMesh.new()
		rm.size = Vector3(length, 0.3, 0.1)
		rail.mesh = rm
		rail.material_override = dark
		rail.position = Vector3(0, 0.25, z)
		add_child(rail)
	_apply()


func _physics_process(delta: float) -> void:
	if not is_equal_approx(angle, goal):
		angle = move_toward(angle, goal, 55.0 * delta)
		_apply()


func _apply() -> void:
	var r := deg_to_rad(angle)
	var x_axis := (dir * cos(r) + Vector3.UP * sin(r)).normalized()
	var z_axis := dir.cross(Vector3.UP).normalized()
	var y_axis := z_axis.cross(x_axis)
	global_transform = Transform3D(Basis(x_axis, y_axis, z_axis), hinge + x_axis * length / 2.0 - y_axis * 0.1)
