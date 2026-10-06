class_name AISteering
extends RefCounted
## Pure steering maths for AI ships: where to head, how to turn and throttle to get there,
## and when to dodge. No nodes, so it's unit-testable.

## A turn this large (radians) or more asks for full steering.
const FULL_TURN_ANGLE := PI / 6.0
## Beyond this angle off the bow the ship stops thrusting and just turns.
const NO_THRUST_ANGLE := deg_to_rad(100.0)


## The point a ship should head for: on a circle around the target, a little way around from
## where it is now. Holds its current distance while inside the band; outside it, the point
## sits on the band's edge, so the ship closes or opens the gap. [param orbit_sign] picks the
## circling direction (+1 / -1).
static func pursuit_point(target_pos: Vector3, my_pos: Vector3, preferred_range: float, range_band: float, orbit_sign: float, orbit_lead_deg: float) -> Vector3:
	var offset := Vector3(my_pos.x - target_pos.x, 0.0, my_pos.z - target_pos.z)
	var distance := offset.length()
	var radial := offset / distance if distance > 0.01 else Vector3.BACK
	var radius := clampf(distance, maxf(preferred_range - range_band, 1.0), preferred_range + range_band)
	var lead := deg_to_rad(orbit_lead_deg) * signf(orbit_sign)
	return Vector3(target_pos.x, 0.0, target_pos.z) + radial.rotated(Vector3.UP, lead) * radius


## Turn and throttle commands to head from [param my_pos] (facing [param my_yaw]) to
## [param point]. Returns {"turn": -1..1, "throttle": 0..1}.
static func steer(my_pos: Vector3, my_yaw: float, point: Vector3, max_throttle: float) -> Dictionary:
	var to_point := Vector3(point.x - my_pos.x, 0.0, point.z - my_pos.z)
	if to_point.length() < 0.5:
		return {"turn": 0.0, "throttle": 0.0}
	var forward := SailingModel.forward_of(my_yaw)
	# Positive angle = the point is to the left; positive turn input = starboard.
	var angle := forward.signed_angle_to(to_point.normalized(), Vector3.UP)
	var turn := -clampf(angle / FULL_TURN_ANGLE, -1.0, 1.0)
	var throttle := 0.0
	if absf(angle) < NO_THRUST_ANGLE:
		throttle = clampf(cos(angle), 0.0, 1.0) * max_throttle
	return {"turn": turn, "throttle": throttle}


## If a projectile will pass close enough to hit the ship soon, the world direction to dodge
## in (away from the projectile's line). Zero if there's no threat.
static func dodge_direction(ship_pos: Vector3, ship_radius: float, proj_pos: Vector3, proj_dir: Vector3, proj_speed: float, horizon: float = 0.7) -> Vector3:
	var rel := Vector3(ship_pos.x - proj_pos.x, 0.0, ship_pos.z - proj_pos.z)
	var dir := Vector3(proj_dir.x, 0.0, proj_dir.z).normalized()
	var along := rel.dot(dir)
	if along <= 0.0 or along > proj_speed * horizon:
		return Vector3.ZERO  # Behind it, or too far away to worry about yet.
	var closest := rel - dir * along
	if closest.length() > ship_radius * 1.4:
		return Vector3.ZERO  # It will miss.
	if closest.length() < 0.05:
		return dir.rotated(Vector3.UP, PI / 2.0)  # Dead centre: either side will do.
	return closest.normalized()
