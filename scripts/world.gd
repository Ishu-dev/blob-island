extends Node3D
## Builds one random island and its set pieces: terraces, trees, rocks, a two-floor
## building (ramp inside, ladder outside, breakable windows, elevator to the roof chest),
## trampolines, a railway with a passing train, crates and barrels, and a small islet
## reached by a drawbridge that only opens while a crate sits on its pressure plate.
## Also answers routing questions so enemies know how to reach you.

const Glass := preload("res://scripts/glass.gd")
const Elevator := preload("res://scripts/elevator.gd")
const Train := preload("res://scripts/train.gd")
const Prop := preload("res://scripts/prop.gd")
const Drawbridge := preload("res://scripts/drawbridge.gd")
const Plate := preload("res://scripts/plate.gd")

const SIZE := 36
const STEP := 0.35
const BASE := -1.0
const FLOOR_H := 2.2
const WALL_T := 0.2
const BW := 6.0
const BD := 6.0
const BIOMES := [
	{"name": "MEADOW", "grass_a": "7cc35a", "grass_b": "6cb44f", "grass_hi": "93d16a", "sand": "e6c47f", "dirt": "a8703f", "leaf": "3f9a55"},
	{"name": "SNOWFIELD", "grass_a": "eef4f8", "grass_b": "e0eaf1", "grass_hi": "ffffff", "sand": "c9d6e0", "dirt": "8a6e5a", "leaf": "2f6b4f"},
	{"name": "DESERT", "grass_a": "e8c88a", "grass_b": "dfbd7b", "grass_hi": "f0d49b", "sand": "f1d9a5", "dirt": "b77b45", "leaf": "5f9e4f"},
	{"name": "AUTUMN", "grass_a": "c9a04a", "grass_b": "bd9440", "grass_hi": "d8b35a", "sand": "e6c47f", "dirt": "8d5a35", "leaf": "d9622b"},
]

var main
var biome := 0
var rng := RandomNumberGenerator.new()
var land_tiles: Array[Vector3] = []   # tiles enemies may spawn on
var spawn_point := Vector3.ZERO
var chest_point := Vector3.ZERO
var gold_point := Vector3.ZERO
var coin_spots: Array[Vector3] = []
var buildings: Array[Dictionary] = []
var mats := {}
var lift: Node3D
var bridge_open := false
var _leaves: Array = []
var _levels := {}
var _reserved := {}
var _tops := {}          # cell -> top height of every tile actually built
var _half := SIZE / 2.0
var _side := 1           # islet direction along x
var _hinge_a := Vector3.ZERO
var _hinge_b := Vector3.ZERO
var _edges := {}         # routing graph: "from>to" -> {a, b, kind}


