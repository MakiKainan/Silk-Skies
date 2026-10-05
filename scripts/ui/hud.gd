class_name Hud
extends CanvasLayer
## Sandbox HUD: the tracked ship's sailing readout, shield/hull/armor, and one status line
## per weapon (mode, cooldown / charge / lock bar).

const MODE_NAMES := {
	WeaponData.Targeting.AUTO: "auto",
	WeaponData.Targeting.MANUAL: "manual LMB",
	WeaponData.Targeting.LOCK_ON: "lock RMB",
}

var _ship: Ship
var _box: VBoxContainer
var _info: Label
var _burn_bar: ProgressBar
var _shield_bar: ProgressBar
var _hull_bar: ProgressBar
var _health_label: Label
var _weapon_box: VBoxContainer
var _weapon_rows: Array[Dictionary] = []  # {controller, label, bar}
var _banner: Label


func _ready() -> void:
	_box = VBoxContainer.new()
	_box.position = Vector2(16.0, 16.0)
	_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_box)

	_info = _make_label()
	_box.add_child(_info)
	_burn_bar = _make_bar(Color(0.9, 0.8, 0.3), 10.0)
	_box.add_child(_burn_bar)

	_health_label = _make_label()
	_box.add_child(_health_label)
	_shield_bar = _make_bar(Color(0.3, 0.65, 1.0), 12.0)
	_box.add_child(_shield_bar)
	_hull_bar = _make_bar(Color(0.9, 0.25, 0.25), 12.0)
	_box.add_child(_hull_bar)

	_weapon_box = VBoxContainer.new()
	_weapon_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box.add_child(_weapon_box)

	var help := _make_label()
	help.text = "\nW/S thrust   A/D steer   Shift = Hard Burn (hold W/A/S/D to aim it)\nmouse aims   LMB manual weapons   RMB hold on enemy = lock, release = fire\nI refit & inventory   1/2/3 hull   B bot   N dummy   X clear   R reset   F1 tuning   F2 sandbox\n[ ] time scale   \\ reset time   wheel zoom"
	help.modulate = Color(1.0, 1.0, 1.0, 0.65)
	_box.add_child(help)

	_banner = Label.new()
	_banner.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_banner.position = Vector2(-160.0, 120.0)
	_banner.add_theme_font_size_override(&"font_size", 36)
	_banner.add_theme_color_override(&"font_color", Color(1.0, 0.35, 0.3))
	_banner.add_theme_color_override(&"font_outline_color", Color.BLACK)
	_banner.add_theme_constant_override(&"outline_size", 8)
	_banner.visible = false
	add_child(_banner)


func track(ship: Ship) -> void:
	_ship = ship
	if not ship.loadout_changed.is_connected(_rebuild_weapons):
		ship.loadout_changed.connect(_rebuild_weapons)
	# Weapon controllers appear a frame after equip() frees the old ones.
	_rebuild_weapons.call_deferred()


func show_banner(text: String) -> void:
	_banner.text = text
	_banner.visible = text != ""


func _process(_delta: float) -> void:
	if _ship == null or _ship.hull == null:
		return
	var move := _ship.movement
	var stats := _ship.stats
	_info.text = "%s\nspeed  %5.1f / %.0f m/s\nturn   %5.1f / %.0f deg/s\nhard burn  %s%s" % [
		_ship.hull.display_name,
		move.speed(),
		stats.get_stat(Stats.MAX_SPEED),
		move.effective_turn_rate_deg(),
		stats.get_stat(Stats.TURN_RATE),
		"READY" if move.burn_ready_fraction() >= 1.0 else "cooling",
		"" if Engine.time_scale == 1.0 else "\ntime scale x%.2f" % Engine.time_scale,
	]
	_burn_bar.value = move.burn_ready_fraction()

	var health := _ship.health
	_health_label.text = "\nshield %3.0f/%.0f   hull %3.0f/%.0f   armor %.0f%s" % [
		health.shield, health.max_shield(), health.hull, health.max_hull(), health.armor(),
		"   GOD MODE" if health.god_mode else "",
	]
	_shield_bar.value = health.shield_fraction()
	_hull_bar.value = health.hull_fraction()

	for row in _weapon_rows:
		var controller := row.controller as WeaponController
		if not is_instance_valid(controller):
			continue
		(row.bar as ProgressBar).value = controller.ready_fraction()
		(row.label as Label).text = "%s [%s] %s" % [controller.weapon.display_name, MODE_NAMES[controller.weapon.targeting], controller.status_text()]


func _rebuild_weapons() -> void:
	for child in _weapon_box.get_children():
		child.queue_free()
	_weapon_rows.clear()
	if _ship == null:
		return
	for controller in _ship.weapons():
		var label := _make_label()
		var bar := _make_bar(Damage.TYPE_COLORS[controller.weapon.projectile.damage_type], 8.0)
		var spacer := Control.new()
		spacer.custom_minimum_size.y = 2.0
		spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_weapon_box.add_child(label)
		_weapon_box.add_child(bar)
		_weapon_box.add_child(spacer)
		_weapon_rows.append({"controller": controller, "label": label, "bar": bar})


func _make_label() -> Label:
	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_color_override(&"font_outline_color", Color.BLACK)
	label.add_theme_constant_override(&"outline_size", 4)
	return label


func _make_bar(color: Color, height: float) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(240.0, height)
	bar.max_value = 1.0
	bar.show_percentage = false
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN  # Don't stretch to the widest label.
	var fill := StyleBoxFlat.new()
	fill.bg_color = color
	bar.add_theme_stylebox_override(&"fill", fill)
	return bar
