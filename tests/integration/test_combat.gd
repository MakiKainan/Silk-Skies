extends "res://tests/helpers/ship_test.gd"
## End-to-end combat with the real content: weapons mounted on a real hull shooting a real
## dummy. Simulated by hand (see ship_test.gd) so a minute of combat takes milliseconds.

var player: Ship
var dummy: Ship


func before_each() -> void:
	player = make_ship(Ship.TEAM_PLAYER, Vector3.ZERO)
	dummy = make_ship(Ship.TEAM_ENEMY, Vector3(0, 0, -15), &"debug_dummy")
	await settle()


func test_pulse_laser_alone_wears_down_the_dummy_shield_then_hull() -> void:
	player.equip(0, weapon(&"pulse_laser"))
	sim(10.0)
	assert_eq(dummy.health.shield, 0.0, "energy shreds shields quickly")
	assert_lt(dummy.health.hull, 200.0, "and then starts on the hull")
	assert_gt(dummy.health.hull, 0.0, "but the armor keeps it from being fast")


func test_the_pulse_laser_kills_a_dummy_eventually() -> void:
	player.equip(0, weapon(&"pulse_laser"))
	var seconds := 0.0
	while dummy.is_alive() and seconds < 120.0:
		sim(1.0)
		seconds += 1.0
	assert_false(dummy.is_alive())
	gut.p("pulse laser alone: dummy dead after ~%.0f s" % seconds)


func test_the_railgun_kills_a_dummy_within_a_minute() -> void:
	player.equip(1, weapon(&"railgun"))
	player.aim_at(dummy.global_position)
	player.set_trigger(WeaponData.Targeting.MANUAL, true)
	var seconds := 0.0
	while dummy.is_alive() and seconds < 60.0:
		sim(1.0)
		seconds += 1.0
	assert_false(dummy.is_alive())
	gut.p("railgun alone: dummy dead after ~%.0f s" % seconds)


func test_kinetic_hurts_armor_more_than_energy_per_point_of_damage() -> void:
	# Same raw damage per hit through the dummy's armor 4: kinetic keeps more of it.
	var energy := DamageModel.resolve(6.0, Damage.Type.ENERGY, 0.0, 4.0, 200.0)
	var kinetic := DamageModel.resolve(6.0, Damage.Type.KINETIC, 0.0, 4.0, 200.0)
	assert_gt(kinetic.hull_damage, energy.hull_damage)


func test_the_default_loadout_kills_the_dummy_in_well_under_a_minute() -> void:
	player.equip(0, weapon(&"pulse_laser"))
	player.equip(1, weapon(&"railgun"))
	player.aim_at(dummy.global_position)
	player.set_trigger(WeaponData.Targeting.MANUAL, true)
	var seconds := 0.0
	while dummy.is_alive() and seconds < 60.0:
		sim(1.0)
		seconds += 1.0
	assert_false(dummy.is_alive())
	assert_lt(seconds, 40.0)
	gut.p("laser + railgun: dummy dead after ~%.0f s" % seconds)


func test_a_missile_salvo_with_a_full_lock_damages_the_dummy() -> void:
	player.equip(1, weapon(&"missile_pod"))
	player.aim_at(dummy.global_position)
	player.set_trigger(WeaponData.Targeting.LOCK_ON, true)
	sim(1.0)
	player.set_trigger(WeaponData.Targeting.LOCK_ON, false)
	sim(4.0)
	assert_lt(dummy.health.shield, 150.0, "missiles landed")
	assert_gt(player.weapon_at(1).cooldown_left, 0.0)


func test_a_destroyed_target_stops_being_shot_at() -> void:
	player.equip(0, weapon(&"pulse_laser"))
	dummy.health.shield = 0.0
	dummy.health.apply_hit(Hit.make(10000.0, Damage.Type.KINETIC, player, Vector3.ZERO))
	clear_projectiles()
	sim(2.0)
	assert_eq(projectiles().size(), 0, "no targets, no shots")


func test_bots_with_auto_weapons_shoot_the_player() -> void:
	dummy.queue_free()
	var bot := make_ship(Ship.TEAM_ENEMY, Vector3(0, 0, -15))
	bot.equip(0, weapon(&"pulse_laser"))
	await settle()
	sim(5.0)
	assert_lt(player.health.shield, 100.0, "enemy auto-fire lands on the player with no AI at all")


func test_a_ship_can_carry_a_different_loadout_after_a_hull_swap() -> void:
	player.equip(0, weapon(&"pulse_laser"))
	player.setup(ContentDB.get_hull(&"debug_barge"))
	assert_eq(player.weapons().size(), 0, "a hull swap empties the slots")
	assert_eq(player.mounts.size(), 5)
	assert_true(player.equip(0, weapon(&"railgun")), "barge slot 0 is Large")
	assert_true(player.equip(2, weapon(&"pulse_laser")))
	assert_false(player.equip(2, weapon(&"railgun")), "barge slot 2 is Small")
	assert_eq(player.weapons().size(), 2)
	await wait_physics_frames(1)  # Let the replaced frigate model finish freeing.


func test_ships_see_only_living_ships_on_other_teams_as_enemies() -> void:
	assert_eq(player.enemies(), [dummy])
	assert_eq(dummy.enemies(), [player])
	dummy.health.shield = 0.0
	dummy.health.apply_hit(Hit.make(10000.0, Damage.Type.KINETIC, null, Vector3.ZERO))
	assert_eq(player.enemies().size(), 0)