func build(seed_value: int, biome_index: int) -> void:
	rng.seed = seed_value
	biome = biome_index % BIOMES.size()
	_make_mats()

	var noise := FastNoiseLite.new()
	noise.seed = rng.randi()
	noise.frequency = 0.07
	for x in SIZE:
		for z in SIZE:
			var dx := (x - _half + 0.5) / _half
			var dz := (z - _half + 0.5) / _half
			var h := (1.0 - sqrt(dx * dx + dz * dz)) * 1.15 + noise.get_noise_2d(x, z) * 0.5
			if h > 0.3:
				_levels[Vector2i(x, z)] = clampi(int((h - 0.3) / 0.25), 0, 3)

	# Railway row: flatten a 3-wide strip.
	var tz := SIZE / 2 - 9
	for x in SIZE:
		for dz in [-1, 0, 1]:
			var c := Vector2i(x, tz + dz)
			if _levels.has(c):
				_levels[c] = 1
			_reserved[c] = true
	var track_z := tz - _half + 0.5

	# Building plot: flatten (and fill in) a 9 x 8 area off to one side.
	var bcx := SIZE / 2 + (6 if rng.randf() < 0.5 else -7)
	var bcz := SIZE / 2 + 5
	for x in range(bcx - 4, bcx + 5):
		for z in range(bcz - 4, bcz + 4):
			_levels[Vector2i(x, z)] = 1
			_reserved[Vector2i(x, z)] = true
	var bpos := Vector3(bcx - _half, STEP, bcz - _half)

	# Keep only the landmass connected to the centre.
	var start := Vector2i(SIZE / 2, SIZE / 2)
	_levels[start] = maxi(int(_levels.get(start, 1)), 1)
	var keep := _flood(start)

	# Islet on the side away from the building, beyond a water gap; flatten a landing
	# patch on the main island where the drawbridge and plate go.
	_side = 1 if bcx < SIZE / 2 else -1
	var cz := SIZE / 2
	var extreme := -9999 * _side
	var row_edge := -9999 * _side
	for cell in keep:
		if _side * cell.x > _side * extreme:
			extreme = cell.x
		if cell.y == cz and _side * cell.x > _side * row_edge:
			row_edge = cell.x
	for k in 4:
		for dz in range(-2, 3):
			var c := Vector2i(row_edge - _side * k, cz + dz)
			_levels[c] = 1
			_reserved[c] = true
			keep[c] = true
	var islet_cells: Array[Vector2i] = []
	for k in range(8, 13):
		for dz in range(-2, 3):
			var c := Vector2i(extreme + _side * k, cz + dz)
			_levels[c] = 1
			islet_cells.append(c)

	var free_tiles: Array[Vector3] = []
	for cell in keep.keys():
		var level: int = _levels[cell]
		var spot := _build_tile(cell, level)
		var in_building: bool = absf(spot.x - bpos.x) < BW / 2.0 + 0.5 and absf(spot.z - bpos.z) < BD / 2.0 + 0.5
		if not in_building:
			land_tiles.append(spot)
		if cell == start:
			spawn_point = Vector3(spot.x, spot.y + 1.2, spot.z)
			continue
		if _reserved.has(cell):
			continue
		free_tiles.append(spot)
		var r := rng.randf()
		if level >= 1 and r < 0.06 and Vector2(spot.x, spot.z).length() > 3.0:
			_tree(spot)
		elif r < 0.09:
			_rock(spot)
	for cell in islet_cells:
		var spot := _build_tile(cell, 1)
		if cell.y != cz and rng.randf() < 0.2:
			_tree(spot)

	_railway(track_z)
	_building(0, bpos)
	_islet(row_edge, extreme, cz)

	# Trampolines: one beside the building (a shortcut to the roof), a few elsewhere.
	_trampoline(bpos + Vector3(-BW / 2.0 - 0.6, 0, 1.5))
	free_tiles.shuffle()
	var placed := 0
	for t in free_tiles:
		if placed >= 3:
			break
		if Vector2(t.x, t.z).length() > 4.0:
			_trampoline(t)
			placed += 1
	for i in range(3, mini(free_tiles.size(), 13)):
		_prop("barrel" if i % 3 == 0 else "crate", free_tiles[i] + Vector3.UP * 0.6)
	_prop("crate", bpos + Vector3(-1.5, 0.6, 1.0))
	_prop("barrel", bpos + Vector3(1.0, 0.6, 1.5))
	for i in range(13, mini(free_tiles.size(), 45)):
		coin_spots.append(free_tiles[i] + Vector3.UP * 0.45)
	_make_routes(bpos)


func _flood(start: Vector2i) -> Dictionary:
	var keep := {start: true}
	var queue: Array[Vector2i] = [start]
	while not queue.is_empty():
		var c: Vector2i = queue.pop_back()
		for o in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = c + o
			if _levels.has(n) and not keep.has(n):
				keep[n] = true
				queue.append(n)
	return keep


func _build_tile(cell: Vector2i, level: int) -> Vector3:
	var wx: float = cell.x - _half + 0.5
	var wz: float = cell.y - _half + 0.5
	var top := level * STEP
	_tile(wx, wz, top, level, (cell.x + cell.y) % 2 == 0)
	_tops[cell] = top
	return Vector3(wx, top, wz)


