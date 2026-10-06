extends "res://tests/helpers/ship_test.gd"
## The duel scene's flow: preview -> fight -> result. Pausing is switched off so the test
## runner keeps running; the overlays still appear.

const DUEL_SCENE := preload("res://scenes/duel/duel.tscn")

var duel: Duel


func before_each() -> void:
	RunState.reset()
	RunState.ensure_player()
	RunState.start_act(ContentDB.get_by_id(&"slice_act") as ActData)


func after_each() -> void:
	super.after_each()
	RunState.reset()


func _start_duel() -> void:
	duel = DUEL_SCENE.instantiate() as Duel
	duel.pause_enabled = false
	add_child_autofree(duel)
	await wait_physics_frames(3)


func _kill(ship: Ship) -> void:
	ship.health.shield = 0.0
	ship.health.apply_hit(Hit.make(100000.0, Damage.Type.KINETIC, null, ship.global_position))


func _texts(root: Node) -> PackedStringArray:
	var out := PackedStringArray()
	for node in root.find_children("*", "Label", true, false):
		if not node.is_queued_for_deletion():
			out.append((node as Label).text)
	return out


func test_a_duel_opens_on_a_preview_of_the_enemy() -> void:
	await _start_duel()
	assert_eq(duel.state, Duel.State.PREVIEW)
	assert_eq(duel.enemy_data.id, &"enemy_raider")
	var texts := _texts(duel._ui)
	assert_true("RAIDER" in texts)
	assert_true("DUEL 1 / 3" in texts)
	assert_true("Style: Brawler" in texts)
	var weapon_listed := false
	for text in texts:
		weapon_listed = weapon_listed or text.begins_with("Autocannon")
	assert_true(weapon_listed, "weapons are listed")


func test_the_preview_shows_both_ships_but_nothing_moves_or_fires() -> void:
	await _start_duel()
	assert_eq(duel.player.team, Ship.TEAM_PLAYER)
	assert_eq(duel.enemy_ship.team, Ship.TEAM_ENEMY)
	assert_false(duel.player.weapons_enabled)
	assert_false(duel.enemy_ship.weapons_enabled)
	var start := duel.enemy_ship.global_position
	watch_signals(EventBus)
	await wait_physics_frames(90)
	assert_almost_eq(duel.enemy_ship.global_position.z, start.z, 0.01, "the AI waits for FIGHT")
	assert_signal_not_emitted(EventBus, "weapon_fired")


func test_the_player_brings_their_run_gear_into_the_duel() -> void:
	await _start_duel()
	assert_eq(duel.player.loadout, RunState.loadout, "the same loadout object, so refits stick")
	assert_eq(duel.player.weapon_at(0).weapon.id, &"pulse_laser")
	assert_eq(duel.player.weapon_at(1).weapon.id, &"railgun")


func test_fight_arms_everyone_and_starts_the_clock() -> void:
	await _start_duel()
	duel.begin_fight()
	assert_eq(duel.state, Duel.State.FIGHTING)
	assert_true(duel.player.weapons_enabled)
	assert_true(duel.enemy_ship.weapons_enabled)
	assert_true(duel._ai().enabled)
	await wait_physics_frames(60)
	assert_gt(duel._clock, 0.9)
	assert_lt(duel._clock, 1.3)


func test_the_enemy_fights_back_once_the_fight_starts() -> void:
	await _start_duel()
	duel.begin_fight()
	duel.player.health.god_mode = true
	watch_signals(EventBus)
	await wait_physics_frames(60 * 6)
	assert_signal_emitted(EventBus, "weapon_fired")
	assert_signal_emitted(EventBus, "ship_hit")


