class_name Ship
extends CharacterBody3D
## One ship, used by the player and by enemies alike. A controller (PlayerInput, later
## AIController) drives it only through the command API below.
##
## Call setup() after the ship is in the scene tree. Calling it again hot-swaps the hull.

signal hull_changed(hull: HullData)
signal burn_used

const GROUP := &"ships"

var hull: HullData
## Where this ship is currently aiming, on the Y = 0 plane.
var aim_point: Vector3 = Vector3.ZERO

@onready var stats: StatsComponent = $StatsComponent
@onready var movement: MovementComponent = $MovementComponent
@onready var _model_root: Node3D = $Model
@onready var _collision: CollisionShape3D = $CollisionShape3D


func _ready() -> void:
	add_to_group(GROUP)


func setup(p_hull: HullData, mods: Array[StatMod] = []) -> void:
	hull = p_hull
	for child in _model_root.get_children():
		_model_root.remove_child(child)  # Out of the tree now, so find_child can't see it.
		child.queue_free()
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
			continue
		var mount := HardpointMount.new()
		mount.name = "Mount_%s" % hardpoint.marker_name
		marker.add_child(mount)
		mount.setup(hardpoint)

	stats.setup(hull, mods)
	hull_changed.emit(hull)


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
