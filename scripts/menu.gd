extends CanvasLayer
## Brawl Stars style lobby. Your brawler stands on a podium (drag to spin it, it does
## random tricks), your car parks beside it. Top bar: trophies, coins, gems. Left: SHOP
## (fashion, for gems), BRAWLERS, GUNS, GARAGE, and a daily gift. Bottom: the trophy road
## and the big PLAY button. Every card can buy, equip and upgrade.

const Profile := preload("res://scripts/profile.gd")
const Cosmetics := preload("res://scripts/cosmetics.gd")
const Vehicle := preload("res://scripts/vehicle.gd")
const PlayerScript := preload("res://scripts/player.gd")

const C_COIN := Color("ffd34d")
const C_GEM := Color("d36bff")
const C_TROPHY := Color("ffb02e")

var main
var profile
var root: Control
var showroom: Node3D
var preview: Blob
var car_model: Node3D
var _chips := {}
var _title: Label
var _name_l: Label
var _desc_l: Label
var _loadout_l: Label
var _road_l: Label
var _road_fill: ColorRect
var _road_bg: ColorRect
var _play: Button
var _side: Array[Button] = []
var _gift: Button
var _panel: PanelContainer
var _panel_title: Label
var _grid: GridContainer
var _toast: Label
var _tab := ""
var _drag := false
var _emote_t := 1.5
var _t := 0.0
var _rays: Node3D


func open() -> void:
	layer = 5
	root = Control.new()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	_build_showroom()

	_title = _label("BLOB ISLAND", 54, Color("ffffff"), 14)
	_title.label_settings.outline_color = Color("1b2a6b")
	root.add_child(_title)
	for k in ["trophies", "coins", "gems"]:
		var chip := PanelContainer.new()
		chip.add_theme_stylebox_override("panel", _style(Color(0.06, 0.08, 0.25, 0.75), Color(0, 0, 0, 0.5), 12, 3))
		var l := _label("", 24, [C_TROPHY, C_COIN, C_GEM][["trophies", "coins", "gems"].find(k)], 6)
		chip.add_child(l)
		chip.custom_minimum_size = Vector2(170, 46)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		root.add_child(chip)
		_chips[k] = l

	var tabs := [["SHOP", Color("ff5d8f"), "shop"], ["BRAWLERS", Color("4dabff"), "brawler"], ["GUNS", Color("ff9f43"), "gun"], ["GARAGE", Color("2ec27e"), "car"]]
	for t in tabs:
		var b := _button(t[0], 26, t[1], _open_tab.bind(t[2]))
		b.custom_minimum_size = Vector2(190, 62)
		root.add_child(b)
		_side.append(b)
	_gift = _button("DAILY GIFT", 22, C_COIN.darkened(0.1), _claim_gift)
	_gift.custom_minimum_size = Vector2(190, 56)
	root.add_child(_gift)

	_name_l = _label("", 40, Color.WHITE, 12)
	_name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(_name_l)
	_desc_l = _label("", 20, Color("e8f1ff"), 6)
	_desc_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(_desc_l)
	_loadout_l = _label("", 20, Color.WHITE, 6)
	root.add_child(_loadout_l)

	_road_bg = ColorRect.new()
	_road_bg.color = Color(0.06, 0.08, 0.25, 0.8)
	_road_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_road_bg)
	_road_fill = ColorRect.new()
	_road_fill.color = C_TROPHY
	_road_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_road_fill)
	_road_l = _label("", 19, Color.WHITE, 6)
	_road_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(_road_l)

	_play = _button("PLAY", 60, Color("ffcf3a"), func() -> void: main.start_run())
	_play.add_theme_color_override("font_color", Color("3a2400"))
	_play.add_theme_color_override("font_outline_color", Color(1, 1, 1, 0.6))
	_play.custom_minimum_size = Vector2(280, 116)
	root.add_child(_play)

	_panel = PanelContainer.new()
	_panel.add_theme_stylebox_override("panel", _style(Color("1d3b8f"), Color("0b1647"), 22, 6))
	_panel.visible = false
	root.add_child(_panel)
	var pv := VBoxContainer.new()
	pv.add_theme_constant_override("separation", 10)
	_panel.add_child(pv)
	var head := HBoxContainer.new()
	pv.add_child(head)
	_panel_title = _label("", 38, Color.WHITE, 10)
	_panel_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(_panel_title)
	var close := _button("X", 26, Color("ff5d5d"), func() -> void: _open_tab(""))
	close.custom_minimum_size = Vector2(56, 52)
	head.add_child(close)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	pv.add_child(scroll)
	_grid = GridContainer.new()
	_grid.columns = 4
	_grid.add_theme_constant_override("h_separation", 14)
	_grid.add_theme_constant_override("v_separation", 14)
	scroll.add_child(_grid)

	_toast = _label("", 40, Color.WHITE, 12)
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.modulate.a = 0.0
	root.add_child(_toast)
	_refresh()


