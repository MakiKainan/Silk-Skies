extends "res://tests/helpers/ship_test.gd"
## Spec section 8: cooldown and arc checks in WeaponController, plus targeting modes.
## Frigate hardpoints: 0 = Small 360 turret, 1 = Large 120 forward turret. The bow faces -Z.

var player: Ship


func before_each() -> void:
	player = make_ship(Ship.TEAM_PLAYER, Vector3.ZERO)


func _enemy(pos: Vector3) -> Ship:
	return make_ship(Ship.TEAM_ENEMY, pos)


func _controller(slot: int, weapon_id: StringName) -> WeaponController:
	assert_true(player.equip(slot, weapon(weapon_id)), "equip %s in slot %d" % [weapon_id, slot])
	return player.weapon_at(slot)


# --- Cooldown ------------------------------------------------------------------------

func test_auto_weapon_fires_at_an_enemy_in_range_then_waits_out_its_cooldown() -> void:
	var gun := _controller(0, &"pulse_laser")  # cooldown 0.18
	_enemy(Vector3(0, 0, -20))
	watch_signals(gun)
	gun.step(0.016)
	assert_signal_emit_count(gun, "fired", 1)
	assert_almost_eq(gun.cooldown_left, 0.18, 0.001)
	assert_false(gun.is_ready())
	gun.step(0.1)
	assert_signal_emit_count(gun, "fired", 1, "still cooling down")
	gun.step(0.1)
	assert_signal_emit_count(gun, "fired", 2, "ready again after 0.18 s")


func test_every_shot_spawns_a_projectile() -> void:
	var gun := _controller(0, &"pulse_laser")
	_enemy(Vector3(0, 0, -20))
	gun.step(0.016)
	assert_eq(projectiles().size(), 1)


func test_ready_fraction_tracks_the_cooldown() -> void:
	var gun := _controller(0, &"pulse_laser")
	_enemy(Vector3(0, 0, -20))
	assert_eq(gun.ready_fraction(), 1.0)
	gun.step(0.016)
	assert_lt(gun.ready_fraction(), 0.2)
	gun.step(0.09)
	assert_almost_eq(gun.ready_fraction(), 0.5, 0.1)


# --- Auto targeting: range, arc, teams -------------------------------------------------

func test_auto_ignores_enemies_beyond_range() -> void:
	var gun := _controller(0, &"pulse_laser")  # range 38
	_enemy(Vector3(0, 0, -60))
	gun.step(0.016)
	assert_eq(projectiles().size(), 0)


func test_auto_ignores_friendly_ships() -> void:
	var gun := _controller(0, &"pulse_laser")
	make_ship(Ship.TEAM_PLAYER, Vector3(0, 0, -15))
	gun.step(0.016)
	assert_eq(projectiles().size(), 0)


func test_auto_ignores_dead_enemies() -> void:
	var gun := _controller(0, &"pulse_laser")
	var enemy := _enemy(Vector3(0, 0, -15))
	enemy.health.shield = 0.0
	enemy.health.apply_hit(Hit.make(10000.0, Damage.Type.KINETIC, null, Vector3.ZERO))
	gun.step(0.016)
	assert_eq(projectiles().size(), 0)


func test_forward_arc_weapon_ignores_targets_behind_the_ship() -> void:
	var gun := _controller(1, &"pulse_laser")  # Large 120 degree forward arc
	_enemy(Vector3(0, 0, 20))
	gun.step(0.016)
	assert_eq(projectiles().size(), 0)


func test_forward_arc_weapon_fires_at_targets_in_front() -> void:
	var gun := _controller(1, &"pulse_laser")
	_enemy(Vector3(0, 0, -20))
	gun.step(0.016)
	assert_eq(projectiles().size(), 1)


func test_all_round_weapon_fires_at_targets_behind() -> void:
	var gun := _controller(0, &"pulse_laser")  # Small 360 degree
	_enemy(Vector3(0, 0, 20))
	gun.step(0.016)
	assert_eq(projectiles().size(), 1)


