class_name MovementComponent
extends Node
## Thin node adapter around SailingModel: feeds it the ship's commands and final stats
## each physics tick, then applies the result to the CharacterBody3D.

## Commands, set through the Ship's command API.
var throttle: float = 0.0
var turn: float = 0.0

var model := SailingModel.new()

@onready var _ship: Ship = get_parent() as Ship


func _physics_process(delta: float) -> void:
	var stats: Dictionary = _ship.stats.values
	if stats.is_empty():
		return  # No hull yet.
	model.step(throttle, turn, stats, delta)
	_ship.rotation.y = model.yaw
	_ship.velocity = Vector3(model.velocity.x, 0.0, model.velocity.z)
	_ship.move_and_slide()
	_ship.position.y = 0.0
	# Collisions may have redirected the body; keep the model in sync with reality.
	model.velocity = Vector3(_ship.velocity.x, 0.0, _ship.velocity.z)


func try_burn(dir_local: Vector2) -> bool:
	return model.try_burn(dir_local, _ship.stats.values)


func speed() -> float:
	return model.speed()


func effective_turn_rate_deg() -> float:
	return model.effective_turn_rate_deg(_ship.stats.values)


func burn_ready_fraction() -> float:
	return model.burn_ready_fraction(_ship.stats.values)


## Teleports the ship: new heading, no motion.
func reset(new_yaw: float = 0.0) -> void:
	model = SailingModel.new()
	model.yaw = new_yaw
	_ship.rotation.y = new_yaw
	_ship.velocity = Vector3.ZERO


## Removes the part of the velocity that points along [param outward] (a unit vector),
## so a ship at the arena edge slides along it instead of pushing through.
func remove_outward_velocity(outward: Vector3) -> void:
	var out_speed := model.velocity.dot(outward)
	if out_speed > 0.0:
		model.velocity -= outward * out_speed
		_ship.velocity = model.velocity
