class_name PlayerInput
extends Node
## Controller: turns keyboard + mouse into Ship commands. Add as a child of the Ship.
## W/S throttle, A/D steer, Shift Hard Burn (the held keys pick its direction), mouse aims,
## left / right mouse hold the PRIMARY / SECONDARY fire-group triggers (each weapon's
## group is set in the refit screen), Q / E / R use the ship's actives (fighter launches).
## While a fire button is held and A/D are not, the ship swings until the cursor sits in a
## held weapon's firing cone; pressing A or D takes the steering back. A charged weapon
## (the railgun) stays primed while held and fires on release.
## Tab / middle mouse lock the enemy nearest the cursor (again = unlock): while the cursor stays
## within LockOn.SNAP_RADIUS of it, aim goes to the lead point and the ship turns by itself to
## present the best weapon cone to it (LockOn.choose_cone), even with no fire held. A/D still
## steer; a cursor far away pauses the assist, then drops the lock.

## Q, E, R: the ship's actives in Ship.active_items() order.
const ACTIVE_ACTIONS: Array[StringName] = [&"ability_1", &"ability_2", &"ability_3"]
## A heading error this large (radians) or more asks for full steering; smaller errors steer
## in proportion, so the ship eases onto its heading instead of wobbling around it.
const FULL_STEER_ERROR := deg_to_rad(45.0)
const MARKER_READY_COLOR := Color(0.55, 1.0, 0.7, 0.95)
const MARKER_BLOCKED_COLOR := Color(1.0, 0.45, 0.4, 0.3)
const BRACKET_ACTIVE_COLOR := Color(1.0, 0.3, 0.25, 0.9)
const BRACKET_PAUSED_COLOR := Color(1.0, 0.3, 0.25, 0.3)

var _ship: Ship
var _marker: MeshInstance3D
var _marker_material: StandardMaterial3D
var _bracket: MeshInstance3D
var _bracket_material: StandardMaterial3D
## Seconds the cursor has been outside the lock's snap radius.
var _lock_away := 0.0
## Centre (degrees off the bow) of the cone the lock is presenting to the target; NAN for none.
var _lock_cone_center := NAN
## True while the lock is steering the aim (the cursor is close enough).
var _assisting := false


func _ready() -> void:
	_ship = get_parent() as Ship
	assert(_ship != null, "PlayerInput must be a child of a Ship")
	_ship.release_to_fire = true
	_ship.flash_cones = true
	_build_marker()
	_build_bracket()


func _process(_delta: float) -> void:
	if _ship == null:
		return
	_update_bracket()
	_marker.global_position = _ship.aim_point + Vector3(0.0, 0.15, 0.0)
	_marker_material.albedo_color = MARKER_READY_COLOR if _cursor_in_cone(_marker_groups()) else MARKER_BLOCKED_COLOR


func _physics_process(delta: float) -> void:
	# The cursor and triggers first: the heading assist needs this tick's aim point.
	var over_ui := get_viewport().gui_get_hovered_control() != null
	var held: Array[WeaponData.FireGroup] = []
	for group: WeaponData.FireGroup in [WeaponData.FireGroup.PRIMARY, WeaponData.FireGroup.SECONDARY]:
		var action := &"fire_primary" if group == WeaponData.FireGroup.PRIMARY else &"fire_secondary"
		var pressed := Input.is_action_pressed(action) and not over_ui
		_ship.set_trigger(group, pressed)
		if pressed:
			held.append(group)
	var camera := get_viewport().get_camera_3d()
	var cursor: Variant = null
	if camera != null:
		cursor = MouseAim.ground_point(camera, get_viewport().get_mouse_position())
		if cursor != null:
			_ship.aim_at(cursor)
	if Input.is_action_just_pressed(&"lock_on"):
		toggle_lock(cursor)
	_assisting = update_lock(cursor, held, delta)

	var steer := Input.get_axis(&"turn_left", &"turn_right")
	var drive := Input.get_axis(&"thrust_back", &"thrust_fwd")
	var aim := _ship.aim_point - _ship.global_position
	_ship.set_throttle(drive)
	var flat_aim := Vector3(aim.x, 0.0, aim.z)
	var turn: float = NAN
	if _assisting and steer == 0.0:
		# Locked on: present the right side of the hull to the target (see LockOn.choose_cone).
		var cone := LockOn.choose_cone(_ship.global_rotation.y, flat_aim, _cone_options(held), _lock_cone_center)
		_lock_cone_center = cone.x
		if not is_nan(cone.x):
			turn = LockOn.steer_to_center(_ship.global_rotation.y, flat_aim, cone.x)
	elif not _assisting:
		_lock_cone_center = NAN
	if is_nan(turn):
		turn = fire_steer(steer, _ship.global_rotation.y, _cones(held), flat_aim)
	_ship.set_turn(turn)
	if Input.is_action_just_pressed(&"hard_burn"):
		_ship.request_hard_burn(mouse_burn_local(_ship.global_rotation.y, Vector2(steer, drive), flat_aim))

	for index in ACTIVE_ACTIONS.size():
		if Input.is_action_just_pressed(ACTIVE_ACTIONS[index]):
			_ship.activate(index)


