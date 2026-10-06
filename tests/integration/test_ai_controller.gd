extends "res://tests/helpers/ship_test.gd"
## AI ships in real physics. These await physics frames, so run the suite with --fixed-fps 60
## (see the godot-cli-commands note) or they take real time. The target is a stationary player
## ship at the origin facing -Z.

var player: Ship


func before_each() -> void:
	player = make_ship(Ship.TEAM_PLAYER, Vector3.ZERO)
	await settle()


func _spawn(id: StringName, pos: Vector3, seed_value: int = 1) -> Ship:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var enemy := EnemyFactory.spawn(self, ContentDB.get_by_id(id) as EnemyData, pos, PI, rng)
	enemy.free_on_death = false
	autofree(enemy)
	return enemy


func _run(seconds: float) -> void:
	await wait_physics_frames(roundi(seconds * 60.0))


func _distance(enemy: Ship) -> float:
	return Vector2(enemy.global_position.x - player.global_position.x, enemy.global_position.z - player.global_position.z).length()


## The smallest and largest distance to the player over the next [param seconds].
func _distance_range(enemy: Ship, seconds: float) -> Vector2:
	var low := INF
	var high := 0.0
	for tick in roundi(seconds * 60.0):
		await wait_physics_frames(1)
		low = minf(low, _distance(enemy))
		high = maxf(high, _distance(enemy))
	return Vector2(low, high)


# --- Brawler -------------------------------------------------------------------------------

func test_the_brawler_closes_the_distance() -> void:
	var enemy := _spawn(&"enemy_raider", Vector3(0, 0, -50))
	assert_almost_eq(_distance(enemy), 50.0, 0.01)
	await _run(10.0)
	assert_lt(_distance(enemy), 25.0, "it came to you")


func test_the_brawler_then_holds_its_range_instead_of_ramming() -> void:
	var enemy := _spawn(&"enemy_raider", Vector3(0, 0, -30))
	await _run(8.0)
	var range_seen := await _distance_range(enemy, 8.0)
	assert_gt(range_seen.x, 5.0, "never collides with the player")
	assert_lt(range_seen.y, 26.0, "never wanders off")


func test_the_brawler_circles_rather_than_sitting_still() -> void:
	var enemy := _spawn(&"enemy_raider", Vector3(0, 0, -16))
	await _run(4.0)
	var start := enemy.global_position
	await _run(4.0)
	assert_gt(enemy.global_position.distance_to(start), 6.0)
	assert_gt(enemy.movement.speed(), 3.0)


func test_the_brawlers_guns_hurt_the_player() -> void:
	player.health.god_mode = false
	var enemy := _spawn(&"enemy_raider", Vector3(0, 0, -25))
	watch_signals(EventBus)
	await _run(8.0)
	assert_signal_emitted(EventBus, "ship_hit")
	assert_lt(player.health.shield, player.health.max_shield())
	assert_true(enemy.is_alive())


# --- Sniper ---------------------------------------------------------------------------------

func test_the_sniper_backs_away_when_you_get_close() -> void:
	var enemy := _spawn(&"enemy_longshot", Vector3(0, 0, -12))
	await _run(7.0)
	assert_gt(_distance(enemy), 22.0, "it opened the gap")


func test_the_sniper_holds_a_long_range() -> void:
	var enemy := _spawn(&"enemy_longshot", Vector3(0, 0, -38))
	await _run(8.0)
	var range_seen := await _distance_range(enemy, 6.0)
	assert_gt(range_seen.x, 24.0)
	assert_lt(range_seen.y, 52.0)


func test_the_sniper_charges_its_railgun_and_fires_it() -> void:
	player.health.god_mode = true
	var enemy := _spawn(&"enemy_longshot", Vector3(0, 0, -35))
	var railgun := enemy.weapon_at(0)
	assert_eq(railgun.weapon.id, &"railgun")
	watch_signals(railgun)
	var saw_charge := false
	for tick in 60 * 10:
		await wait_physics_frames(1)
		saw_charge = saw_charge or railgun.charge > 0.3
	assert_true(saw_charge, "the glow telegraph appears before the shot")
	assert_signal_emitted(railgun, "fired")


func test_the_sniper_dodges_an_incoming_shot_with_hard_burn() -> void:
	var enemy := _spawn(&"enemy_longshot", Vector3(0, 0, -30))
	enemy.weapons_enabled = false
	await _run(1.0)
	assert_eq(enemy.movement.burn_ready_fraction(), 1.0)
	var direction := (enemy.global_position - player.global_position).normalized()
	var data := make_projectile_data(40.0, 5.0)
	Projectile.spawn(self, data, player, player.global_position + direction * 2.0, direction)
	await wait_physics_frames(20)
	assert_lt(enemy.movement.burn_ready_fraction(), 1.0, "it burned sideways")