func _make_mats() -> void:
	var b: Dictionary = BIOMES[biome]
	var colors := {
		"grass_a": b["grass_a"], "grass_b": b["grass_b"], "grass_hi": b["grass_hi"], "sand": b["sand"],
		"dirt": b["dirt"], "trunk": "8a5a35", "leaf": b["leaf"], "rock": "9aa3ad",
		"wall": "f3e6d0", "floor": "c9a27a", "roof": "d9705a", "wood": "8b5e3c", "metal": "8f96a3",
		"pad": "ff5c8a", "dark": "2b2b33",
	}
	for k in colors:
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(colors[k])
		m.roughness = 0.85
		mats[k] = m
	var fade := StandardMaterial3D.new()
	fade.albedo_color = Color(0.95, 0.9, 0.82, 0.22)
	fade.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mats["wall_fade"] = fade
	var rail := StandardMaterial3D.new()
	rail.albedo_color = Color("8f96a3")
	rail.metallic = 0.6
	rail.roughness = 0.3
	rail.emission_enabled = true
	rail.emission = Color(1.0, 0.2, 0.15)
	rail.emission_energy_multiplier = 0.0
	mats["rail"] = rail


## Top height of a buildable tile under p, or NAN if you can't build there.
func build_top(p: Vector3) -> float:
	var cell := Vector2i(int(floor(p.x + _half)), int(floor(p.z + _half)))
	if not _tops.has(cell) or _reserved.has(cell):
		return NAN
	return _tops[cell]


func cell_center(p: Vector3) -> Vector3:
	return Vector3(floor(p.x + _half) - _half + 0.5, 0, floor(p.z + _half) - _half + 0.5)


# ---------- helpers ----------

func _box(center: Vector3, size: Vector3, m: Material, building_id := -1, collide := true) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = m
	if not collide:
		mi.position = center
		add_child(mi)
		return mi
	var body := StaticBody3D.new()
	body.position = center
	var col := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = size
	col.shape = sh
	body.add_child(col)
	body.add_child(mi)
	if building_id >= 0:
		body.set_meta("building", building_id)
	add_child(body)
	return mi


func _tile(x: float, z: float, top: float, level: int, checker: bool) -> void:
	var tile := StaticBody3D.new()
	tile.position = Vector3(x, (top + BASE) / 2.0, z)
	var height := top - BASE
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(1, height, 1)
	col.shape = shape
	tile.add_child(col)
	var cap_h := 0.14
	var body := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(1, height - cap_h, 1)
	body.mesh = bm
	body.material_override = mats["dirt"]
	body.position.y = -cap_h / 2.0
	tile.add_child(body)
	var cap := MeshInstance3D.new()
	var cm := BoxMesh.new()
	cm.size = Vector3(1, cap_h, 1)
	cap.mesh = cm
	if level == 0:
		cap.material_override = mats["sand"]
	elif level >= 3:
		cap.material_override = mats["grass_hi"]
	else:
		cap.material_override = mats["grass_a"] if checker else mats["grass_b"]
	cap.position.y = height / 2.0 - cap_h / 2.0
	tile.add_child(cap)
	add_child(tile)


func _tree(at: Vector3) -> void:
	var tree := StaticBody3D.new()
	tree.position = at
	var col := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = 0.25
	shape.height = 1.6
	col.shape = shape
	col.position.y = 0.8
	tree.add_child(col)
	var trunk := MeshInstance3D.new()
	var tm := CylinderMesh.new()
	tm.top_radius = 0.1
	tm.bottom_radius = 0.14
	tm.height = 0.6
	trunk.mesh = tm
	trunk.material_override = mats["trunk"]
	trunk.position.y = 0.3
	tree.add_child(trunk)
	for i in 2:
		var cone := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.0
		cm.bottom_radius = 0.55 - i * 0.15
		cm.height = 0.8
		cone.mesh = cm
		cone.material_override = mats["leaf"]
		cone.position.y = 0.85 + i * 0.45
		tree.add_child(cone)
	add_child(tree)