func close_menu() -> void:
	if is_instance_valid(showroom):
		showroom.queue_free()
	queue_free()


# ---------- 3D showroom ----------

func _build_showroom() -> void:
	showroom = Node3D.new()
	main.add_child(showroom)
	showroom.add_child(_mesh_part(_cyl(1.15, 0.35), Color("ffcf3a"), Vector3(0, -0.18, 0)))
	showroom.add_child(_mesh_part(_cyl(1.3, 0.2), Color("2e4cb3"), Vector3(0, -0.32, 0)))
	showroom.add_child(_mesh_part(_cyl(9.0, 0.1), Color("3a63d6"), Vector3(0, -0.45, 0)))
	# Sunburst rays behind the brawler, slowly turning.
	_rays = Node3D.new()
	_rays.position = Vector3(0.3, 1.2, -5.0)
	showroom.add_child(_rays)
	for i in 12:
		var ray := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.9, 14.0, 0.05)
		ray.mesh = bm
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.albedo_color = Color(1, 1, 1, 0.07)
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		ray.material_override = m
		ray.rotation.z = PI * i / 12.0
		_rays.add_child(ray)
	# A couple of grumpy enemies hanging around the back.
	for spot in [Vector3(-2.3, 0.0, -2.4), Vector3(3.6, 0.0, -2.8)]:
		var e := Blob.new()
		e.main = main
		e.team = "enemy"
		e.color = Color("f2789a") if spot.x < 0 else Color("9b6bff")
		e.radius = 0.4 if spot.x < 0 else 0.7
		e.teeth = 3 if spot.x < 0 else 5
		e.prints = false
		e.freeze = true
		showroom.add_child(e)
		e.position = spot + Vector3.UP * e.radius * 0.9
		e.facing = Vector3(-spot.x, 0, 4.0).normalized()
		e.set_meta("idle", true)
	_make_preview()
	_make_car()


func _make_preview() -> void:
	if is_instance_valid(preview):
		preview.queue_free()
	var b: Dictionary = profile.brawler()
	preview = Blob.new()
	preview.main = main
	preview.team = "player"
	preview.color = Color(b["color"])
	preview.radius = b["radius"] * 1.6
	preview.prints = false
	preview.freeze = true
	showroom.add_child(preview)
	preview.position = Vector3(0, preview.radius * 0.9, 0)
	Cosmetics.dress(preview.visual, preview.radius, profile.equip["hat"], profile.equip["glasses"])
	preview.squash = Vector3(0.5, 1.6, 0.5)
	preview.trick("spin", 0.6, 1.0)


func _make_car() -> void:
	if is_instance_valid(car_model):
		car_model.queue_free()
	var id: String = profile.equip["car"]
	var model := Vehicle.build_model(id, Color(Profile.CARS[id]["color"]))
	car_model = model["root"]
	showroom.add_child(car_model)
	car_model.position = Vector3(2.4, 0.05 if id != "hover" else 0.4, 0.4)
	car_model.rotation.y = -0.7
	car_model.scale = Vector3.ONE * 0.9
	for w in model["wheels"]:
		(w as Node3D).position = (w as Node3D).get_meta("mount") + Vector3.DOWN * 0.15


func _mesh_part(mesh: Mesh, c: Color, pos: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.4
	mi.material_override = m
	mi.position = pos
	return mi


func _cyl(r: float, h: float) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = r
	c.bottom_radius = r
	c.height = h
	return c


# ---------- UI helpers ----------

func _style(bg: Color, border := Color(0, 0, 0, 0.55), radius := 16, bw := 4) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(bw)
	sb.set_corner_radius_all(radius)
	sb.shadow_color = Color(0, 0, 0, 0.3)
	sb.shadow_offset = Vector2(0, 5)
	sb.shadow_size = 2
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	return sb


func _button(text: String, size: int, bg: Color, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", size)
	b.add_theme_stylebox_override("normal", _style(bg))
	b.add_theme_stylebox_override("hover", _style(bg.lightened(0.15)))
	b.add_theme_stylebox_override("pressed", _style(bg.darkened(0.15)))
	b.add_theme_stylebox_override("disabled", _style(bg.darkened(0.45)))
	b.add_theme_color_override("font_color", Color.WHITE)
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.add_theme_color_override("font_pressed_color", Color.WHITE)
	b.add_theme_color_override("font_disabled_color", Color(1, 1, 1, 0.5))
	b.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.75))
	b.add_theme_constant_override("outline_size", 8)
	b.pressed.connect(func() -> void:
		main.sfx.play("click", null, 1.2)
		b.pivot_offset = b.size / 2.0
		b.scale = Vector2(0.9, 0.9)
		var tw := b.create_tween()
		tw.tween_property(b, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT))
	b.pressed.connect(cb)
	return b


