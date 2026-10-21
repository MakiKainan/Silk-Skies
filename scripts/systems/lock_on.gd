class_name LockOn
extends RefCounted
## Pure maths for the player's soft lock-on (Tab / middle mouse): which enemy gets locked, where
## to aim to hit it, and when the assist pauses or the lock lets go. PlayerInput runs the state.

## While the cursor is within this many metres of the locked ship, aim goes to the lead point
## and the ship turns a cone onto it. Further out, the player free-aims (the lock is kept).
const SNAP_RADIUS := 20.0
## The lock drops after the cursor has stayed outside SNAP_RADIUS this long.
const DROP_AFTER_SECONDS := 1.5
## The lock drops if the target gets this far from the ship.
const LEASH_RANGE := 100.0
## Lead speed when no aimed weapon can say (m/s).
const FALLBACK_SPEED := 100.0
## A cone this wide or wider is an all-round turret: it can shoot from any heading, so it never
## decides which side of the ship faces the target.
const OMNI_ARC := 300.0
## A cone the target is already in is kept until another covering cone is this many times stronger.
const STICKY_RATIO := 1.5
## No steering while the chosen cone's centre is within this many degrees of the target.
const CENTER_DEADZONE_DEG := 4.0
## Turns this close (degrees) count as a tie when choosing between cones that miss the target.
const TIE_DEG := 0.5


## The enemy to lock: the one nearest the cursor point ([param cursor] null = nearest to
## [param ship_position] instead). Dead or freed ships never count. Null if there is none.
static func pick(enemies: Array, cursor: Variant, ship_position: Vector3) -> Ship:
	var origin: Vector3 = cursor if cursor != null else ship_position
	var best: Ship
	var best_distance := INF
	for candidate: Variant in enemies:
		if not is_instance_valid(candidate):
			continue
		var ship := candidate as Ship
		if ship == null or not ship.is_alive():
			continue
		var distance := AutoAim.flat(ship.global_position - origin).length()
		if distance < best_distance:
			best = ship
			best_distance = distance
	return best


## Where to aim from [param muzzle] so a shot of [param speed] meets the moving target: the
## direction of the first-order intercept, at the target's current range.
static func lead_point(muzzle: Vector3, target_position: Vector3, target_velocity: Vector3, speed: float) -> Vector3:
	var direction := AutoAim.intercept_direction(muzzle, target_position, target_velocity, speed)
	var distance := maxf(AutoAim.flat(target_position - muzzle).length(), 1.0)
	return Vector3(muzzle.x, 0.0, muzzle.z) + direction * distance


## The weapon cone the ship should present to the target, as (centre_deg, arc_deg, dps), or
## Vector3(NAN, 0, 0) when no cone should steer the ship. [param cones] holds one
## (centre_deg, arc_deg, dps) per weapon; weapons sharing a cone are added together. All-round
## turrets are ignored (they fire from any heading). Choice, in order:
##  - a cone the target is already inside: the strongest of those, but the cone chosen last tick
##    ([param sticky_center], NAN for none) is kept unless another is STICKY_RATIO times stronger;
##  - otherwise the cone that needs the smallest turn, ties going to the stronger one.
static func choose_cone(yaw: float, direction: Vector3, cones: Array[Vector3], sticky_center: float) -> Vector3:
	var groups: Dictionary = {}  # Vector2(centre, arc) -> dps
	for cone in cones:
		if cone.y >= OMNI_ARC:
			continue
		var key := Vector2(cone.x, cone.y)
		groups[key] = float(groups.get(key, 0.0)) + cone.z
	var covering: Array[Vector3] = []
	var best_miss := Vector3(NAN, 0.0, 0.0)
	var best_turn := INF
	for key: Vector2 in groups:
		var group := Vector3(key.x, key.y, groups[key])
		var turn := PlayerInput.cone_turn_deg(yaw, key.x, key.y, direction)
		if turn <= 0.0:
			covering.append(group)
		elif turn < best_turn - TIE_DEG or (absf(turn - best_turn) <= TIE_DEG and not is_nan(best_miss.x) and group.z > best_miss.z):
			best_turn = turn
			best_miss = group
	if covering.is_empty():
		return best_miss
	var strongest := covering[0]
	var sticky := Vector3(NAN, 0.0, 0.0)
	for group in covering:
		if group.z > strongest.z:
			strongest = group
		if not is_nan(sticky_center) and absf(group.x - sticky_center) < 0.01:
			sticky = group
	if not is_nan(sticky.x) and strongest.z < sticky.z * STICKY_RATIO:
		return sticky
	return strongest


## The Ship.set_turn value that swings the cone centred [param center_deg] off the bow onto
## [param direction], at the normal proportional rate; 0 inside the CENTER_DEADZONE_DEG.
static func steer_to_center(yaw: float, direction: Vector3, center_deg: float) -> float:
	if direction.length_squared() < 0.0001 or is_nan(center_deg):
		return 0.0
	var wanted := wrapf(PlayerInput.wanted_yaw(direction) + deg_to_rad(center_deg), -PI, PI)
	var error := PlayerInput.yaw_error(yaw, wanted)
	if absf(rad_to_deg(error)) < CENTER_DEADZONE_DEG:
		return 0.0
	return PlayerInput.steer_for(error)


## Is the assist on: the cursor close enough to the locked ship?
static func assist_active(cursor: Vector3, target_position: Vector3) -> bool:
	return AutoAim.flat(cursor - target_position).length() <= SNAP_RADIUS


## Seconds the cursor has been away: counts up while the assist is paused, resets when it is on.
static func next_away_time(away: float, active: bool, delta: float) -> float:
	return 0.0 if active else away + delta