func _rock(at: Vector3) -> void:
	var s := rng.randf_range(0.25, 0.4)
	var size := Vector3(s * 1.4, s, s * 1.2)
	var mi := _box(at + Vector3(rng.randf_range(-0.2, 0.2), s * 0.5, rng.randf_range(-0.2, 0.2)), size, mats["rock"])
	mi.get_parent().rotation.y = rng.randf() * TAU


func _prop(kind: String, at: Vector3) -> Node3D:
	var p := Prop.new()
	p.main = main
	p.kind = kind
	add_child(p)
	p.global_position = at
	return p


func _label(text: String, at: Vector3, size := 36) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.font_size = size
	l.outline_size = 10
	l.pixel_size = 0.01
	l.modulate = Color("fff3c4")
	add_child(l)
	l.global_position = at
	return l


# ---------- railway ----------

func _railway(z: float) -> void:
	var y := STEP
	var span := 46.0
	# Bridge decks over the water, merged into runs.
	var run_start := -999.0
	var x := -span
	while x <= span + 1.0:
		var cell := Vector2i(int(floor(x + _half)), int(floor(z + _half)))
		var land := _tops.has(cell) and x <= span
		if not land and run_start < -900.0 and x <= span:
			run_start = x
		elif (land or x > span) and run_start > -900.0:
			var length := x - run_start
			_box(Vector3(run_start + length / 2.0 - 0.5, y - 0.15, z), Vector3(length, 0.3, 2.4), mats["wood"])
			var px := run_start
			while px < x - 0.5:
				var pillar := MeshInstance3D.new()
				var pm := CylinderMesh.new()
				pm.top_radius = 0.15
				pm.bottom_radius = 0.2
				pm.height = 3.0
				pillar.mesh = pm
				pillar.material_override = mats["wood"]
				pillar.position = Vector3(px, y - 1.8, z)
				add_child(pillar)
				px += 3.0
			run_start = -999.0
		x += 1.0
	for side in [-0.45, 0.45]:
		_box(Vector3(0, y + 0.05, z + side), Vector3(span * 2.0, 0.08, 0.08), mats["rail"], -1, false)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	var sleeper := BoxMesh.new()
	sleeper.size = Vector3(0.25, 0.06, 1.4)
	mm.mesh = sleeper
	var count := int(span * 2.0 / 0.7)
	mm.instance_count = count
	for i in count:
		mm.set_instance_transform(i, Transform3D(Basis(), Vector3(-span + i * 0.7, y + 0.01, z)))
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = mats["wood"]
	add_child(mmi)

	var train := Train.new()
	train.main = main
	train.rail_mat = mats["rail"]
	train.position = Vector3(-46.0, y + 0.05, z)
	add_child(train)


# ---------- islet, drawbridge and plate ----------

func _islet(row_edge: int, extreme: int, cz: int) -> void:
	var y := STEP
	var z := cz - _half + 0.5
	_hinge_a = Vector3(row_edge - _half + 0.5 + _side * 0.5, y, z)
	_hinge_b = Vector3(extreme + _side * 8 - _half + 0.5 - _side * 0.5, y, z)
	var gap := absf(_hinge_b.x - _hinge_a.x)
	for pair in [[_hinge_a, _side], [_hinge_b, -_side]]:
		var leaf := Drawbridge.new()
		leaf.hinge = pair[0]
		leaf.dir = Vector3(pair[1], 0, 0)
		leaf.length = gap / 2.0
		leaf.mat = mats["wood"]
		add_child(leaf)
		_leaves.append(leaf)
		# stone posts at each hinge
		for pz in [-1.25, 1.25]:
			_box(pair[0] + Vector3(-pair[1] * 0.2, 0.5, pz), Vector3(0.35, 1.0, 0.35), mats["rock"])

	var plate_at := Vector3(row_edge - _side * 2 - _half + 0.5, y, z + 2.0)
	var plate := Plate.new()
	plate.world = self
	plate.main = main
	add_child(plate)
	plate.global_position = plate_at
	_label("PUT A CRATE HERE\nTO LOWER THE BRIDGE", plate_at + Vector3.UP * 1.3, 30)
	# The crate for the plate starts some way off, so you have to carry it.
	var crate_spot := plate_at - Vector3(_side * 7.0, 0, 3.0)
	var top := build_top(crate_spot)
	if is_nan(top):
		crate_spot = spawn_point + Vector3(2.0, 0, 0)
	_prop("crate", Vector3(crate_spot.x, 1.5, crate_spot.z))
	gold_point = Vector3(extreme + _side * 10 - _half + 0.5, y + 0.45, z)


