extends GutTest
## ItemInstance (rarity + rolls, saving) and ItemRoller (deterministic rolls, spec 5.2 / 5.8).


func _item(id: StringName) -> ItemData:
	return ContentDB.get_by_id(id) as ItemData


func _roll(id: StringName, rarity: Rarity.Type, seed_value: int = 1) -> ItemInstance:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return ItemRoller.roll(_item(id), rarity, rng)


# --- ItemInstance ----------------------------------------------------------------------

func test_make_records_the_definition_rarity_and_rolls() -> void:
	var rolls: Array[StatMod] = [StatMod.make(Stats.ARMOR, StatMod.Op.FLAT, 1.5)]
	var item := ItemInstance.make(_item(&"shield_capacitor"), Rarity.Type.RARE, rolls)
	assert_eq(item.data_id, &"shield_capacitor")
	assert_eq(item.rarity, Rarity.Type.RARE)
	assert_eq(item.rolls.size(), 1)
	assert_eq(item.display_name(), "Shield Capacitor")


func test_all_mods_lists_built_in_effects_then_rolls() -> void:
	var rolls: Array[StatMod] = [StatMod.make(Stats.ARMOR, StatMod.Op.FLAT, 1.5)]
	var item := ItemInstance.make(_item(&"shield_capacitor"), Rarity.Type.RARE, rolls)
	var mods := item.all_mods()
	assert_eq(mods.size(), 3, "capacitor has two built-in effects plus one roll")
	assert_eq(mods[2].stat, Stats.ARMOR)


func test_instances_do_not_share_their_roll_list() -> void:
	var rolls: Array[StatMod] = [StatMod.make(Stats.ARMOR, StatMod.Op.FLAT, 1.0)]
	var item := ItemInstance.make(_item(&"shield_capacitor"), Rarity.Type.RARE, rolls)
	rolls.clear()
	assert_eq(item.rolls.size(), 1)


func test_save_round_trip_keeps_everything() -> void:
	var rolls: Array[StatMod] = [
		StatMod.make(Stats.DAMAGE, StatMod.Op.PERCENT, 0.18, StatMod.Scope.THIS_ITEM),
		StatMod.make(Stats.FIRE_RATE, StatMod.Op.PERCENT, 0.12, StatMod.Scope.ALL_TURRETS),
	]
	var original := ItemInstance.make(_item(&"railgun"), Rarity.Type.EPIC, rolls)
	var copy := ItemInstance.from_dict(original.to_dict())
	assert_eq(copy.data_id, &"railgun")
	assert_eq(copy.rarity, Rarity.Type.EPIC)
	assert_eq(copy.rolls.size(), 2)
	for i in 2:
		assert_eq(copy.rolls[i].stat, original.rolls[i].stat)
		assert_eq(copy.rolls[i].op, original.rolls[i].op)
		assert_eq(copy.rolls[i].scope, original.rolls[i].scope)
		assert_almost_eq(copy.rolls[i].value, original.rolls[i].value, 0.0001)


func test_save_survives_a_trip_through_json() -> void:
	var rolls: Array[StatMod] = [StatMod.make(Stats.MAX_SHIELD, StatMod.Op.FLAT, 12.5, StatMod.Scope.SHIP)]
	var original := ItemInstance.make(_item(&"shield_capacitor"), Rarity.Type.RARE, rolls)
	var text := JSON.stringify(original.to_dict())
	var copy := ItemInstance.from_dict(JSON.parse_string(text))
	assert_not_null(copy)
	assert_eq(copy.rarity, Rarity.Type.RARE)
	assert_eq(copy.rolls[0].op, StatMod.Op.FLAT)
	assert_eq(copy.rolls[0].scope, StatMod.Scope.SHIP)
	assert_almost_eq(copy.rolls[0].value, 12.5, 0.0001)


func test_unknown_item_id_is_skipped_not_a_crash() -> void:
	var gone := ItemInstance.from_dict({"data_id": "removed_in_a_patch", "rarity": 1, "rolls": []})
	assert_null(gone)


func test_a_custom_lookup_can_supply_definitions() -> void:
	var fake := TechmodData.new()
	fake.id = &"fake"
	var item := ItemInstance.from_dict({"data_id": "fake", "rarity": 0, "rolls": []}, func(id: StringName) -> ItemData: return fake if id == &"fake" else null)
	assert_not_null(item)
	assert_eq(item.data(), fake)


# --- ItemRoller ------------------------------------------------------------------------

