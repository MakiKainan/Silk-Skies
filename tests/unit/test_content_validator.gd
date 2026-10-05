extends GutTest

const FRIGATE_MODEL := preload("res://scenes/ship/models/frigate_model.tscn")


func _hardpoint(marker: StringName) -> HardpointData:
	var hardpoint := HardpointData.new()
	hardpoint.marker_name = marker
	return hardpoint


func _hull(id: StringName, markers: Array[StringName] = [&"Turret_A"]) -> HullData:
	var hull := HullData.new()
	hull.id = id
	hull.model_scene = FRIGATE_MODEL
	for marker in markers:
		hull.hardpoints.append(_hardpoint(marker))
	return hull


func _joined(errors: PackedStringArray) -> String:
	return "\n".join(errors)


func test_a_valid_hull_produces_no_errors() -> void:
	assert_eq(ContentValidator.validate([_hull(&"ok")]).size(), 0)


func test_duplicate_ids_are_reported() -> void:
	var errors := ContentValidator.validate([_hull(&"twin"), _hull(&"twin"), _hull(&"unique")])
	assert_eq(errors.size(), 1)
	assert_string_contains(_joined(errors), "duplicate id 'twin'")


func test_empty_id_is_reported() -> void:
	var errors := ContentValidator.validate([_hull(&"")])
	assert_eq(errors.size(), 1)
	assert_string_contains(_joined(errors), "empty id")


func test_missing_hardpoint_marker_is_reported() -> void:
	var errors := ContentValidator.validate([_hull(&"bad_marker", [&"Turret_A", &"Does_Not_Exist"])])
	assert_eq(errors.size(), 1)
	assert_string_contains(_joined(errors), "marker 'Does_Not_Exist'")


func test_hardpoint_with_no_marker_name_is_reported() -> void:
	var errors := ContentValidator.validate([_hull(&"blank_marker", [&""])])
	assert_eq(errors.size(), 1)


func test_missing_model_scene_is_reported() -> void:
	var hull := _hull(&"no_model")
	hull.model_scene = null
	var errors := ContentValidator.validate([hull])
	assert_eq(errors.size(), 1)
	assert_string_contains(_joined(errors), "model_scene")


func test_every_problem_is_listed_not_just_the_first() -> void:
	var errors := ContentValidator.validate([_hull(&"twin"), _hull(&"twin", [&"Nope"])])
	assert_eq(errors.size(), 2, "one duplicate id plus one missing marker")


func test_resources_without_an_id_are_ignored() -> void:
	assert_eq(ContentValidator.validate([HardpointData.new(), StatMod.new()]).size(), 0)