func set_bridge(open: bool) -> void:
	if open == bridge_open:
		return
	bridge_open = open
	for leaf in _leaves:
		leaf.goal = 0.0 if open else 78.0
	main.sfx.play("powerup" if open else "click", _hinge_a, 0.6)
	if open:
		main.show_banner("BRIDGE LOWERED", Color("8dffb0"))


# ---------- building ----------

func _building(id: int, c: Vector3) -> void:
	var b := {"id": id, "center": c, "walls": [], "upper": [], "roof": [], "faded": false}
	var hw := BW / 2.0
	var hd := BD / 2.0
	for fl in 2:
		for side in ["front", "back", "left", "right"]:
			_wall_side(b, fl, side, c.y + fl * FLOOR_H, fl == 0 and side == "front")

	# Upper floor with a long opening along the back wall for the ramp.
	var back := c.z - hd + WALL_T
	var strip := 1.3
	var hz1 := back + strip
	var hole_left := c.x - 1.6
	var sy := c.y + FLOOR_H
	b["upper"].append(_box(Vector3(c.x, sy, (hz1 + c.z + hd) / 2.0), Vector3(BW, 0.2, c.z + hd - hz1), mats["floor"], id))
	b["upper"].append(_box(Vector3((c.x - hw + hole_left) / 2.0, sy, (c.z - hd + hz1) / 2.0), Vector3(hole_left - (c.x - hw), 0.2, hz1 - (c.z - hd)), mats["floor"], id))
	# Ramp rising from the back-right corner up to the upper floor.
	var x_low := c.x + hw - WALL_T - 0.05
	var x_high := hole_left
	var rise := FLOOR_H + 0.1
	var run := x_low - x_high
	var ramp := _box(Vector3((x_low + x_high) / 2.0, c.y + rise / 2.0 - 0.07, back + strip / 2.0), Vector3(sqrt(rise * rise + run * run), 0.15, strip - 0.05), mats["floor"], id)
	ramp.get_parent().rotation.z = -atan2(rise, run)

	# Roof, chimney, and the chest that rewards getting up there.
	var roof_y := c.y + 2.0 * FLOOR_H
	b["roof"].append(_box(Vector3(c.x, roof_y, c.z), Vector3(BW + 0.4, 0.25, BD + 0.4), mats["roof"], id))
	b["roof"].append(_box(Vector3(c.x - 1.6, roof_y + 0.6, c.z - 1.6), Vector3(0.6, 1.0, 0.6), mats["roof"], id))
	chest_point = Vector3(c.x - 0.6, roof_y + 0.45, c.z + 1.0)
	b["roof_top"] = roof_y + 0.125

	# Outside ladder up the back wall to the roof.
	_ladder(Vector3(c.x + 0.6, c.y, c.z - hd - 0.08), 2.0 * FLOOR_H + 0.3, Vector3(0, 0, -1))

	# Elevator up the right-hand side.
	lift = Elevator.new()
	lift.y_low = c.y - 0.1
	lift.y_high = roof_y + 0.025
	lift.position = Vector3(c.x + hw + 0.85, c.y - 0.1, c.z)
	add_child(lift)
	for pz in [-0.95, 0.95]:
		_box(Vector3(c.x + hw + 0.85, c.y + FLOOR_H, c.z + pz), Vector3(0.12, FLOOR_H * 2.0 + 0.6, 0.12), mats["metal"], -1, false)
	buildings.append(b)


