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
	assert_eq(ContentDB.hulls().size(), 3)


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


func test_every_hull_has_sane_handling_stats() -> void:
	for hull in ContentDB.hulls():
		var stats := hull.base_stats()
		for stat: StringName in stats:
			assert_gt(float(stats[stat]), 0.0, "%s.%s must be positive" % [hull.id, stat])
