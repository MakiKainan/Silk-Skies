extends GutTest
## RunState is an autoload, so every test resets it first and leaves it clean.

var act: ActData


func before_each() -> void:
	RunState.reset()
	act = ContentDB.get_by_id(&"slice_act") as ActData


func after_each() -> void:
	RunState.reset()


func test_a_fresh_run_builds_the_starter_frigate_loadout() -> void:
	assert_true(RunState.ensure_player())
	assert_eq(RunState.player_hull.id, &"starter_frigate")
	assert_eq(RunState.loadout.get_item(ShipLoadout.Kind.SLOT, 0).data_id, &"pulse_laser")
	assert_eq(RunState.loadout.get_item(ShipLoadout.Kind.SLOT, 1).data_id, &"railgun")
	assert_eq(RunState.loadout.cargo.size(), RunState.cargo_capacity)


func test_ensure_player_never_replaces_existing_gear() -> void:
	RunState.ensure_player()
	var loadout := RunState.loadout
	assert_false(RunState.ensure_player())
	assert_eq(RunState.loadout, loadout)


func test_reset_forgets_everything() -> void:
	RunState.ensure_player()
	RunState.start_act(act)
	RunState.reset()
	assert_null(RunState.loadout)
	assert_null(RunState.act)
	assert_null(RunState.current_enemy())


func test_starting_an_act_points_at_its_first_encounter() -> void:
	RunState.start_act(act)
	assert_eq(RunState.duel_index, 0)
	assert_eq(RunState.duel_count(), 3)
	assert_eq(RunState.current_enemy().id, &"enemy_raider")


func test_advancing_walks_the_act_and_stops_at_the_end() -> void:
	RunState.start_act(act)
	assert_true(RunState.has_next())
	assert_true(RunState.advance())
	assert_eq(RunState.current_enemy().id, &"enemy_longshot")
	assert_true(RunState.advance())
	assert_eq(RunState.current_enemy().id, &"enemy_warden")
	assert_false(RunState.has_next())
	assert_false(RunState.advance(), "already on the last duel")
	assert_eq(RunState.current_enemy().id, &"enemy_warden")


func test_advancing_clears_the_last_result() -> void:
	RunState.start_act(act)
	RunState.last_result = DuelResult.new()
	RunState.advance()
	assert_null(RunState.last_result)


func test_no_act_means_no_enemy_and_nothing_next() -> void:
	assert_null(RunState.current_enemy())
	assert_false(RunState.has_next())
	assert_eq(RunState.duel_count(), 0)


func test_the_duel_rng_is_repeatable_for_a_retry() -> void:
	RunState.start_act(act)
	var first := RunState.make_rng()
	var second := RunState.make_rng()
	assert_eq(first.randi(), second.randi(), "same run seed + same duel = same rolls")


func test_the_duel_rng_differs_between_duels_and_salts() -> void:
	RunState.start_act(act)
	var duel_one := RunState.make_rng().randi()
	var salted := RunState.make_rng(7).randi()
	RunState.advance()
	var duel_two := RunState.make_rng().randi()
	assert_ne(duel_one, duel_two)
	assert_ne(duel_one, salted)


func test_a_new_run_gets_a_new_seed() -> void:
	var seeds := {}
	for i in 5:
		RunState.start_act(act)
		seeds[RunState.seed_value] = true
	assert_gt(seeds.size(), 1)
