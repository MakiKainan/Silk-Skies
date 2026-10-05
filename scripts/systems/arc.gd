class_name Arc
extends RefCounted
## Firing-arc maths. Angles are in degrees, measured from the ship's bow, positive toward
## starboard (so 90 = starboard beam, -90 = port beam, 180 = dead astern).

## Bearing of a world-space direction relative to the ship's bow: -180..180, starboard positive.
static func relative_bearing_deg(ship_yaw: float, direction: Vector3) -> float:
	var forward := SailingModel.forward_of(ship_yaw)
	var right := SailingModel.right_of(ship_yaw)
	return rad_to_deg(atan2(direction.dot(right), direction.dot(forward)))


## Is [param direction] inside an arc [param arc_deg] wide, centred [param center_deg] off the bow?
static func contains(ship_yaw: float, center_deg: float, arc_deg: float, direction: Vector3) -> bool:
	if arc_deg >= 360.0:
		return true
	var off := wrapf(relative_bearing_deg(ship_yaw, direction) - center_deg, -180.0, 180.0)
	return absf(off) <= arc_deg * 0.5 + 0.0001


## The world direction toward [param direction], held to the nearest edge if it's outside the arc.
static func clamp_direction(ship_yaw: float, center_deg: float, arc_deg: float, direction: Vector3) -> Vector3:
	if contains(ship_yaw, center_deg, arc_deg, direction):
		return direction
	var off := wrapf(relative_bearing_deg(ship_yaw, direction) - center_deg, -180.0, 180.0)
	var edge := center_deg + signf(off) * arc_deg * 0.5
	return direction_at(ship_yaw, edge)


## World direction at [param bearing_deg] off the bow.
static func direction_at(ship_yaw: float, bearing_deg: float) -> Vector3:
	var bearing := deg_to_rad(bearing_deg)
	return SailingModel.forward_of(ship_yaw) * cos(bearing) + SailingModel.right_of(ship_yaw) * sin(bearing)