func _wall_side(b: Dictionary, fl: int, side: String, y0: float, door: bool) -> void:
	var c: Vector3 = b["center"]
	var along_x := side == "front" or side == "back"
	var start := (c.x - BW / 2.0) if along_x else (c.z - BD / 2.0)
	var fixed := 0.0
	match side:
		"front":
			fixed = c.z + BD / 2.0 - WALL_T / 2.0
		"back":
			fixed = c.z - BD / 2.0 + WALL_T / 2.0
		"left":
			fixed = c.x - BW / 2.0 + WALL_T / 2.0
		"right":
			fixed = c.x + BW / 2.0 - WALL_T / 2.0
	var segs := [[0.8, "s"], [1.6, "w"], [1.2, "s"], [1.6, "w"], [0.8, "s"]]
	var u := start
	var first_window := true
	for sg in segs:
		var length: float = sg[0]
		var mid := u + length / 2.0
		if sg[1] == "s":
			_wall_piece(b, fl, along_x, mid, fixed, y0, FLOOR_H, length)
		else:
			var is_door := door and first_window
			first_window = false
			if not is_door:
				_wall_piece(b, fl, along_x, mid, fixed, y0, 0.7, length)
			_wall_piece(b, fl, along_x, mid, fixed, y0 + 1.7, FLOOR_H - 1.7, length)
			if not is_door:
				var g := Glass.new()
				g.main = main
				g.size = Vector3(length - 0.05, 1.0, 0.06) if along_x else Vector3(0.06, 1.0, length - 0.05)
				g.position = Vector3(mid, y0 + 1.2, fixed) if along_x else Vector3(fixed, y0 + 1.2, mid)
				g.set_meta("building", b["id"])
				add_child(g)
				if fl == 1:
					b["upper"].append(g)
		u += length


func _wall_piece(b: Dictionary, fl: int, along_x: bool, mid: float, fixed: float, ybot: float, h: float, length: float) -> void:
	var center := Vector3(mid, ybot + h / 2.0, fixed) if along_x else Vector3(fixed, ybot + h / 2.0, mid)
	var size := Vector3(length, h, WALL_T) if along_x else Vector3(WALL_T, h, length)
	var mi := _box(center, size, mats["wall"], b["id"])
	b["walls"].append(mi)
	if fl == 1:
		b["upper"].append(mi)


## A ladder against a wall. `out` points away from the wall, toward where you climb.
func _ladder(foot: Vector3, height: float, out: Vector3) -> void:
	var across := Vector3(out.z, 0, -out.x)
	for s in [-0.3, 0.3]:
		_box(foot + across * s + Vector3(0, height / 2.0, 0), Vector3(0.07, height, 0.07), mats["wood"], -1, false)
	var rungs := int(height / 0.35)
	for i in rungs:
		var r := _box(foot + Vector3(0, 0.25 + i * 0.35, 0), Vector3(0.6, 0.05, 0.06), mats["wood"], -1, false)
		r.rotation.y = atan2(across.x, across.z) - PI / 2.0
	var area := Area3D.new()
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.9, height + 0.6, 0.9)
	col.shape = shape
	area.add_child(col)
	area.position = foot + Vector3(0, height / 2.0 + 0.2, 0) + out * 0.45
	add_child(area)
	area.body_entered.connect(func(body: Node3D) -> void:
		if "ladders" in body:
			body.ladders += 1)
	area.body_exited.connect(func(body: Node3D) -> void:
		if "ladders" in body:
			body.ladders = maxi(body.ladders - 1, 0))


