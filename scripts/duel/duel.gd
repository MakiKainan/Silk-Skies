class_name Duel
extends Node3D
## One 1v1 duel from RunState: enemy preview -> fight -> (salvage, after a win that isn't the last)
## -> result. The player's gear comes from RunState.loadout, the enemy from the current encounter
## of RunState.act. Pauses the game behind the preview, salvage and result overlays. In Original
## mode the HUD is compact, there is an action bar, and a defeat ends the run.

enum State { PREVIEW, FIGHTING, RESULT }

const SANDBOX_SCENE := "res://scenes/debug/sandbox.tscn"
const MENU_SCENE := "res://scenes/menu/start_screen.tscn"
const SHIP_SCENE := preload("res://scenes/ship/ship.tscn")
const DEFAULT_ACT_ID := &"slice_act"
## Ships start this far from the arena centre, facing each other.
const START_OFFSET := 18.0
const RESULT_DELAY := 1.2

## Tests turn this off so the runner isn't frozen by a paused tree.
var pause_enabled: bool = true
var state: State = State.PREVIEW
var player: Ship
var enemy_ship: Ship
var enemy_data: EnemyData
var result: DuelResult

var _clock: float = 0.0
var _damage_dealt: float = 0.0
var _damage_taken: float = 0.0
var _ui: DuelUI
var _hud: Hud
var _action_bar: ActionBar
var _reward: RewardScreen
var _inventory: InventoryScreen
var _overlay_up: bool = true

@onready var _ships: Node3D = $Ships
@onready var _camera_rig: FollowCamera = $FollowCamera


func _ready() -> void:
	RunState.ensure_player()
	if RunState.act == null:
		RunState.start_act(ContentDB.get_by_id(DEFAULT_ACT_ID) as ActData)
	enemy_data = RunState.current_enemy()
	if enemy_data == null:
		push_error("Duel: the act has no current encounter")
		return

	var projectiles := Node3D.new()
	projectiles.name = "Projectiles"
	projectiles.add_to_group(&"projectile_root")
	add_child(projectiles)
	add_child(DamageNumbers.new())

	player = SHIP_SCENE.instantiate() as Ship
	player.free_on_death = false
	_ships.add_child(player)
	player.setup(RunState.player_hull, [], RunState.loadout)
	player.place(Vector3(0.0, 0.0, START_OFFSET), 0.0)
	player.add_child(PlayerInput.new())
	player.weapons_enabled = false

	enemy_ship = EnemyFactory.spawn(_ships, enemy_data, Vector3(0.0, 0.0, -START_OFFSET), PI, RunState.make_rng())
	enemy_ship.weapons_enabled = false
	_ai().enabled = false
	enemy_ship.died.connect(func(_source: Node) -> void: _finish(true))
	player.died.connect(func(_source: Node) -> void: _finish(false))

	_camera_rig.target = player
	_camera_rig.snap_to_target()

	var original := RunState.is_original()
	_hud = Hud.new()
	_hud.compact = original
	add_child(_hud)
	_hud.track(player)
	if original:
		_action_bar = ActionBar.new()
		add_child(_action_bar)
		_action_bar.track(player)
	else:
		_hud.set_help("W/S thrust   A/D steer   Shift = Hard Burn (hold W/A/S/D to aim it)\nmouse aims   LMB manual weapons   RMB hold on enemy = lock, release = fire\nI refit")

	_inventory = InventoryScreen.new()
	add_child(_inventory)
	_inventory.bind(player)
	_inventory.closed.connect(_on_inventory_closed)

	_ui = DuelUI.new()
	add_child(_ui)
	_ui.bind_enemy(enemy_ship, enemy_data)
	_ui.fight_pressed.connect(begin_fight)
	_ui.refit_pressed.connect(func() -> void: _inventory.open())
	_ui.next_pressed.connect(_next_duel)
	_ui.retry_pressed.connect(_retry)
	_ui.menu_pressed.connect(_leave)
	_ui.new_run_pressed.connect(_new_run)

	_reward = RewardScreen.new()
	add_child(_reward)
	_reward.refit_pressed.connect(func() -> void: _inventory.open())

	EventBus.ship_hit.connect(_on_ship_hit)
	EventBus.phase_started.connect(_on_phase_started)

	_ui.show_preview(enemy_data, RunState.duel_index, RunState.duel_count())
	_pause_for_overlay()


