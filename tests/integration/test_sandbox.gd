extends "res://tests/helpers/ship_test.gd"
## The sandbox's M3 additions: spawning AI enemies and sharing gear with the run.

const SANDBOX_SCENE := preload("res://scenes/debug/sandbox.tscn")

var sandbox: Node


func before_each() -> void:
	RunState.reset()
	sandbox = SANDBOX_SCENE.instantiate()
	add_child_autofree(sandbox)
	await wait_physics_frames(3)


func after_each() -> void:
	super.after_each()
	RunState.reset()


func test_the_player_uses_the_run_loadout() -> void:
	assert_eq(sandbox.player.loadout, RunState.loadout)
	assert_eq(sandbox.player.hull, RunState.player_hull)
	assert_eq(sandbox.player.weapon_at(0).weapon.id, &"pulse_laser")
	assert_gt(sandbox.player.loadout.cargo_count(), 0, "the sample stash is in the hold")


func test_gear_from_an_earlier_scene_carries_into_a_new_sandbox() -> void:
	var loadout: ShipLoadout = RunState.loadout
	loadout.take(ShipLoadout.Kind.SLOT, 0)
	var second := SANDBOX_SCENE.instantiate()
	add_child_autofree(second)
	await wait_physics_frames(2)
	assert_eq(second.player.loadout, loadout)
	assert_null(second.player.weapon_at(0), "the gun we removed is still removed")


func test_hull_choices_skip_enemy_hulls_and_the_dummy() -> void:
	for hull: HullData in sandbox.hulls:
		assert_true(hull.player_selectable)
	assert_eq(sandbox.hulls.size(), 3)


func test_swapping_hulls_updates_the_run_state() -> void:
	sandbox.set_player_hull(1)
	assert_eq(RunState.player_hull, sandbox.hulls[1])
	assert_eq(sandbox.player.loadout, RunState.loadout, "same loadout object, rebound to the new hull")


func test_spawning_an_enemy_creates_an_ai_ship_on_the_enemy_team() -> void:
	sandbox.spawn_enemy(ContentDB.get_by_id(&"enemy_longshot") as EnemyData)
	var enemies: Array[Ship] = sandbox.player.enemies()
	assert_eq(enemies.size(), 1)
	assert_eq(enemies[0].hull.id, &"longshot")
	assert_not_null(enemies[0].get_node("AIController"))
	assert_eq(enemies[0].weapons().size(), 2)


func test_a_spawned_enemy_fights_and_can_be_cleared() -> void:
	sandbox.spawn_enemy(ContentDB.get_by_id(&"enemy_raider") as EnemyData)
	watch_signals(EventBus)
	await wait_physics_frames(60 * 6)
	assert_signal_emitted(EventBus, "weapon_fired")
	sandbox.clear_enemies()
	await wait_physics_frames(3)
	assert_eq(sandbox.player.enemies().size(), 0)


func test_the_enemy_dropdown_lists_every_enemy() -> void:
	assert_eq(sandbox._panel._enemy_picker.item_count, ContentDB.enemies().size())
