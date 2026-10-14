extends Node3D
## Day and night lighting plus random weather: clear, rain, storm (rain, wind, lightning),
## snow, fog and wind. Wind pushes blobs and props around.

const MODES := ["clear", "clear", "rain", "storm", "snow", "fog", "wind"]

var main
var sun: DirectionalLight3D
var env: Environment
var mode := "clear"
var night := false
var wind := Vector3.ZERO
var lantern: OmniLight3D
var _rain: CPUParticles3D
var _snow: CPUParticles3D
var _bolt := 0.0


func setup() -> void:
	_rain = _particles(700, 0.9, Vector3(0.02, 0.5, 0.02), Color(0.75, 0.85, 1.0, 0.55), 18.0)
	_snow = _particles(450, 4.0, Vector3(0.06, 0.06, 0.06), Color(1, 1, 1, 0.95), 2.0)
	_snow.spread = 25.0
	lantern = OmniLight3D.new()
	lantern.light_color = Color(1.0, 0.8, 0.5)
	lantern.omni_range = 7.0
	lantern.light_energy = 0.0
	add_child(lantern)


func _particles(amount: int, life: float, size: Vector3, c: Color, speed: float) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = amount
	p.lifetime = life
	p.local_coords = false
	p.emitting = false
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(20, 0.5, 20)
	p.direction = Vector3.DOWN
	p.spread = 3.0
	p.gravity = Vector3.ZERO
	p.initial_velocity_min = speed * 0.85
	p.initial_velocity_max = speed * 1.15
	var mesh := BoxMesh.new()
	mesh.size = size
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = c
	mesh.material = m
	p.mesh = mesh
	add_child(p)
	return p


func set_night(on: bool) -> void:
	night = on
	var tw := create_tween().set_parallel()
	tw.tween_property(sun, "light_energy", 0.22 if on else 1.15, 2.5)
	tw.tween_property(sun, "light_color", Color(0.55, 0.65, 1.0) if on else Color(1.0, 0.96, 0.88), 2.5)
	tw.tween_property(env, "ambient_light_energy", 0.3 if on else 0.55, 2.5)
	tw.tween_property(env, "ambient_light_color", Color(0.35, 0.42, 0.75) if on else Color(0.75, 0.82, 0.95), 2.5)
	tw.tween_property(env, "background_color", Color(0.04, 0.1, 0.2) if on else Color(0.13, 0.42, 0.52), 2.5)
	tw.tween_property(lantern, "light_energy", 1.6 if on else 0.0, 2.5)


func random_weather(biome: int) -> void:
	var options: Array = MODES.duplicate()
	if biome == 1:
		options.append_array(["snow", "snow"])
	elif biome == 2:
		options.erase("snow")
		options.erase("rain")
	set_weather(options[randi() % options.size()])


func set_weather(m: String) -> void:
	mode = m
	_rain.emitting = m == "rain" or m == "storm"
	_snow.emitting = m == "snow"
	env.fog_enabled = m == "fog"
	env.fog_light_color = Color(0.8, 0.85, 0.9)
	env.fog_density = 0.035
	wind = Vector3.ZERO
	if m == "wind" or m == "storm":
		var a := randf() * TAU
		wind = Vector3(cos(a), 0, sin(a)) * (5.0 if m == "wind" else 3.5)
	_rain.direction = (Vector3.DOWN * 18.0 + wind * 2.0).normalized()
	_snow.direction = (Vector3.DOWN * 2.0 + wind * 0.4).normalized()


func label() -> String:
	return {"clear": "", "rain": "RAIN", "storm": "STORM", "snow": "SNOW", "fog": "FOG", "wind": "WIND"}[mode]


func _process(delta: float) -> void:
	var c: Vector3 = main.cam_target
	_rain.global_position = c + Vector3.UP * 14.0
	_snow.global_position = c + Vector3.UP * 9.0
	if is_instance_valid(main.player):
		lantern.global_position = main.player.global_position + Vector3.UP * 1.2
	if wind != Vector3.ZERO:
		for group in ["actor", "prop"]:
			for n in get_tree().get_nodes_in_group(group):
				var rb := n as RigidBody3D
				if rb and not rb.freeze:
					rb.apply_central_force(wind * rb.mass * 0.6)
	if mode == "storm":
		_bolt -= delta
		if _bolt <= 0.0:
			_bolt = randf_range(5.0, 11.0)
			var base_e := sun.light_energy
			sun.light_energy = 4.0
			var tw := create_tween()
			tw.tween_property(sun, "light_energy", base_e, 0.25)
			main.sfx.play("thunder", null, randf_range(0.7, 1.0), -2.0)
