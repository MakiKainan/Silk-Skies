extends GutTest

const TOL := Vector3.ONE * 0.0001


func test_a_full_circle_contains_everything() -> void:
	for dir in [Vector3.FORWARD, Vector3.BACK, Vector3.LEFT, Vector3.RIGHT]:
		assert_true(Arc.contains(0.0, 0.0, 360.0, dir))


func test_forward_arc_contains_the_bow_and_not_the_stern() -> void:
	assert_true(Arc.contains(0.0, 0.0, 120.0, Vector3.FORWARD))
	assert_false(Arc.contains(0.0, 0.0, 120.0, Vector3.BACK))


func test_arc_edges() -> void:
	# 120 degree arc: +-60 off the bow.
	assert_true(Arc.contains(0.0, 0.0, 120.0, Arc.direction_at(0.0, 59.0)))
	assert_false(Arc.contains(0.0, 0.0, 120.0, Arc.direction_at(0.0, 61.0)))
	assert_true(Arc.contains(0.0, 0.0, 120.0, Arc.direction_at(0.0, -59.0)))
	assert_false(Arc.contains(0.0, 0.0, 120.0, Arc.direction_at(0.0, -61.0)))


func test_broadside_arc_points_to_its_side() -> void:
	# 90 degree arc centred on starboard (+90).
	assert_true(Arc.contains(0.0, 90.0, 90.0, Vector3.RIGHT))
	assert_false(Arc.contains(0.0, 90.0, 90.0, Vector3.LEFT))
	assert_false(Arc.contains(0.0, 90.0, 90.0, Vector3.FORWARD), "bow is 90 off a 90-wide arc's centre")
	assert_true(Arc.contains(0.0, -90.0, 90.0, Vector3.LEFT), "port broadside")


func test_arc_wraps_around_astern() -> void:
	# Centred dead astern (180), 60 wide: contains +-30 around the stern on either side of the seam.
	assert_true(Arc.contains(0.0, 180.0, 60.0, Arc.direction_at(0.0, 170.0)))
	assert_true(Arc.contains(0.0, 180.0, 60.0, Arc.direction_at(0.0, -170.0)))
	assert_false(Arc.contains(0.0, 180.0, 60.0, Arc.direction_at(0.0, 140.0)))


func test_arc_turns_with_the_ship() -> void:
	# Ship yawed 90 degrees left: the bow now faces -X, so a forward arc contains -X.
	var yaw := PI / 2.0
	assert_true(Arc.contains(yaw, 0.0, 120.0, Vector3.LEFT))
	assert_false(Arc.contains(yaw, 0.0, 120.0, Vector3.FORWARD))


func test_relative_bearing_signs() -> void:
	assert_almost_eq(Arc.relative_bearing_deg(0.0, Vector3.RIGHT), 90.0, 0.001, "starboard is positive")
	assert_almost_eq(Arc.relative_bearing_deg(0.0, Vector3.LEFT), -90.0, 0.001)
	assert_almost_eq(Arc.relative_bearing_deg(0.0, Vector3.FORWARD), 0.0, 0.001)
	assert_almost_eq(absf(Arc.relative_bearing_deg(0.0, Vector3.BACK)), 180.0, 0.001)


func test_direction_at_round_trips_with_bearing() -> void:
	for bearing in [-150.0, -45.0, 0.0, 30.0, 90.0, 170.0]:
		assert_almost_eq(Arc.relative_bearing_deg(0.7, Arc.direction_at(0.7, bearing)), bearing, 0.001)


func test_clamp_leaves_an_inside_direction_alone() -> void:
	var dir := Arc.direction_at(0.0, 20.0)
	assert_almost_eq(Arc.clamp_direction(0.0, 0.0, 120.0, dir), dir, TOL)


func test_clamp_holds_an_outside_direction_to_the_nearest_edge() -> void:
	var clamped := Arc.clamp_direction(0.0, 0.0, 120.0, Arc.direction_at(0.0, 100.0))
	assert_almost_eq(Arc.relative_bearing_deg(0.0, clamped), 60.0, 0.001)
	clamped = Arc.clamp_direction(0.0, 0.0, 120.0, Arc.direction_at(0.0, -100.0))
	assert_almost_eq(Arc.relative_bearing_deg(0.0, clamped), -60.0, 0.001)
