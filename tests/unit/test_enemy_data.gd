extends GutTest
## The authored enemies, and the validator rules that guard them (including the "does this item
## fit that slot" check). Uses starter-frigate-shaped hardpoints: Turret_A Small, Turret_B Large.


func _item(id: StringName) -> ItemData:
	return ContentDB.get_by_id(id) as ItemData


func _spec(id: StringName, slot: StringName, rarity: Rarity.Type = Rarity.Type.COMMON) -> ItemSpec:
	var spec := ItemSpec.new()
	spec.item = _item(id)
	spec.slot = slot
	spec.rarity = rarity
	return spec


func _enemy(specs: Array) -> EnemyData:
	var enemy := EnemyData.new()
	enemy.id = &"test_enemy"
	enemy.display_name = "Test Enemy"
	enemy.hull = ContentDB.get_hull(&"starter_frigate")
	enemy.ai_profile = ContentDB.get_by_id(&"ai_brawler") as AIProfile
	enemy.loadout.assign(specs)
	return enemy


func _errors(res: Resource) -> String:
	return "\n".join(ContentValidator.validate([res]))


# --- The real content ---------------------------------------------------------------------

func test_the_slice_act_is_brawler_then_sniper_then_boss() -> void:
	var act := ContentDB.get_by_id(&"slice_act") as ActData
	assert_not_null(act)
	assert_eq(act.encounters.size(), 3)
	assert_eq(act.encounters[0].id, &"enemy_raider")
	assert_eq(act.encounters[1].id, &"enemy_longshot")
	assert_eq(act.encounters[2].id, &"enemy_warden")
	assert_false(act.encounters[0].is_boss)
	assert_true(act.encounters[2].is_boss)


func test_the_four_ai_profiles_exist_with_distinct_styles() -> void:
	var brawler := ContentDB.get_by_id(&"ai_brawler") as AIProfile
	var sniper := ContentDB.get_by_id(&"ai_sniper") as AIProfile
	assert_not_null(brawler)
	assert_not_null(sniper)
	assert_lt(brawler.preferred_range, sniper.preferred_range, "the brawler fights close, the sniper far")
	assert_false(brawler.dodge_burn)
	assert_true(sniper.dodge_burn)
	assert_not_null(ContentDB.get_by_id(&"ai_warden_guard"))
	assert_not_null(ContentDB.get_by_id(&"ai_warden_enraged"))


func test_every_authored_enemy_validates_and_is_not_player_selectable() -> void:
	for enemy in ContentDB.enemies():
		assert_eq(ContentValidator.validate([enemy]).size(), 0, "%s: %s" % [enemy.id, _errors(enemy)])
		assert_false(enemy.hull.player_selectable, "%s's hull stays out of the player's picker" % enemy.id)
	assert_eq(ContentDB.enemies().size(), 3)


func test_the_sniper_carries_a_railgun_and_the_brawler_does_not() -> void:
	var longshot := ContentDB.get_by_id(&"enemy_longshot") as EnemyData
	var raider := ContentDB.get_by_id(&"enemy_raider") as EnemyData
	assert_true(longshot.loadout.any(func(s: ItemSpec) -> bool: return s.item.id == &"railgun"))
	assert_false(raider.loadout.any(func(s: ItemSpec) -> bool: return s.item.id == &"railgun"))


func test_the_warden_has_one_phase_at_half_hull_that_adds_a_missile_pod() -> void:
	var warden := ContentDB.get_by_id(&"enemy_warden") as EnemyData
	assert_eq(warden.phases.size(), 1)
	var phase := warden.phases[0]
	assert_almost_eq(phase.hull_threshold, 0.5, 0.0001)
	assert_not_null(phase.ai_profile)
	assert_true(phase.added_items.any(func(s: ItemSpec) -> bool: return s.item.id == &"missile_pod"))
	assert_ne(phase.banner, "")


# --- Validator: enemies --------------------------------------------------------------------

func test_a_well_formed_enemy_is_clean() -> void:
	assert_eq(ContentValidator.validate([_enemy([_spec(&"pulse_laser", &"Turret_A"), _spec(&"railgun", &"Turret_B")])]).size(), 0)


func test_a_loadout_slot_that_is_not_on_the_hull_is_reported() -> void:
	assert_string_contains(_errors(_enemy([_spec(&"pulse_laser", &"Turret_Z")])), "'Turret_Z' is not a hardpoint")


func test_an_item_that_does_not_fit_its_slot_is_reported() -> void:
	assert_string_contains(_errors(_enemy([_spec(&"railgun", &"Turret_A")])), "railgun does not fit")
	assert_string_contains(_errors(_enemy([_spec(&"shield_capacitor", &"Turret_B")])), "does not fit")


func test_two_items_on_one_slot_are_reported() -> void:
	assert_string_contains(_errors(_enemy([_spec(&"pulse_laser", &"Turret_A"), _spec(&"autocannon", &"Turret_A")])), "two loadout items")


func test_a_spec_with_no_item_is_reported() -> void:
	var spec := ItemSpec.new()
	spec.slot = &"Turret_A"
	assert_string_contains(_errors(_enemy([spec])), "no item")


func test_an_enemy_needs_a_hull_and_an_ai_profile() -> void:
	var no_hull := _enemy([])
	no_hull.hull = null
	assert_string_contains(_errors(no_hull), "no hull")
	var no_ai := _enemy([])
	no_ai.ai_profile = null
	assert_string_contains(_errors(no_ai), "no ai_profile")


func _phase(threshold: float) -> PhaseData:
	var phase := PhaseData.new()
	phase.hull_threshold = threshold
	return phase


func test_phase_thresholds_must_fall() -> void:
	var enemy := _enemy([])
	enemy.phases.assign([_phase(0.5), _phase(0.7)])
	assert_string_contains(_errors(enemy), "strictly falling")
	enemy.phases.assign([_phase(0.7), _phase(0.3)])
	assert_eq(ContentValidator.validate([enemy]).size(), 0)


func test_phase_items_are_checked_against_the_hull_too() -> void:
	var enemy := _enemy([])
	var phase := _phase(0.5)
	phase.added_items.assign([_spec(&"railgun", &"Turret_A")])
	enemy.phases.assign([phase])
	assert_string_contains(_errors(enemy), "railgun does not fit")


func test_a_boss_needs_a_phase() -> void:
	var enemy := _enemy([])
	enemy.is_boss = true
	assert_string_contains(_errors(enemy), "at least one phase")


func test_acts_must_have_real_encounters() -> void:
	var act := ActData.new()
	act.id = &"empty_act"
	assert_string_contains(_errors(act), "no encounters")
	act.encounters.assign([null])
	assert_string_contains(_errors(act), "null encounter")


func test_ai_profile_numbers_are_checked() -> void:
	var profile := AIProfile.new()
	profile.id = &"bad_ai"
	profile.preferred_range = 10.0
	profile.range_band = 12.0
	profile.reaction_time = 0.0
	profile.orbit_flip_min = 5.0
	profile.orbit_flip_max = 2.0
	var text := _errors(profile)
	assert_string_contains(text, "range_band")
	assert_string_contains(text, "reaction_time")
	assert_string_contains(text, "orbit flip")
