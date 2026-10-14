extends StaticBody3D
## Pressure plate. Pressed while something heavy (a crate, or a brute) rests on it.
## Blobs and barrels are too light. Lowers the world's drawbridge while pressed.

var world
var main
var _count := 0
var _top: MeshInstance3D
var _mat: StandardMaterial3D


func _ready() -> void:
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(1.3, 0.12, 1.3)
	col.shape = shape
	col.position.y = 0.06
	add_child(col)
	var base := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(1.5, 0.08, 1.5)
	base.mesh = bm
	var dm := StandardMaterial3D.new()
	dm.albedo_color = Color("3a3f4d")
	base.material_override = dm
	base.position.y = 0.04
	add_child(base)
	_top = MeshInstance3D.new()
	var tm := BoxMesh.new()
	tm.size = Vector3(1.2, 0.08, 1.2)
	_top.mesh = tm
	_mat = StandardMaterial3D.new()
	_mat.albedo_color = Color("ffcf4a")
	_mat.emission_enabled = true
	_mat.emission = Color("ff5a3d")
	_mat.emission_energy_multiplier = 0.6
	_top.material_override = _mat
	_top.position.y = 0.12
	add_child(_top)
	var area := Area3D.new()
	var ac := CollisionShape3D.new()
	var ashape := BoxShape3D.new()
	ashape.size = Vector3(1.2, 0.9, 1.2)
	ac.shape = ashape
	area.add_child(ac)
	area.position.y = 0.55
	add_child(area)
	area.body_entered.connect(func(body: Node3D) -> void:
		if body is RigidBody3D and (body as RigidBody3D).mass >= 1.2:
			_count += 1
			_update())
	area.body_exited.connect(func(body: Node3D) -> void:
		if body is RigidBody3D and (body as RigidBody3D).mass >= 1.2:
			_count = maxi(_count - 1, 0)
			_update())


func _update() -> void:
	var pressed := _count > 0
	_top.position.y = 0.07 if pressed else 0.12
	_mat.emission = Color("4dff88") if pressed else Color("ff5a3d")
	main.sfx.play("click", global_position, 0.6)
	world.set_bridge(pressed)
