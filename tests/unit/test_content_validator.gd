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


func _scene_of(root: Node) -> PackedScene:
	var scene := PackedScene.new()
	scene.pack(root)
	root.free()
	return scene


func _weapon(id: StringName) -> WeaponData:
	var weapon := WeaponData.new()
	weapon.id = id
	weapon.display_name = "Test"
	weapon.projectile = ProjectileData.new()
	weapon.projectile.id = &"test_shot"
	return weapon


func test_weapon_without_art_is_valid() -> void:
	assert_eq(ContentValidator.validate([_weapon(&"plain")]).size(), 0)


func test_barrel_scene_with_a_3d_root_is_valid() -> void:
	var weapon := _weapon(&"good_barrel")
	weapon.barrel_scene = _scene_of(Node3D.new())
	assert_eq(ContentValidator.validate([weapon]).size(), 0)


func test_barrel_scene_with_a_2d_root_is_reported() -> void:
	var weapon := _weapon(&"bad_barrel")
	weapon.barrel_scene = _scene_of(Control.new())
	assert_string_contains(_joined(ContentValidator.validate([weapon])), "Node3D root")


func test_art_outside_the_assets_folder_is_reported() -> void:
	var weapon := _weapon(&"stray")
	weapon.barrel_scene = FRIGATE_MODEL  # Lives in scenes/, not assets/.
	assert_string_contains(_joined(ContentValidator.validate([weapon])), "outside res://assets/")


func test_non_square_icon_is_reported() -> void:
	var item := ItemData.new()
	item.id = &"wide_icon"
	item.display_name = "Wide"
	item.icon = ImageTexture.create_from_image(Image.create(128, 64, false, Image.FORMAT_RGBA8))
	assert_string_contains(_joined(ContentValidator.validate([item])), "must be square")


func test_tiny_icon_is_reported() -> void:
	var item := ItemData.new()
	item.id = &"tiny_icon"
	item.display_name = "Tiny"
	item.icon = ImageTexture.create_from_image(Image.create(16, 16, false, Image.FORMAT_RGBA8))
	assert_string_contains(_joined(ContentValidator.validate([item])), "between 64 and 512")


func test_good_icon_is_valid() -> void:
	var item := ItemData.new()
	item.id = &"good_icon"
	item.display_name = "Good"
	item.icon = ImageTexture.create_from_image(Image.create(128, 128, false, Image.FORMAT_RGBA8))
	assert_eq(ContentValidator.validate([item]).size(), 0)


func test_resources_without_an_id_are_ignored() -> void:
	assert_eq(ContentValidator.validate([HardpointData.new(), StatMod.new()]).size(), 0)
