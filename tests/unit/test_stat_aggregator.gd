extends GutTest

const THRUST := Stats.THRUST


func _mod(op: StatMod.Op, value: float, scope: StatMod.Scope = StatMod.Scope.SHIP) -> StatMod:
	return StatMod.make(THRUST, op, value, scope)


func _mods(list: Array) -> Array[StatMod]:
	var typed: Array[StatMod] = []
	typed.assign(list)
	return typed


func test_no_mods_returns_base_unchanged() -> void:
	var out := StatAggregator.aggregate({THRUST: 100.0, Stats.MASS: 50.0}, _mods([]))
	assert_eq(out[THRUST], 100.0)
	assert_eq(out[Stats.MASS], 50.0)


func test_flat_adds_to_base() -> void:
	var out := StatAggregator.aggregate({THRUST: 100.0}, _mods([_mod(StatMod.Op.FLAT, 25.0)]))
	assert_eq(out[THRUST], 125.0)


func test_percent_scales_base() -> void:
	var out := StatAggregator.aggregate({THRUST: 100.0}, _mods([_mod(StatMod.Op.PERCENT, 0.25)]))
	assert_almost_eq(float(out[THRUST]), 125.0, 0.0001)


func test_flat_applies_before_percent() -> void:
	# (100 + 20) * 1.5 = 180. Percent-first would give 100 * 1.5 + 20 = 170.
	var out := StatAggregator.aggregate(
		{THRUST: 100.0},
		_mods([_mod(StatMod.Op.PERCENT, 0.5), _mod(StatMod.Op.FLAT, 20.0)]),
	)
	assert_almost_eq(float(out[THRUST]), 180.0, 0.0001)


func test_percent_mods_add_together_not_multiply() -> void:
	var out := StatAggregator.aggregate(
		{THRUST: 100.0},
		_mods([_mod(StatMod.Op.PERCENT, 0.25), _mod(StatMod.Op.PERCENT, 0.25)]),
	)
	assert_almost_eq(float(out[THRUST]), 150.0, 0.0001, "1.25 * 1.25 would be 156.25")


func test_negative_percent_reduces() -> void:
	var out := StatAggregator.aggregate({THRUST: 100.0}, _mods([_mod(StatMod.Op.PERCENT, -0.15)]))
	assert_almost_eq(float(out[THRUST]), 85.0, 0.0001)


func test_mods_only_touch_their_own_stat() -> void:
	var out := StatAggregator.aggregate({THRUST: 100.0, Stats.MASS: 50.0}, _mods([_mod(StatMod.Op.FLAT, 10.0)]))
	assert_eq(out[Stats.MASS], 50.0)


func test_scope_filters_which_mods_apply() -> void:
	var base := {THRUST: 100.0}
	var mods := _mods([
		_mod(StatMod.Op.FLAT, 10.0, StatMod.Scope.SHIP),
		_mod(StatMod.Op.FLAT, 20.0, StatMod.Scope.THIS_ITEM),
		_mod(StatMod.Op.FLAT, 40.0, StatMod.Scope.ALL_TURRETS),
	])
	assert_eq(StatAggregator.aggregate(base, mods)[THRUST], 110.0, "ship stats take SHIP scope only by default")
	var weapon_scopes := [StatMod.Scope.SHIP, StatMod.Scope.THIS_ITEM, StatMod.Scope.ALL_TURRETS]
	assert_eq(StatAggregator.aggregate(base, mods, weapon_scopes)[THRUST], 170.0)


func test_stat_missing_from_base_counts_as_zero() -> void:
	var out := StatAggregator.aggregate({}, _mods([_mod(StatMod.Op.FLAT, 5.0)]))
	assert_eq(out[THRUST], 5.0)


func test_aggregation_does_not_mutate_the_base() -> void:
	var base := {THRUST: 100.0}
	StatAggregator.aggregate(base, _mods([_mod(StatMod.Op.FLAT, 25.0)]))
	assert_eq(base[THRUST], 100.0)


func test_stats_component_recomputes_on_loadout_change() -> void:
	var hull := HullData.new()
	hull.thrust = 900.0
	var component := StatsComponent.new()
	add_child_autofree(component)
	component.setup(hull)
	assert_eq(component.get_stat(Stats.THRUST), 900.0)

	watch_signals(component)
	component.set_mods(_mods([_mod(StatMod.Op.PERCENT, 0.1)]))
	assert_almost_eq(component.get_stat(Stats.THRUST), 990.0, 0.001)
	assert_signal_emitted(component, "stats_changed")


func test_stats_component_override_never_touches_the_hull_resource() -> void:
	var hull := HullData.new()
	hull.thrust = 900.0
	var component := StatsComponent.new()
	add_child_autofree(component)
	component.setup(hull)
	component.set_base_stat(Stats.THRUST, 1500.0)
	assert_eq(component.get_stat(Stats.THRUST), 1500.0)
	assert_eq(hull.thrust, 900.0, "authored data stays read-only at runtime")
