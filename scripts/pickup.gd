extends Node3D
## Coins, power-ups, weapon crates and chests. Dropped ones pop out on an arc and land;
## weapon crates float down under a parachute. Power-ups placed on the ground get a light
## beam so you can spot them. Coins fly to you when you're close (much closer with Magnet).

const PlayerScript := preload("res://scripts/player.gd")
const POWER_COLORS := {
	"heart": Color("ff5d7a"), "shield": Color("8ae3ff"), "allies": Color("6ee7c8"),
	"speed": Color("ffe14d"), "magnet": Color("ff7b54"),
}

var main
var kind := "coin"
var gun := ""
var vel := Vector3.ZERO
var settled := true
var parachute := false
var beam := false
var _t := 0.0
var _visual: Node3D
var _chute: Node3D
var _beam_node: MeshInstance3D


func _ready() -> void:
	add_to_group("pickup")
	_t = randf() * 5.0
	_visual = Node3D.new()
	add_child(_visual)
	match kind:
		"coin":
			var c := _part(CylinderMesh.new(), Color("ffd34d"), Vector3(0.22, 0.06, 0.22), Vector3.ZERO, true)
			c.rotation.x = PI / 2.0
		"heart":
			_part(SphereMesh.new(), POWER_COLORS[kind], Vector3(0.16, 0, 0), Vector3(-0.1, 0.08, 0), true)
			_part(SphereMesh.new(), POWER_COLORS[kind], Vector3(0.16, 0, 0), Vector3(0.1, 0.08, 0), true)
			var tip := _part(CylinderMesh.new(), POWER_COLORS[kind], Vector3(0.25, 0.3, 0), Vector3(0, -0.1, 0), true)
			(tip.mesh as CylinderMesh).bottom_radius = 0.0
		"shield":
			_part(SphereMesh.new(), Color(0.5, 0.9, 1.0, 0.5), Vector3(0.28, 0, 0), Vector3.ZERO, true)
			_part(SphereMesh.new(), Color(1, 1, 1), Vector3(0.1, 0, 0), Vector3.ZERO, true)
		"allies":
			_part(SphereMesh.new(), POWER_COLORS[kind], Vector3(0.24, 0, 0), Vector3.ZERO, true)
			for sx in [-0.08, 0.08]:
				_part(SphereMesh.new(), Color(0.1, 0.1, 0.15), Vector3(0.05, 0, 0), Vector3(sx, 0.06, 0.2), false)
		"speed":
			for i in 2:
				var bolt := _part(BoxMesh.new(), POWER_COLORS[kind], Vector3(0.1, 0.32, 0.08), Vector3(0.05 - i * 0.1, 0.1 - i * 0.22, 0), true)
				bolt.rotation.z = 0.5
		"magnet":
			var arc := _part(CylinderMesh.new(), POWER_COLORS[kind], Vector3(0.22, 0.12, 0), Vector3.ZERO, true)
			arc.rotation.x = PI / 2.0
			for sx in [-0.16, 0.16]:
				_part(BoxMesh.new(), Color(0.9, 0.9, 0.95), Vector3(0.1, 0.14, 0.12), Vector3(sx, -0.22, 0), false)
		"gun":
			_part(BoxMesh.new(), Color("3a5a8c"), Vector3(0.6, 0.4, 0.45), Vector3.ZERO, false)
			_part(BoxMesh.new(), Color("ffd34d"), Vector3(0.62, 0.08, 0.47), Vector3(0, 0.1, 0), true)
		"chest", "goldchest":
			var gold := kind == "goldchest"
			_part(BoxMesh.new(), Color("ffd34d") if gold else Color("9a5b2e"), Vector3(0.8, 0.45, 0.55), Vector3.ZERO, gold)
			_part(BoxMesh.new(), Color("fff3a0") if gold else Color("ffd34d"), Vector3(0.84, 0.12, 0.59), Vector3(0, 0.25, 0), true)
			_part(BoxMesh.new(), Color("ffd34d"), Vector3(0.14, 0.18, 0.04), Vector3(0, 0.08, 0.29), true)
			if gold:
				_visual.scale = Vector3.ONE * 1.3
	var text := ""
	if POWER_COLORS.has(kind):
		text = kind.to_upper()
	elif kind == "gun":
		text = PlayerScript.GUNS[gun]["name"]
	if text != "":
		var l := Label3D.new()
		l.text = text
		l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		l.font_size = 28
		l.outline_size = 8
		l.pixel_size = 0.01
		l.position.y = 0.6
		add_child(l)
	if parachute:
		_build_chute()
	if beam:
		_beam_node = MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.25
		cm.bottom_radius = 0.35
		cm.height = 6.0
		_beam_node.mesh = cm
		var bm := StandardMaterial3D.new()
		var bc: Color = POWER_COLORS.get(kind, Color("ffd34d"))
		bm.albedo_color = Color(bc.r, bc.g, bc.b, 0.18)
		bm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		bm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_beam_node.material_override = bm
		_beam_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_beam_node.position.y = 3.0
		add_child(_beam_node)