func _trampoline(at: Vector3) -> void:
	var root := StaticBody3D.new()
	root.position = at
	add_child(root)
	var col := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = 0.55
	shape.height = 0.25
	col.shape = shape
	col.position.y = 0.125
	root.add_child(col)
	var frame := MeshInstance3D.new()
	var fm := CylinderMesh.new()
	fm.top_radius = 0.6
	fm.bottom_radius = 0.6
	fm.height = 0.22
	frame.mesh = fm
	frame.material_override = mats["dark"]
	frame.position.y = 0.11
	root.add_child(frame)
	var pad := MeshInstance3D.new()
	var pm := CylinderMesh.new()
	pm.top_radius = 0.5
	pm.bottom_radius = 0.5
	pm.height = 0.06
	pad.mesh = pm
	pad.material_override = mats["pad"]
	pad.position.y = 0.25
	root.add_child(pad)
	var area := Area3D.new()
	var ac := CollisionShape3D.new()
	var ashape := CylinderShape3D.new()
	ashape.radius = 0.5
	ashape.height = 0.5
	ac.shape = ashape
	area.add_child(ac)
	area.position.y = 0.5
	root.add_child(area)
	area.body_entered.connect(func(body: Node3D) -> void:
		if body is RigidBody3D:
			var rb := body as RigidBody3D
			rb.linear_velocity = Vector3(rb.linear_velocity.x, 13.0, rb.linear_velocity.z)
			pad.scale = Vector3(1.15, 0.3, 1.15)
			var tw := pad.create_tween()
			tw.tween_property(pad, "scale", Vector3.ONE, 0.45).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
			main.sfx.play("spring", at)
			if body is Blob:
				(body as Blob).squash = Vector3(0.6, 1.5, 0.6))


# ---------- routing for enemies ----------

func _make_routes(c: Vector3) -> void:
	var hw := BW / 2.0
	var hd := BD / 2.0
	var y := c.y
	var door_x := c.x - hw + 1.6
	var back := c.z - hd + WALL_T
	var roof_top: float = buildings[0]["roof_top"]
	var door_out := Vector3(door_x, y, c.z + hd + 0.9)
	var door_in := Vector3(door_x, y, c.z + hd - 1.0)
	var ramp_low := Vector3(c.x + hw - 0.7, y, back + 0.65)
	var ramp_high := Vector3(c.x - 2.2, y + FLOOR_H, back + 0.65)
	var lift_spot := Vector3(c.x + hw + 0.85, y, c.z)
	var lift_wait := Vector3(c.x + hw + 0.85, y, c.z + 1.8)
	var roof_edge := Vector3(c.x - hw + 0.2, roof_top, c.z)
	var below := Vector3(c.x - hw - 1.2, y, c.z)
	_edge("out", "in", door_out, door_in)
	_edge("in", "out", door_in, door_out)
	_edge("in", "f2", ramp_low, ramp_high)
	_edge("f2", "in", ramp_high, ramp_low)
	_edge("out", "roof", lift_wait, lift_spot, "lift")
	_edge("roof", "out", roof_edge, below)
	var a_land := _hinge_a - Vector3(_side * 1.0, 0, 0)
	var b_land := _hinge_b + Vector3(_side * 1.0, 0, 0)
	_edge("out", "bridge", a_land, _hinge_a + Vector3(_side * 0.8, 0, 0), "bridge")
	_edge("bridge", "out", _hinge_a + Vector3(_side * 0.8, 0, 0), a_land, "bridge")
	_edge("bridge", "islet", _hinge_b - Vector3(_side * 0.8, 0, 0), b_land, "bridge")
	_edge("islet", "bridge", b_land, _hinge_b - Vector3(_side * 0.8, 0, 0), "bridge")


func _edge(from: String, to: String, a: Vector3, b: Vector3, kind := "walk") -> void:
	_edges[from + ">" + to] = {"from": from, "to": to, "a": a, "b": b, "kind": kind}


