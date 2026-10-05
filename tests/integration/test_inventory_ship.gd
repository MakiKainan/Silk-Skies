extends "res://tests/helpers/ship_test.gd"
## Customization on a real ship: equipping items changes its stats, health maximums and
## weapons; swapping hulls keeps the gear.
## Starter frigate: 0 Small turret, 1 Large turret, 2 bay, 3 techmod, 4 crew.

const SLOT := ShipLoadout.Kind.SLOT
const CARGO := ShipLoadout.Kind.CARGO

var ship: Ship


func before_each() -> void:
	ship = make_ship(Ship.TEAM_PLAYER, Vector3.ZERO)


func _item(id: StringName, rarity: Rarity.Type = Rarity.Type.COMMON, rolls: Array[StatMod] = []) -> ItemInstance:
	return ItemInstance.make(ContentDB.get_by_id(id) as ItemData, rarity, rolls)


func test_a_techmod_changes_the_ships_stats_and_health_maximums() -> void:
	assert_eq(ship.health.max_shield(), 100.0)
	ship.equip_item(3, _item(&"shield_capacitor"))
	assert_eq(ship.stats.get_stat(Stats.MAX_SHIELD), 150.0)
	assert_eq(ship.stats.get_stat(Stats.SHIELD_REGEN), 12.0)
	assert_eq(ship.health.shield, 150.0, "the new capacity arrives full")


func test_removing_the_techmod_puts_everything_back() -> void:
	ship.equip_item(3, _item(&"shield_capacitor"))
	ship.loadout.take(SLOT, 3)
	assert_eq(ship.stats.get_stat(Stats.MAX_SHIELD), 100.0)
	assert_eq(ship.health.shield, 100.0, "current shield is clamped back down")


func test_extra_capacity_does_not_refill_a_damaged_ship_beyond_the_bonus() -> void:
	ship.health.shield = 40.0
	ship.equip_item(3, _item(&"shield_capacitor"))
	assert_eq(ship.health.shield, 90.0, "40 + the 50 added")


func test_armor_plating_trades_mass_for_toughness() -> void:
	var hull := ship.hull
	ship.equip_item(3, _item(&"armor_plating"))
	assert_eq(ship.health.armor(), hull.armor + 2.0)
	assert_eq(ship.stats.get_stat(Stats.MASS), hull.mass + 20.0)
	assert_eq(ship.stats.get_stat(Stats.MAX_HULL), hull.max_hull + 50.0)
	assert_eq(ship.health.hull, hull.max_hull + 50.0)


func test_a_heavier_ship_accelerates_slower() -> void:
	var before := ship.stats.get_stat(Stats.THRUST) / ship.stats.get_stat(Stats.MASS)
	ship.equip_item(3, _item(&"armor_plating"))
	assert_lt(ship.stats.get_stat(Stats.THRUST) / ship.stats.get_stat(Stats.MASS), before)


func test_the_gunner_speeds_up_every_turret() -> void:
	ship.equip(0, weapon(&"pulse_laser"))
	ship.equip(1, weapon(&"railgun"))
	var laser_before := ship.weapon_at(0).cooldown_seconds()
	var rail_before := ship.weapon_at(1).cooldown_seconds()
	ship.equip_item(4, _item(&"gunner"))
	assert_almost_eq(ship.weapon_at(0).cooldown_seconds(), laser_before / 1.15, 0.0001)
	assert_almost_eq(ship.weapon_at(1).cooldown_seconds(), rail_before / 1.15, 0.0001)
	ship.loadout.take(SLOT, 4)
	assert_almost_eq(ship.weapon_at(0).cooldown_seconds(), laser_before, 0.0001, "the bonus leaves with the crew")


func test_the_engineer_boosts_the_capacitor() -> void:
	ship.equip_item(3, _item(&"shield_capacitor"))
	ship.equip_item(4, _item(&"engineer"))
	assert_almost_eq(ship.stats.get_stat(Stats.MAX_SHIELD), 100.0 + 62.5, 0.001)
	assert_almost_eq(ship.stats.get_stat(Stats.TECHMOD_POTENCY), 0.25, 0.0001)


func test_a_rolled_damage_bonus_reaches_the_projectile() -> void:
	var rolls: Array[StatMod] = [StatMod.make(Stats.DAMAGE, StatMod.Op.PERCENT, 0.2, StatMod.Scope.THIS_ITEM)]
	ship.equip_item(0, _item(&"pulse_laser", Rarity.Type.RARE, rolls))
	var enemy := make_ship(Ship.TEAM_ENEMY, Vector3(0, 0, -20))
	var gun := ship.weapon_at(0)
	assert_almost_eq(gun.shot_damage(), gun.weapon.projectile.damage * 1.2, 0.0001)
	gun.step(0.016)
	assert_almost_eq((projectiles()[0] as Projectile)._damage_value, gun.weapon.projectile.damage * 1.2, 0.0001)
	assert_eq(enemy.health.shield, 100.0, "(not landed yet)")


