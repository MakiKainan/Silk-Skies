class_name MouseAim
extends RefCounted
## Projects the mouse cursor onto the flat play plane.

## World point under [param screen_pos] on the plane y = [param plane_y], or null if the
## ray never hits it.
static func ground_point(camera: Camera3D, screen_pos: Vector2, plane_y: float = 0.0) -> Variant:
	var origin := camera.project_ray_origin(screen_pos)
	var direction := camera.project_ray_normal(screen_pos)
	return Plane(Vector3.UP, plane_y).intersects_ray(origin, direction)