func zone(p: Vector3) -> String:
	if absf(p.z - _hinge_a.z) < 3.0:
		if _side * (p.x - _hinge_b.x) > -0.2:
			return "islet"
		if _side * (p.x - _hinge_a.x) > 0.2 and absf(p.z - _hinge_a.z) < 1.4:
			return "bridge"
	if buildings.is_empty():
		return "out"
	var b: Dictionary = buildings[0]
	var c: Vector3 = b["center"]
	var roof_top: float = b["roof_top"]
	if is_instance_valid(lift) and absf(p.x - lift.global_position.x) < 0.8 and absf(p.z - lift.global_position.z) < 0.9 and p.y > roof_top - 0.6:
		return "roof"
	if absf(p.x - c.x) < BW / 2.0 + 0.1 and absf(p.z - c.z) < BD / 2.0 + 0.1:
		if p.y > roof_top - 0.3:
			return "roof"
		if p.y > c.y + FLOOR_H - 0.2:
			return "f2"
		return "in"
	return "out"


func _path(from: String, to: String) -> Array:
	var prev := {from: ""}
	var queue := [from]
	while not queue.is_empty():
		var z: String = queue.pop_front()
		if z == to:
			break
		for key in _edges:
			var e: Dictionary = _edges[key]
			if e["from"] != z or prev.has(e["to"]):
				continue
			if e["kind"] == "bridge" and not bridge_open:
				continue
			prev[e["to"]] = z
			queue.append(e["to"])
	if not prev.has(to):
		return []
	var path := [to]
	while path[0] != from:
		path.push_front(prev[path[0]])
	return path


## Where a walker at `from` should head next to reach `to`. Returns `from` to mean "wait".
func route_point(from: Vector3, to: Vector3) -> Vector3:
	var zf := zone(from)
	var zt := zone(to)
	if zf == zt or (zf == "roof" and zt == "out"):
		return to
	var path := _path(zf, zt)
	if path.size() < 2:
		return from
	var e: Dictionary = _edges[zf + ">" + path[1]]
	var a: Vector3 = e["a"]
	if e["kind"] == "lift" and is_instance_valid(lift):
		var plat: Vector3 = lift.global_position
		var on_lift := absf(from.x - plat.x) < 0.7 and absf(from.z - plat.z) < 0.8 and from.y > plat.y
		if on_lift:
			return from
		if plat.y < lift.y_low + 0.15:
			return Vector3(plat.x, from.y, plat.z)
		return a
	if Vector2(from.x - a.x, from.z - a.z).length() > 0.8:
		return a
	return e["b"]


# ---------- see-through building ----------

## Fades a building's walls when the player is inside or hidden behind it, and hides the
## floors above the player so you can see in.
func update_xray(player_pos: Vector3, cam_pos: Vector3) -> void:
	var blocking := -1
	var q := PhysicsRayQueryParameters3D.create(player_pos + Vector3.UP * 0.3, cam_pos)
	q.exclude = [main.player.get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if not hit.is_empty():
		var body: Object = hit["collider"]
		if body.has_meta("building"):
			blocking = body.get_meta("building")
	for b in buildings:
		var c: Vector3 = b["center"]
		var inside := absf(player_pos.x - c.x) < BW / 2.0 and absf(player_pos.z - c.z) < BD / 2.0 and player_pos.y < c.y + 2.0 * FLOOR_H and player_pos.y > c.y - 0.5
		var fade: bool = inside or blocking == b["id"]
		if fade != b["faded"]:
			b["faded"] = fade
			for w in b["walls"]:
				(w as MeshInstance3D).material_override = mats["wall_fade"] if fade else mats["wall"]
		var hide_upper := inside and player_pos.y < c.y + FLOOR_H + 0.2
		for n in b["upper"]:
			if is_instance_valid(n):
				(n as Node3D).visible = not hide_upper
		for n in b["roof"]:
			(n as Node3D).visible = not inside
