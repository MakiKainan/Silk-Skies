class_name ContentValidator
extends RefCounted
## Pure checks over a list of loaded content resources. ContentDB runs this at startup and
## tests inject deliberately broken data into it.
##
## Implemented: empty/duplicate ids, hull model scene + hardpoint markers, weapons,
## projectiles, and item basics (name, roll pool ranges, fighter bays).
## Added with their content: references to missing ids (enemy loadouts, acts, synergies)
## and items assigned to an incompatible slot type.

static func validate(resources: Array) -> PackedStringArray:
	var errors := PackedStringArray()
	_check_ids(resources, errors)
	for res: Resource in resources:
		if res is ItemData:
			_check_item(res as ItemData, errors)
		if res is HullData:
			_check_hull(res as HullData, errors)
		elif res is WeaponData:
			_check_weapon(res as WeaponData, errors)
		elif res is ProjectileData:
			_check_projectile(res as ProjectileData, errors)
	return errors


static func _check_ids(resources: Array, errors: PackedStringArray) -> void:
	var seen: Dictionary = {}  # id -> resource_path of first holder
	for res: Resource in resources:
		var id: Variant = res.get(&"id")
		if id == null:
			continue  # Not an id-bearing content type (e.g. a sub-resource saved on its own).
		var key := StringName(id)
		if key == &"":
			errors.append("%s: empty id" % _where(res))
		elif seen.has(key):
			errors.append("duplicate id '%s' in %s and %s" % [key, seen[key], _where(res)])
		else:
			seen[key] = _where(res)


static func _check_hull(hull: HullData, errors: PackedStringArray) -> void:
	var where := _where(hull)
	if hull.model_scene == null:
		errors.append("%s: hull has no model_scene" % where)
		return
	var model := hull.model_scene.instantiate()
	for hardpoint in hull.hardpoints:
		if hardpoint == null:
			errors.append("%s: null entry in hardpoints" % where)
		elif hardpoint.find_marker(model) == null:
			errors.append("%s: hardpoint marker '%s' not found in the hull model" % [where, hardpoint.marker_name])
	model.free()


static func _check_item(item: ItemData, errors: PackedStringArray) -> void:
	var where := _where(item)
	if item.display_name.strip_edges() == "":
		errors.append("%s: item has no display_name" % where)
	if item.roll_pool != null:
		for template in item.roll_pool.templates:
			if template == null:
				errors.append("%s: null entry in roll pool" % where)
			elif template.min_value > template.max_value:
				errors.append("%s: roll template '%s' has min_value above max_value" % [where, template.stat])
	if item is FighterBayData and (item as FighterBayData).fighter_count < 1:
		errors.append("%s: fighter bay must launch at least 1 fighter" % where)


static func _check_weapon(weapon: WeaponData, errors: PackedStringArray) -> void:
	var where := _where(weapon)
	if weapon.projectile == null:
		errors.append("%s: weapon has no projectile" % where)
	if weapon.cooldown <= 0.0:
		errors.append("%s: cooldown must be positive" % where)
	if weapon.shots_per_fire < 1:
		errors.append("%s: shots_per_fire must be at least 1" % where)
	if weapon.targeting == WeaponData.Targeting.LOCK_ON and weapon.lock_time <= 0.0:
		errors.append("%s: lock-on weapon needs a positive lock_time" % where)
	if weapon.targeting != WeaponData.Targeting.MANUAL and weapon.range <= 0.0:
		errors.append("%s: auto/lock-on weapon needs a positive range" % where)


static func _check_projectile(projectile: ProjectileData, errors: PackedStringArray) -> void:
	var where := _where(projectile)
	if projectile.speed <= 0.0:
		errors.append("%s: projectile speed must be positive" % where)
	if projectile.lifetime <= 0.0:
		errors.append("%s: projectile lifetime must be positive" % where)
	if projectile.damage <= 0.0:
		errors.append("%s: projectile damage must be positive" % where)


static func _where(res: Resource) -> String:
	return res.resource_path if res.resource_path != "" else "<unsaved %s>" % res.get_class()
