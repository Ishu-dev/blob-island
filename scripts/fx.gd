extends Node3D
## Visual effects. Everything spawned here is a child of this node, so clear() wipes it all.

var main
var rng := RandomNumberGenerator.new()
var parts: Array[Dictionary] = []
var puddles: Array[Dictionary] = []
var _mats := {}
var unit_sphere := SphereMesh.new()
var unit_disc := CylinderMesh.new()
var unit_box := BoxMesh.new()


func _ready() -> void:
	rng.randomize()
	unit_sphere.radius = 0.5
	unit_sphere.height = 1.0
	unit_sphere.radial_segments = 12
	unit_sphere.rings = 6
	unit_disc.top_radius = 0.5
	unit_disc.bottom_radius = 0.5
	unit_disc.height = 0.02
	unit_disc.radial_segments = 14
	unit_box.size = Vector3.ONE


func clear() -> void:
	for c in get_children():
		c.queue_free()
	parts.clear()
	puddles.clear()


func mat(c: Color, unshaded := false) -> StandardMaterial3D:
	var key := c.to_html() + ("u" if unshaded else "")
	if not _mats.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = c
		m.roughness = 0.1
		if c.a < 1.0:
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		if unshaded:
			m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_mats[key] = m
	return _mats[key]


func _fresh(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return m


func _mesh(mesh: Mesh, m: Material, pos: Vector3) -> MeshInstance3D:
	var n := MeshInstance3D.new()
	n.mesh = mesh
	n.material_override = m
	n.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(n)
	n.global_position = pos
	return n


# ---------- particles ----------

func particle(pos: Vector3, vel: Vector3, size: float, life: float, m: Material, gravity := 14.0, grow := false, mesh: Mesh = null) -> void:
	var use: Mesh = mesh if mesh != null else unit_sphere
	var n := _mesh(use, m, pos)
	n.scale = Vector3.ONE * size
	if use == unit_box:
		n.rotation = Vector3(rng.randf() * TAU, rng.randf() * TAU, 0)
	parts.append({"node": n, "vel": vel, "life": life, "max": life, "size": size, "g": gravity, "grow": grow})


func _process(delta: float) -> void:
	for i in range(parts.size() - 1, -1, -1):
		var p := parts[i]
		var node: MeshInstance3D = p["node"]
		p["life"] -= delta
		if p["life"] <= 0.0 or not is_instance_valid(node):
			if is_instance_valid(node):
				node.queue_free()
			parts.remove_at(i)
			continue
		var vel: Vector3 = p["vel"]
		vel.y -= p["g"] * delta
		vel *= 1.0 - 1.5 * delta
		p["vel"] = vel
		node.global_position += vel * delta
		var k: float = p["life"] / p["max"]
		var s: float = p["size"]
		if p["grow"]:
			node.scale = Vector3.ONE * s * (1.0 + (1.0 - k) * 1.5) * minf(1.0, k * 3.0)
		else:
			node.scale = Vector3.ONE * s * minf(1.0, k * 2.0)


func droplet(pos: Vector3, c: Color, vel: Vector3, size: float) -> void:
	particle(pos, vel, size, 0.4, mat(c))


func burst(pos: Vector3, c: Color, count: int) -> void:
	for i in count:
		var v := Vector3(rng.randf_range(-1, 1), rng.randf_range(0.6, 1.6), rng.randf_range(-1, 1)) * rng.randf_range(2.0, 4.5)
		particle(pos, v, rng.randf_range(0.08, 0.18), rng.randf_range(0.35, 0.6), mat(c))


func dust(pos: Vector3) -> void:
	for i in 6:
		var a := TAU * i / 6.0
		particle(pos, Vector3(cos(a), 0.3, sin(a)) * 1.6, 0.16, 0.35, mat(Color(0.95, 0.92, 0.85)), 0.0, true)


func puff(pos: Vector3) -> void:
	particle(pos, Vector3(rng.randf_range(-0.3, 0.3), 1.5, rng.randf_range(-0.3, 0.3)), 0.3, 0.8, mat(Color(0.9, 0.9, 0.95)), -0.5, true)


func shards(at: Vector3, size: Vector3) -> void:
	var m := mat(Color(0.75, 0.92, 1.0, 0.7))
	for i in 18:
		var off := Vector3(rng.randf_range(-0.5, 0.5) * size.x, rng.randf_range(-0.5, 0.5) * size.y, rng.randf_range(-0.5, 0.5) * size.z)
		var v := Vector3(rng.randf_range(-3, 3), rng.randf_range(0, 3), rng.randf_range(-3, 3))
		particle(at + off, v, rng.randf_range(0.06, 0.14), rng.randf_range(0.5, 0.9), m, 12.0, false, unit_box)


# ---------- goo ----------

func splat(at: Vector3, c: Color, size: float, normal := Vector3.UP) -> void:
	if normal.y < 0.6:
		return   # hit a wall or a blob's side; the droplet burst is enough
	var root := Node3D.new()
	add_child(root)
	root.global_position = at + Vector3.UP * 0.02
	var m := mat(Color(c.r, c.g, c.b, 0.9))
	# A few overlapping flat discs make an uneven puddle shape.
	for i in 4:
		var disc := MeshInstance3D.new()
		disc.mesh = unit_disc
		disc.material_override = m
		disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var r := 0.0 if i == 0 else rng.randf_range(0.2, 0.35) * size
		var a := rng.randf() * TAU
		disc.position = Vector3(cos(a) * r, 0.005 * i, sin(a) * r)
		var s := size * (0.9 if i == 0 else rng.randf_range(0.35, 0.55))
		disc.scale = Vector3(s, 1, s * rng.randf_range(0.75, 1.0))
		root.add_child(disc)
	root.scale = Vector3(0.1, 1, 0.1)
	var tw := root.create_tween()
	tw.tween_property(root, "scale", Vector3.ONE, 0.35).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	tw.tween_interval(3.0)
	tw.tween_property(root, "scale", Vector3(0.05, 1, 0.05), 0.8).set_ease(Tween.EASE_IN)
	tw.tween_callback(root.queue_free)
	puddles.append({"pos": at, "r": size * 0.45, "until": Time.get_ticks_msec() + 4000})


## Speed multiplier for a blob standing at pos: goo puddles slow you down.
func goo_slow(pos: Vector3) -> float:
	var now := Time.get_ticks_msec()
	var result := 1.0
	for i in range(puddles.size() - 1, -1, -1):
		var p := puddles[i]
		if p["until"] < now:
			puddles.remove_at(i)
			continue
		var c: Vector3 = p["pos"]
		if absf(pos.y - c.y) < 0.8 and Vector2(pos.x - c.x, pos.z - c.z).length() < p["r"]:
			result = 0.5
	return result


## A small liquid print in the walker's colour that shrinks away over about 1.5 s.
func footprint(at: Vector3, c: Color, s: float) -> void:
	var n := _mesh(unit_disc, mat(Color(c.r * 0.85, c.g * 0.85, c.b * 0.85, 0.7)), at + Vector3.UP * 0.015)
	n.scale = Vector3(s, 1, s * 0.75)
	n.rotation.y = rng.randf() * TAU
	var tw := n.create_tween()
	tw.tween_interval(0.4)
	tw.tween_property(n, "scale", Vector3(0.02, 1, 0.02), 1.2).set_ease(Tween.EASE_IN)
	tw.tween_callback(n.queue_free)


# ---------- big moments ----------

func ring(at: Vector3, c: Color, radius: float, time: float) -> void:
	var r := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.85
	tm.outer_radius = 1.0
	r.mesh = tm
	var m := _fresh(c)
	r.material_override = m
	r.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	r.scale = Vector3(0.2, 0.2, 0.2)
	add_child(r)
	r.global_position = at
	var tw := r.create_tween().set_parallel()
	tw.tween_property(r, "scale", Vector3(radius, 0.2, radius), time).set_ease(Tween.EASE_OUT)
	tw.tween_property(m, "albedo_color:a", 0.0, time)
	tw.chain().tween_callback(r.queue_free)


## Red disc that grows to full size exactly when an attack lands.
func warn_ring(at: Vector3, radius: float, time: float) -> void:
	var d := _mesh(unit_disc, _fresh(Color(1.0, 0.2, 0.2, 0.3)), at + Vector3.UP * 0.04)
	d.scale = Vector3(0.1, 1, 0.1)
	var edge := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.47
	tm.outer_radius = 0.5
	edge.mesh = tm
	edge.material_override = _fresh(Color(1.0, 0.3, 0.3, 0.8))
	edge.scale = Vector3(radius * 2.0, 0.1, radius * 2.0)
	add_child(edge)
	edge.global_position = at + Vector3.UP * 0.04
	var tw := d.create_tween()
	tw.tween_property(d, "scale", Vector3(radius * 2.0, 1, radius * 2.0), time)
	tw.tween_callback(d.queue_free)
	tw.tween_callback(edge.queue_free)


func crack(at: Vector3, radius: float) -> void:
	var root := Node3D.new()
	add_child(root)
	root.global_position = at + Vector3.UP * 0.03
	var m := mat(Color(0.12, 0.08, 0.1, 0.85))
	for i in 10:
		var a := TAU * i / 10.0 + rng.randf_range(-0.3, 0.3)
		var length := radius * rng.randf_range(0.45, 1.0)
		var seg := MeshInstance3D.new()
		seg.mesh = unit_box
		seg.material_override = m
		seg.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		seg.scale = Vector3(0.09, 0.02, length)
		seg.rotation.y = a
		seg.position = Vector3(sin(a), 0, cos(a)) * length * 0.5
		root.add_child(seg)
		# a short branch off each crack
		var b := MeshInstance3D.new()
		b.mesh = unit_box
		b.material_override = m
		var bl := length * 0.4
		var ba := a + rng.randf_range(-0.7, 0.7)
		b.scale = Vector3(0.06, 0.02, bl)
		b.rotation.y = ba
		b.position = Vector3(sin(a), 0, cos(a)) * length * 0.6 + Vector3(sin(ba), 0, cos(ba)) * bl * 0.5
		root.add_child(b)
	root.scale = Vector3(0.1, 1, 0.1)
	var tw := root.create_tween()
	tw.tween_property(root, "scale", Vector3.ONE, 0.12)
	tw.tween_interval(2.0)
	tw.tween_property(root, "scale", Vector3(0.01, 1, 0.01), 0.6)
	tw.tween_callback(root.queue_free)
	ring(at + Vector3.UP * 0.1, Color(0.95, 0.88, 0.75, 0.9), radius, 0.4)
	for i in 14:
		var v := Vector3(rng.randf_range(-1, 1), rng.randf_range(1.0, 2.0), rng.randf_range(-1, 1)) * 3.0
		particle(at, v, rng.randf_range(0.1, 0.2), 0.7, mat(Color("a8703f")), 14.0, false, unit_box)


func explosion(at: Vector3, radius: float) -> void:
	var fm := _fresh(Color(1.0, 0.85, 0.45, 0.95))
	var flash := _mesh(unit_sphere, fm, at)
	flash.scale = Vector3.ONE * 0.3
	var tw := flash.create_tween().set_parallel()
	tw.tween_property(flash, "scale", Vector3.ONE * radius * 1.3, 0.22).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(fm, "albedo_color", Color(1.0, 0.45, 0.2, 0.0), 0.3)
	tw.chain().tween_callback(flash.queue_free)
	ring(at, Color(1, 1, 1, 0.8), radius, 0.3)

	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.7, 0.3)
	light.omni_range = radius * 2.5
	light.light_energy = 6.0
	add_child(light)
	light.global_position = at + Vector3.UP * 0.5
	var tw3 := light.create_tween()
	tw3.tween_property(light, "light_energy", 0.0, 0.35)
	tw3.tween_callback(light.queue_free)

	var spark := mat(Color(1.0, 0.75, 0.3), true)
	for i in 14:
		var v := Vector3(rng.randf_range(-1, 1), rng.randf_range(0.5, 1.5), rng.randf_range(-1, 1)).normalized() * rng.randf_range(5, 9)
		particle(at, v, rng.randf_range(0.06, 0.12), rng.randf_range(0.3, 0.5), spark)
	for i in 8:
		var v := Vector3(rng.randf_range(-1, 1), rng.randf_range(0.8, 1.8), rng.randf_range(-1, 1)) * 3.5
		particle(at, v, rng.randf_range(0.1, 0.18), 0.7, mat(Color(0.25, 0.22, 0.3)), 14.0, false, unit_box)
	for i in 7:
		var v := Vector3(rng.randf_range(-1, 1), rng.randf_range(0.8, 1.4), rng.randf_range(-1, 1)) * 1.2
		particle(at + v * 0.2, v, rng.randf_range(0.4, 0.6), rng.randf_range(0.6, 0.9), mat(Color(0.82, 0.8, 0.86)), -0.5, true)