func test_the_arc_turns_with_the_ship() -> void:
	var gun := _controller(1, &"pulse_laser")
	player.place(Vector3.ZERO, PI)  # Bow now faces +Z.
	_enemy(Vector3(0, 0, 20))
	gun.step(0.016)
	assert_eq(projectiles().size(), 1)


func test_auto_picks_the_nearest_valid_target() -> void:
	var gun := _controller(1, &"pulse_laser")  # 120 degree forward arc
	var near := _enemy(Vector3(0, 0, -12))
	_enemy(Vector3(0, 0, -30))
	_enemy(Vector3(5, 0, 8))  # Closest of all, but behind the arc.
	assert_eq(gun.pick_auto_target(), near)


func test_an_all_round_weapon_picks_the_nearest_in_any_direction() -> void:
	var gun := _controller(0, &"pulse_laser")
	_enemy(Vector3(0, 0, -12))
	var behind := _enemy(Vector3(5, 0, 6))
	assert_eq(gun.pick_auto_target(), behind)


func test_disabled_weapons_do_not_fire() -> void:
	var gun := _controller(0, &"pulse_laser")
	_enemy(Vector3(0, 0, -20))
	player.weapons_enabled = false
	gun.step(0.016)
	assert_eq(projectiles().size(), 0)


func test_a_dead_ship_does_not_fire() -> void:
	var gun := _controller(0, &"pulse_laser")
	_enemy(Vector3(0, 0, -20))
	player.health.shield = 0.0
	player.health.apply_hit(Hit.make(10000.0, Damage.Type.KINETIC, null, Vector3.ZERO))
	gun.step(0.016)
	assert_eq(projectiles().size(), 0)


# --- Lead ----------------------------------------------------------------------------

func test_lead_at_a_stationary_target_is_a_straight_line() -> void:
	var dir := WeaponController.intercept_direction(Vector3.ZERO, Vector3(0, 0, -20), Vector3.ZERO, 50.0)
	assert_almost_eq(dir, Vector3(0, 0, -1), Vector3.ONE * 0.0001)


func test_lead_aims_ahead_of_a_crossing_target() -> void:
	var from := Vector3.ZERO
	var target := Vector3(0, 0, -20)
	var velocity := Vector3(10, 0, 0)
	var dir := WeaponController.intercept_direction(from, target, velocity, 50.0)
	assert_gt(dir.x, 0.0, "aims toward where it is going")
	# Walk the bullet and the target forward: they must meet.
	var closest := INF
	for i in 2000:
		var t := i * 0.001
		closest = minf(closest, (from + dir * 50.0 * t).distance_to(target + velocity * t))
	assert_lt(closest, 0.05)


func test_lead_falls_back_to_direct_aim_when_the_target_outruns_the_bullet() -> void:
	var dir := WeaponController.intercept_direction(Vector3.ZERO, Vector3(0, 0, -20), Vector3(0, 0, -80), 50.0)
	assert_almost_eq(dir, Vector3(0, 0, -1), Vector3.ONE * 0.0001)
	assert_false(is_nan(dir.x))


func test_auto_fire_leads_a_moving_target() -> void:
	var gun := _controller(0, &"pulse_laser")
	var enemy := _enemy(Vector3(0, 0, -20))
	enemy.velocity = Vector3(10, 0, 0)
	gun.step(0.016)
	assert_gt((projectiles()[0] as Projectile).direction.x, 0.05)


# --- Manual weapons ------------------------------------------------------------------

func test_manual_weapon_does_nothing_until_the_trigger_is_held() -> void:
	var gun := _controller(1, &"railgun")
	player.aim_at(Vector3(0, 0, -30))
	gun.step(0.5)
	assert_eq(gun.charge, 0.0)
	assert_eq(projectiles().size(), 0)


