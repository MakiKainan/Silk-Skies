extends Node3D
## Debug sandbox (the project's main scene for now): one player ship in the arena with
## no enemies, to judge sailing on its own.
##
## 1..9 swap the player's hull   B spawn a bot   X clear bots   R reset player
## [ / ] halve / double time scale   \ reset time scale   F1 tuning panel   wheel zoom

const SHIP_SCENE := preload("res://scenes/ship/ship.tscn")
const MAX_BOTS := 6
const MIN_TIME_SCALE := 0.125
const MAX_TIME_SCALE := 4.0
const MIN_CAMERA_HEIGHT := 12.0
const MAX_CAMERA_HEIGHT := 120.0

var _hulls: Array[HullData] = []
var _hull_index := 0
var _player: Ship
var _bots: Array[Ship] = []
var _hud: Hud
var _tuning: TuningPanel
var _reticle: MeshInstance3D

@onready var _arena: Arena = $Arena
@onready var _ships: Node3D = $Ships
@onready var _camera_rig: FollowCamera = $FollowCamera


func _ready() -> void:
	_hulls = ContentDB.hulls()
	# Real hulls first, debug hulls after, each group by id; keys 1..9 index this list.
	_hulls.sort_custom(func(a: HullData, b: HullData) -> bool: return _hull_sort_key(a) < _hull_sort_key(b))
	if _hulls.is_empty():
		push_error("Sandbox: no hulls found under res://data/hulls")
		return

	_player = _spawn_ship(_hulls[0], Vector3.ZERO, 0.0)
	_player.add_child(PlayerInput.new())
	_camera_rig.target = _player
	_camera_rig.snap_to_target()

	_hud = Hud.new()
	add_child(_hud)
	_hud.track(_player)
	_tuning = TuningPanel.new()
	add_child(_tuning)
	_tuning.bind(_player)
	_build_reticle()


func _exit_tree() -> void:
	Engine.time_scale = 1.0


func _process(_delta: float) -> void:
	if _player != null:
		_reticle.global_position = _player.aim_point + Vector3(0.0, 0.1, 0.0)


func _unhandled_input(event: InputEvent) -> void:
	var wheel := event as InputEventMouseButton
	if wheel != null and wheel.pressed:
		if wheel.button_index == MOUSE_BUTTON_WHEEL_UP:
			_camera_rig.height = maxf(_camera_rig.height * 0.9, MIN_CAMERA_HEIGHT)
		elif wheel.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_camera_rig.height = minf(_camera_rig.height * 1.1, MAX_CAMERA_HEIGHT)
		return

	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo or _player == null:
		return
	var code := key.physical_keycode
	if code >= KEY_1 and code <= KEY_9:
		_set_player_hull(code - KEY_1)
		return
	match code:
		KEY_B:
			_spawn_bot()
		KEY_X:
			_clear_bots()
		KEY_R:
			_player.place(Vector3.ZERO, 0.0)
			_camera_rig.snap_to_target()
		KEY_BRACKETLEFT:
			Engine.time_scale = maxf(Engine.time_scale * 0.5, MIN_TIME_SCALE)
		KEY_BRACKETRIGHT:
			Engine.time_scale = minf(Engine.time_scale * 2.0, MAX_TIME_SCALE)
		KEY_BACKSLASH:
			Engine.time_scale = 1.0
		KEY_F1:
			_tuning.toggle()


func _spawn_ship(hull: HullData, at: Vector3, yaw: float) -> Ship:
	var ship := SHIP_SCENE.instantiate() as Ship
	_ships.add_child(ship)
	ship.setup(hull)
	ship.place(at, yaw)
	return ship


func _set_player_hull(index: int) -> void:
	if index >= _hulls.size() or index == _hull_index:
		return
	_hull_index = index
	_player.setup(_hulls[index])


func _spawn_bot() -> void:
	if _bots.size() >= MAX_BOTS:
		return
	var spot := Vector3.ZERO
	for attempt in 20:
		var angle := randf() * TAU
		spot = Vector3(cos(angle), 0.0, sin(angle)) * randf_range(0.3, 0.7) * _arena.radius
		if spot.distance_to(_player.global_position) > 10.0:
			break
	var hull := _hulls[_bots.size() % _hulls.size()]
	var bot := _spawn_ship(hull, spot, randf() * TAU)
	bot.add_child(CircleBot.new())
	_bots.append(bot)


func _clear_bots() -> void:
	for bot in _bots:
		bot.queue_free()
	_bots.clear()


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