func test_rarity_decides_the_number_of_rolled_lines() -> void:
	assert_eq(_roll(&"pulse_laser", Rarity.Type.COMMON).rolls.size(), 0)
	assert_eq(_roll(&"pulse_laser", Rarity.Type.RARE).rolls.size(), 1)
	assert_eq(_roll(&"pulse_laser", Rarity.Type.EPIC).rolls.size(), 2)
	assert_eq(_roll(&"pulse_laser", Rarity.Type.LEGENDARY).rolls.size(), 2)


func test_rolled_lines_are_distinct_stats() -> void:
	for seed_value in 30:
		var item := _roll(&"pulse_laser", Rarity.Type.EPIC, seed_value)
		assert_ne(item.rolls[0].stat, item.rolls[1].stat, "seed %d rolled the same stat twice" % seed_value)


func test_the_same_seed_gives_the_same_drop() -> void:
	var a := _roll(&"autocannon", Rarity.Type.EPIC, 99)
	var b := _roll(&"autocannon", Rarity.Type.EPIC, 99)
	assert_eq(a.to_dict(), b.to_dict())


func test_different_seeds_give_different_drops() -> void:
	var seen := {}
	for seed_value in 20:
		seen[JSON.stringify(_roll(&"autocannon", Rarity.Type.EPIC, seed_value).to_dict())] = true
	assert_gt(seen.size(), 10)


func test_rare_values_stay_inside_the_template_range() -> void:
	var pool := _item(&"pulse_laser").roll_pool
	for seed_value in 60:
		var line := _roll(&"pulse_laser", Rarity.Type.RARE, seed_value).rolls[0]
		var template: RollTemplate
		for candidate in pool.templates:
			if candidate.stat == line.stat:
				template = candidate
		assert_not_null(template)
		assert_gte(line.value, template.min_value - 0.011)
		assert_lte(line.value, template.max_value + 0.011)
		assert_eq(line.op, template.op)
		assert_eq(line.scope, template.scope)


func test_epic_rolls_are_bigger_than_rare_rolls_of_the_same_template() -> void:
	var template := RollTemplate.new()
	template.stat = Stats.DAMAGE
	template.min_value = 0.10
	template.max_value = 0.10
	var pool := RollPool.new()
	pool.templates = [template]
	var data := WeaponData.new()
	data.roll_pool = pool
	var rng := RandomNumberGenerator.new()
	var rare := ItemRoller.roll(data, Rarity.Type.RARE, rng).rolls[0].value
	var epic := ItemRoller.roll(data, Rarity.Type.EPIC, rng).rolls[0].value
	assert_almost_eq(rare, 0.10, 0.0001)
	assert_almost_eq(epic, 0.15, 0.0001, "Epic is %sx" % Rarity.EPIC_SCALE)


func test_percent_rolls_are_rounded_to_whole_percent() -> void:
	for seed_value in 20:
		var value := _roll(&"pulse_laser", Rarity.Type.RARE, seed_value).rolls[0].value
		assert_almost_eq(value, snappedf(value, 0.01), 0.00001)


func test_an_item_without_a_pool_never_rolls() -> void:
	var data := TechmodData.new()
	data.id = &"plain"
	var item := ItemRoller.roll(data, Rarity.Type.EPIC, RandomNumberGenerator.new())
	assert_eq(item.rolls.size(), 0)
	assert_eq(item.rarity, Rarity.Type.EPIC)


func test_a_small_pool_caps_the_number_of_lines() -> void:
	var template := RollTemplate.new()
	template.stat = Stats.DAMAGE
	var pool := RollPool.new()
	pool.templates = [template]
	var data := WeaponData.new()
	data.roll_pool = pool
	assert_eq(ItemRoller.roll(data, Rarity.Type.EPIC, RandomNumberGenerator.new()).rolls.size(), 1)


func test_rolling_never_edits_the_item_definition() -> void:
	var data := _item(&"pulse_laser")
	var templates_before := data.roll_pool.templates.size()
	for seed_value in 10:
		_roll(&"pulse_laser", Rarity.Type.EPIC, seed_value)
	assert_eq(data.roll_pool.templates.size(), templates_before)
	assert_eq(data.base_mods.size(), 0)


func test_rarity_helpers() -> void:
	assert_eq(Rarity.roll_count(Rarity.Type.RARE), 1)
	assert_eq(Rarity.display_name(Rarity.Type.EPIC), "Epic")
	assert_ne(Rarity.color(Rarity.Type.RARE), Rarity.color(Rarity.Type.EPIC))
