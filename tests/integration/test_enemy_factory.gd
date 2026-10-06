extends "res://tests/helpers/ship_test.gd"
## Enemies built from their EnemyData recipes, and boss phase changes.

var player: Ship


func before_each() -> void:
	player = make_ship(Ship.TEAM_PLAYER, Vector3.ZERO)


func _enemy_data(id: StringName) -> EnemyData:
	return ContentDB.get_by_id(id) as EnemyData


func _spawn(id: StringName, pos: Vector3 = Vector3(0, 0, -40), seed_value: int = 1) -> Ship:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var ship := EnemyFactory.spawn(self, _enemy_data(id), pos, PI, rng)
	ship.free_on_death = false
	autofree(ship)
	return ship


func _hit(damage: float) -> Hit:
	return Hit.make(damage, Damage.Type.KINETIC, null, Vector3.ZERO)


# --- Factory ---------------------------------------------------------------------------

func test_a_spawned_enemy_is_an_ordinary_ship_on_the_enemy_team() -> void:
	var enemy := _spawn(&"enemy_raider")
	assert_true(enemy is Ship)
	assert_eq(enemy.team, Ship.TEAM_ENEMY)
	assert_eq(enemy.hull.id, &"raider")
	assert_true(enemy.is_alive())
	assert_eq(enemy.global_position, Vector3(0, 0, -40))
	assert_eq(player.enemies(), [enemy])
	assert_eq(enemy.enemies(), [player])


func test_the_enemy_carries_exactly_its_recipe_loadout() -> void:
	var raider := _spawn(&"enemy_raider")
	assert_eq(raider.weapons().size(), 1, "the Raider has a single autocannon")
	assert_null(raider.weapon_at(0))
	assert_eq(raider.weapon_at(1).weapon.id, &"autocannon")
	var sniper := _spawn(&"enemy_longshot", Vector3(0, 0, -70))
	assert_eq(sniper.weapons().size(), 2)
	assert_eq(sniper.weapon_at(0).weapon.id, &"railgun")
	assert_eq(sniper.weapon_at(1).weapon.id, &"pulse_laser")
	assert_eq(sniper.weapon_at(0).instance.rarity, Rarity.Type.RARE)
	assert_eq(sniper.weapon_at(1).instance.rarity, Rarity.Type.COMMON)


func test_rarity_decides_how_many_rolled_lines_the_enemys_items_have() -> void:
	var enemy := _spawn(&"enemy_longshot")
	assert_eq(enemy.weapon_at(0).instance.rolls.size(), 1, "Rare railgun")
	assert_eq(enemy.weapon_at(1).instance.rolls.size(), 0, "Common pulse laser")


func test_rolled_stats_really_change_the_enemy_weapon() -> void:
	var enemy := _spawn(&"enemy_longshot")
	var controller := enemy.weapon_at(0)
	var base := WeaponStats.base(controller.weapon)
	var changed := false
	for stat: StringName in base:
		changed = changed or not is_equal_approx(float(controller.stats[stat]), float(base[stat]))
	assert_true(changed, "the Rare railgun's roll shows up in its stats")


func test_the_same_seed_builds_the_same_enemy() -> void:
	var a := _spawn(&"enemy_longshot", Vector3(0, 0, -40), 99)
	var b := _spawn(&"enemy_longshot", Vector3(0, 0, -60), 99)
	assert_eq(a.loadout.to_dict(), b.loadout.to_dict())


func test_different_seeds_roll_different_items() -> void:
	var seen := {}
	for seed_value in 12:
		var enemy := _spawn(&"enemy_longshot", Vector3(0, 0, -40 - seed_value * 5), seed_value)
		seen[JSON.stringify(enemy.loadout.to_dict())] = true
	assert_gt(seen.size(), 3)


func test_enemies_get_an_ai_controller_with_the_recipes_profile() -> void:
	var enemy := _spawn(&"enemy_raider")
	var ai := enemy.get_node("AIController") as AIController
	assert_not_null(ai)
	assert_eq(ai.profile.id, &"ai_brawler")
	assert_null(enemy.get_node_or_null("PhaseController"), "only bosses get one")


func test_the_boss_gets_a_phase_controller() -> void:
	var boss := _spawn(&"enemy_warden", Vector3(0, 0, -40))
	var phases := boss.get_node("PhaseController") as PhaseController
	assert_not_null(phases)
	assert_eq(phases.phases.size(), 1)
	assert_eq(phases.current_phase, 0)


func test_equip_spec_refuses_a_slot_the_hull_does_not_have() -> void:
	var enemy := _spawn(&"enemy_raider")
	var spec := ItemSpec.new()
	spec.item = ContentDB.get_by_id(&"pulse_laser") as ItemData
	spec.slot = &"No_Such_Slot"
	assert_false(EnemyFactory.equip_spec(enemy, spec, RandomNumberGenerator.new()))