func test_railgun_charges_while_held_and_fires_at_full_charge() -> void:
	var gun := _controller(1, &"railgun")  # charge 1.0 s, cooldown 2.5 s
	player.aim_at(Vector3(0, 0, -30))
	player.set_trigger(WeaponData.Targeting.MANUAL, true)
	gun.step(0.5)
	assert_almost_eq(gun.charge, 0.5, 0.001)
	assert_eq(projectiles().size(), 0)
	assert_almost_eq(gun.ready_fraction(), 0.5, 0.001)
	gun.step(0.6)
	assert_eq(projectiles().size(), 1, "fires on reaching full charge")
	assert_eq(gun.charge, 0.0)
	assert_almost_eq(gun.cooldown_left, 2.5, 0.001)


func test_releasing_early_cancels_the_charge() -> void:
	var gun := _controller(1, &"railgun")
	player.aim_at(Vector3(0, 0, -30))
	player.set_trigger(WeaponData.Targeting.MANUAL, true)
	gun.step(0.6)
	player.set_trigger(WeaponData.Targeting.MANUAL, false)
	gun.step(0.016)
	assert_eq(gun.charge, 0.0)
	assert_eq(projectiles().size(), 0)
	assert_eq(gun.cooldown_left, 0.0, "a cancelled charge costs no cooldown")


func test_aiming_outside_the_arc_does_not_charge_or_fire() -> void:
	var gun := _controller(1, &"railgun")  # 120 degree forward arc
	player.aim_at(Vector3(0, 0, 30))  # Astern.
	player.set_trigger(WeaponData.Targeting.MANUAL, true)
	gun.step(2.0)
	assert_eq(gun.charge, 0.0)
	assert_eq(projectiles().size(), 0)


func test_leaving_the_arc_mid_charge_cancels_it() -> void:
	var gun := _controller(1, &"railgun")
	player.aim_at(Vector3(0, 0, -30))
	player.set_trigger(WeaponData.Targeting.MANUAL, true)
	gun.step(0.6)
	player.aim_at(Vector3(0, 0, 30))
	gun.step(0.016)
	assert_eq(gun.charge, 0.0)


func test_manual_shots_go_toward_the_aim_point() -> void:
	var gun := _controller(1, &"railgun")
	player.aim_at(Vector3(-20, 0, -20))
	player.set_trigger(WeaponData.Targeting.MANUAL, true)
	gun.step(1.1)
	var direction := (projectiles()[0] as Projectile).direction
	assert_almost_eq(direction.x, -0.7071, 0.05)
	assert_almost_eq(direction.z, -0.7071, 0.05)


func test_manual_weapon_without_a_charge_fires_immediately() -> void:
	var quick := WeaponData.new()
	quick.projectile = weapon(&"autocannon").projectile
	quick.targeting = WeaponData.Targeting.MANUAL
	quick.cooldown = 0.3
	quick.charge_time = 0.0
	var mount := player.mounts[0]
	mount.equip(quick, player)
	var gun := mount.weapon_controller
	player.aim_at(Vector3(0, 0, -30))
	player.set_trigger(WeaponData.Targeting.MANUAL, true)
	gun.step(0.016)
	assert_eq(projectiles().size(), 1)


func test_manual_trigger_does_not_fire_auto_weapons_and_vice_versa() -> void:
	var gun := _controller(0, &"pulse_laser")
	player.aim_at(Vector3(0, 0, -30))
	player.set_trigger(WeaponData.Targeting.MANUAL, true)
	gun.step(0.5)
	assert_eq(projectiles().size(), 0, "no enemy, so the auto weapon stays quiet whatever the triggers do")


# --- Lock-on ---------------------------------------------------------------------------

func _hold_lock(gun: WeaponController, seconds: float) -> void:
	player.set_trigger(WeaponData.Targeting.LOCK_ON, true)
	for i in roundi(seconds / 0.05):
		gun.step(0.05)


func _release_lock(gun: WeaponController) -> void:
	player.set_trigger(WeaponData.Targeting.LOCK_ON, false)
	gun.step(0.016)