func test_the_brawler_does_not_dodge() -> void:
	var enemy := _spawn(&"enemy_raider", Vector3(0, 0, -30))
	enemy.weapons_enabled = false
	await _run(0.5)
	var direction := (enemy.global_position - player.global_position).normalized()
	Projectile.spawn(self, make_projectile_data(40.0, 5.0), player, player.global_position + direction * 2.0, direction)
	await wait_physics_frames(20)
	assert_eq(enemy.movement.burn_ready_fraction(), 1.0)


# --- Lock-on ----------------------------------------------------------------------------------

func test_the_ai_makes_a_lock_and_fires_a_homing_salvo() -> void:
	var enemy := _spawn(&"enemy_raider", Vector3(0, 0, -25))
	enemy.equip(1, weapon(&"missile_pod"))
	player.health.god_mode = true
	var launched := false
	for tick in 60 * 20:
		await wait_physics_frames(1)
		for p in projectiles():
			launched = launched or (p as Projectile).data.homing_deg_per_sec > 0.0
		if launched:
			break
	assert_true(launched, "release-to-fire means the AI must let go of the trigger once locked")


# --- Control -----------------------------------------------------------------------------------

func test_a_disabled_ai_does_nothing() -> void:
	var enemy := _spawn(&"enemy_raider", Vector3(0, 0, -25))
	(enemy.get_node("AIController") as AIController).enabled = false
	enemy.weapons_enabled = false  # (the AI only drives movement and the manual/lock triggers)
	var start := enemy.global_position
	watch_signals(EventBus)
	await _run(3.0)
	assert_almost_eq(enemy.global_position.x, start.x, 0.01)
	assert_almost_eq(enemy.global_position.z, start.z, 0.01)
	assert_signal_not_emitted(EventBus, "weapon_fired")


func test_with_nobody_left_to_fight_the_ai_stops() -> void:
	var enemy := _spawn(&"enemy_raider", Vector3(0, 0, -25))
	player.health.shield = 0.0
	player.health.apply_hit(Hit.make(100000.0, Damage.Type.KINETIC, null, Vector3.ZERO))
	await _run(2.0)
	assert_eq(enemy.movement.throttle, 0.0)
	assert_eq(enemy.movement.turn, 0.0)


func test_a_dead_ai_ship_stops_acting() -> void:
	var enemy := _spawn(&"enemy_raider", Vector3(0, 0, -25))
	enemy.health.shield = 0.0
	enemy.health.apply_hit(Hit.make(100000.0, Damage.Type.KINETIC, null, Vector3.ZERO))
	await _run(1.0)
	assert_eq(enemy.movement.throttle, 0.0)
	assert_eq(projectiles().size(), 0)


func test_the_ai_never_shoots_its_own_side() -> void:
	var ally := _spawn(&"enemy_raider", Vector3(0, 0, -25), 2)
	var shooter := _spawn(&"enemy_raider", Vector3(0, 0, -40), 3)
	player.global_position = Vector3(300, 0, 300)  # Far outside anyone's range.
	await _run(4.0)
	assert_eq(ally.health.shield, ally.health.max_shield())
	assert_eq(shooter.health.shield, shooter.health.max_shield())


# --- Two AIs --------------------------------------------------------------------------------------

func test_two_ai_ships_fight_to_a_finish() -> void:
	# Player-side ship driven by the same AI as the enemy: a duel with nobody at the keyboard.
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var ally_data := ContentDB.get_by_id(&"enemy_raider") as EnemyData
	var ally := EnemyFactory.spawn(self, ally_data, Vector3(0, 0, 20), 0.0, rng)
	ally.team = Ship.TEAM_PLAYER
	ally.free_on_death = false
	autofree(ally)
	player.queue_free()
	await wait_physics_frames(2)
	var enemy := _spawn(&"enemy_raider", Vector3(0, 0, -20), 6)
	var seconds := 0.0
	while ally.is_alive() and enemy.is_alive() and seconds < 420.0:
		await wait_physics_frames(60)
		seconds += 1.0
	gut.p("AI vs AI Raider mirror match lasted ~%.0f s" % seconds)
	assert_false(ally.is_alive() and enemy.is_alive(), "someone won within 7 minutes: no stalemate")
