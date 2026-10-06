class_name ContentValidator
extends RefCounted
## Pure checks over a list of loaded content resources. ContentDB runs this at startup and
## tests inject deliberately broken data into it.
##
## Implemented: empty/duplicate ids, hull model scene + hardpoint markers, weapons,
## projectiles, and item basics (name, roll pool ranges, fighter bays).
## Enemies: hull + AI present, loadout slots exist and items fit them, phase thresholds fall.
## Acts: no empty or null encounters. Added later: synergies.

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
		elif res is AIProfile:
			_check_ai_profile(res as AIProfile, errors)
		elif res is EnemyData:
			_check_enemy(res as EnemyData, errors)
		elif res is ActData:
			_check_act(res as ActData, errors)
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


static func _check_ai_profile(profile: AIProfile, errors: PackedStringArray) -> void:
	var where := _where(profile)
	if profile.preferred_range <= 0.0:
		errors.append("%s: preferred_range must be positive" % where)
	if profile.range_band < 0.0 or profile.range_band >= profile.preferred_range:
		errors.append("%s: range_band must be between 0 and preferred_range" % where)
	if profile.orbit_flip_min <= 0.0 or profile.orbit_flip_max < profile.orbit_flip_min:
		errors.append("%s: orbit flip times must be positive with max >= min" % where)
	if profile.reaction_time <= 0.0:
		errors.append("%s: reaction_time must be positive" % where)


## An enemy needs a hull and AI, and every item it carries must name a real hardpoint it fits.
static func _check_enemy(enemy: EnemyData, errors: PackedStringArray) -> void:
	var where := _where(enemy)
	if enemy.hull == null:
		errors.append("%s: enemy has no hull" % where)
		return
	if enemy.ai_profile == null:
		errors.append("%s: enemy has no ai_profile" % where)
	var seen := {}
	for spec in enemy.loadout:
		_check_item_spec(spec, enemy.hull, where, errors)
		if spec != null:
			if seen.has(spec.slot):
				errors.append("%s: two loadout items on '%s'" % [where, spec.slot])
			seen[spec.slot] = true
	var last_threshold := 1.0
	for phase in enemy.phases:
		if phase == null:
			errors.append("%s: null entry in phases" % where)
			continue
		if phase.hull_threshold >= last_threshold:
			errors.append("%s: phases must have strictly falling hull_threshold" % where)
		last_threshold = phase.hull_threshold
		for spec in phase.added_items:
			_check_item_spec(spec, enemy.hull, "%s (phase at %.0f%%)" % [where, phase.hull_threshold * 100.0], errors)
	if enemy.is_boss and enemy.phases.is_empty():
		errors.append("%s: a boss should have at least one phase" % where)


static func _check_item_spec(spec: ItemSpec, hull: HullData, where: String, errors: PackedStringArray) -> void:
	if spec == null or spec.item == null:
		errors.append("%s: loadout entry with no item" % where)
		return
	var hardpoint: HardpointData
	for candidate in hull.hardpoints:
		if candidate != null and candidate.marker_name == spec.slot:
			hardpoint = candidate
	if hardpoint == null:
		errors.append("%s: loadout slot '%s' is not a hardpoint on hull '%s'" % [where, spec.slot, hull.id])
	elif not Loadout.can_equip(hardpoint, spec.item):
		errors.append("%s: %s does not fit hardpoint '%s'" % [where, spec.item.id, spec.slot])


static func _check_act(act: ActData, errors: PackedStringArray) -> void:
	var where := _where(act)
	if act.encounters.is_empty():
		errors.append("%s: act has no encounters" % where)
	for encounter in act.encounters:
		if encounter == null:
			errors.append("%s: null encounter" % where)


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
