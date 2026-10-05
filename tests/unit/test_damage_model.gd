extends GutTest
## Spec 2.2: shields -> armor -> hull, plus the damage-type multiplier table.

const E := Damage.Type.ENERGY
const K := Damage.Type.KINETIC
const X := Damage.Type.EXPLOSIVE


# --- Multipliers against each layer ----------------------------------------------------

func test_energy_is_strong_against_shields() -> void:
	var r := DamageModel.resolve(10.0, E, 100.0, 0.0, 100.0)
	assert_almost_eq(r.shield_damage, 15.0, 0.001)
	assert_almost_eq(r.shield_left, 85.0, 0.001)
	assert_eq(r.hull_damage, 0.0)


func test_kinetic_is_weak_against_shields() -> void:
	assert_almost_eq(DamageModel.resolve(10.0, K, 100.0, 0.0, 100.0).shield_damage, 7.5, 0.001)


func test_explosive_is_very_weak_against_shields() -> void:
	assert_almost_eq(DamageModel.resolve(10.0, X, 100.0, 0.0, 100.0).shield_damage, 5.0, 0.001)


func test_energy_is_weak_against_hull() -> void:
	assert_almost_eq(DamageModel.resolve(10.0, E, 0.0, 0.0, 100.0).hull_damage, 7.5, 0.001)


func test_kinetic_is_normal_against_hull() -> void:
	assert_almost_eq(DamageModel.resolve(10.0, K, 0.0, 0.0, 100.0).hull_damage, 10.0, 0.001)


func test_explosive_is_strong_against_hull() -> void:
	assert_almost_eq(DamageModel.resolve(10.0, X, 0.0, 0.0, 100.0).hull_damage, 15.0, 0.001)


# --- Armor ---------------------------------------------------------------------------

func test_armor_removes_a_flat_amount_per_hit() -> void:
	var r := DamageModel.resolve(10.0, E, 0.0, 4.0, 100.0)
	assert_almost_eq(r.armor_absorbed, 4.0, 0.001)
	assert_almost_eq(r.hull_damage, 6.0 * 0.75, 0.001, "(10 - 4) then the energy hull multiplier")


func test_kinetic_ignores_half_the_armor() -> void:
	var r := DamageModel.resolve(10.0, K, 0.0, 4.0, 100.0)
	assert_almost_eq(r.armor_absorbed, 2.0, 0.001)
	assert_almost_eq(r.hull_damage, 8.0, 0.001)


func test_explosive_gets_full_armor_reduction() -> void:
	var r := DamageModel.resolve(10.0, X, 0.0, 4.0, 100.0)
	assert_almost_eq(r.armor_absorbed, 4.0, 0.001)
	assert_almost_eq(r.hull_damage, 6.0 * 1.5, 0.001)


func test_a_hit_that_reaches_armor_always_does_at_least_one_damage() -> void:
	var r := DamageModel.resolve(3.0, K, 0.0, 50.0, 100.0)
	assert_almost_eq(r.hull_damage, 1.0, 0.001, "armor 50 cannot reduce a 3-damage kinetic hit below 1")
	var weak := DamageModel.resolve(3.0, E, 0.0, 50.0, 100.0)
	assert_almost_eq(weak.hull_damage, 0.75, 0.001, "min 1 is applied before the energy hull multiplier")


func test_the_minimum_never_exceeds_what_was_left() -> void:
	var r := DamageModel.resolve(0.4, K, 0.0, 50.0, 100.0)
	assert_almost_eq(r.hull_damage, 0.4, 0.001, "a 0.4 hit can't become 1")


func test_armor_does_nothing_while_the_shield_absorbs_the_whole_hit() -> void:
	var r := DamageModel.resolve(10.0, K, 100.0, 50.0, 100.0)
	assert_eq(r.armor_absorbed, 0.0)
	assert_eq(r.hull_damage, 0.0)


# --- Layer order and overflow ----------------------------------------------------------

func test_damage_goes_shield_then_armor_then_hull() -> void:
	# Kinetic 20 vs shield 6: shield needs 20 * 0.75 = 15 to stop it; 6 of 15 absorbed
	# leaves 60% of the hit = 12 raw, then armor 4 (kinetic ignores half: 2) -> 10, hull x1.
	var r := DamageModel.resolve(20.0, K, 6.0, 4.0, 100.0)
	assert_almost_eq(r.shield_damage, 6.0, 0.001)
	assert_eq(r.shield_left, 0.0)
	assert_almost_eq(r.armor_absorbed, 2.0, 0.001)
	assert_almost_eq(r.hull_damage, 10.0, 0.001)
	assert_almost_eq(r.hull_left, 90.0, 0.001)


func test_overflow_never_applies_a_multiplier_twice() -> void:
	# Energy 10 vs shield 7.5: it needs 15 to stop it, so exactly half the raw hit is left.
	var r := DamageModel.resolve(10.0, E, 7.5, 0.0, 100.0)
	assert_almost_eq(r.shield_damage, 7.5, 0.001)
	assert_almost_eq(r.hull_damage, 5.0 * 0.75, 0.001)


func test_a_hit_the_shield_exactly_absorbs_leaves_the_hull_alone() -> void:
	var r := DamageModel.resolve(10.0, E, 15.0, 3.0, 100.0)
	assert_eq(r.shield_left, 0.0)
	assert_eq(r.hull_damage, 0.0)
	assert_eq(r.armor_absorbed, 0.0)


func test_zero_shield_skips_straight_to_armor() -> void:
	var r := DamageModel.resolve(10.0, X, 0.0, 4.0, 100.0)
	assert_eq(r.shield_damage, 0.0)
	assert_gt(r.hull_damage, 0.0)


# --- Destruction -----------------------------------------------------------------------

func test_hull_reaching_zero_destroys_the_ship() -> void:
	var r := DamageModel.resolve(100.0, K, 0.0, 0.0, 30.0)
	assert_true(r.destroyed)
	assert_eq(r.hull_left, 0.0)
	assert_almost_eq(r.hull_damage, 30.0, 0.001, "damage dealt is capped at the hull that was left")


func test_a_ship_that_survives_is_not_destroyed() -> void:
	assert_false(DamageModel.resolve(10.0, K, 0.0, 0.0, 30.0).destroyed)


func test_a_hit_absorbed_by_shields_never_destroys() -> void:
	assert_false(DamageModel.resolve(10.0, K, 100.0, 0.0, 1.0).destroyed)


func test_zero_damage_changes_nothing() -> void:
	var r := DamageModel.resolve(0.0, K, 10.0, 3.0, 20.0)
	assert_eq(r.shield_left, 10.0)
	assert_eq(r.hull_left, 20.0)
	assert_eq(r.total_dealt(), 0.0)