func _exit_tree() -> void:
	get_tree().paused = false
	for signal_connection in [[EventBus.ship_hit, _on_ship_hit], [EventBus.phase_started, _on_phase_started]]:
		if signal_connection[0].is_connected(signal_connection[1]):
			signal_connection[0].disconnect(signal_connection[1])


func _physics_process(delta: float) -> void:
	if state == State.FIGHTING:
		_clock += delta


## Starts the fight: unpauses, arms both ships and unleashes the AI.
func begin_fight() -> void:
	if state != State.PREVIEW:
		return
	state = State.FIGHTING
	_overlay_up = false
	_ui.hide_preview()
	player.weapons_enabled = true
	enemy_ship.weapons_enabled = true
	_ai().enabled = true
	get_tree().paused = false
	_ui.show_banner("FIGHT!", 1.5)


# --- Outcome -------------------------------------------------------------------------

func _finish(won: bool) -> void:
	if state != State.FIGHTING:
		return
	state = State.RESULT
	result = DuelResult.new()
	result.won = won
	result.enemy = enemy_data
	result.seconds = _clock
	result.damage_dealt = _damage_dealt
	result.damage_taken = _damage_taken
	RunState.last_result = result
	# Let the explosion play out before the result covers the screen.
	await get_tree().create_timer(RESULT_DELAY).timeout
	if won and RunState.has_next():
		await _offer_salvage()
	var complete := won and not RunState.has_next()
	_ui.show_result(result, RunState.has_next(), complete, RunState.is_original())
	_pause_for_overlay()


## Shows the pick-one-of-three screen for the enemy just beaten and waits for the choice.
func _offer_salvage() -> void:
	var offers := LootGenerator.offers(enemy_data, ContentDB.items(), RunState.duel_index, RunState.make_rng(RunState.REWARD_SALT))
	if offers.is_empty():
		return
	if _action_bar != null:
		_action_bar.visible = false  # The salvage cards use that part of the screen.
	_reward.show_offers(offers, RunState.loadout)
	_pause_for_overlay()
	await _reward.finished
	if _action_bar != null:
		_action_bar.visible = true


func _on_ship_hit(ship: Node, hit_result: DamageResult) -> void:
	if state != State.FIGHTING:
		return
	if ship == enemy_ship:
		_damage_dealt += hit_result.total_dealt()
	elif ship == player:
		_damage_taken += hit_result.total_dealt()


func _on_phase_started(ship: Node, phase: PhaseData) -> void:
	if ship == enemy_ship and phase.banner != "":
		_ui.show_banner(phase.banner, 3.0)


# --- Navigation ----------------------------------------------------------------------

func _next_duel() -> void:
	RunState.advance()
	get_tree().paused = false
	get_tree().reload_current_scene()


func _retry() -> void:
	if result != null and result.won and not RunState.has_next():
		RunState.start_act(RunState.act)  # Finished the act: start it over.
	get_tree().paused = false
	get_tree().reload_current_scene()


## Starts a brand-new run from the first duel (after a defeat or a finished gauntlet in Original mode).
func _new_run() -> void:
	RunState.new_run(RunState.act)
	get_tree().paused = false
	get_tree().reload_current_scene()


## Back to the start screen from a real run, or to the sandbox from the debug gauntlet.
func _leave() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file(MENU_SCENE if RunState.is_original() else SANDBOX_SCENE)


func _pause_for_overlay() -> void:
	_overlay_up = true
	if pause_enabled:
		get_tree().paused = true


## Closing the refit screen un-pauses the tree; if an overlay is still showing, pause again.
func _on_inventory_closed() -> void:
	if _overlay_up and pause_enabled:
		get_tree().paused = true


func _ai() -> AIController:
	return enemy_ship.get_node("AIController") as AIController
