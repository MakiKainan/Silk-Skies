class_name SailingModel
extends RefCounted
## Pure sailing physics on the XZ plane: no nodes, no engine state, fully unit-testable.
## MovementComponent feeds it input each physics tick and applies the result to the body.
##
## Conventions: yaw is radians about +Y; the bow points toward -Z at yaw 0.
## Turn input is -1 (port/left) .. +1 (starboard/right). Positive yaw is a left turn.

## At full speed the turn rate is this fraction of the standstill turn rate (spec 2.1).
const FULL_SPEED_TURN_FACTOR := 0.4
## Reverse thrust and reverse top speed, as a fraction of the forward values.
const REVERSE_FACTOR := 0.4
## Per-second decay of speed above max_speed (the tail of a Hard Burn).
const OVERSPEED_DECAY := 2.5
## How quickly the ship's rotation eases to the target rate, as a multiple of turn_rate per second.
const TURN_RESPONSE := 5.0
## Seconds after a Hard Burn during which steering is ignored, so a strafe burst
## doesn't also spin the ship.
const BURN_TURN_LOCK := 0.2

var yaw: float = 0.0
var velocity: Vector3 = Vector3.ZERO
## Radians per second; positive = turning left (counter-clockwise from above).
var angular_velocity: float = 0.0
var burn_cooldown_left: float = 0.0
var burn_turn_lock_left: float = 0.0


static func forward_of(p_yaw: float) -> Vector3:
	return Basis(Vector3.UP, p_yaw) * Vector3.FORWARD


static func right_of(p_yaw: float) -> Vector3:
	return Basis(Vector3.UP, p_yaw) * Vector3.RIGHT


## Turn rate (deg/s) available at a given speed: full at standstill, 40% at max_speed.
static func turn_rate_at_speed(base_turn_deg: float, speed: float, max_speed: float) -> float:
	var t := clampf(speed / maxf(max_speed, 0.001), 0.0, 1.0)
	return base_turn_deg * lerpf(1.0, FULL_SPEED_TURN_FACTOR, t)


## World-space velocity change for a Hard Burn. [param dir_local] is (x = starboard, y = bow)
## relative to the ship; a zero vector means straight ahead.
static func burn_velocity(p_yaw: float, dir_local: Vector2, impulse: float) -> Vector3:
	var dir := Vector2(0.0, 1.0) if dir_local.length_squared() < 0.0001 else dir_local.normalized()
	return (forward_of(p_yaw) * dir.y + right_of(p_yaw) * dir.x) * impulse


func speed() -> float:
	return velocity.length()


func effective_turn_rate_deg(stats: Dictionary) -> float:
	return turn_rate_at_speed(stats[Stats.TURN_RATE], speed(), stats[Stats.MAX_SPEED])


## 0..1; 1 means Hard Burn is ready.
func burn_ready_fraction(stats: Dictionary) -> float:
	var cooldown: float = stats[Stats.BURN_COOLDOWN]
	if burn_cooldown_left <= 0.0 or cooldown <= 0.0:
		return 1.0
	return 1.0 - burn_cooldown_left / cooldown


## Fires a Hard Burn if it's off cooldown. Returns whether it fired.
func try_burn(dir_local: Vector2, stats: Dictionary) -> bool:
	if burn_cooldown_left > 0.0:
		return false
	velocity += burn_velocity(yaw, dir_local, stats[Stats.BURN_IMPULSE])
	burn_cooldown_left = stats[Stats.BURN_COOLDOWN]
	burn_turn_lock_left = BURN_TURN_LOCK
	return true


## Advances the model by [param delta] seconds. [param throttle] is -1 (reverse) .. +1 (ahead).
func step(throttle: float, turn: float, stats: Dictionary, delta: float) -> void:
	var max_speed: float = stats[Stats.MAX_SPEED]
	var accel: float = float(stats[Stats.THRUST]) / maxf(float(stats[Stats.MASS]), 0.001)
	var turn_rate_deg: float = stats[Stats.TURN_RATE]

	burn_cooldown_left = maxf(burn_cooldown_left - delta, 0.0)
	burn_turn_lock_left = maxf(burn_turn_lock_left - delta, 0.0)

	# Turning: rotation eases toward a target rate that falls as the ship speeds up.
	var steer := 0.0 if burn_turn_lock_left > 0.0 else clampf(turn, -1.0, 1.0)
	var target_rate := -steer * deg_to_rad(turn_rate_at_speed(turn_rate_deg, speed(), max_speed))
	var response := deg_to_rad(turn_rate_deg) * TURN_RESPONSE * delta
	angular_velocity = move_toward(angular_velocity, target_rate, response)
	yaw = wrapf(yaw + angular_velocity * delta, -PI, PI)
	var forward := forward_of(yaw)

	# Thrust: along the bow only. Engines never push past the speed cap, and never
	# brake an overspeed ship (drag does that).
	var t := clampf(throttle, -1.0, 1.0)
	if t != 0.0:
		var forward_speed := velocity.dot(forward)
		var new_speed := forward_speed
		if t > 0.0:
			new_speed = minf(forward_speed + t * accel * delta, maxf(forward_speed, max_speed))
		else:
			var reverse_cap := max_speed * REVERSE_FACTOR
			new_speed = maxf(forward_speed + t * REVERSE_FACTOR * accel * delta, minf(forward_speed, -reverse_cap))
		velocity += forward * (new_speed - forward_speed)

	# Drag, then kill sideways drift according to lateral grip.
	velocity *= exp(-float(stats[Stats.DRAG]) * delta)
	var lateral := velocity - forward * velocity.dot(forward)
	velocity -= lateral * (1.0 - exp(-float(stats[Stats.LATERAL_GRIP]) * delta))

	# Speed above the cap (a Hard Burn) bleeds off quickly.
	var current := velocity.length()
	if current > max_speed:
		velocity *= (max_speed + (current - max_speed) * exp(-OVERSPEED_DECAY * delta)) / current
