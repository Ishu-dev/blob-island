extends "res://scripts/enemy.gd"
## Hovers at jump height and bumps into you. Jump on top of it to stomp it in one hit.

const HOVER := 1.3

var _wings: Array[MeshInstance3D] = []
var _bump_cd := 0.0


func _ready() -> void:
	prints = false
	keep_distance = 0.4
	super()
	gravity_scale = 0.0
	linear_damp = 2.5
	var wm := StandardMaterial3D.new()
	wm.albedo_color = Color(1, 1, 1, 0.85)
	wm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	for side in [-1.0, 1.0]:
		var w := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.5
		sm.height = 1.0
		w.mesh = sm
		w.material_override = wm
		w.scale = Vector3(0.38, 0.05, 0.22)
		w.position = Vector3(side * radius * 1.15, radius * 0.25, -radius * 0.1)
		visual.add_child(w)
		_wings.append(w)


func hop(_delta: float) -> void:
	pass   # flyers don't hop


func think(delta: float) -> void:
	chase(delta)
	# Hold HOVER above whatever is underneath (sea level if nothing).
	var q := PhysicsRayQueryParameters3D.create(global_position, global_position + Vector3.DOWN * 6.0)
	q.exclude = [get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	var ground_y := -0.15
	if not hit.is_empty():
		var p: Vector3 = hit["position"]
		ground_y = p.y
	var goal := ground_y + HOVER + sin(_t * 2.0) * 0.12
	apply_central_force(Vector3.UP * ((goal - global_position.y) * 25.0 - linear_velocity.y * 5.0) * mass)


func _physics_process(delta: float) -> void:
	_bump_cd -= delta
	if not dead:
		var p = main.player
		if is_instance_valid(p) and not p.dead:
			var rel: Vector3 = p.global_position - global_position
			var flat := Vector2(rel.x, rel.z).length()
			if flat < radius + p.radius * 0.9 and rel.y > radius * 0.5 and rel.y < radius + p.radius + 0.35 and p.linear_velocity.y < 1.0:
				p.bounce(8.5)
				main.fx.float_text(global_position + Vector3.UP * 0.8, "STOMP!", Color("ffe066"), 56)
				main.sfx.play("spring", global_position, 1.3)
				take_damage(max_hp + 1.0)
				return
			if _bump_cd <= 0.0 and flat < radius + p.radius + 0.05 and absf(rel.y) < 0.5:
				p.take_damage(6.0, Vector3(rel.x, 0, rel.z).normalized() * 3.0)
				_bump_cd = 1.2
	super(delta)
	for i in _wings.size():
		_wings[i].rotation.z = sin(_t * 26.0) * 0.7 * (1.0 if i == 0 else -1.0)
