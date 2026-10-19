class_name Hud
extends CanvasLayer
## The tracked ship's HUD. Full (sandbox, debug gauntlet): sailing readout, shield/hull/armor, and
## one status line per weapon (mode, cooldown / charge / lock bar). Compact (a real run): only
## the hull name and the shield/hull bars; weapon cooldowns live on the ActionBar instead.

const MODE_NAMES := {
	WeaponData.Targeting.AIMED: "aimed",
	WeaponData.Targeting.LOCK_ON: "lock",
}

## Set before adding the HUD to the tree. Compact drops the controls help, the speed and Hard Burn
## readout and the per-weapon cooldown rows.
var compact: bool = false

var _ship: Ship
var _box: VBoxContainer
var _info: Label
var _burn_bar: Range
var _shield_bar: Range
var _hull_bar: Range
var _health_label: Label
var _weapon_box: VBoxContainer
var _weapon_rows: Array[Dictionary] = []  # {controller, label, bar, heat (or null)}
var _banner: Label
## Flashes while an enemy is locking missiles onto the tracked ship.
var lock_warning: Label
var _help: Label


func _ready() -> void:
	_box = VBoxContainer.new()
	_box.position = Vector2(16.0, 16.0)
	_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_box)

	_info = _make_label()
	_box.add_child(_info)
	if not compact:
		_burn_bar = _make_bar(Color(0.9, 0.8, 0.3), 14.0)
		_box.add_child(_bar_row(UiArt.status_icon("burn"), Color(0.9, 0.8, 0.3), _burn_bar))

	_health_label = _make_label()
	_box.add_child(_health_label)
	_shield_bar = _make_bar(Color(0.3, 0.65, 1.0), 18.0)
	_box.add_child(_bar_row(UiArt.status_icon("shield"), Color(0.3, 0.65, 1.0), _shield_bar))
	_hull_bar = _make_bar(Color(0.9, 0.25, 0.25), 18.0)
	_box.add_child(_bar_row(UiArt.status_icon("hull"), Color(0.9, 0.25, 0.25), _hull_bar))

	_weapon_box = VBoxContainer.new()
	_weapon_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box.add_child(_weapon_box)

	_help = _make_label()
	_help.text = "\nW/S thrust   A/D steer   Shift = Hard Burn (hold W/A/S/D to aim it)\nmouse aims   LMB / RMB fire their weapon groups   RMB on enemy = missile lock, release = fire\nQ/E/R fighters   I refit (right-click a weapon: switch button)   1/2/3 hull   B bot   N dummy   X clear\nR revive (when dead)   F1 tuning   F2 sandbox   [ ] time scale   \\ reset time   wheel zoom"
	_help.modulate = Color(1.0, 1.0, 1.0, 0.65)
	_help.visible = not compact
	_box.add_child(_help)

	_banner = Label.new()
	_banner.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_banner.position = Vector2(-160.0, 120.0)
	_banner.add_theme_font_size_override(&"font_size", 36)
	_banner.add_theme_color_override(&"font_color", Color(1.0, 0.35, 0.3))
	_banner.add_theme_color_override(&"font_outline_color", Color.BLACK)
	_banner.add_theme_constant_override(&"outline_size", 8)
	_banner.visible = false
	add_child(_banner)

	lock_warning = Label.new()
	lock_warning.text = "MISSILE LOCK"
	lock_warning.set_anchors_preset(Control.PRESET_CENTER_TOP)
	lock_warning.position = Vector2(-110.0, 64.0)
	lock_warning.add_theme_font_size_override(&"font_size", 28)
	lock_warning.add_theme_color_override(&"font_color", Color(1.0, 0.25, 0.2))
	lock_warning.add_theme_color_override(&"font_outline_color", Color.BLACK)
	lock_warning.add_theme_constant_override(&"outline_size", 8)
	lock_warning.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lock_warning.visible = false
	add_child(lock_warning)


func track(ship: Ship) -> void:
	_ship = ship
	if not ship.loadout_changed.is_connected(_rebuild_weapons):
		ship.loadout_changed.connect(_rebuild_weapons)
	# Weapon controllers appear a frame after equip() frees the old ones.
	_rebuild_weapons.call_deferred()


## True while any enemy weapon is building a lock on [param ship].
static func is_being_locked(ship: Ship) -> bool:
	for enemy in ship.enemies():
		for controller in enemy.weapons():
			if controller.lock_target == ship:
				return true
	return false


## Replaces the key-help text under the bars.
func set_help(text: String) -> void:
	_help.text = text


func show_banner(text: String) -> void:
	_banner.text = text
	_banner.visible = text != ""


func _process(_delta: float) -> void:
	if _ship == null or _ship.hull == null:
		return
	var locked_on := is_being_locked(_ship)
	lock_warning.visible = locked_on
	if locked_on:
		lock_warning.modulate.a = 0.55 + 0.45 * absf(sin(Time.get_ticks_msec() * 0.012))
	if compact:
		_info.text = _ship.hull.display_name
	else:
		var move := _ship.movement
		_info.text = "%s\nspeed  %5.1f / %.0f m/s\nturn   %5.1f / %.0f deg/s\nhard burn  %s%s" % [
			_ship.hull.display_name,
			move.speed(),
			_ship.stats.get_stat(Stats.MAX_SPEED),
			move.effective_turn_rate_deg(),
			_ship.stats.get_stat(Stats.TURN_RATE),
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
		(row.bar as Range).value = controller.ready_fraction()
		if row.heat != null:
			(row.heat as Range).value = controller.heat_fraction()
		(row.label as Label).text = "%s [%s %s] %s" % [controller.weapon.full_name(), MODE_NAMES[controller.weapon.targeting], WeaponData.group_key(controller.fire_group()), controller.status_text()]


func _rebuild_weapons() -> void:
	for child in _weapon_box.get_children():
		child.queue_free()
	_weapon_rows.clear()
	if _ship == null or compact:
		return
	for controller in _ship.weapons():
		var label := _make_label()
		var type := controller.weapon.projectile.damage_type
		var bar := _make_bar(Damage.TYPE_COLORS[type], 12.0)
		var spacer := Control.new()
		spacer.custom_minimum_size.y = 2.0
		spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_weapon_box.add_child(label)
		_weapon_box.add_child(_bar_row(UiArt.damage_icon(type), Damage.TYPE_COLORS[type], bar))
		var heat_bar: Range = null
		if controller.weapon.heat_per_shot > 0.0:
			heat_bar = _make_bar(HardpointMount.HEAT_COLOR, 5.0)
			_weapon_box.add_child(heat_bar)
		_weapon_box.add_child(spacer)
		_weapon_rows.append({"controller": controller, "label": label, "bar": bar, "heat": heat_bar})


func _make_label() -> Label:
	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_color_override(&"font_outline_color", Color.BLACK)
	label.add_theme_constant_override(&"outline_size", 4)
	return label


## A bar made from the HUD bar art (or a flat ProgressBar when there is none), 240 px wide.
func _make_bar(color: Color, height: float) -> Range:
	var bar := UiArt.make_bar(color, Vector2(240.0, height))
	bar.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN  # Don't stretch to the widest label.
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return bar


## [param bar] with a small tinted icon on its left. Without the icon art it is just the bar.
func _bar_row(icon: Texture2D, tint: Color, bar: Range) -> Control:
	var picture := UiArt.icon_rect(icon, bar.custom_minimum_size.y + 8.0, tint)
	if picture == null:
		return bar
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override(&"separation", 6)
	row.add_child(picture)
	row.add_child(bar)
	return row
