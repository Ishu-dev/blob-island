extends RigidBody3D
## Physics props you can grab (Shift) and throw. Crates are just heavy toys; red barrels
## explode when blasted, shot, or thrown hard into something.

var main
var kind := "crate"
var _fuse := -1.0
var _thrown_t := 0.0


func _ready() -> void:
	add_to_group("prop")
	add_to_group("grabbable")
	contact_monitor = true
	max_contacts_reported = 2
	body_entered.connect(_on_hit)
	var col := CollisionShape3D.new()
	var mi := MeshInstance3D.new()
	var m := StandardMaterial3D.new()
	m.roughness = 0.6
	if kind == "barrel":
		mass = 1.0
		var shape := CylinderShape3D.new()
		shape.radius = 0.3
		shape.height = 0.75
		col.shape = shape
		var cm := CylinderMesh.new()
		cm.top_radius = 0.3
		cm.bottom_radius = 0.3
		cm.height = 0.75
		mi.mesh = cm
		m.albedo_color = Color("e0483e")
		var band := MeshInstance3D.new()
		var bm := CylinderMesh.new()
		bm.top_radius = 0.31
		bm.bottom_radius = 0.31
		bm.height = 0.12
		band.mesh = bm
		var wm := StandardMaterial3D.new()
		wm.albedo_color = Color("fff1d6")
		band.material_override = wm
		add_child(band)
	else:
		mass = 1.4
		var shape := BoxShape3D.new()
		shape.size = Vector3(0.7, 0.7, 0.7)
		col.shape = shape
		var bx := BoxMesh.new()
		bx.size = shape.size
		mi.mesh = bx
		m.albedo_color = Color("c08a4f")
	mi.material_override = m
	add_child(col)
	add_child(mi)


func thrown() -> void:
	_thrown_t = 1.0


func _on_hit(_body: Node) -> void:
	if kind == "barrel" and _thrown_t > 0.0 and linear_velocity.length() > 4.0:
		blast_hit()


## Called by explosions and shots. Barrels go off after a short fuse so chains ripple.
func blast_hit() -> void:
	if kind == "barrel" and _fuse < 0.0:
		_fuse = 0.15


func _process(delta: float) -> void:
	_thrown_t -= delta
	if _fuse >= 0.0:
		_fuse -= delta
		if _fuse < 0.0:
			_fuse = 99.0
			main.blast(global_position, 3.4, 15.0, 50.0, "neutral", 7.0, self)
			main.fx.explosion(global_position, 3.4)
			main.sfx.play("boom", global_position, 0.8)
			main.shake = maxf(main.shake, 0.8)
			queue_free()
	if global_position.y < -6.0:
		queue_free()
