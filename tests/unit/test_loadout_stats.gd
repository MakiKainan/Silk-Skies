extends GutTest
## How equipped items turn into stat modifiers; WeaponStats; and stat formatting.


func _item(id: StringName, rarity: Rarity.Type = Rarity.Type.COMMON, rolls: Array[StatMod] = []) -> ItemInstance:
	return ItemInstance.make(ContentDB.get_by_id(id) as ItemData, rarity, rolls)


func _items(list: Array) -> Array[ItemInstance]:
	var out: Array[ItemInstance] = []
	out.assign(list)
	return out


func _value(mods: Array[StatMod], stat: StringName) -> float:
	var total := 0.0
	for mod in mods:
		if mod.stat == stat:
			total += mod.value
	return total


# --- LoadoutStats --------------------------------------------------------------------

func test_ship_and_turret_scoped_mods_are_global() -> void:
	var mods := LoadoutStats.global_mods(_items([_item(&"shield_capacitor"), _item(&"gunner")]))
	assert_eq(_value(mods, Stats.MAX_SHIELD), 50.0)
	assert_almost_eq(_value(mods, Stats.FIRE_RATE), 0.15, 0.0001)


func test_this_item_mods_never_leak_to_the_rest_of_the_ship() -> void:
	var rolls: Array[StatMod] = [StatMod.make(Stats.DAMAGE, StatMod.Op.PERCENT, 0.2, StatMod.Scope.THIS_ITEM)]
	var laser := _item(&"pulse_laser", Rarity.Type.RARE, rolls)
	assert_eq(LoadoutStats.global_mods(_items([laser])).size(), 0)
	assert_eq(LoadoutStats.own_mods(laser).size(), 1)


func test_own_mods_are_only_this_item_lines() -> void:
	var rolls: Array[StatMod] = [
		StatMod.make(Stats.DAMAGE, StatMod.Op.PERCENT, 0.2, StatMod.Scope.THIS_ITEM),
		StatMod.make(Stats.MAX_HULL, StatMod.Op.FLAT, 20.0, StatMod.Scope.SHIP),
	]
	var item := _item(&"pulse_laser", Rarity.Type.EPIC, rolls)
	var own := LoadoutStats.own_mods(item)
	assert_eq(own.size(), 1)
	assert_eq(own[0].stat, Stats.DAMAGE)
	assert_eq(LoadoutStats.own_mods(null).size(), 0)


func test_the_engineer_scales_techmod_effects() -> void:
	var without := LoadoutStats.global_mods(_items([_item(&"shield_capacitor")]))
	var with_engineer := LoadoutStats.global_mods(_items([_item(&"shield_capacitor"), _item(&"engineer")]))
	assert_eq(_value(without, Stats.MAX_SHIELD), 50.0)
	assert_almost_eq(_value(with_engineer, Stats.MAX_SHIELD), 62.5, 0.001, "+25% potency")
	assert_almost_eq(_value(with_engineer, Stats.SHIELD_REGEN), 5.0, 0.001)


func test_potency_does_not_scale_crew_or_weapons_or_itself() -> void:
	var mods := LoadoutStats.global_mods(_items([_item(&"engineer"), _item(&"gunner"), _item(&"pulse_laser")]))
	assert_almost_eq(_value(mods, Stats.FIRE_RATE), 0.15, 0.0001, "the Gunner's bonus is not a techmod effect")
	assert_almost_eq(_value(mods, Stats.TECHMOD_POTENCY), 0.25, 0.0001)


func test_potency_scales_techmod_rolls_too() -> void:
	var rolls: Array[StatMod] = [StatMod.make(Stats.ARMOR, StatMod.Op.FLAT, 2.0, StatMod.Scope.SHIP)]
	var plating := _item(&"armor_plating", Rarity.Type.RARE, rolls)  # base armor +2, roll armor +2
	var mods := LoadoutStats.global_mods(_items([plating, _item(&"engineer")]))
	assert_almost_eq(_value(mods, Stats.ARMOR), 5.0, 0.001, "(2 + 2) * 1.25")


func test_two_engineers_stack_potency() -> void:
	var mods := LoadoutStats.global_mods(_items([_item(&"shield_capacitor"), _item(&"engineer"), _item(&"engineer")]))
	assert_almost_eq(_value(mods, Stats.MAX_SHIELD), 75.0, 0.001, "+50% potency")