func _build_chute() -> void:
	_chute = Node3D.new()
	add_child(_chute)
	var canopy := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.9
	sm.height = 0.9
	sm.is_hemisphere = true
	canopy.mesh = sm
	var m := StandardMaterial3D.new()
	m.albedo_color = Color("ff6b6b")
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	canopy.material_override = m
	canopy.position.y = 1.6
	_chute.add_child(canopy)
	var sm2 := StandardMaterial3D.new()
	sm2.albedo_color = Color(1, 1, 1)
	for sx in [-0.6, 0.6]:
		for sz in [-0.6, 0.6]:
			var line := MeshInstance3D.new()
			var lm := BoxMesh.new()
			lm.size = Vector3(0.02, 1.5, 0.02)
			line.mesh = lm
			line.material_override = sm2
			line.position = Vector3(sx * 0.6, 0.9, sz * 0.6)
			line.rotation = Vector3(-sz * 0.35, 0, sx * 0.35)
			_chute.add_child(line)


func _part(mesh: PrimitiveMesh, c: Color, size: Vector3, pos: Vector3, glow: bool) -> MeshInstance3D:
	if mesh is SphereMesh:
		(mesh as SphereMesh).radius = size.x
		(mesh as SphereMesh).height = size.x * 2.0
	elif mesh is CylinderMesh:
		(mesh as CylinderMesh).top_radius = size.x
		(mesh as CylinderMesh).bottom_radius = size.x
		(mesh as CylinderMesh).height = size.y
	elif mesh is BoxMesh:
		(mesh as BoxMesh).size = size
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.25
	m.metallic = 0.4 if c == Color("ffd34d") else 0.0
	if c.a < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if glow:
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = 0.25
	mi.material_override = m
	mi.position = pos
	_visual.add_child(mi)
	return mi


func _process(delta: float) -> void:
	_t += delta
	if not settled:
		vel.y -= 14.0 * delta
		if parachute:
			vel.y = maxf(vel.y, -2.2)
			_chute.rotation.z = sin(_t * 2.0) * 0.15
		var from := global_position
		var to := from + vel * delta
		var q := PhysicsRayQueryParameters3D.create(from, to + Vector3.DOWN * 0.3)
		var hit := get_world_3d().direct_space_state.intersect_ray(q)
		if not hit.is_empty() and vel.y < 0.0 and not (hit["collider"] is RigidBody3D):
			var p: Vector3 = hit["position"]
			global_position = p + Vector3.UP * 0.35
			settled = true
			if _chute:
				_chute.queue_free()
				_chute = null
				main.fx.dust(p)
		else:
			global_position = to
			if to.y < -5.0:
				queue_free()
				return
	if kind == "chest" or kind == "goldchest" or kind == "gun":
		_visual.rotation.y += delta * 0.6
	else:
		_visual.rotation.y += delta * 3.0
		_visual.position.y = sin(_t * 3.0) * 0.08
	if _beam_node:
		_beam_node.scale = Vector3(1.0 + sin(_t * 4.0) * 0.1, 1, 1.0 + sin(_t * 4.0) * 0.1)

	var p = main.player
	if not is_instance_valid(p) or p.dead:
		return
	var d: Vector3 = p.global_position - global_position
	var dist := d.length()
	if settled and kind == "coin":
		var reach: float = 9.0 if p.magnet_t > 0.0 else 2.8
		if dist < reach:
			global_position += d.normalized() * minf(dist, maxf(12.0 - dist * 1.5, 4.0) * delta)
	if dist < (1.0 if kind in ["chest", "goldchest", "gun"] else 0.75):
		main.collect(self)
		queue_free()