func test_one_weapons_roll_does_not_buff_its_neighbour() -> void:
	var rolls: Array[StatMod] = [StatMod.make(Stats.DAMAGE, StatMod.Op.PERCENT, 0.5, StatMod.Scope.THIS_ITEM)]
	ship.equip_item(0, _item(&"pulse_laser", Rarity.Type.RARE, rolls))
	ship.equip_item(1, _item(&"autocannon"))
	assert_almost_eq(ship.weapon_at(1).shot_damage(), ship.weapon_at(1).weapon.projectile.damage, 0.0001)


func test_a_range_bonus_extends_targeting_and_shot_lifetime() -> void:
	var rolls: Array[StatMod] = [StatMod.make(Stats.RANGE, StatMod.Op.PERCENT, 0.25, StatMod.Scope.THIS_ITEM)]
	ship.equip_item(0, _item(&"pulse_laser", Rarity.Type.RARE, rolls))
	var gun := ship.weapon_at(0)
	assert_almost_eq(gun.effective_range(), gun.weapon.range * 1.25, 0.0001)
	make_ship(Ship.TEAM_ENEMY, Vector3(0, 0, -45))  # Beyond the base 38, inside 47.5
	gun.step(0.016)
	assert_eq(projectiles().size(), 1)
	assert_almost_eq((projectiles()[0] as Projectile)._lifetime, gun.weapon.projectile.lifetime * 1.25, 0.0001)


func test_moving_an_item_in_the_loadout_updates_the_ship() -> void:
	ship.loadout.add_to_cargo(_item(&"autocannon"))
	assert_null(ship.weapon_at(0))
	ship.loadout.move(CARGO, 0, SLOT, 0)
	assert_not_null(ship.weapon_at(0))
	assert_eq(ship.weapon_at(0).weapon.id, &"autocannon")
	ship.loadout.move(SLOT, 0, CARGO, 3)
	assert_null(ship.weapon_at(0))


func test_loadout_changed_fires_when_gear_moves() -> void:
	watch_signals(ship)
	ship.loadout.add_to_cargo(_item(&"autocannon"))
	ship.loadout.move(CARGO, 0, SLOT, 0)
	assert_signal_emit_count(ship, "loadout_changed", 2)


func test_swapping_a_weapon_between_slots_keeps_it_the_same_drop() -> void:
	var rolls: Array[StatMod] = [StatMod.make(Stats.DAMAGE, StatMod.Op.PERCENT, 0.2, StatMod.Scope.THIS_ITEM)]
	var laser := _item(&"pulse_laser", Rarity.Type.RARE, rolls)
	ship.equip_item(0, laser)
	ship.loadout.move(SLOT, 0, SLOT, 1)
	assert_eq(ship.weapon_at(1).instance, laser)
	assert_almost_eq(ship.weapon_at(1).shot_damage(), laser.data().projectile.damage * 1.2, 0.0001)


func test_a_hull_swap_keeps_the_gear_that_fits() -> void:
	var laser := _item(&"pulse_laser")
	ship.equip_item(0, laser)
	ship.equip_item(1, _item(&"railgun"))
	ship.equip_item(3, _item(&"shield_capacitor"))
	ship.swap_hull(ContentDB.get_hull(&"debug_skiff"))  # Small turret + techmod
	assert_eq(ship.hull.id, &"debug_skiff")
	assert_eq(ship.weapon_at(0).instance, laser)
	assert_eq(ship.stats.get_stat(Stats.MAX_SHIELD), 60.0 + 50.0, "skiff shield plus the capacitor")
	assert_true(ship.loadout.cargo.any(func(i: ItemInstance) -> bool: return i != null and i.data_id == &"railgun"), "the railgun waits in cargo")
	await wait_physics_frames(1)


func test_a_fresh_ship_has_the_run_cargo_size_unless_told_otherwise() -> void:
	assert_eq(ship.loadout.cargo.size(), ShipLoadout.RUN_CARGO_SLOTS)
	var roomy := SHIP_SCENE.instantiate() as Ship
	roomy.cargo_capacity = 12
	add_child_autofree(roomy)
	roomy.setup(ContentDB.get_hull(&"starter_frigate"))
	assert_eq(roomy.loadout.cargo.size(), 12)


func test_tuning_panel_reset_keeps_the_loadouts_bonuses() -> void:
	ship.equip_item(3, _item(&"shield_capacitor"))
	ship.stats.set_base_stat(Stats.MAX_SHIELD, 999.0)
	ship.refresh_stats()
	assert_eq(ship.stats.get_stat(Stats.MAX_SHIELD), 150.0)


func test_non_weapon_items_never_spawn_weapon_controllers() -> void:
	ship.equip_item(2, _item(&"strike_bay"))
	ship.equip_item(3, _item(&"emp_emitter"))
	ship.equip_item(4, _item(&"gunner"))
	assert_eq(ship.weapons().size(), 0)


func test_equipping_the_wrong_kind_of_item_is_refused() -> void:
	assert_false(ship.equip_item(0, _item(&"shield_capacitor")))
	assert_false(ship.equip_item(0, _item(&"railgun")), "Large weapon, Small turret")
	assert_true(ship.equip_item(0, _item(&"pulse_laser")))
	assert_eq(ship.weapons().size(), 1)
