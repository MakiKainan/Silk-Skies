extends Node3D
## Debug sandbox (the project's main scene for now): one player ship in the arena, with
## target dummies and bots to shoot at on demand.
##
## 1..9 swap the player's hull   B spawn a bot   N spawn a dummy   X clear enemies
## R revive / reset player   [ / ] halve / double time scale   \ reset time scale
## I refit / inventory   F1 tuning panel   F2 sandbox panel   wheel zoom

const SHIP_SCENE := preload("res://scenes/ship/ship.tscn")
const MAX_ENEMIES := 8
const MIN_TIME_SCALE := 0.125
const MAX_TIME_SCALE := 4.0
const MIN_CAMERA_HEIGHT := 12.0
const MAX_CAMERA_HEIGHT := 120.0
const DUMMY_RESPAWN_SECONDS := 2.0
const DUMMY_HULL_ID := &"debug_dummy"
## The sandbox hold is roomier than a run's (ShipLoadout.RUN_CARGO_SLOTS) so you can stock up.
const SANDBOX_CARGO_SLOTS := 12
const DUEL_SCENE := "res://scenes/duel/duel.tscn"
const DEFAULT_ACT_ID := &"slice_act"

var hulls: Array[HullData] = []  # Hulls a ship can sail; the dummy hull is not one of them.
var player: Ship

var _dummy_hull: HullData
var _enemies: Array[Ship] = []
var _bot_count := 0
var _bots_fire := true
var _show_arcs := false
var _generation := 0  # Bumped by clear_enemies() so pending dummy respawns are cancelled.
var _clock := 0.0
var _fights: Dictionary = {}  # Ship instance id -> {start, damage}
var _hud: Hud
var _tuning: TuningPanel
var _panel: SandboxPanel
var _inventory: InventoryScreen
var _rng := RandomNumberGenerator.new()
var _reticle: MeshInstance3D

@onready var _arena: Arena = $Arena
@onready var _ships: Node3D = $Ships
@onready var _camera_rig: FollowCamera = $FollowCamera


func _ready() -> void:
	_dummy_hull = ContentDB.get_hull(DUMMY_HULL_ID)
	for hull in ContentDB.hulls():
		if hull.player_selectable:
			hulls.append(hull)
	# Real hulls first, debug hulls after, each group by id; keys 1..9 index this list.
	hulls.sort_custom(func(a: HullData, b: HullData) -> bool: return _hull_sort_key(a) < _hull_sort_key(b))
	if hulls.is_empty():
		push_error("Sandbox: no hulls found under res://data/hulls")
		return

	var projectiles := Node3D.new()
	projectiles.name = "Projectiles"
	projectiles.add_to_group(&"projectile_root")
	add_child(projectiles)
	add_child(DamageNumbers.new())

	player = SHIP_SCENE.instantiate() as Ship
	player.free_on_death = false
	RunState.cargo_capacity = SANDBOX_CARGO_SLOTS
	var fresh := RunState.ensure_player()  # Gear carries over from a duel, if we came from one.
	_ships.add_child(player)
	player.setup(RunState.player_hull, [], RunState.loadout)
	player.place(Vector3.ZERO, 0.0)
	_rng.randomize()
	if fresh:
		_stock_sample_cargo()
	player.add_child(PlayerInput.new())
	_camera_rig.target = player
	_camera_rig.snap_to_target()

	_hud = Hud.new()
	add_child(_hud)
	_hud.track(player)
	_tuning = TuningPanel.new()
	add_child(_tuning)
	_tuning.bind(player)
	_panel = SandboxPanel.new()
	add_child(_panel)
	_panel.bind(self)
	player.hull_changed.connect(func(_h: HullData) -> void: _panel.sync_hull(), CONNECT_DEFERRED)
	_inventory = InventoryScreen.new()
	add_child(_inventory)
	_inventory.bind(player)
	_build_reticle()

	EventBus.ship_hit.connect(_on_ship_hit)
	EventBus.ship_destroyed.connect(_on_ship_destroyed)


func _exit_tree() -> void:
	Engine.time_scale = 1.0


func _physics_process(delta: float) -> void:
	_clock += delta


func _process(_delta: float) -> void:
	if player != null:
		_reticle.global_position = player.aim_point + Vector3(0.0, 0.1, 0.0)