func test_lock_builds_while_the_cursor_stays_on_an_enemy() -> void:
	var gun := _controller(1, &"missile_pod")  # lock_time 0.8
	var enemy := _enemy(Vector3(0, 0, -25))
	player.aim_at(enemy.global_position)
	_hold_lock(gun, 0.5)
	assert_eq(gun.lock_target, enemy)
	assert_almost_eq(gun.lock_progress, 0.45, 0.06)
	assert_eq(projectiles().size(), 0, "holding the trigger alone never fires")


func test_releasing_with_a_full_lock_fires_a_homing_salvo() -> void:
	var gun := _controller(1, &"missile_pod")
	var enemy := _enemy(Vector3(0, 0, -25))
	player.aim_at(enemy.global_position)
	_hold_lock(gun, 1.0)
	_release_lock(gun)
	gun.step(0.6)  # Let the burst finish.
	assert_eq(projectiles().size(), 4)
	for p in projectiles():
		assert_eq((p as Projectile).target, enemy, "every missile homes on the locked ship")
	assert_almost_eq(gun.cooldown_left, 6.0 - 0.6 - 0.016, 0.05)
	assert_null(gun.lock_target, "the lock is spent")


func test_releasing_before_the_lock_completes_fires_nothing_and_costs_no_cooldown() -> void:
	var gun := _controller(1, &"missile_pod")
	var enemy := _enemy(Vector3(0, 0, -25))
	player.aim_at(enemy.global_position)
	_hold_lock(gun, 0.4)
	_release_lock(gun)
	assert_eq(projectiles().size(), 0)
	assert_eq(gun.cooldown_left, 0.0)
	assert_null(gun.lock_target)
	assert_eq(gun.lock_progress, 0.0)


func test_moving_the_cursor_off_the_enemy_drops_the_lock() -> void:
	var gun := _controller(1, &"missile_pod")
	var enemy := _enemy(Vector3(0, 0, -25))
	player.aim_at(enemy.global_position)
	_hold_lock(gun, 0.5)
	player.aim_at(Vector3(40, 0, -25))  # Far outside the pick radius.
	gun.step(0.05)
	assert_null(gun.lock_target)
	assert_eq(gun.lock_progress, 0.0)


func test_switching_targets_restarts_the_lock() -> void:
	var gun := _controller(1, &"missile_pod")
	var first := _enemy(Vector3(-12, 0, -25))
	var second := _enemy(Vector3(12, 0, -25))
	player.aim_at(first.global_position)
	_hold_lock(gun, 0.5)
	player.aim_at(second.global_position)
	gun.step(0.05)
	assert_eq(gun.lock_target, second)
	assert_eq(gun.lock_progress, 0.0)


func test_cannot_lock_an_enemy_outside_the_arc() -> void:
	var gun := _controller(1, &"missile_pod")  # 120 degree forward arc
	var enemy := _enemy(Vector3(0, 0, 25))
	player.aim_at(enemy.global_position)
	_hold_lock(gun, 1.0)
	assert_null(gun.lock_target)


func test_cannot_lock_a_friendly_ship() -> void:
	var gun := _controller(1, &"missile_pod")
	var friend := make_ship(Ship.TEAM_PLAYER, Vector3(0, 0, -25))
	player.aim_at(friend.global_position)
	_hold_lock(gun, 1.0)
	assert_null(gun.lock_target)


func test_a_full_lock_still_waits_for_the_cooldown() -> void:
	var gun := _controller(1, &"missile_pod")
	var enemy := _enemy(Vector3(0, 0, -25))
	player.aim_at(enemy.global_position)
	gun.cooldown_left = 3.0
	_hold_lock(gun, 1.0)
	gun.cooldown_left = 3.0  # (step() ticked it down while locking)
	_release_lock(gun)
	assert_eq(projectiles().size(), 0)


# --- Salvos and spread ---------------------------------------------------------------

