class_name ContentValidator
extends RefCounted
## Pure checks over a list of loaded content resources. ContentDB runs this at startup and
## tests inject deliberately broken data into it.
##
## Implemented: empty/duplicate ids, hull model scene + hardpoint markers.
## Added with their content: references to missing ids (enemy loadouts, acts, synergies)
## and items assigned to an incompatible slot type.

static func validate(resources: Array) -> PackedStringArray:
	var errors := PackedStringArray()
	_check_ids(resources, errors)
	for res: Resource in resources:
		if res is HullData:
			_check_hull(res as HullData, errors)
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


static func _where(res: Resource) -> String:
	return res.resource_path if res.resource_path != "" else "<unsaved %s>" % res.get_class()
