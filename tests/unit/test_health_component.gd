extends "res://tests/helpers/ship_test.gd"

var ship: Ship


func before_each() -> void:
	# Frigate: shield 100, regen 8/s after 3 s, armor 3, hull 300.
	ship = make_ship(Ship.TEAM_PLAYER, Vector3.ZERO)


func _hit(damage: float, type: Damage.Type = Damage.Type.KINETIC) -> Hit:
	return Hit.make(damage, type, null, Vector3.ZERO)


func test_a_new_ship_starts_at_full_health() -> void:
	assert_eq(ship.health.shield, 100.0)
	assert_eq(ship.health.hull, 300.0)
	assert_true(ship.is_alive())


func test_a_hit_takes_shield_first() -> void:
	var result := ship.health.apply_hit(_hit(20.0, Damage.Type.ENERGY))
	assert_almost_eq(ship.health.shield, 70.0, 0.001, "20 * 1.5 shield multiplier")
	assert_eq(ship.health.hull, 300.0)
	assert_almost_eq(result.shield_damage, 30.0, 0.001)


func test_hull_takes_what_the_shield_cannot() -> void:
	ship.health.shield = 0.0
	ship.health.apply_hit(_hit(20.0))
	assert_almost_eq(ship.health.hull, 300.0 - (20.0 - 3.0 * 0.5), 0.001, "kinetic ignores half the 3 armor")


func test_damaged_signal_and_event_bus_report_the_result() -> void:
	watch_signals(ship.health)
	watch_signals(EventBus)
	ship.health.apply_hit(_hit(10.0))
	assert_signal_emitted(ship.health, "damaged")
	assert_signal_emitted(EventBus, "ship_hit")


func test_shield_does_not_regenerate_until_the_delay_has_passed() -> void:
	ship.health.apply_hit(_hit(20.0))  # shield 100 -> 85
	ship.health.step(2.0)
	assert_almost_eq(ship.health.shield, 85.0, 0.001, "still inside the 3 s delay")
	ship.health.step(1.5)
	assert_gt(ship.health.shield, 85.0, "regen has begun")


func test_regeneration_stops_at_the_maximum() -> void:
	ship.health.apply_hit(_hit(8.0))
	ship.health.step(60.0)
	assert_eq(ship.health.shield, 100.0)


func test_taking_another_hit_restarts_the_regen_delay() -> void:
	ship.health.apply_hit(_hit(20.0))
	ship.health.step(2.5)
	ship.health.apply_hit(_hit(1.0))
	var after := ship.health.shield
	ship.health.step(2.5)
	assert_almost_eq(ship.health.shield, after, 0.001, "delay restarted by the second hit")


func test_hull_never_regenerates() -> void:
	ship.health.shield = 0.0
	ship.health.apply_hit(_hit(50.0))
	var hull := ship.health.hull
	ship.health.step(30.0)
	assert_eq(ship.health.hull, hull)


func test_lethal_hit_destroys_once() -> void:
	ship.health.shield = 0.0
	watch_signals(ship.health)
	ship.health.apply_hit(_hit(1000.0))
	ship.health.apply_hit(_hit(1000.0))
	assert_true(ship.health.is_dead)
	assert_false(ship.is_alive())
	assert_signal_emit_count(ship.health, "destroyed", 1)
	assert_eq(ship.health.hull, 0.0)


func test_a_dead_ship_ignores_further_hits_and_regen() -> void:
	ship.health.shield = 0.0
	ship.health.apply_hit(_hit(1000.0))
	var result := ship.health.apply_hit(_hit(50.0))
	assert_eq(result.total_dealt(), 0.0)
	ship.health.step(30.0)
	assert_eq(ship.health.shield, 0.0)


func test_destruction_hides_the_ship_and_makes_it_untargetable() -> void:
	ship.health.shield = 0.0
	ship.health.apply_hit(_hit(1000.0))
	assert_false(ship.visible)
	assert_eq(ship.collision_layer, 0)


func test_revive_restores_everything() -> void:
	ship.health.shield = 0.0
	ship.health.apply_hit(_hit(1000.0))
	ship.revive(Vector3(5, 0, 5))
	assert_true(ship.is_alive())
	assert_true(ship.visible)
	assert_eq(ship.collision_layer, 1)
	assert_eq(ship.health.hull, 300.0)
	assert_eq(ship.health.shield, 100.0)
	assert_eq(ship.global_position, Vector3(5, 0, 5))


func test_god_mode_reports_damage_but_takes_none() -> void:
	ship.health.god_mode = true
	watch_signals(ship.health)
	var result := ship.health.apply_hit(_hit(1000.0))
	assert_gt(result.total_dealt(), 0.0, "damage numbers still show")
	assert_eq(ship.health.shield, 100.0)
	assert_eq(ship.health.hull, 300.0)
	assert_true(ship.is_alive())
	assert_signal_emitted(ship.health, "damaged")
	assert_signal_not_emitted(ship.health, "destroyed")


func test_stat_changes_clamp_current_health_to_the_new_maximum() -> void:
	ship.stats.set_base_stat(Stats.MAX_SHIELD, 40.0)
	assert_eq(ship.health.shield, 40.0)


func test_armor_comes_from_the_stats_so_mods_can_change_it() -> void:
	var mods: Array[StatMod] = [StatMod.make(Stats.ARMOR, StatMod.Op.FLAT, 2.0)]
	ship.stats.set_mods(mods)
	assert_eq(ship.health.armor(), 5.0)


func test_free_on_death_ships_are_removed() -> void:
	var temp := SHIP_SCENE.instantiate() as Ship
	add_child_autofree(temp)
	temp.setup(ContentDB.get_hull(&"debug_dummy"))
	temp.health.shield = 0.0
	temp.health.apply_hit(_hit(10000.0))
	await wait_physics_frames(2)
	assert_false(is_instance_valid(temp))
