extends Control
## Screen-space health bar that follows a blob. The fill snaps down on a hit, a white
## "ghost" segment lingers and then drains, and the bar punches up in size.

var target
var camera: Camera3D
var fill_color := Color("ff5d73")
var bar_width := 44.0
var bar_height := 7.0
var _shown := 1.0
var _ghost := 1.0
var _hold := 0.0
var _last := 1.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	pivot_offset = Vector2(bar_width / 2.0, bar_height / 2.0)


func _process(delta: float) -> void:
	if not is_instance_valid(target) or (target.dead and not target.is_in_group("player")):
		queue_free()
		return
	visible = not target.dead and target.global_position.y > -0.4
	var frac: float = clampf(target.hp / target.max_hp, 0.0, 1.0)
	if frac < _last - 0.001:
		_hold = 0.35
		scale = Vector2(1.3, 1.6)
	elif frac > _last + 0.001:
		_ghost = frac
	_last = frac
	_shown = lerpf(_shown, frac, 20.0 * delta)
	_hold -= delta
	if _hold <= 0.0:
		_ghost = move_toward(_ghost, _shown, 0.8 * delta)
	scale = scale.lerp(Vector2.ONE, 10.0 * delta)
	var wp: Vector3 = target.global_position + Vector3.UP * (target.radius + 0.55)
	position = camera.unproject_position(wp) - pivot_offset
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(-2, -2, bar_width + 4, bar_height + 4), Color(0.05, 0.05, 0.1, 0.65))
	draw_rect(Rect2(0, 0, bar_width * _ghost, bar_height), Color(1, 1, 1, 0.9))
	var c := fill_color
	if target and target.is_in_group("player") and _shown < 0.35:
		c = c.lerp(Color("ff4040"), 0.7 + 0.3 * sin(Time.get_ticks_msec() * 0.015))
	draw_rect(Rect2(0, 0, bar_width * _shown, bar_height), c)
	draw_rect(Rect2(0, 0, bar_width * _shown, bar_height * 0.35), Color(1, 1, 1, 0.25))
