extends GutTest
## Checks the real authored content under res://data, not synthetic data.


func test_all_authored_content_validates_clean() -> void:
	var resources := ContentLoader.load_all("res://data")
	assert_gt(resources.size(), 0, "found content under res://data")
	var errors := ContentValidator.validate(resources)
	assert_eq(errors.size(), 0, "content errors:\n%s" % "\n".join(errors))


func test_content_db_autoload_indexes_the_hulls() -> void:
	assert_eq(ContentDB.validation_errors.size(), 0, "\n".join(ContentDB.validation_errors))
	var frigate := ContentDB.get_hull(&"starter_frigate")
	assert_not_null(frigate)
	assert_not_null(ContentDB.get_hull(&"debug_skiff"))
	assert_not_null(ContentDB.get_hull(&"debug_barge"))
	assert_null(ContentDB.get_hull(&"no_such_hull"))
	assert_not_null(ContentDB.get_hull(&"debug_dummy"))
	assert_eq(ContentDB.hulls().size(), 7, "3 player hulls, the dummy, and 3 enemy hulls")
	var playable := ContentDB.hulls().filter(func(h: HullData) -> bool: return h.player_selectable)
	assert_eq(playable.size(), 3, "the player can pick the frigate, skiff and barge")


func test_starter_frigate_matches_the_spec_loadout() -> void:
	var frigate := ContentDB.get_hull(&"starter_frigate")
	var turrets: Array[HardpointData] = []
	var counts := {}
	for hardpoint in frigate.hardpoints:
		counts[hardpoint.type] = int(counts.get(hardpoint.type, 0)) + 1
		if hardpoint.type == HardpointData.Type.TURRET:
			turrets.append(hardpoint)
	assert_eq(counts[HardpointData.Type.TURRET], 2)
	assert_eq(counts[HardpointData.Type.FIGHTER_BAY], 1)
	assert_eq(counts[HardpointData.Type.TECHMOD], 1)
	assert_eq(counts[HardpointData.Type.CREW_SEAT], 1)
	var small := turrets.filter(func(t: HardpointData) -> bool: return t.size == HardpointData.Size.SMALL)[0] as HardpointData
	var large := turrets.filter(func(t: HardpointData) -> bool: return t.size == HardpointData.Size.LARGE)[0] as HardpointData
	assert_eq(small.arc_deg, 360.0, "Small turret is all-round")
	assert_eq(large.arc_deg, 120.0, "Large turret is a 120 degree forward arc")
	assert_eq(large.arc_center_deg, 0.0)


func test_every_hull_has_sane_stats() -> void:
	for hull in ContentDB.hulls():
		var stats := hull.base_stats()
		for stat: StringName in stats:
			if stat == Stats.ARMOR:
				assert_gte(float(stats[stat]), 0.0, "%s.armor may be zero but not negative" % hull.id)
			else:
				assert_gt(float(stats[stat]), 0.0, "%s.%s must be positive" % [hull.id, stat])


func test_the_four_slice_weapons_exist_with_the_spec_modes_and_types() -> void:
	var expected := {
		&"pulse_laser": [WeaponData.Targeting.AUTO, Damage.Type.ENERGY, HardpointData.Size.SMALL],
		&"autocannon": [WeaponData.Targeting.AUTO, Damage.Type.KINETIC, HardpointData.Size.SMALL],
		&"railgun": [WeaponData.Targeting.MANUAL, Damage.Type.KINETIC, HardpointData.Size.LARGE],
		&"missile_pod": [WeaponData.Targeting.LOCK_ON, Damage.Type.EXPLOSIVE, HardpointData.Size.LARGE],
	}
	for id: StringName in expected:
		var weapon := ContentDB.get_by_id(id) as WeaponData
		assert_not_null(weapon, "weapon %s exists" % id)
		if weapon == null:
			continue
		assert_eq(weapon.targeting, expected[id][0], "%s targeting" % id)
		assert_eq(weapon.projectile.damage_type, expected[id][1], "%s damage type" % id)
		assert_eq(weapon.size, expected[id][2], "%s size" % id)
	assert_gt((ContentDB.get_by_id(&"railgun") as WeaponData).projectile.pierce, 0, "railgun pierces")
	assert_gt((ContentDB.get_by_id(&"missile_pod") as WeaponData).projectile.homing_deg_per_sec, 0.0, "missiles home")


func test_every_item_kind_is_authored_as_data() -> void:
	var counts := {}
	for item in ContentDB.items():
		counts[item.slot_type()] = int(counts.get(item.slot_type(), 0)) + 1
		assert_ne(item.display_name, "", "%s needs a name" % item.id)
		assert_not_null(item.roll_pool, "%s should be able to roll stat lines" % item.id)
	assert_eq(counts[HardpointData.Type.TURRET], 4, "the four slice turrets")
	assert_eq(counts[HardpointData.Type.TECHMOD], 3)
	assert_eq(counts[HardpointData.Type.FIGHTER_BAY], 2, "interceptor and strike bays")
	assert_eq(counts[HardpointData.Type.CREW_SEAT], 2, "gunner and engineer")


func test_slice_modules_match_the_spec() -> void:
	var capacitor := ContentDB.get_by_id(&"shield_capacitor") as TechmodData
	assert_not_null(capacitor)
	var stats := StatAggregator.aggregate({}, capacitor.base_mods)
	assert_gt(stats[Stats.MAX_SHIELD], 0.0, "adds shield capacity")
	assert_gt(stats[Stats.SHIELD_REGEN], 0.0, "and regeneration")
	assert_eq((ContentDB.get_by_id(&"emp_emitter") as TechmodData).active_name, "EMP Pulse")
	assert_eq((ContentDB.get_by_id(&"gunner") as CrewData).active_name, "Overcharge")
	assert_eq((ContentDB.get_by_id(&"engineer") as CrewData).active_name, "Emergency Repair")
	assert_true((ContentDB.get_by_id(&"interceptor_bay") as FighterBayData).role.contains("missiles"))
	assert_true((ContentDB.get_by_id(&"strike_bay") as FighterBayData).role.contains("hull"))


func test_items_are_never_edited_by_rolling_or_equipping() -> void:
	var capacitor := ContentDB.get_by_id(&"shield_capacitor") as TechmodData
	var mods_before := capacitor.base_mods.size()
	var value_before: float = capacitor.base_mods[0].value
	var ship := (preload("res://scenes/ship/ship.tscn").instantiate()) as Ship
	add_child_autofree(ship)
	ship.setup(ContentDB.get_hull(&"starter_frigate"))
	ship.equip_item(3, ItemInstance.make(capacitor, Rarity.Type.EPIC))
	assert_eq(capacitor.base_mods.size(), mods_before)
	assert_eq(capacitor.base_mods[0].value, value_before)