func test_the_aggregate_of_global_mods_changes_ship_stats() -> void:
	var hull := ContentDB.get_hull(&"starter_frigate")
	var mods := LoadoutStats.global_mods(_items([_item(&"armor_plating")]))
	var final := StatAggregator.aggregate(hull.base_stats(), mods)
	assert_eq(final[Stats.ARMOR], hull.armor + 2.0)
	assert_eq(final[Stats.MASS], hull.mass + 20.0)
	assert_eq(final[Stats.MAX_HULL], hull.max_hull + 50.0)
	assert_eq(final[Stats.THRUST], hull.thrust, "untouched stats stay put")


# --- WeaponStats ---------------------------------------------------------------------

func test_weapon_base_stats_come_from_its_data() -> void:
	var laser := ContentDB.get_by_id(&"pulse_laser") as WeaponData
	var stats := WeaponStats.base(laser)
	assert_eq(stats[Stats.DAMAGE], laser.projectile.damage)
	assert_almost_eq(float(stats[Stats.FIRE_RATE]), 1.0 / laser.cooldown, 0.0001)
	assert_eq(stats[Stats.RANGE], laser.range)
	assert_eq(stats[Stats.PROJECTILE_SPEED], laser.projectile.speed)


func test_own_rolls_and_global_bonuses_both_apply() -> void:
	var laser := ContentDB.get_by_id(&"pulse_laser") as WeaponData
	var own: Array[StatMod] = [StatMod.make(Stats.DAMAGE, StatMod.Op.PERCENT, 0.1, StatMod.Scope.THIS_ITEM)]
	var global: Array[StatMod] = [StatMod.make(Stats.FIRE_RATE, StatMod.Op.PERCENT, 0.15, StatMod.Scope.ALL_TURRETS)]
	var stats := WeaponStats.compute(laser, own, global)
	assert_almost_eq(float(stats[Stats.DAMAGE]), laser.projectile.damage * 1.1, 0.0001)
	assert_almost_eq(float(stats[Stats.FIRE_RATE]), 1.0 / laser.cooldown * 1.15, 0.0001)


func test_dps_counts_every_missile_in_a_salvo() -> void:
	var pod := ContentDB.get_by_id(&"missile_pod") as WeaponData
	var dps := WeaponStats.dps(pod, WeaponStats.base(pod))
	assert_almost_eq(dps, 14.0 * 4.0 / 6.0, 0.001)


# --- StatInfo ------------------------------------------------------------------------

func test_value_formatting() -> void:
	assert_eq(StatInfo.format_value(Stats.MAX_SHIELD, 150.0), "150")
	assert_eq(StatInfo.format_value(Stats.SHIELD_REGEN, 9.5), "9.5/s")
	assert_eq(StatInfo.format_value(Stats.SHIELD_REGEN, 8.0), "8/s")
	assert_eq(StatInfo.format_value(Stats.TECHMOD_POTENCY, 0.25), "25%")


func test_modifier_formatting() -> void:
	assert_eq(StatInfo.format_mod(StatMod.make(Stats.MAX_SHIELD, StatMod.Op.FLAT, 50.0, StatMod.Scope.SHIP)), "+50 Shield")
	assert_eq(StatInfo.format_mod(StatMod.make(Stats.FIRE_RATE, StatMod.Op.PERCENT, 0.15, StatMod.Scope.ALL_TURRETS)), "+15% Fire rate (all turrets)")
	assert_eq(StatInfo.format_mod(StatMod.make(Stats.DAMAGE, StatMod.Op.PERCENT, 0.12, StatMod.Scope.THIS_ITEM)), "+12% Damage")


func test_delta_formatting_and_direction() -> void:
	assert_eq(StatInfo.format_delta(Stats.MAX_SHIELD, 50.0), "+50")
	assert_eq(StatInfo.format_delta(Stats.MASS, -10.0), "-10")
	assert_eq(StatInfo.format_delta(Stats.MAX_SHIELD, 0.0), "", "no change shows nothing")
	assert_true(StatInfo.higher_is_better(Stats.MAX_HULL))
	assert_false(StatInfo.higher_is_better(Stats.MASS), "lighter is better")
	assert_false(StatInfo.higher_is_better(Stats.BURN_COOLDOWN))


func test_potency_shows_as_a_percentage_in_tooltips() -> void:
	var engineer := ContentDB.get_by_id(&"engineer") as CrewData
	assert_eq(StatInfo.format_mod(engineer.base_mods[0]), "+25% Techmod potency")


func test_potency_delta_shows_a_percent_sign() -> void:
	assert_eq(StatInfo.format_delta(Stats.TECHMOD_POTENCY, 0.25), "+25%")
