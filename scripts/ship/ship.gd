class_name Ship
extends CharacterBody3D
## One ship, used by the player and by enemies alike. A controller (PlayerInput, later
## AIController) drives it only through the command API below.
##
## Call setup() after the ship is in the scene tree. Calling it again hot-swaps the hull
## (and empties the weapon slots; equip() again afterwards).

signal hull_changed(hull: HullData)
signal loadout_changed
signal burn_used
signal died(source: Node)

const GROUP := &"ships"
const TEAM_PLAYER := &"player"
const TEAM_ENEMY := &"enemy"

var hull: HullData
## What this ship carries: mounted items and the cargo hold. Change it through this object
## (move / set_item / ...); the ship follows automatically.
var loadout: ShipLoadout
## Cargo hold size used when a new loadout is created.
var cargo_capacity: int = ShipLoadout.RUN_CARGO_SLOTS
var team: StringName = TEAM_PLAYER
## Where this ship is currently aiming, on the Y = 0 plane.
var aim_point: Vector3 = Vector3.ZERO
## Sandbox/EMP hook: when false no weapon will fire.
var weapons_enabled: bool = true
## Enemies and dummies disappear when destroyed; the player persists so it can be revived.
var free_on_death: bool = true
var show_arcs: bool = false:
	set(value):
		show_arcs = value
		for mount in mounts:
			if mount != null:
				mount.set_arc_visible(value)
## One per hull hardpoint, in hardpoint order.
var mounts: Array[HardpointMount] = []

var _extra_mods: Array[StatMod] = []
var _triggers := {
	WeaponData.Targeting.MANUAL: false,
	WeaponData.Targeting.LOCK_ON: false,
}

@onready var stats: StatsComponent = $StatsComponent
@onready var movement: MovementComponent = $MovementComponent
@onready var health: HealthComponent = $HealthComponent
@onready var _model_root: Node3D = $Model
@onready var _collision: CollisionShape3D = $CollisionShape3D


func _ready() -> void:
	add_to_group(GROUP)
	health.setup(stats)
	health.destroyed.connect(_on_destroyed)


## Builds the ship from [param p_hull]. [param mods] are extra stat modifiers on top of the
## loadout's. [param keep_loadout] carries an existing loadout over to this hull (mounted
## items that fit re-mount; the rest go to cargo).
func setup(p_hull: HullData, mods: Array[StatMod] = [], keep_loadout: ShipLoadout = null) -> void:
	hull = p_hull
	_extra_mods = mods.duplicate()
	if keep_loadout != null:
		loadout = keep_loadout
		loadout.rebind_hull(hull, false)
	else:
		loadout = ShipLoadout.new(hull, cargo_capacity)
	if not loadout.changed.is_connected(_apply_loadout):
		loadout.changed.connect(_apply_loadout)
	for child in _model_root.get_children():
		_model_root.remove_child(child)  # Out of the tree now, so find_child can't see it.
		child.queue_free()
	mounts.clear()
	var model := hull.model_scene.instantiate() as Node3D
	_model_root.add_child(model)

	var shape := CylinderShape3D.new()
	shape.radius = hull.collision_radius
	shape.height = 1.0
	_collision.shape = shape

	for hardpoint in hull.hardpoints:
		var marker := hardpoint.find_marker(model)
		if marker == null:
			push_warning("Hull '%s': marker '%s' missing" % [hull.id, hardpoint.marker_name])
			mounts.append(null)
			continue
		var mount := HardpointMount.new()
		mount.name = "Mount_%s" % hardpoint.marker_name
		marker.add_child(mount)
		mount.setup(hardpoint)
		mount.set_arc_visible(show_arcs)
		mounts.append(mount)

	stats.setup(hull, _extra_mods)
	_apply_loadout()
	health.refill()
	hull_changed.emit(hull)


## Switches hull but keeps the loadout (see setup()).
func swap_hull(new_hull: HullData) -> void:
	setup(new_hull, _extra_mods, loadout)


## Swaps in a whole loadout (for example a saved one) for the current hull.
func set_loadout(new_loadout: ShipLoadout) -> void:
	setup(hull, _extra_mods, new_loadout)


## Recomputes stats from the hull and everything equipped. Used by the tuning panel's reset.
func refresh_stats(reset_base: bool = true) -> void:
	if reset_base:
		stats.setup(hull, _global_mods())
	else:
		stats.set_mods(_global_mods())


# --- Command API (shared by every controller) -----------------------------------------

## -1 (reverse) .. +1 (full ahead).
func set_throttle(amount: float) -> void:
	movement.throttle = clampf(amount, -1.0, 1.0)