func test_killing_the_enemy_is_a_victory_with_stats() -> void:
	await _start_duel()
	duel.begin_fight()
	duel.enemy_ship.health.apply_hit(Hit.make(40.0, Damage.Type.KINETIC, duel.player, Vector3.ZERO))
	await wait_physics_frames(30)
	_kill(duel.enemy_ship)
	await wait_physics_frames(int(Duel.RESULT_DELAY * 60.0) + 20)
	assert_eq(duel.state, Duel.State.RESULT)
	assert_true(duel.result.won)
	assert_eq(duel.result.enemy.id, &"enemy_raider")
	assert_gt(duel.result.seconds, 0.4)
	assert_gt(duel.result.damage_dealt, 40.0)
	assert_eq(RunState.last_result, duel.result)
	assert_true("VICTORY" in _texts(duel._ui))
	assert_true("Next duel" in _button_texts(duel._ui))


func _button_texts(root: Node) -> PackedStringArray:
	var out := PackedStringArray()
	for node in root.find_children("*", "Button", true, false):
		if not node.is_queued_for_deletion():
			out.append((node as Button).text)
	return out


func test_the_player_dying_is_a_defeat_with_a_retry() -> void:
	await _start_duel()
	duel.begin_fight()
	_kill(duel.player)
	await wait_physics_frames(int(Duel.RESULT_DELAY * 60.0) + 20)
	assert_eq(duel.state, Duel.State.RESULT)
	assert_false(duel.result.won)
	assert_true("DEFEAT" in _texts(duel._ui))
	var buttons := _button_texts(duel._ui)
	assert_true("Retry" in buttons)
	assert_false("Next duel" in buttons)


func test_the_last_victory_completes_the_gauntlet() -> void:
	RunState.advance()
	RunState.advance()  # The Warden
	await _start_duel()
	assert_eq(duel.enemy_data.id, &"enemy_warden")
	duel.begin_fight()
	_kill(duel.enemy_ship)
	await wait_physics_frames(int(Duel.RESULT_DELAY * 60.0) + 20)
	assert_true("GAUNTLET COMPLETE" in _texts(duel._ui))
	assert_false("Next duel" in _button_texts(duel._ui))


func test_the_boss_phase_banner_shows_during_the_fight() -> void:
	RunState.advance()
	RunState.advance()
	await _start_duel()
	duel.begin_fight()
	duel.enemy_ship.health.shield = 0.0
	duel.enemy_ship.health.apply_hit(Hit.make(500.0, Damage.Type.KINETIC, duel.player, Vector3.ZERO))
	await wait_physics_frames(3)
	assert_true("THE WARDEN OVERCLOCKS" in _texts(duel._ui))


func test_a_second_result_cannot_be_recorded() -> void:
	await _start_duel()
	duel.begin_fight()
	_kill(duel.enemy_ship)
	await wait_physics_frames(5)
	_kill(duel.player)
	await wait_physics_frames(int(Duel.RESULT_DELAY * 60.0) + 20)
	assert_true(duel.result.won, "the first outcome stands")


func test_fight_can_only_be_started_once() -> void:
	await _start_duel()
	duel.begin_fight()
	var clock := duel._clock
	duel.begin_fight()
	assert_eq(duel._clock, clock)
	assert_eq(duel.state, Duel.State.FIGHTING)


func test_an_enemy_bar_tracks_the_enemy() -> void:
	await _start_duel()
	assert_eq(duel._ui._enemy_hull.value, 1.0)
	duel.enemy_ship.health.shield = 0.0
	duel.enemy_ship.health.apply_hit(Hit.make(100.0, Damage.Type.KINETIC, duel.player, Vector3.ZERO))
	await wait_physics_frames(3)
	assert_lt(duel._ui._enemy_hull.value, 1.0)
	assert_eq(duel._ui._enemy_shield.value, 0.0)


func test_retrying_a_duel_fights_the_same_enemy_with_the_same_rolls() -> void:
	await _start_duel()
	var first := JSON.stringify(duel.enemy_ship.loadout.to_dict())
	duel.queue_free()
	await wait_physics_frames(2)
	await _start_duel()
	assert_eq(JSON.stringify(duel.enemy_ship.loadout.to_dict()), first)
