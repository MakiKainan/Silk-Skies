extends GutTest
## Pure AI steering maths. The bow faces -Z at yaw 0; positive yaw is a left turn; turn input
## +1 is starboard (right).

const ORIGIN := Vector3.ZERO


# --- pursuit_point -----------------------------------------------------------------------

func test_far_away_the_point_sits_on_the_outer_edge_of_the_band() -> void:
	var point := AISteering.pursuit_point(ORIGIN, Vector3(0, 0, 60), 20.0, 5.0, 1.0, 0.0)
	assert_almost_eq(point.distance_to(ORIGIN), 25.0, 0.001, "preferred 20 + band 5")


func test_too_close_the_point_sits_on_the_inner_edge_pushing_the_ship_out() -> void:
	var point := AISteering.pursuit_point(ORIGIN, Vector3(0, 0, 5), 20.0, 5.0, 1.0, 0.0)
	assert_almost_eq(point.distance_to(ORIGIN), 15.0, 0.001)
	assert_gt(point.z, 5.0, "further out than the ship is now, so it backs away")


func test_inside_the_band_it_holds_its_current_distance() -> void:
	var point := AISteering.pursuit_point(ORIGIN, Vector3(0, 0, 21), 20.0, 5.0, 1.0, 0.0)
	assert_almost_eq(point.distance_to(ORIGIN), 21.0, 0.001)


func test_the_lead_angle_moves_the_point_around_the_target() -> void:
	var ahead := AISteering.pursuit_point(ORIGIN, Vector3(0, 0, 20), 20.0, 5.0, 1.0, 40.0)
	var angle := rad_to_deg(Vector3(0, 0, 20).signed_angle_to(ahead, Vector3.UP))
	assert_almost_eq(absf(angle), 40.0, 0.01)


func test_the_orbit_sign_picks_the_circling_direction() -> void:
	var left := AISteering.pursuit_point(ORIGIN, Vector3(0, 0, 20), 20.0, 5.0, 1.0, 40.0)
	var right := AISteering.pursuit_point(ORIGIN, Vector3(0, 0, 20), 20.0, 5.0, -1.0, 40.0)
	assert_almost_eq(left.x, -right.x, 0.001)
	assert_ne(signf(left.x), signf(right.x))


func test_a_ship_on_top_of_its_target_still_gets_a_sane_point() -> void:
	var point := AISteering.pursuit_point(ORIGIN, ORIGIN, 20.0, 5.0, 1.0, 30.0)
	assert_false(is_nan(point.x))
	assert_gt(point.length(), 1.0)


func test_the_point_stays_on_the_play_plane() -> void:
	assert_eq(AISteering.pursuit_point(Vector3(3, 9, 4), Vector3(10, 7, 20), 20.0, 5.0, 1.0, 30.0).y, 0.0)


# --- steer -----------------------------------------------------------------------------------

func test_a_point_dead_ahead_means_full_throttle_and_no_turn() -> void:
	var command := AISteering.steer(ORIGIN, 0.0, Vector3(0, 0, -30), 1.0)
	assert_almost_eq(command.turn, 0.0, 0.001)
	assert_almost_eq(command.throttle, 1.0, 0.001)


func test_a_point_to_starboard_turns_right() -> void:
	var command := AISteering.steer(ORIGIN, 0.0, Vector3(30, 0, 0), 1.0)
	assert_gt(command.turn, 0.0)


func test_a_point_to_port_turns_left() -> void:
	var command := AISteering.steer(ORIGIN, 0.0, Vector3(-30, 0, 0), 1.0)
	assert_lt(command.turn, 0.0)


func test_steering_respects_the_ships_heading() -> void:
	# Facing -X (yaw +90 degrees): a point at -Z is to the right of the bow.
	var command := AISteering.steer(ORIGIN, PI / 2.0, Vector3(0, 0, -30), 1.0)
	assert_gt(command.turn, 0.0)


func test_a_point_behind_means_turn_without_thrust() -> void:
	var command := AISteering.steer(ORIGIN, 0.0, Vector3(0, 0, 30), 1.0)
	assert_eq(command.throttle, 0.0)
	assert_ne(command.turn, 0.0)


func test_a_small_error_gives_a_gentle_turn_and_a_big_one_full_lock() -> void:
	var gentle := AISteering.steer(ORIGIN, 0.0, Vector3(5, 0, -30), 1.0)
	var hard := AISteering.steer(ORIGIN, 0.0, Vector3(30, 0, -10), 1.0)
	assert_lt(absf(gentle.turn), 0.7)
	assert_almost_eq(absf(hard.turn), 1.0, 0.001)


func test_the_throttle_cap_is_honoured() -> void:
	assert_almost_eq(AISteering.steer(ORIGIN, 0.0, Vector3(0, 0, -30), 0.6).throttle, 0.6, 0.001)


func test_arriving_at_the_point_stops_the_ship() -> void:
	var command := AISteering.steer(ORIGIN, 0.0, Vector3(0.1, 0, 0.1), 1.0)
	assert_eq(command.throttle, 0.0)
	assert_eq(command.turn, 0.0)


# --- dodge_direction ---------------------------------------------------------------------------

func test_a_projectile_on_course_gives_a_dodge_away_from_its_line() -> void:
	# Ship at origin, radius 2; projectile 20 m to the south heading north, offset 1 m to port (-X).
	var away := AISteering.dodge_direction(ORIGIN, 2.0, Vector3(-1, 0, 20), Vector3(0, 0, -1), 60.0)
	assert_ne(away, Vector3.ZERO)
	assert_gt(away.x, 0.9, "it passes on the port side, so dodge toward starboard")


func test_a_projectile_that_will_miss_is_ignored() -> void:
	assert_eq(AISteering.dodge_direction(ORIGIN, 2.0, Vector3(10, 0, 20), Vector3(0, 0, -1), 60.0), Vector3.ZERO)


func test_a_projectile_flying_away_is_ignored() -> void:
	assert_eq(AISteering.dodge_direction(ORIGIN, 2.0, Vector3(0, 0, 20), Vector3(0, 0, 1), 60.0), Vector3.ZERO)


func test_a_projectile_too_far_off_is_not_yet_a_threat() -> void:
	assert_eq(AISteering.dodge_direction(ORIGIN, 2.0, Vector3(0, 0, 200), Vector3(0, 0, -1), 60.0), Vector3.ZERO, "more than 0.7 s away")


func test_a_dead_centre_shot_still_gives_a_sideways_dodge() -> void:
	var away := AISteering.dodge_direction(ORIGIN, 2.0, Vector3(0, 0, 20), Vector3(0, 0, -1), 60.0)
	assert_ne(away, Vector3.ZERO)
	assert_almost_eq(away.dot(Vector3(0, 0, -1)), 0.0, 0.001, "perpendicular to the shot")