## -1 (port) .. +1 (starboard).
func set_turn(amount: float) -> void:
	movement.turn = clampf(amount, -1.0, 1.0)


## [param dir_local]: x = starboard, y = bow; a zero vector bursts straight ahead.
func request_hard_burn(dir_local: Vector2 = Vector2.ZERO) -> void:
	if movement.try_burn(dir_local):
		burn_used.emit()


func aim_at(world_point: Vector3) -> void:
	aim_point = Vector3(world_point.x, 0.0, world_point.z)


## Holds or releases the trigger for a weapon class. Auto weapons ignore triggers.
func set_trigger(mode: WeaponData.Targeting, held: bool) -> void:
	if _triggers.has(mode):
		_triggers[mode] = held


func is_trigger_held(mode: WeaponData.Targeting) -> bool:
	return _triggers.get(mode, false)


# --- Loadout -------------------------------------------------------------------------

## Mounts a plain (Common, no rolls) [param weapon] on hardpoint [param index]; null empties
## it. Returns false, changing nothing, if the index is bad or the weapon doesn't fit.
func equip(index: int, weapon: WeaponData) -> bool:
	return equip_item(index, ItemInstance.make(weapon) if weapon != null else null)


## Mounts a specific item (any kind) on hardpoint [param index]; null empties it.
func equip_item(index: int, item: ItemInstance) -> bool:
	if index < 0 or index >= mounts.size() or mounts[index] == null:
		return false
	return loadout.set_item(ShipLoadout.Kind.SLOT, index, item)


func weapon_at(index: int) -> WeaponController:
	if index < 0 or index >= mounts.size() or mounts[index] == null:
		return null
	return mounts[index].weapon_controller


## Every equipped weapon, in hardpoint order.
func weapons() -> Array[WeaponController]:
	var out: Array[WeaponController] = []
	for mount in mounts:
		if mount != null and mount.weapon_controller != null:
			out.append(mount.weapon_controller)
	return out


func _global_mods() -> Array[StatMod]:
	var mods := LoadoutStats.global_mods(loadout.equipped())
	mods.append_array(_extra_mods)
	return mods


## Brings everything that depends on the loadout up to date: weapon controllers on the
## mounts, the ship's stats, each weapon's own stats. Runs whenever the loadout changes.
func _apply_loadout() -> void:
	for index in mounts.size():
		var mount := mounts[index]
		if mount == null:
			continue
		var item := loadout.slots[index]
		if item != null and item.data() is WeaponData:
			if mount.weapon_controller == null or mount.weapon_controller.instance != item:
				mount.equip(item.data() as WeaponData, self, item)
		elif mount.weapon_controller != null:
			mount.equip(null, self)
	stats.set_mods(_global_mods())
	var global := LoadoutStats.global_mods(loadout.equipped())
	for controller in weapons():
		controller.refresh_stats(global)
	loadout_changed.emit()


# --- Combat state --------------------------------------------------------------------

func is_alive() -> bool:
	return not health.is_dead


## Living ships on other teams.
func enemies() -> Array[Ship]:
	var out: Array[Ship] = []
	for node in get_tree().get_nodes_in_group(GROUP):
		var other := node as Ship
		if other != self and other.team != team and other.is_alive():
			out.append(other)
	return out


func _on_destroyed(source: Node) -> void:
	movement.throttle = 0.0
	movement.turn = 0.0
	collision_layer = 0
	visible = false
	Vfx.ring(get_parent(), global_position, hull.collision_radius * 3.0, Color(1.0, 0.6, 0.2), 0.6)
	died.emit(source)
	if free_on_death:
		queue_free()


## Brings a dead ship back at [param world_position] with full health.
func revive(world_position: Vector3, yaw: float = 0.0) -> void:
	health.refill()
	collision_layer = 1
	visible = true
	place(world_position, yaw)


# --- World hooks ---------------------------------------------------------------------

## Teleports the ship and stops it.
func place(world_position: Vector3, yaw: float = 0.0) -> void:
	global_position = Vector3(world_position.x, 0.0, world_position.z)
	movement.reset(yaw)
	reset_physics_interpolation()


## Keeps the ship inside a circular arena: pulls it back to the edge and cancels the
## outward part of its velocity, so it slides along the boundary.
func enforce_bounds(center: Vector3, radius: float) -> void:
	var offset := Vector3(global_position.x - center.x, 0.0, global_position.z - center.z)
	var limit := radius - (hull.collision_radius if hull != null else 0.0)
	var distance := offset.length()
	if distance <= limit or distance == 0.0:
		return
	var outward := offset / distance
	global_position = Vector3(center.x, 0.0, center.z) + outward * limit
	movement.remove_outward_velocity(outward)