func _unhandled_input(event: InputEvent) -> void:
	var wheel := event as InputEventMouseButton
	if wheel != null and wheel.pressed:
		if wheel.button_index == MOUSE_BUTTON_WHEEL_UP:
			_camera_rig.height = maxf(_camera_rig.height * 0.9, MIN_CAMERA_HEIGHT)
		elif wheel.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_camera_rig.height = minf(_camera_rig.height * 1.1, MAX_CAMERA_HEIGHT)
		return

	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo or player == null:
		return
	var code := key.physical_keycode
	if code >= KEY_1 and code <= KEY_9:
		set_player_hull(code - KEY_1)
		return
	match code:
		KEY_B:
			spawn_bot()
		KEY_N:
			spawn_dummy()
		KEY_X:
			clear_enemies()
		KEY_R:
			revive_player()
		KEY_BRACKETLEFT:
			Engine.time_scale = maxf(Engine.time_scale * 0.5, MIN_TIME_SCALE)
		KEY_BRACKETRIGHT:
			Engine.time_scale = minf(Engine.time_scale * 2.0, MAX_TIME_SCALE)
		KEY_BACKSLASH:
			Engine.time_scale = 1.0
		KEY_F1:
			_tuning.toggle()
		KEY_F2:
			_panel.toggle()


# --- Actions (also called by the F2 panel) ---------------------------------------------

func set_player_hull(index: int) -> void:
	if index < 0 or index >= hulls.size() or hulls[index] == player.hull:
		return
	player.swap_hull(hulls[index])  # Keeps the loadout: what fits re-mounts, the rest goes to cargo.
	RunState.player_hull = hulls[index]


## Rolls a [param data] drop at [param rarity] and puts it in the player's cargo hold.
func spawn_item(data: ItemData, rarity: Rarity.Type) -> bool:
	var item := ItemRoller.roll(data, rarity, _rng)
	if player.loadout.add_to_cargo(item) < 0:
		_hud.show_banner("Cargo hold is full")
		get_tree().create_timer(2.0).timeout.connect(func() -> void: _hud.show_banner(""))
		return false
	return true


func spawn_random_item() -> bool:
	var items := ContentDB.items()
	return spawn_item(items[_rng.randi_range(0, items.size() - 1)], _rng.randi_range(Rarity.Type.COMMON, Rarity.Type.EPIC) as Rarity.Type)


## Spawns an AI enemy from its recipe, away from the player.
func spawn_enemy(enemy: EnemyData) -> void:
	if _enemies.size() >= MAX_ENEMIES:
		return
	var spot := _free_spot(24.0, 36.0)
	var ship := EnemyFactory.spawn(_ships, enemy, spot, 0.0, _rng)
	ship.show_arcs = _show_arcs
	_enemies.append(ship)
	ship.tree_exiting.connect(_enemies.erase.bind(ship))


## Starts the slice act and jumps to the duel scene with the current gear.
func start_gauntlet() -> void:
	RunState.start_act(ContentDB.get_by_id(DEFAULT_ACT_ID) as ActData)
	get_tree().change_scene_to_file(DUEL_SCENE)


func open_inventory() -> void:
	_inventory.open()


func revive_player() -> void:
	player.revive(Vector3.ZERO, 0.0)
	_camera_rig.snap_to_target()
	_hud.show_banner("")


func spawn_dummy() -> void:
	if _enemies.size() >= MAX_ENEMIES or _dummy_hull == null:
		return
	var spot := _free_spot(18.0, 32.0)
	_spawn_dummy_at(spot)


func spawn_bot() -> void:
	if _enemies.size() >= MAX_ENEMIES:
		return
	var hull := hulls[_bot_count % hulls.size()]
	_bot_count += 1
	var bot := _spawn_enemy(hull, _free_spot(20.0, 35.0), randf() * TAU)
	bot.add_child(CircleBot.new())
	var pick := 0
	for index in hull.hardpoints.size():
		if hull.hardpoints[index].type == HardpointData.Type.TURRET:
			var id: StringName = &"pulse_laser" if pick % 2 == 0 else &"autocannon"
			bot.equip(index, ContentDB.get_by_id(id) as WeaponData)
			pick += 1
	bot.weapons_enabled = _bots_fire


func clear_enemies() -> void:
	_generation += 1
	for enemy in _enemies:
		if is_instance_valid(enemy):
			enemy.queue_free()
	_enemies.clear()


func set_god_mode(on: bool) -> void:
	player.health.god_mode = on


func set_bots_fire(on: bool) -> void:
	_bots_fire = on
	for enemy in _enemies:
		if is_instance_valid(enemy):
			enemy.weapons_enabled = on


