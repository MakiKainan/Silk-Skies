extends GutTest

const DT := 1.0 / 60.0


func _stats(overrides: Dictionary = {}) -> Dictionary:
	var stats := {
		Stats.MASS: 100.0,
		Stats.THRUST: 900.0,
		Stats.MAX_SPEED: 18.0,
		Stats.TURN_RATE: 120.0,
		Stats.DRAG: 0.35,
		Stats.LATERAL_GRIP: 2.0,
		Stats.BURN_IMPULSE: 22.0,
		Stats.BURN_COOLDOWN: 3.0,
	}
	stats.merge(overrides, true)
	return stats


func _run(model: SailingModel, seconds: float, throttle: float, turn: float, stats: Dictionary) -> void:
	for i in roundi(seconds / DT):
		model.step(throttle, turn, stats, DT)


# --- Turn rate falls with speed (spec 2.1: 40% at full speed) ---------------------------

func test_turn_rate_is_full_at_standstill() -> void:
	assert_almost_eq(SailingModel.turn_rate_at_speed(120.0, 0.0, 18.0), 120.0, 0.001)


func test_turn_rate_is_40_percent_at_full_speed() -> void:
	assert_almost_eq(SailingModel.turn_rate_at_speed(120.0, 18.0, 18.0), 48.0, 0.001)


func test_turn_rate_falls_linearly_between() -> void:
	assert_almost_eq(SailingModel.turn_rate_at_speed(120.0, 9.0, 18.0), 84.0, 0.001)


func test_turn_rate_stops_falling_above_max_speed() -> void:
	assert_almost_eq(SailingModel.turn_rate_at_speed(120.0, 40.0, 18.0), 48.0, 0.001)


func test_model_reports_effective_turn_rate_from_its_speed() -> void:
	var model := SailingModel.new()
	assert_almost_eq(model.effective_turn_rate_deg(_stats()), 120.0, 0.001)
	model.velocity = Vector3(0.0, 0.0, -18.0)
	assert_almost_eq(model.effective_turn_rate_deg(_stats()), 48.0, 0.001)


# --- Heading ----------------------------------------------------------------------------

func test_bow_points_down_negative_z_at_yaw_zero() -> void:
	assert_almost_eq(SailingModel.forward_of(0.0), Vector3(0, 0, -1), Vector3.ONE * 0.0001)


func test_positive_yaw_turns_the_bow_toward_negative_x() -> void:
	assert_almost_eq(SailingModel.forward_of(PI / 2.0), Vector3(-1, 0, 0), Vector3.ONE * 0.0001)


func test_steering_starboard_turns_right() -> void:
	var model := SailingModel.new()
	_run(model, 1.0, 0.0, 1.0, _stats())
	# Right turn = clockwise from above = negative yaw. ~108 degrees after 1s (it eases in).
	assert_lt(model.yaw, -1.5)
	assert_gt(model.yaw, -2.1)


func test_steering_port_turns_left() -> void:
	var model := SailingModel.new()
	_run(model, 1.0, 0.0, -1.0, _stats())
	assert_gt(model.yaw, 1.5)


func test_rotation_eases_in_rather_than_snapping() -> void:
	var model := SailingModel.new()
	model.step(0.0, 1.0, _stats(), DT)
	assert_lt(absf(model.angular_velocity), deg_to_rad(120.0) * 0.5, "one tick must not reach full turn rate")


# --- Thrust, drag, speed cap ------------------------------------------------------------

func test_full_throttle_approaches_but_never_exceeds_max_speed() -> void:
	var model := SailingModel.new()
	_run(model, 30.0, 1.0, 0.0, _stats())
	assert_gt(model.speed(), 17.5)
	assert_lte(model.speed(), 18.0001)


func test_full_throttle_accelerates_along_the_bow() -> void:
	var model := SailingModel.new()
	_run(model, 1.0, 1.0, 0.0, _stats())
	assert_lt(model.velocity.z, -1.0, "moving toward -Z")
	assert_almost_eq(model.velocity.x, 0.0, 0.0001)


func test_heavier_hull_accelerates_slower() -> void:
	var light := SailingModel.new()
	var heavy := SailingModel.new()
	_run(light, 1.0, 1.0, 0.0, _stats({Stats.MASS: 50.0}))
	_run(heavy, 1.0, 1.0, 0.0, _stats({Stats.MASS: 200.0}))
	assert_gt(light.speed(), heavy.speed() * 2.0)


func test_coasting_decays_by_drag() -> void:
	var model := SailingModel.new()
	model.velocity = Vector3(0.0, 0.0, -18.0)
	_run(model, 5.0, 0.0, 0.0, _stats())
	assert_almost_eq(model.speed(), 18.0 * exp(-0.35 * 5.0), 0.2)


func test_reverse_is_slower_than_forward() -> void:
	var model := SailingModel.new()
	_run(model, 30.0, -1.0, 0.0, _stats())
	var back_speed := -model.velocity.dot(SailingModel.forward_of(model.yaw))
	assert_gt(back_speed, 6.5)
	assert_lte(back_speed, 18.0 * SailingModel.REVERSE_FACTOR + 0.0001)


func test_thrust_never_brakes_an_overspeed_ship() -> void:
	var model := SailingModel.new()
	model.velocity = Vector3(0.0, 0.0, -30.0)
	model.step(1.0, 0.0, _stats({Stats.DRAG: 0.0}), DT)
	# Throttle on, no drag: the only thing that may slow it is the overspeed bleed, never thrust.
	assert_gt(model.speed(), 29.0)


