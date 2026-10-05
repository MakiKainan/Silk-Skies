class_name StatsPanel
extends VBoxContainer
## The ship's final stats, with each one's change from the bare hull in green (better) or red
## (worse), plus a line per mounted weapon.

## [section title, stats in that section]
const SECTIONS := [
	["DEFENCE", [Stats.MAX_HULL, Stats.MAX_SHIELD, Stats.SHIELD_REGEN, Stats.SHIELD_DELAY, Stats.ARMOR]],
	["MOBILITY", [Stats.MAX_SPEED, Stats.THRUST, Stats.MASS, Stats.TURN_RATE, Stats.BURN_IMPULSE, Stats.BURN_COOLDOWN]],
]
const GOOD := Color(0.4, 0.95, 0.5)
const BAD := Color(1.0, 0.45, 0.4)

var _ship: Ship


func bind(ship: Ship) -> void:
	_ship = ship
	refresh()


func refresh() -> void:
	for child in get_children():
		child.queue_free()
	if _ship == null or _ship.hull == null:
		return
	var base := _ship.hull.base_stats()
	for section: Array in SECTIONS:
		_add_header(section[0])
		for stat: StringName in section[1]:
			_add_row(stat, _ship.stats.get_stat(stat), float(base.get(stat, 0.0)))
	var potency := _ship.stats.get_stat(Stats.TECHMOD_POTENCY)
	if potency > 0.0:
		_add_row(Stats.TECHMOD_POTENCY, potency, 0.0)

	_add_header("WEAPONS")
	var controllers := _ship.weapons()
	if controllers.is_empty():
		_add_text("no weapons mounted", Color(1, 1, 1, 0.4))
	for controller in controllers:
		var rarity_color := Rarity.color(controller.instance.rarity) if controller.instance != null else Color.WHITE
		var stats := controller.stats
		_add_text("%s   DPS %.1f" % [controller.weapon.display_name, WeaponStats.dps(controller.weapon, stats)], rarity_color)
		_add_text("   dmg %s   rate %s   range %s" % [
			StatInfo.format_value(Stats.DAMAGE, stats[Stats.DAMAGE]),
			StatInfo.format_value(Stats.FIRE_RATE, stats[Stats.FIRE_RATE]),
			StatInfo.format_value(Stats.RANGE, stats[Stats.RANGE]),
		], Color(1, 1, 1, 0.6), 12)


func _add_header(text: String) -> void:
	var spacer := Control.new()
	spacer.custom_minimum_size.y = 6.0
	add_child(spacer)
	_add_text(text, Color(1.0, 0.85, 0.4), 13)


func _add_row(stat: StringName, value: float, base_value: float) -> void:
	var row := HBoxContainer.new()
	var name_label := _make_label(StatInfo.label(stat), Color(0.9, 0.9, 0.9), 14)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_label)
	row.add_child(_make_label(StatInfo.format_value(stat, value), Color.WHITE, 14))
	var delta := value - base_value
	var delta_label := _make_label(StatInfo.format_delta(stat, delta), GOOD if (delta > 0.0) == StatInfo.higher_is_better(stat) else BAD, 13)
	delta_label.custom_minimum_size.x = 64.0
	delta_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(delta_label)
	add_child(row)


func _add_text(text: String, color: Color, size: int = 14) -> void:
	add_child(_make_label(text, color, size))


func _make_label(text: String, color: Color, size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_color_override(&"font_color", color)
	label.add_theme_font_size_override(&"font_size", size)
	return label