# --- Pure maths (unit-tested) --------------------------------------------------------

## The Ship.set_turn value: A/D ([param key_steer]) win whenever pressed. Otherwise, with fire
## held ([param cones] non-empty), steer toward assist_yaw for the cursor [param direction];
## no keys and no fire, or the cursor already in a cone, means no turn.
static func fire_steer(key_steer: float, yaw: float, cones: Array[Vector2], direction: Vector3) -> float:
	if key_steer != 0.0 or cones.is_empty():
		return key_steer
	var assist := assist_yaw(yaw, cones, direction)
	return 0.0 if is_nan(assist) else steer_for(yaw_error(yaw, assist))


## Hard Burn direction as ship-local (x = starboard, y = bow) for keys read against the mouse:
## [param keys] is (D - A, W - S) and [param aim] the flat vector from the ship to the cursor, so
## W bursts toward the cursor, S away from it, A/D to either side of that line, whichever way
## the bow points. No keys, or the cursor on top of the ship, keeps the bow (a zero vector).
static func mouse_burn_local(yaw: float, keys: Vector2, aim: Vector3) -> Vector2:
	var toward := Vector3(aim.x, 0.0, aim.z)
	if keys.length_squared() < 0.0001 or toward.length_squared() < 0.0001:
		return Vector2.ZERO
	toward = toward.normalized()
	var beside := Vector3(-toward.z, 0.0, toward.x)  # Starboard of the line to the cursor.
	var world := beside * keys.x + toward * keys.y
	return Vector2(world.dot(SailingModel.right_of(yaw)), world.dot(SailingModel.forward_of(yaw)))


## The ship yaw that points the bow along [param direction] (SailingModel.forward_of's inverse).
static func wanted_yaw(direction: Vector3) -> float:
	return atan2(-direction.x, -direction.z)


## Signed shortest turn from yaw [param from] to [param to], -PI..PI (positive = left turn).
static func yaw_error(from: float, to: float) -> float:
	return wrapf(to - from, -PI, PI)


## Ship.set_turn value that closes [param error] (see yaw_error): proportional, clamped to -1..1.
## A positive error is a left turn, and +1 is starboard, so the sign flips.
static func steer_for(error: float) -> float:
	return clampf(-error / FULL_STEER_ERROR, -1.0, 1.0)


## Degrees the ship would have to turn before [param direction] enters the cone (centre / width
## in degrees off the bow, as on a hardpoint). 0 if it is inside already.
static func cone_turn_deg(yaw: float, center_deg: float, arc_deg: float, direction: Vector3) -> float:
	if Arc.contains(yaw, center_deg, arc_deg, direction):
		return 0.0
	var off := wrapf(Arc.relative_bearing_deg(yaw, direction) - center_deg, -180.0, 180.0)
	return absf(off) - arc_deg * 0.5


## The ship yaw that puts the cursor at the centre of whichever cone needs the smallest turn.
## [param cones] holds (centre_deg, arc_deg) per held weapon. NAN when there is no correction
## to make: no cones, no cursor direction, or the cursor is already inside one of them.
static func assist_yaw(yaw: float, cones: Array[Vector2], direction: Vector3) -> float:
	if cones.is_empty() or direction.length_squared() < 0.0001:
		return NAN
	var best_turn := INF
	var best_center := 0.0
	for cone in cones:
		var turn := cone_turn_deg(yaw, cone.x, cone.y, direction)
		if turn <= 0.0:
			return NAN
		if turn < best_turn:
			best_turn = turn
			best_center = cone.x
	# Bearing is positive to starboard, which is a smaller yaw, hence the plus.
	return wrapf(wanted_yaw(direction) + deg_to_rad(best_center), -PI, PI)


# --- Lock-on -------------------------------------------------------------------------

## Tab: lock the enemy nearest [param cursor] (null = nearest the ship), or let go if locked.
func toggle_lock(cursor: Variant) -> void:
	if _ship.locked() != null:
		_ship.lock_target = null
	else:
		_ship.lock_target = LockOn.pick(_ship.enemies(), cursor, _ship.global_position)
	_lock_away = 0.0
	_lock_cone_center = NAN


