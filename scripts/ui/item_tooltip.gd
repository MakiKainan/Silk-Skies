class_name ItemTooltip
extends RefCounted
## Builds the hover card for an item: name in its rarity colour, what it does, its rolled
## bonuses, and (for crew and techmods) the active it grants.

const WIDTH := 300.0


static func build(item: ItemInstance) -> Control:
	var data := item.data()
	var panel := PanelContainer.new()
	panel.custom_minimum_size.x = WIDTH
	panel.add_theme_stylebox_override(&"panel", ItemVisuals.slot_style(Rarity.color(item.rarity), Color(0.06, 0.07, 0.1), 2))
	var box := VBoxContainer.new()
	panel.add_child(box)

	var rarity_color := Rarity.color(item.rarity)
	box.add_child(_label(data.display_name, rarity_color, 18))
	box.add_child(_label("%s %s%s" % [Rarity.display_name(item.rarity), data.category_name(), _subtitle(data)], Color(1, 1, 1, 0.6), 13))
	box.add_child(HSeparator.new())

	for line in _stat_lines(item):
		box.add_child(_label(line, Color(0.92, 0.92, 0.92), 14))

	if not item.rolls.is_empty():
		box.add_child(_label("Rolled bonuses", Color(1, 1, 1, 0.5), 12))
		for roll in item.rolls:
			box.add_child(_label("* " + StatInfo.format_mod(roll), rarity_color, 14))

	if data.description != "":
		box.add_child(HSeparator.new())
		var description := _label(data.description, Color(1, 1, 1, 0.65), 13)
		description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		description.custom_minimum_size.x = WIDTH - 16.0
		box.add_child(description)

	if data.active_name != "":
		var active := _label("Active: %s" % data.active_name, Color(1.0, 0.85, 0.4), 14)
		box.add_child(active)
		var active_description := _label(data.active_description, Color(1, 1, 1, 0.65), 13)
		active_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		active_description.custom_minimum_size.x = WIDTH - 16.0
		box.add_child(active_description)
	return panel


## The stat lines for an item's definition and rolls (also used by tests).
static func _stat_lines(item: ItemInstance) -> PackedStringArray:
	var data := item.data()
	var lines := PackedStringArray()
	if data is WeaponData:
		var weapon := data as WeaponData
		var stats := WeaponStats.compute(weapon, LoadoutStats.own_mods(item), [])
		lines.append("Damage %s (%s)" % [StatInfo.format_value(Stats.DAMAGE, stats[Stats.DAMAGE]), Damage.Type.keys()[weapon.projectile.damage_type].to_lower()])
		lines.append("Fire rate %s" % StatInfo.format_value(Stats.FIRE_RATE, stats[Stats.FIRE_RATE]))
		lines.append("DPS %.1f" % WeaponStats.dps(weapon, stats))
		lines.append("Range %s" % StatInfo.format_value(Stats.RANGE, stats[Stats.RANGE]))
		if weapon.shots_per_fire > 1:
			lines.append("Salvo of %d" % weapon.shots_per_fire)
		if weapon.projectile.pierce > 0:
			lines.append("Pierces %d ships" % weapon.projectile.pierce)
		if weapon.projectile.blast_radius > 0.0:
			lines.append("Blast radius %.0f m" % weapon.projectile.blast_radius)
		if weapon.projectile.homing_deg_per_sec > 0.0:
			lines.append("Homing")
		if weapon.charge_time > 0.0:
			lines.append("Charge time %.1f s" % weapon.charge_time)
	elif data is FighterBayData:
		var bay := data as FighterBayData
		lines.append("%d x %s" % [bay.fighter_count, bay.fighter_name])
		lines.append("Fighter hull %.0f, damage %.0f" % [bay.fighter_hull, bay.fighter_damage])
		lines.append("Lasts %.0f s, relaunch %.0f s" % [bay.fighter_lifetime, bay.launch_cooldown])
		if bay.role != "":
			lines.append(bay.role)
	if data is CrewData and (data as CrewData).station_text != "":
		lines.append((data as CrewData).station_text)
	for mod in data.base_mods:
		lines.append(StatInfo.format_mod(mod))
	return lines


static func _subtitle(data: ItemData) -> String:
	if data is WeaponData:
		var weapon := data as WeaponData
		var mode: String = ["auto", "manual", "lock-on"][weapon.targeting]
		return " - %s, %s" % ["Large" if weapon.size == HardpointData.Size.LARGE else "Small", mode]
	return ""


static func _label(text: String, color: Color, size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_color_override(&"font_color", color)
	label.add_theme_font_size_override(&"font_size", size)
	return label
