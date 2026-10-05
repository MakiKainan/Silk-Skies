extends GutTest


func _hardpoint(type: HardpointData.Type, size: HardpointData.Size) -> HardpointData:
	var hp := HardpointData.new()
	hp.type = type
	hp.size = size
	return hp


func _weapon(size: HardpointData.Size) -> WeaponData:
	var weapon := WeaponData.new()
	weapon.size = size
	weapon.projectile = ProjectileData.new()
	return weapon


func test_small_weapon_fits_small_and_large_turrets() -> void:
	var weapon := _weapon(HardpointData.Size.SMALL)
	assert_true(Loadout.can_equip(_hardpoint(HardpointData.Type.TURRET, HardpointData.Size.SMALL), weapon))
	assert_true(Loadout.can_equip(_hardpoint(HardpointData.Type.TURRET, HardpointData.Size.LARGE), weapon))


func test_large_weapon_needs_a_large_turret() -> void:
	var weapon := _weapon(HardpointData.Size.LARGE)
	assert_false(Loadout.can_equip(_hardpoint(HardpointData.Type.TURRET, HardpointData.Size.SMALL), weapon))
	assert_true(Loadout.can_equip(_hardpoint(HardpointData.Type.TURRET, HardpointData.Size.LARGE), weapon))


func test_weapons_only_fit_turrets() -> void:
	var weapon := _weapon(HardpointData.Size.SMALL)
	for type in [HardpointData.Type.FIGHTER_BAY, HardpointData.Type.TECHMOD, HardpointData.Type.CREW_SEAT]:
		assert_false(Loadout.can_equip(_hardpoint(type, HardpointData.Size.LARGE), weapon))


func test_null_inputs_never_fit() -> void:
	assert_false(Loadout.can_equip(null, _weapon(HardpointData.Size.SMALL)))
	assert_false(Loadout.can_equip(_hardpoint(HardpointData.Type.TURRET, HardpointData.Size.SMALL), null))


# --- ContentValidator: weapons and projectiles -----------------------------------------

func _joined(errors: PackedStringArray) -> String:
	return "\n".join(errors)


func _good_projectile(id: StringName) -> ProjectileData:
	var projectile := ProjectileData.new()
	projectile.id = id
	return projectile


func _good_weapon(id: StringName) -> WeaponData:
	var weapon := WeaponData.new()
	weapon.id = id
	weapon.display_name = String(id).capitalize()
	weapon.projectile = _good_projectile(StringName("%s_shot" % id))
	return weapon


func test_valid_weapon_and_projectile_produce_no_errors() -> void:
	var weapon := _good_weapon(&"gun")
	assert_eq(ContentValidator.validate([weapon, weapon.projectile]).size(), 0)


func test_weapon_without_a_projectile_is_reported() -> void:
	var weapon := _good_weapon(&"gun")
	weapon.projectile = null
	assert_string_contains(_joined(ContentValidator.validate([weapon])), "no projectile")


func test_weapon_with_non_positive_cooldown_is_reported() -> void:
	var weapon := _good_weapon(&"gun")
	weapon.cooldown = 0.0
	assert_string_contains(_joined(ContentValidator.validate([weapon])), "cooldown")


func test_lock_on_weapon_needs_a_lock_time() -> void:
	var weapon := _good_weapon(&"pod")
	weapon.targeting = WeaponData.Targeting.LOCK_ON
	weapon.lock_time = 0.0
	assert_string_contains(_joined(ContentValidator.validate([weapon])), "lock_time")


func test_auto_weapon_needs_a_range() -> void:
	var weapon := _good_weapon(&"gun")
	weapon.range = 0.0
	assert_string_contains(_joined(ContentValidator.validate([weapon])), "range")


func test_projectile_with_bad_numbers_is_reported() -> void:
	var projectile := _good_projectile(&"bad")
	projectile.speed = 0.0
	projectile.lifetime = -1.0
	projectile.damage = 0.0
	assert_eq(ContentValidator.validate([projectile]).size(), 3)


func test_weapon_and_projectile_ids_share_the_duplicate_check() -> void:
	var a := _good_weapon(&"same")
	var b := _good_weapon(&"same")
	assert_string_contains(_joined(ContentValidator.validate([a, b])), "duplicate id 'same'")


# --- ContentValidator: items --------------------------------------------------------------

func test_an_item_without_a_name_is_reported() -> void:
	var weapon := _good_weapon(&"gun")
	weapon.display_name = ""
	assert_string_contains(_joined(ContentValidator.validate([weapon, weapon.projectile])), "display_name")


func test_a_roll_template_with_min_above_max_is_reported() -> void:
	var template := RollTemplate.new()
	template.stat = Stats.DAMAGE
	template.min_value = 0.5
	template.max_value = 0.1
	var pool := RollPool.new()
	pool.templates = [template]
	var weapon := _good_weapon(&"gun")
	weapon.roll_pool = pool
	assert_string_contains(_joined(ContentValidator.validate([weapon, weapon.projectile])), "min_value above max_value")


func test_a_fighter_bay_must_launch_something() -> void:
	var bay := FighterBayData.new()
	bay.id = &"empty_bay"
	bay.display_name = "Empty Bay"
	bay.fighter_count = 0
	assert_string_contains(_joined(ContentValidator.validate([bay])), "at least 1 fighter")


func test_techmods_crew_and_bays_go_in_their_own_slots_only() -> void:
	var techmod := TechmodData.new()
	var crew := CrewData.new()
	var bay := FighterBayData.new()
	var large_turret := _hardpoint(HardpointData.Type.TURRET, HardpointData.Size.LARGE)
	assert_false(Loadout.can_equip(large_turret, techmod))
	assert_false(Loadout.can_equip(large_turret, crew))
	assert_false(Loadout.can_equip(large_turret, bay))
	assert_true(Loadout.can_equip(_hardpoint(HardpointData.Type.TECHMOD, HardpointData.Size.SMALL), techmod))
	assert_true(Loadout.can_equip(_hardpoint(HardpointData.Type.CREW_SEAT, HardpointData.Size.SMALL), crew))
	assert_true(Loadout.can_equip(_hardpoint(HardpointData.Type.FIGHTER_BAY, HardpointData.Size.SMALL), bay))