func test_equip_spec_refuses_an_item_that_does_not_fit() -> void:
	var enemy := _spawn(&"enemy_raider")
	var spec := ItemSpec.new()
	spec.item = ContentDB.get_by_id(&"railgun") as ItemData
	spec.slot = &"Turret_A"  # Small slot
	assert_false(EnemyFactory.equip_spec(enemy, spec, RandomNumberGenerator.new()))
	assert_null(enemy.weapon_at(0), "the refused item was not mounted")
	assert_eq(enemy.weapon_at(1).weapon.id, &"autocannon", "and the existing gun is untouched")


func test_hardpoint_index_finds_markers_by_name() -> void:
	var hull := ContentDB.get_hull(&"warden")
	assert_eq(EnemyFactory.hardpoint_index(hull, &"Turret_A"), 0)
	assert_eq(EnemyFactory.hardpoint_index(hull, &"Turret_D"), 1)
	assert_eq(EnemyFactory.hardpoint_index(hull, &"nope"), -1)


# --- Boss phases -------------------------------------------------------------------------

func _boss() -> Ship:
	var boss := _spawn(&"enemy_warden")
	boss.health.shield = 0.0  # Make hits count on the hull.
	return boss


func test_the_boss_starts_in_its_first_phase_with_one_weapon() -> void:
	var boss := _boss()
	assert_eq(boss.weapons().size(), 1)
	assert_eq(boss.get_node("AIController").profile.id, &"ai_warden_guard")
	assert_eq(boss.get_node("PhaseController").current_phase, 0)


func test_dropping_to_half_hull_starts_the_phase() -> void:
	var boss := _boss()
	var phases := boss.get_node("PhaseController") as PhaseController
	watch_signals(phases)
	boss.health.apply_hit(_hit(300.0))  # 900 -> ~600: still above half
	assert_signal_not_emitted(phases, "phase_started")
	boss.health.apply_hit(_hit(200.0))  # ~400: below half
	assert_signal_emit_count(phases, "phase_started", 1)
	assert_eq(phases.current_phase, 1)


func test_a_phase_swaps_the_ai_profile() -> void:
	var boss := _boss()
	boss.health.apply_hit(_hit(500.0))
	assert_eq(boss.get_node("AIController").profile.id, &"ai_warden_enraged")


func test_a_phase_mounts_extra_weapons() -> void:
	var boss := _boss()
	assert_null(boss.weapon_at(1), "Turret_D starts empty")
	assert_null(boss.weapon_at(2), "and so does Turret_B")
	assert_eq(boss.weapon_at(0).weapon.id, &"autocannon")
	boss.health.apply_hit(_hit(500.0))
	assert_eq(boss.weapon_at(1).weapon.id, &"missile_pod")
	assert_eq(boss.weapon_at(2).weapon.id, &"pulse_laser")
	assert_eq(boss.weapon_at(0).weapon.id, &"autocannon", "the original gun stays")
	assert_eq(boss.weapons().size(), 3)


func test_a_phase_can_replace_the_item_in_a_slot() -> void:
	var boss := _boss()
	var spec := ItemSpec.new()
	spec.item = ContentDB.get_by_id(&"railgun") as ItemData
	spec.slot = &"Turret_A"
	assert_true(EnemyFactory.equip_spec(boss, spec, RandomNumberGenerator.new()))
	assert_eq(boss.weapon_at(0).weapon.id, &"railgun")


func test_a_phase_refills_the_shield() -> void:
	var boss := _boss()
	assert_eq(boss.health.shield, 0.0)
	boss.health.apply_hit(_hit(500.0))
	assert_eq(boss.health.shield, boss.health.max_shield())


func test_a_phase_triggers_only_once() -> void:
	var boss := _boss()
	var phases := boss.get_node("PhaseController") as PhaseController
	watch_signals(phases)
	boss.health.apply_hit(_hit(500.0))
	boss.health.shield = 0.0
	boss.health.apply_hit(_hit(100.0))
	boss.health.apply_hit(_hit(100.0))
	assert_signal_emit_count(phases, "phase_started", 1)


func test_the_phase_announces_itself_on_the_event_bus() -> void:
	var boss := _boss()
	watch_signals(EventBus)
	boss.health.apply_hit(_hit(500.0))
	assert_signal_emitted(EventBus, "phase_started")


func test_a_one_shot_kill_does_not_start_a_phase() -> void:
	var boss := _boss()
	var phases := boss.get_node("PhaseController") as PhaseController
	watch_signals(phases)
	boss.health.apply_hit(_hit(5000.0))
	assert_false(boss.is_alive())
	assert_signal_not_emitted(phases, "phase_started")