## Runs the lock for one tick: ends it when the target dies, strays past LockOn.LEASH_RANGE or the
## cursor stays away LockOn.DROP_AFTER_SECONDS; otherwise, while the cursor is within
## LockOn.SNAP_RADIUS of the target, moves the aim point to the lead point. Returns true while
## that assist is on.
func update_lock(cursor: Variant, held: Array[WeaponData.FireGroup], delta: float) -> bool:
	var target := _ship.locked()
	if target == null:
		_lock_away = 0.0
		return false
	if AutoAim.flat(target.global_position - _ship.global_position).length() > LockOn.LEASH_RANGE:
		_ship.lock_target = null
		return false
	var cursor_point: Vector3 = cursor if cursor != null else _ship.aim_point
	var active := LockOn.assist_active(cursor_point, target.global_position)
	_lock_away = LockOn.next_away_time(_lock_away, active, delta)
	if _lock_away >= LockOn.DROP_AFTER_SECONDS:
		_ship.lock_target = null
		_lock_away = 0.0
		return false
	if active:
		_ship.aim_at(LockOn.lead_point(_ship.global_position, target.global_position, target.velocity, _lead_speed(held)))
	return active


## The slowest projectile among the aimed weapons in [param held] (all aimed weapons when none).
func _lead_speed(held: Array[WeaponData.FireGroup]) -> float:
	var speed := INF
	for gun in _ship.weapons():
		if gun.weapon.targeting != WeaponData.Targeting.AIMED:
			continue
		if not held.is_empty() and not held.has(gun.fire_group()):
			continue
		speed = minf(speed, gun.projectile_speed())
	return speed if speed < INF else LockOn.FALLBACK_SPEED


## (centre_deg, arc_deg, dps) of every aimed weapon in [param held] (all of them when no button
## is down): what LockOn.choose_cone picks the facing from.
func _cone_options(held: Array[WeaponData.FireGroup]) -> Array[Vector3]:
	var out: Array[Vector3] = []
	for gun in _ship.weapons():
		if gun.weapon.targeting != WeaponData.Targeting.AIMED:
			continue
		if not held.is_empty() and not held.has(gun.fire_group()):
			continue
		out.append(Vector3(gun.hardpoint.arc_center_deg, gun.hardpoint.arc_deg, WeaponStats.dps(gun.weapon, gun.stats)))
	return out


func _update_bracket() -> void:
	var target := _ship.locked()
	_bracket.visible = target != null
	if target == null:
		return
	_bracket.global_position = Vector3(target.global_position.x, 0.12, target.global_position.z)
	var radius := (target.hull.collision_radius if target.hull != null else 1.5) * 1.5
	_bracket.scale = Vector3(radius, 1.0, radius)
	_bracket_material.albedo_color = BRACKET_ACTIVE_COLOR if _assisting else BRACKET_PAUSED_COLOR


func _build_bracket() -> void:
	var ring := TorusMesh.new()
	ring.inner_radius = 0.92
	ring.outer_radius = 1.0
	_bracket_material = StandardMaterial3D.new()
	_bracket_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_bracket_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_bracket_material.albedo_color = BRACKET_ACTIVE_COLOR
	ring.material = _bracket_material
	_bracket = MeshInstance3D.new()
	_bracket.name = "LockBracket"
	_bracket.mesh = ring
	_bracket.visible = false
	_bracket.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	add_child(_bracket)


# --- Weapons and the ready marker ----------------------------------------------------

## (centre_deg, arc_deg) of every weapon in [param groups].
func _cones(groups: Array[WeaponData.FireGroup]) -> Array[Vector2]:
	var out: Array[Vector2] = []
	for gun in _ship.weapons():
		if groups.has(gun.fire_group()):
			out.append(Vector2(gun.hardpoint.arc_center_deg, gun.hardpoint.arc_deg))
	return out


## The groups the ready marker judges: those held, or both when no button is down.
func _marker_groups() -> Array[WeaponData.FireGroup]:
	var out: Array[WeaponData.FireGroup] = []
	for group: WeaponData.FireGroup in [WeaponData.FireGroup.PRIMARY, WeaponData.FireGroup.SECONDARY]:
		if _ship.is_trigger_held(group):
			out.append(group)
	if out.is_empty():
		out = [WeaponData.FireGroup.PRIMARY, WeaponData.FireGroup.SECONDARY]
	return out


## Does at least one weapon in [param groups] have the cursor inside its firing cone?
func _cursor_in_cone(groups: Array[WeaponData.FireGroup]) -> bool:
	for gun in _ship.weapons():
		if groups.has(gun.fire_group()):
			var offset := _ship.aim_point - gun.muzzle_position()
			if gun.in_arc(Vector3(offset.x, 0.0, offset.z)):
				return true
	return false


func _build_marker() -> void:
	var ring := TorusMesh.new()
	ring.inner_radius = 1.0
	ring.outer_radius = 1.12
	_marker_material = StandardMaterial3D.new()
	_marker_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_marker_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_marker_material.albedo_color = MARKER_READY_COLOR
	ring.material = _marker_material
	_marker = MeshInstance3D.new()
	_marker.name = "ReadyMarker"
	_marker.mesh = ring
	# This node is not a Node3D, so the marker sits in world space, not on the ship.
	# Moved every render frame, so it must not be smoothed against physics ticks.
	_marker.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	add_child(_marker)
