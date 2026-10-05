extends GutTest

const SHIP_SCENE := preload("res://scenes/ship/ship.tscn")
const SANDBOX_SCENE := preload("res://scenes/debug/sandbox.tscn")


func _make_ship(hull_id: StringName = &"starter_frigate") -> Ship:
	var ship := SHIP_SCENE.instantiate() as Ship
	add_child_autofree(ship)
	ship.setup(ContentDB.get_hull(hull_id))
	return ship


func _mounts_of(ship: Ship) -> Array[Node]:
	return ship.find_children("Mount_*", "HardpointMount", true, false)


func test_setup_builds_model_collider_and_one_mount_per_hardpoint() -> void:
	var ship := _make_ship()
	assert_eq(ship.get_node("Model").get_child_count(), 1)
	assert_eq(_mounts_of(ship).size(), 5, "2 turrets, bay, techmod, crew seat")
	assert_almost_eq((ship.get_node("CollisionShape3D") as CollisionShape3D).shape.radius, 1.7, 0.0001)
	assert_eq(ship.stats.get_stat(Stats.MAX_SPEED), 18.0)


func test_mounts_sit_on_their_hull_markers() -> void:
	var ship := _make_ship()
	var turret_b := ship.find_child("Mount_Turret_B", true, false) as HardpointMount
	assert_not_null(turret_b)
	assert_eq(turret_b.get_parent().name, &"Turret_B")
	assert_eq(turret_b.data.size, HardpointData.Size.LARGE)


func test_hull_swap_replaces_model_mounts_collider_and_stats() -> void:
	var ship := _make_ship()
	watch_signals(ship)
	ship.setup(ContentDB.get_hull(&"debug_skiff"))
	assert_eq(ship.get_node("Model").get_child_count(), 1, "old model removed, new one added")
	assert_eq(_mounts_of(ship).size(), 2)
	assert_eq(ship.stats.get_stat(Stats.MAX_SPEED), 24.0)
	assert_almost_eq((ship.get_node("CollisionShape3D") as CollisionShape3D).shape.radius, 1.1, 0.0001)
	assert_signal_emitted(ship, "hull_changed")
	await wait_physics_frames(1)  # Let the removed model finish freeing so orphan checks stay honest.


func test_throttle_drives_the_ship_along_its_bow_on_the_play_plane() -> void:
	var ship := _make_ship()
	ship.place(Vector3.ZERO, 0.0)
	ship.set_throttle(1.0)
	await wait_physics_frames(30)
	assert_lt(ship.global_position.z, -0.3, "bow points down -Z")
	assert_almost_eq(ship.global_position.x, 0.0, 0.01)
	assert_eq(ship.global_position.y, 0.0)
	assert_lte(ship.movement.speed(), ship.stats.get_stat(Stats.MAX_SPEED) + 0.001)


func test_steering_rotates_the_ship_node() -> void:
	var ship := _make_ship()
	ship.place(Vector3.ZERO, 0.0)
	ship.set_turn(1.0)
	await wait_physics_frames(30)
	assert_lt(ship.rotation.y, -0.2, "starboard turn = negative yaw")


func test_hard_burn_fires_once_then_waits_out_its_cooldown() -> void:
	var ship := _make_ship()
	ship.place(Vector3.ZERO, 0.0)
	watch_signals(ship)
	ship.request_hard_burn(Vector2(1, 0))
	ship.request_hard_burn(Vector2(1, 0))
	assert_signal_emit_count(ship, "burn_used", 1)
	assert_gt(ship.movement.model.velocity.x, 20.0, "starboard strafe burst")


func test_place_teleports_and_stops_the_ship() -> void:
	var ship := _make_ship()
	ship.set_throttle(1.0)
	await wait_physics_frames(10)
	ship.set_throttle(0.0)
	ship.place(Vector3(5, 3, -7), 1.0)
	assert_eq(ship.global_position, Vector3(5, 0, -7), "snapped onto the play plane")
	assert_eq(ship.velocity, Vector3.ZERO)
	assert_eq(ship.movement.speed(), 0.0)


func test_enforce_bounds_pulls_the_ship_back_and_cancels_outward_motion() -> void:
	var ship := _make_ship()
	ship.place(Vector3(60, 0, 0), 0.0)
	ship.movement.model.velocity = Vector3(10, 0, 4)
	ship.enforce_bounds(Vector3.ZERO, 50.0)
	assert_almost_eq(ship.global_position.length(), 50.0 - 1.7, 0.001)
	assert_almost_eq(ship.movement.model.velocity.x, 0.0, 0.001, "no more outward speed")
	assert_almost_eq(ship.movement.model.velocity.z, 4.0, 0.001, "sliding along the edge is kept")


func test_enforce_bounds_leaves_a_ship_inside_alone() -> void:
	var ship := _make_ship()
	ship.place(Vector3(10, 0, 0), 0.0)
	ship.movement.model.velocity = Vector3(5, 0, 0)
	ship.enforce_bounds(Vector3.ZERO, 50.0)
	assert_eq(ship.global_position, Vector3(10, 0, 0))
	assert_eq(ship.movement.model.velocity, Vector3(5, 0, 0))


func test_ships_are_driven_only_through_commands() -> void:
	# A bot and a player use the same Ship scene; here a bare script plays the controller.
	var ship := _make_ship()
	var bot := CircleBot.new()
	ship.add_child(bot)
	await wait_physics_frames(30)
	assert_gt(ship.movement.speed(), 0.5)
	assert_ne(ship.rotation.y, 0.0)


func test_sandbox_boots_with_a_player_ship_and_no_errors() -> void:
	var sandbox := SANDBOX_SCENE.instantiate()
	add_child_autofree(sandbox)
	await wait_physics_frames(10)
	var ships := get_tree().get_nodes_in_group(Ship.GROUP)
	assert_eq(ships.size(), 1, "just the player: the sandbox starts with no enemies")
	assert_not_null((ships[0] as Ship).hull)
	assert_true(sandbox.get_node("FollowCamera").camera.current)