func _label(text: String, size: int, c: Color, outline: int) -> Label:
	var l := Label.new()
	l.text = text
	var ls := LabelSettings.new()
	ls.font_size = size
	ls.font_color = c
	ls.outline_size = outline
	ls.outline_color = Color(0, 0, 0, 0.7)
	l.label_settings = ls
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func toast(text: String, c := Color.WHITE) -> void:
	_toast.text = text
	_toast.label_settings.font_color = c
	_toast.modulate.a = 1.0
	_toast.pivot_offset = _toast.size / 2.0
	_toast.scale = Vector2(0.4, 0.4)
	_toast.rotation = -0.2
	var tw := _toast.create_tween()
	tw.tween_property(_toast, "scale", Vector2.ONE, 0.4).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(_toast, "rotation", 0.0, 0.4).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	tw.tween_interval(1.3)
	tw.tween_property(_toast, "modulate:a", 0.0, 0.4)


# ---------- tabs and cards ----------

func _open_tab(tab: String) -> void:
	_tab = tab
	_panel.visible = tab != ""
	if tab == "":
		return
	_panel_title.text = {"shop": "FASHION SHOP (GEMS)", "brawler": "BRAWLERS", "gun": "GUNS: STARTING GUN AND UPGRADES", "car": "GARAGE"}[tab]
	_panel.pivot_offset = _panel.size / 2.0
	_panel.scale = Vector2(0.85, 0.85)
	var tw := _panel.create_tween()
	tw.tween_property(_panel, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_fill_grid()


func _fill_grid() -> void:
	for c in _grid.get_children():
		c.queue_free()
	match _tab:
		"brawler":
			for id in Profile.BRAWLERS:
				var b: Dictionary = Profile.BRAWLERS[id]
				var info := "%s\nHP %d   SPEED %.1f" % [b["desc"], roundi(b["hp"]), b["speed"]]
				_card("brawler", id, b["name"], Color(b["color"]), info)
		"gun":
			for id in Profile.GUN_PRICES:
				var g: Dictionary = PlayerScript.GUNS[id]
				var lv: int = profile.level_of("gun", id)
				var info := "DAMAGE +%d%%\nAMMO %d" % [roundi((profile.gun_mult(id) - 1.0) * 100.0), roundi(g["ammo"] * profile.ammo_mult(id))]
				if id == "bomb":
					info += "\nAlways carried"
				_card("gun", id, g["name"], Color("ff9f43").lerp(Color("ff4d6d"), lv / 5.0), info)
		"car":
			for id in Profile.CARS:
				var c: Dictionary = profile.car_stats(id)
				var info := "%s\nSPEED %d   HP %d" % [c["desc"], roundi(c["speed"]), roundi(c["hp"])]
				_card("car", id, c["name"], Color(c["color"]), info)
		"shop":
			for id in Profile.HATS:
				_card("hat", id, "NO HAT" if id == "none" else id.to_upper(), Color("ff5d8f"), "Hat")
			for id in Profile.GLASSES:
				_card("glasses", id, "NO GLASSES" if id == "none" else id.to_upper(), Color("5dd6ff"), "Glasses")


func _card(kind: String, id: String, title: String, c: Color, info: String) -> void:
	var card := PanelContainer.new()
	var equipped: bool = profile.equip[kind] == id
	card.add_theme_stylebox_override("panel", _style(Color("2c55c7") if not equipped else Color("3f8f4f"), Color("0b1647"), 16, 4))
	card.custom_minimum_size = Vector2(205, 0)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	card.add_child(v)
	var sw := ColorRect.new()
	sw.color = c
	sw.custom_minimum_size = Vector2(0, 44)
	v.add_child(sw)
	var tl := _label(title, 22, Color.WHITE, 6)
	tl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tl.size = Vector2(180, 40)
	sw.add_child(tl)
	tl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var owned: bool = profile.owns(kind, id)
	var upgradable := kind in ["brawler", "gun", "car"]
	if upgradable and owned:
		var lv: int = profile.level_of(kind, id)
		var stars := _label("LEVEL %d  %s" % [lv, "*".repeat(lv)], 18, C_COIN, 5)
		v.add_child(stars)
	var il := _label(info, 15, Color("dfe8ff"), 4)
	il.autowrap_mode = TextServer.AUTOWRAP_WORD
	il.custom_minimum_size = Vector2(180, 0)
	v.add_child(il)
	var cur: String = profile.currency_of(kind)
	var cur_c := C_GEM if cur == "gems" else C_COIN
	if not owned:
		var price: int = profile.price_of(kind, id)
		var b := _button("BUY  %d %s" % [price, "GEMS" if cur == "gems" else "COINS"], 17, cur_c.darkened(0.25), _buy.bind(kind, id))
		b.disabled = (profile.gems if cur == "gems" else profile.coins) < price
		v.add_child(b)
		var road := _road_unlock(kind, id)
		if road != "":
			v.add_child(_label(road, 14, C_TROPHY, 4))
	else:
		var eq := _button("EQUIPPED" if equipped else "EQUIP", 18, Color("2ec27e") if not equipped else Color("1f6b3a"), _equip.bind(kind, id))
		eq.disabled = equipped
		v.add_child(eq)
		if upgradable:
			var cost: int = profile.upgrade_cost(kind, id)
			var up := _button("MAX LEVEL" if cost < 0 else "UPGRADE  %d COINS" % cost, 16, Color("ff9f43"), _upgrade.bind(kind, id))
			up.disabled = cost < 0 or profile.coins < cost
			v.add_child(up)
	_grid.add_child(card)


func _road_unlock(kind: String, id: String) -> String:
	for r in Profile.ROAD:
		if r[1] == kind and r[2] == id:
			return "FREE AT %d TROPHIES" % r[0]
	return ""


func _buy(kind: String, id: String) -> void:
	if profile.buy(kind, id):
		main.sfx.play("power_big")
		toast("UNLOCKED!", Color("8dffb0"))
		_after_change(kind)
	else:
		main.sfx.play("click", null, 0.5)
		toast("NOT ENOUGH " + profile.currency_of(kind).to_upper(), Color("ff8a8a"))


func _equip(kind: String, id: String) -> void:
	profile.equip[kind] = id
	profile.save()
	_after_change(kind)


func _upgrade(kind: String, id: String) -> void:
	if profile.upgrade(kind, id):
		main.sfx.play("powerup")
		toast("LEVEL %d!" % profile.level_of(kind, id), C_COIN)
		if is_instance_valid(preview):
			preview.trick("flip", 0.5, 2.0)
			preview.squash = Vector3(0.6, 1.5, 0.6)
		_after_change(kind)


func _after_change(kind: String) -> void:
	if kind in ["brawler", "hat", "glasses"]:
		_make_preview()
	if kind == "car":
		_make_car()
	_refresh()
	_fill_grid()


func _claim_gift() -> void:
	if profile.claim_gift():
		main.sfx.play("power_big")
		toast("+60 COINS  +5 GEMS", C_COIN)
		if is_instance_valid(preview):
			preview.trick("spin", 0.7, 2.0)
		_refresh()
	else:
		toast("COME BACK TOMORROW", Color("dfe8ff"))


func _refresh() -> void:
	_chips["trophies"].text = "TROPHIES  %d" % profile.trophies
	_chips["coins"].text = "COINS  %d" % profile.coins
	_chips["gems"].text = "GEMS  %d" % profile.gems
	var b: Dictionary = profile.brawler()
	_name_l.text = "%s   LV %d" % [b["name"], profile.level_of("brawler", profile.equip["brawler"])]
	_desc_l.text = b["desc"]
	var gun: String = profile.equip["gun"]
	var car: String = profile.equip["car"]
	_loadout_l.text = "STARTING GUN   %s  Lv%d\nCAR   %s  Lv%d\nBEST   Level %d, Wave %d" % [PlayerScript.GUNS[gun]["name"], profile.level_of("gun", gun), Profile.CARS[car]["name"], profile.level_of("car", car), profile.best_level, profile.best_wave]
	var nxt: Array = profile.next_road()
	if nxt.is_empty():
		_road_l.text = "TROPHY ROAD COMPLETE!   %d TROPHIES" % profile.trophies
	else:
		var prev: int = 0 if profile.road_claimed == 0 else Profile.ROAD[profile.road_claimed - 1][0]
		_road_l.text = "TROPHY ROAD   %d / %d   NEXT: %s" % [profile.trophies, nxt[0], nxt[3]]
		_road_fill.set_meta("frac", clampf(float(profile.trophies - prev) / float(nxt[0] - prev), 0.0, 1.0))
	_gift.text = "DAILY GIFT!" if profile.gift_ready() else "GIFT CLAIMED"


func _layout() -> void:
	var vs := root.get_viewport_rect().size
	root.size = vs
	_title.position = Vector2(26, 14)
	var x := vs.x - 20.0
	for k in ["gems", "coins", "trophies"]:
		var chip: Control = _chips[k].get_parent()
		x -= chip.size.x + 12
		chip.position = Vector2(x, 20)
	for i in _side.size():
		_side[i].position = Vector2(26, 110 + i * 76)
	_gift.position = Vector2(26, 110 + _side.size() * 76 + 10)
	_name_l.size = Vector2(500, 50)
	_name_l.position = Vector2(vs.x * 0.42 - 250, vs.y * 0.17)
	_desc_l.size = Vector2(500, 30)
	_desc_l.position = Vector2(vs.x * 0.42 - 250, vs.y * 0.17 + 52)
	_loadout_l.position = Vector2(26, vs.y - 120)
	var road_w := minf(520.0, vs.x - 700.0)
	_road_bg.size = Vector2(road_w, 22)
	_road_bg.position = Vector2(vs.x / 2.0 - road_w / 2.0 + 40, vs.y - 52)
	_road_fill.size = Vector2(road_w * float(_road_fill.get_meta("frac", 1.0)), 22)
	_road_fill.position = _road_bg.position
	_road_l.size = Vector2(road_w + 200, 30)
	_road_l.position = _road_bg.position + Vector2(-100, -34)
	_play.position = vs - _play.size - Vector2(30, 30)
	_play.pivot_offset = _play.size / 2.0
	_play.scale = Vector2.ONE * (1.0 + 0.03 * sin(_t * 4.0))
	_panel.size = Vector2(minf(940.0, vs.x - 260.0), vs.y - 150.0)
	_panel.position = Vector2(240, 96)
	_grid.columns = maxi(2, int((_panel.size.x - 40.0) / 220.0))
	_toast.size = Vector2(vs.x, 60)
	_toast.position = Vector2(0, vs.y * 0.45)
	if profile.gift_ready():
		_gift.pivot_offset = _gift.size / 2.0
		_gift.rotation = sin(_t * 6.0) * 0.04


func _process(delta: float) -> void:
	_t += delta
	_layout()
	if is_instance_valid(_rays):
		_rays.rotation.z += delta * 0.15
	if is_instance_valid(car_model):
		car_model.rotation.y += delta * 0.25
		car_model.position.y = (0.4 if profile.equip["car"] == "hover" else 0.05) + sin(_t * 2.0) * 0.03
	if not is_instance_valid(preview):
		return
	# Idle: bob, look around, and do a random trick every few seconds.
	if not _drag:
		preview.rotation.y = lerp_angle(preview.rotation.y, sin(_t * 0.6) * 0.35, 2.0 * delta)
	_emote_t -= delta
	if _emote_t <= 0.0:
		_emote_t = randf_range(2.5, 4.5)
		match randi() % 4:
			0:
				preview.trick("flip", 0.55, 1.0)
			1:
				preview.trick("spin", 0.6, 2.0)
			2:
				preview.trick("barrel", 0.6, 1.0)
			3:
				preview.squash = Vector3(1.4, 0.6, 1.4)
		var tw := preview.create_tween()
		tw.tween_property(preview, "position:y", preview.radius * 0.9 + 0.9, 0.28).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
		tw.tween_property(preview, "position:y", preview.radius * 0.9, 0.28).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
		tw.tween_callback(func() -> void:
			if is_instance_valid(preview):
				preview.squash = Vector3(1.35, 0.65, 1.35))
		for e in showroom.get_children():
			if e is Blob and e.has_meta("idle") and randf() < 0.5:
				(e as Blob).trick(["spin", "flip"][randi() % 2], 0.6, 1.0)
				(e as Blob).squash = Vector3(0.7, 1.3, 0.7)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		_drag = event.pressed and not _panel.visible
		if _drag and is_instance_valid(preview):
			preview.squash = Vector3(0.8, 1.25, 0.8)
	elif event is InputEventMouseMotion and _drag and is_instance_valid(preview):
		preview.rotation.y += (event as InputEventMouseMotion).relative.x * 0.012
	elif event is InputEventPanGesture and is_instance_valid(preview):
		preview.rotation.y -= (event as InputEventPanGesture).delta.x * 0.08