# --- Lateral grip (sailing slide) -------------------------------------------------------

func test_high_grip_kills_sideways_drift() -> void:
	var model := SailingModel.new()
	model.velocity = Vector3(10.0, 0.0, 0.0)  # Sideways: the bow points down -Z.
	_run(model, 3.0, 0.0, 0.0, _stats({Stats.LATERAL_GRIP: 2.0}))
	assert_lt(model.speed(), 0.1)


func test_zero_grip_lets_the_ship_slide() -> void:
	var model := SailingModel.new()
	model.velocity = Vector3(10.0, 0.0, 0.0)
	_run(model, 1.0, 0.0, 0.0, _stats({Stats.LATERAL_GRIP: 0.0}))
	assert_gt(model.speed(), 6.5, "only drag slows a ship with no grip")


func test_grip_leaves_forward_motion_alone() -> void:
	var with_grip := SailingModel.new()
	var no_grip := SailingModel.new()
	with_grip.velocity = Vector3(0.0, 0.0, -10.0)
	no_grip.velocity = Vector3(0.0, 0.0, -10.0)
	_run(with_grip, 1.0, 0.0, 0.0, _stats({Stats.LATERAL_GRIP: 10.0}))
	_run(no_grip, 1.0, 0.0, 0.0, _stats({Stats.LATERAL_GRIP: 0.0}))
	assert_almost_eq(with_grip.speed(), no_grip.speed(), 0.0001)


# --- Hard Burn --------------------------------------------------------------------------

func test_burn_with_no_direction_goes_forward() -> void:
	assert_almost_eq(SailingModel.burn_velocity(0.0, Vector2.ZERO, 10.0), Vector3(0, 0, -10), Vector3.ONE * 0.0001)


func test_burn_directions_follow_the_held_keys() -> void:
	var tol := Vector3.ONE * 0.0001
	assert_almost_eq(SailingModel.burn_velocity(0.0, Vector2(0, 1), 10.0), Vector3(0, 0, -10), tol, "W: ahead")
	assert_almost_eq(SailingModel.burn_velocity(0.0, Vector2(0, -1), 10.0), Vector3(0, 0, 10), tol, "S: astern")
	assert_almost_eq(SailingModel.burn_velocity(0.0, Vector2(1, 0), 10.0), Vector3(10, 0, 0), tol, "D: starboard")
	assert_almost_eq(SailingModel.burn_velocity(0.0, Vector2(-1, 0), 10.0), Vector3(-10, 0, 0), tol, "A: port")


func test_burn_diagonal_keeps_the_same_impulse() -> void:
	assert_almost_eq(SailingModel.burn_velocity(0.0, Vector2(1, 1), 10.0).length(), 10.0, 0.0001)


func test_burn_direction_is_relative_to_the_ship() -> void:
	# Facing -X (yaw +90 degrees), "ahead" is -X and starboard is -Z.
	var tol := Vector3.ONE * 0.0001
	assert_almost_eq(SailingModel.burn_velocity(PI / 2.0, Vector2(0, 1), 10.0), Vector3(-10, 0, 0), tol)
	assert_almost_eq(SailingModel.burn_velocity(PI / 2.0, Vector2(1, 0), 10.0), Vector3(0, 0, -10), tol)


func test_burn_adds_the_impulse_then_goes_on_cooldown() -> void:
	var model := SailingModel.new()
	var stats := _stats()
	assert_true(model.try_burn(Vector2.ZERO, stats))
	assert_almost_eq(model.velocity, Vector3(0, 0, -22), Vector3.ONE * 0.0001)
	assert_false(model.try_burn(Vector2.ZERO, stats), "still cooling down")
	assert_almost_eq(model.velocity, Vector3(0, 0, -22), Vector3.ONE * 0.0001, "refused burn adds nothing")


func test_burn_is_ready_again_after_its_cooldown() -> void:
	var model := SailingModel.new()
	var stats := _stats()
	model.try_burn(Vector2.ZERO, stats)
	assert_almost_eq(model.burn_ready_fraction(stats), 0.0, 0.001)
	_run(model, 1.5, 0.0, 0.0, stats)
	assert_almost_eq(model.burn_ready_fraction(stats), 0.5, 0.02)
	_run(model, 1.6, 0.0, 0.0, stats)
	assert_eq(model.burn_ready_fraction(stats), 1.0)
	assert_true(model.try_burn(Vector2.ZERO, stats))


func test_burn_overspeed_bleeds_back_to_max_speed() -> void:
	var model := SailingModel.new()
	var stats := _stats()
	model.try_burn(Vector2.ZERO, stats)
	_run(model, 0.1, 0.0, 0.0, stats)
	assert_gt(model.speed(), 18.0, "the surge is felt")
	_run(model, 3.0, 0.0, 0.0, stats)
	assert_lte(model.speed(), 18.0)


func test_burn_briefly_locks_steering_so_a_strafe_does_not_spin_the_ship() -> void:
	var model := SailingModel.new()
	var stats := _stats()
	model.try_burn(Vector2(1, 0), stats)
	_run(model, SailingModel.BURN_TURN_LOCK * 0.9, 0.0, -1.0, stats)
	assert_almost_eq(model.yaw, 0.0, 0.0001, "steering ignored during the lock")
	_run(model, 0.5, 0.0, -1.0, stats)
	assert_gt(model.yaw, 0.1, "steering works again afterwards")
