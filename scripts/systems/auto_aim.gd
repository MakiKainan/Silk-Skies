class_name AutoAim
extends RefCounted
## Pure auto-targeting maths: pick the nearest valid target and lead it. Fighters use this to
## fire on their own; the AI uses the lead for its aimed shots.


## The candidate nearest [param from] within [param max_range] (flat distance) that
## [param accept] (optional, Node3D -> bool) allows, or null.
static func nearest(from: Vector3, candidates: Array, max_range: float, accept: Callable = Callable()) -> Node3D:
	var best: Node3D
	var best_distance := INF
	for candidate: Variant in candidates:
		if not is_instance_valid(candidate):
			continue
		var node := candidate as Node3D
		if node == null:
			continue
		if accept.is_valid() and not accept.call(node):
			continue
		var distance := flat(node.global_position - from).length()
		if distance <= max_range and distance < best_distance:
			best = node
			best_distance = distance
	return best


## Unit direction that makes a projectile of [param speed] meet a target moving at a
## constant velocity (first-order lead). Falls back to aiming straight at it when no
## intercept exists.
static func intercept_direction(from: Vector3, target_pos: Vector3, target_velocity: Vector3, speed: float) -> Vector3:
	var to_target := flat(target_pos - from)
	var vel := flat(target_velocity)
	var a := vel.dot(vel) - speed * speed
	var b := 2.0 * to_target.dot(vel)
	var c := to_target.dot(to_target)
	var time := -1.0
	if absf(a) < 0.0001:
		if absf(b) > 0.0001:
			time = -c / b
	else:
		var discriminant := b * b - 4.0 * a * c
		if discriminant >= 0.0:
			var root := sqrt(discriminant)
			var t1 := (-b - root) / (2.0 * a)
			var t2 := (-b + root) / (2.0 * a)
			time = minf(t1, t2) if minf(t1, t2) > 0.0 else maxf(t1, t2)
	if time <= 0.0:
		return to_target.normalized()
	return (to_target + vel * time).normalized()


static func flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)