func float_text(at: Vector3, text: String, c: Color, size := 44) -> void:
	var l := Label3D.new()
	l.text = text
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.font_size = size
	l.outline_size = 12
	l.pixel_size = 0.012
	l.modulate = c.lightened(0.3)
	l.outline_modulate = Color(0.1, 0.05, 0.15)
	add_child(l)
	l.global_position = at + Vector3(rng.randf_range(-0.2, 0.2), 0, rng.randf_range(-0.2, 0.2))
	l.scale = Vector3.ONE * 0.4
	var tw := l.create_tween().set_parallel()
	tw.tween_property(l, "scale", Vector3.ONE, 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "global_position", l.global_position + Vector3.UP * 0.9, 0.7)
	tw.tween_property(l, "modulate:a", 0.0, 0.3).set_delay(0.4)
	tw.tween_property(l, "outline_modulate:a", 0.0, 0.3).set_delay(0.4)
	tw.chain().tween_callback(l.queue_free)


## Respawn effect: droplets fly in from all around and pool into a growing blob at `at`.
func gather(at: Vector3, c: Color, duration: float, done: Callable) -> void:
	var m := mat(c)
	for i in 28:
		var dir := Vector3(rng.randf_range(-1, 1), rng.randf_range(-0.2, 1.0), rng.randf_range(-1, 1)).normalized()
		var start := at + dir * rng.randf_range(2.5, 5.0) + Vector3.UP
		var d := _mesh(unit_sphere, m, start)
		var s := rng.randf_range(0.12, 0.26)
		d.scale = Vector3.ONE * s
		var delay := rng.randf_range(0.0, duration * 0.35)
		var tw := d.create_tween()
		tw.tween_interval(delay)
		tw.tween_property(d, "global_position", at, duration - delay).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
		tw.parallel().tween_property(d, "scale", Vector3.ONE * s * 0.5, duration - delay)
		tw.tween_callback(d.queue_free)
	var core := _mesh(unit_sphere, m, at)
	core.scale = Vector3.ZERO
	var ct := core.create_tween()
	ct.tween_property(core, "scale", Vector3.ONE * 0.8, duration).set_ease(Tween.EASE_IN)
	ct.tween_callback(core.queue_free)
	ct.tween_callback(done)
	ring(at + Vector3.DOWN * 0.4, Color(c.r, c.g, c.b, 0.6), 1.5, duration)
