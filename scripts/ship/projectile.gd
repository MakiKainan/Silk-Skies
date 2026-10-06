class_name Projectile
extends Node3D
## A bullet, bolt or missile. Flies on the XZ plane and each physics tick ray-casts the
## segment it just travelled, so fast slugs can't tunnel through ships. Hits enemy-team ships,
## is stopped by world geometry (asteroids), can pierce, can home, can explode.

const GROUP := &"projectiles"
## Physics layers 1 (ships) and 2 (world).
const HIT_MASK := 3

var data: ProjectileData
var direction: Vector3 = Vector3.FORWARD
var target: Ship
var pierce_left: int = 0

var _damage_value: float = 0.0
var _speed: float = 0.0
var _lifetime: float = 0.0
var _source: Ship
var _team: StringName
var _age: float = 0.0
var _excluded: Array[RID] = []


## Creates a projectile under [param parent] and launches it. [param target] only matters if the
## data homes. The damage / speed / lifetime overrides (when >= 0) replace the data's values;
## a weapon passes its final stats this way.
static func spawn(parent: Node, p_data: ProjectileData, source: Ship, origin: Vector3, dir: Vector3, p_target: Ship = null, damage: float = -1.0, speed: float = -1.0, lifetime: float = -1.0) -> Projectile:
	var projectile := Projectile.new()
	projectile.data = p_data
	projectile._damage_value = damage if damage >= 0.0 else p_data.damage
	projectile._speed = speed if speed >= 0.0 else p_data.speed
	projectile._lifetime = lifetime if lifetime >= 0.0 else p_data.lifetime
	projectile._source = source
	projectile._team = source.team
	projectile.direction = Vector3(dir.x, 0.0, dir.z).normalized()
	projectile.target = p_target if p_data.homing_deg_per_sec > 0.0 else null
	projectile.pierce_left = p_data.pierce
	projectile._excluded.append(source.get_rid())
	parent.add_child(projectile)
	projectile.global_position = Vector3(origin.x, 0.0, origin.z)
	projectile._face_direction()
	projectile.reset_physics_interpolation()
	return projectile


func team() -> StringName:
	return _team


func current_speed() -> float:
	return _speed


func _ready() -> void:
	add_to_group(GROUP)
	_build_visual()


func _physics_process(delta: float) -> void:
	_age += delta
	if _age >= _lifetime:
		queue_free()
		return
	_steer(delta)
	var from := global_position
	var to := from + direction * _speed * delta
	var space := get_world_3d().direct_space_state
	while true:
		var query := PhysicsRayQueryParameters3D.create(from, to, HIT_MASK)
		query.exclude = _excluded
		var hit := space.intersect_ray(query)
		if hit.is_empty():
			break
		var collider := hit.collider as Object
		var point: Vector3 = hit.position
		if collider is Ship:
			var ship := collider as Ship
			_excluded.append(ship.get_rid())
			if ship.team == _team or not ship.is_alive():
				continue  # Friendly or already dead: fly through.
			if data.blast_radius > 0.0:
				_explode(point)
				return
			_damage(ship, point)
			if pierce_left > 0:
				pierce_left -= 1
				continue
			queue_free()
			return
		# World geometry stops it.
		if data.blast_radius > 0.0:
			_explode(point)
		else:
			queue_free()
		return
	global_position = to
	_face_direction()


func _steer(delta: float) -> void:
	if target == null or not is_instance_valid(target) or not target.is_alive():
		target = null
		return
	var to_target := target.global_position - global_position
	to_target.y = 0.0
	if to_target.length_squared() < 0.0001:
		return
	var max_turn := deg_to_rad(data.homing_deg_per_sec) * delta
	var wanted := direction.signed_angle_to(to_target.normalized(), Vector3.UP)
	direction = direction.rotated(Vector3.UP, clampf(wanted, -max_turn, max_turn)).normalized()


func _damage(ship: Ship, point: Vector3) -> void:
	ship.health.apply_hit(Hit.make(_damage_value, data.damage_type, _source if is_instance_valid(_source) else null, point))


## Damages every living enemy-team ship whose hull is within the blast radius.
func _explode(point: Vector3) -> void:
	for node in get_tree().get_nodes_in_group(Ship.GROUP):
		var ship := node as Ship
		if ship.team == _team or not ship.is_alive():
			continue
		var offset := ship.global_position - point
		offset.y = 0.0
		var reach := data.blast_radius + (ship.hull.collision_radius if ship.hull != null else 0.0)
		if offset.length() <= reach:
			_damage(ship, ship.global_position)
	Vfx.ring(get_parent(), point, data.blast_radius, data.color)
	queue_free()


func _face_direction() -> void:
	global_basis = Basis.looking_at(direction, Vector3.UP)


func _build_visual() -> void:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = data.color
	var mesh: Mesh
	match data.damage_type:
		Damage.Type.ENERGY:
			var bolt := BoxMesh.new()  # Thin, long, bright.
			bolt.size = Vector3(data.radius, data.radius, data.length)
			mesh = bolt
		Damage.Type.KINETIC:
			var slug := BoxMesh.new()  # Short, hard.
			slug.size = Vector3(data.radius * 2.0, data.radius * 2.0, data.length)
			mesh = slug
		_:
			var missile := CapsuleMesh.new()  # Fat and round.
			missile.radius = data.radius
			missile.height = maxf(data.length, data.radius * 2.0)
			mesh = missile
	mesh.material = material
	var visual := MeshInstance3D.new()
	visual.mesh = mesh
	if data.damage_type == Damage.Type.EXPLOSIVE:
		visual.rotation.x = PI / 2.0  # Capsules stand up; lay it along the flight direction.
	add_child(visual)