func set_show_arcs(on: bool) -> void:
	_show_arcs = on
	player.show_arcs = on
	for enemy in _enemies:
		if is_instance_valid(enemy):
			enemy.show_arcs = on


# --- Internals -----------------------------------------------------------------------

func _spawn_enemy(hull: HullData, at: Vector3, yaw: float) -> Ship:
	var ship := SHIP_SCENE.instantiate() as Ship
	ship.team = Ship.TEAM_ENEMY
	_ships.add_child(ship)
	ship.setup(hull)
	ship.place(at, yaw)
	ship.show_arcs = _show_arcs
	_enemies.append(ship)
	ship.tree_exiting.connect(_enemies.erase.bind(ship))  # Never hold a freed ship.
	return ship


func _spawn_dummy_at(spot: Vector3) -> void:
	var dummy := _spawn_enemy(_dummy_hull, spot, 0.0)
	var generation := _generation
	dummy.died.connect(func(_source: Node) -> void: _respawn_dummy_later(spot, generation))


func _respawn_dummy_later(spot: Vector3, generation: int) -> void:
	await get_tree().create_timer(DUMMY_RESPAWN_SECONDS).timeout
	if generation == _generation and _enemies.size() < MAX_ENEMIES:
		_spawn_dummy_at(spot)


## A random spot between two distances from the player, away from other ships.
func _free_spot(min_distance: float, max_distance: float) -> Vector3:
	var spot := Vector3.ZERO
	for attempt in 20:
		var angle := randf() * TAU
		spot = player.global_position + Vector3(cos(angle), 0.0, sin(angle)) * randf_range(min_distance, max_distance)
		if spot.length() > _arena.radius - 6.0:
			continue
		var clear := true
		for enemy in _enemies:
			if is_instance_valid(enemy) and enemy.global_position.distance_to(spot) < 8.0:
				clear = false
		if clear:
			break
	return spot


## A few drops of every kind and rarity, so there's something to play with in the hold.
func _stock_sample_cargo() -> void:
	var stock := [
		[&"autocannon", Rarity.Type.RARE],
		[&"missile_pod", Rarity.Type.EPIC],
		[&"shield_capacitor", Rarity.Type.RARE],
		[&"armor_plating", Rarity.Type.COMMON],
		[&"emp_emitter", Rarity.Type.COMMON],
		[&"interceptor_bay", Rarity.Type.RARE],
		[&"gunner", Rarity.Type.EPIC],
		[&"engineer", Rarity.Type.RARE],
	]
	for entry: Array in stock:
		var data := ContentDB.get_by_id(entry[0]) as ItemData
		if data != null:
			player.loadout.add_to_cargo(ItemRoller.roll(data, entry[1], _rng))


func _on_ship_hit(ship: Node, result: DamageResult) -> void:
	var target := ship as Ship
	if target == null or target.team != Ship.TEAM_ENEMY:
		return
	var key := target.get_instance_id()
	if not _fights.has(key):
		_fights[key] = {"start": _clock, "damage": 0.0}
	_fights[key].damage += result.total_dealt()


func _on_ship_destroyed(ship: Node, _source: Node) -> void:
	if ship == player:
		_hud.show_banner("DESTROYED - press R")
		return
	var key := ship.get_instance_id()
	if not _fights.has(key):
		return
	var fight: Dictionary = _fights[key]
	_fights.erase(key)
	var seconds := maxf(_clock - float(fight.start), 0.001)
	_hud.show_banner("%s destroyed in %.1f s  (%.0f damage, %.1f / s)" % [(ship as Ship).hull.display_name, seconds, fight.damage, fight.damage / seconds])
	get_tree().create_timer(4.0).timeout.connect(func() -> void:
		if player.is_alive():
			_hud.show_banner(""))


func _build_reticle() -> void:
	var ring := TorusMesh.new()
	ring.inner_radius = 0.6
	ring.outer_radius = 0.8
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(1.0, 0.9, 0.3)
	ring.material = material
	_reticle = MeshInstance3D.new()
	_reticle.name = "Reticle"
	_reticle.mesh = ring
	# Moved every render frame, so it must not be smoothed against physics ticks.
	_reticle.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	add_child(_reticle)


func _hull_sort_key(hull: HullData) -> String:
	return ("1_" if String(hull.id).begins_with("debug_") else "0_") + String(hull.id)
