extends StaticBody3D
## A window pane. Solid until something hits it fast enough (you, a thrown crate, a shot,
## a blast), then it shatters into shards.

var main
var size := Vector3(1, 1, 0.06)
var _broken := false


func _ready() -> void:
	add_to_group("glass")
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	col.shape = shape
	add_child(col)
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.7, 0.9, 1.0, 0.35)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.roughness = 0.0
	m.metallic = 0.3
	m.rim_enabled = true
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	# Slightly bigger trigger so fast bodies register before they stop against the pane.
	var area := Area3D.new()
	var ac := CollisionShape3D.new()
	var ashape := BoxShape3D.new()
	ashape.size = size + Vector3(0.5, 0.0, 0.5)
	ac.shape = ashape
	area.add_child(ac)
	add_child(area)
	area.body_entered.connect(_on_body)


func _on_body(body: Node3D) -> void:
	if body is RigidBody3D and (body as RigidBody3D).linear_velocity.length() > 2.2:
		shatter()


func shatter() -> void:
	if _broken:
		return
	_broken = true
	main.fx.shards(global_position, size)
	main.sfx.play("glass", global_position)
	queue_free()