func test_a_salvo_launches_its_missiles_one_burst_interval_apart() -> void:
	var gun := _controller(1, &"missile_pod")  # 4 shots, 0.12 s apart
	var enemy := _enemy(Vector3(0, 0, -25))
	player.aim_at(enemy.global_position)
	_hold_lock(gun, 1.0)
	_release_lock(gun)
	assert_eq(projectiles().size(), 1, "first missile leaves at once")
	gun.step(0.12)
	assert_eq(projectiles().size(), 2)
	gun.step(0.12)
	assert_eq(projectiles().size(), 3)
	gun.step(0.12)
	assert_eq(projectiles().size(), 4)
	gun.step(0.5)
	assert_eq(projectiles().size(), 4, "no more than the salvo size")


func test_seeded_spread_is_repeatable() -> void:
	var gun := _controller(0, &"autocannon")  # spread 3.5 degrees
	_enemy(Vector3(0, 0, -20))
	var runs: Array[Array] = []
	for run in 2:
		clear_projectiles()
		gun.rng.seed = 12345
		gun.cooldown_left = 0.0
		for shot in 3:
			gun.cooldown_left = 0.0
			gun.step(0.016)
		var directions: Array = []
		for p in projectiles():
			directions.append((p as Projectile).direction)
		runs.append(directions)
	assert_eq(runs[0], runs[1])


func test_spread_actually_spreads_shots() -> void:
	var gun := _controller(0, &"autocannon")
	_enemy(Vector3(0, 0, -20))
	gun.rng.seed = 7
	for shot in 12:
		gun.cooldown_left = 0.0
		gun.step(0.016)
	var xs: Array[float] = []
	for p in projectiles():
		xs.append((p as Projectile).direction.x)
	assert_gt(xs.max() - xs.min(), 0.02, "shots are not all identical")
	assert_lt(xs.max() - xs.min(), 0.15, "but stay within a few degrees")


func test_equipping_checks_the_slot_and_leaves_it_alone_on_failure() -> void:
	assert_false(player.equip(0, weapon(&"railgun")), "Large weapon in a Small slot")
	assert_null(player.weapon_at(0))
	assert_true(player.equip(1, weapon(&"railgun")))
	assert_false(player.equip(2, weapon(&"pulse_laser")), "slot 2 is a fighter bay")
	assert_false(player.equip(9, weapon(&"pulse_laser")), "no such hardpoint")
	assert_true(player.equip(1, weapon(&"pulse_laser")), "hot-swap a Large slot to a Small weapon")
	assert_eq(player.weapon_at(1).weapon.id, &"pulse_laser")
	assert_true(player.equip(1, null))
	await wait_physics_frames(1)
	assert_null(player.weapon_at(1))


# --- Targets that die mid-lock or mid-salvo ---------------------------------------------------

func test_a_target_freed_mid_salvo_does_not_break_the_weapon() -> void:
	var gun := _controller(1, &"missile_pod")
	var enemy := _enemy(Vector3(0, 0, -25))
	player.aim_at(enemy.global_position)
	_hold_lock(gun, 1.0)
	_release_lock(gun)
	assert_eq(projectiles().size(), 1, "first missile away, three still to come")
	enemy.free()  # Destroyed and removed while the salvo is still launching.
	gun.step(0.6)
	assert_eq(projectiles().size(), 4, "the rest of the salvo still launches, just unguided")
	gun.step(0.1)
	assert_true(gun.is_ready() or gun.cooldown_left > 0.0, "and the weapon carries on normally")


func test_a_lock_target_freed_mid_lock_is_dropped() -> void:
	var gun := _controller(1, &"missile_pod")
	var enemy := _enemy(Vector3(0, 0, -25))
	player.aim_at(enemy.global_position)
	_hold_lock(gun, 0.5)
	assert_eq(gun.lock_target, enemy)
	enemy.free()
	gun.step(0.05)
	assert_null(gun.lock_target)
	assert_eq(gun.lock_progress, 0.0)
