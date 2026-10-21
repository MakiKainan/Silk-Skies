class_name Projectile
extends Node3D
## A bullet, bolt or missile. Flies on the XZ plane and each physics tick ray-casts the
## segment it just travelled, so fast slugs can't tunnel through ships. Hits enemy-team ships and
## fighters, is stopped by world geometry (asteroids), can pierce, can home, can explode. Homing
## shots (missiles) can be shot down by interceptor fighters and by any bullet: a missile blinks
## red faster and faster as it closes on its target, and one hit disarms it.

const GROUP := &"projectiles"
## Physics layers 1 (ships), 2 (world) and 4 (fighters).
const HIT_MASK := 1 | 2 | Fighter.LAYER
## How near a bullet's path must pass a missile to disarm it (metres, plus the bullet's radius).
const MISSILE_HIT_RADIUS := 0.9
## A missile's blink: slow beyond BLINK_FAR metres from its target, frantic inside BLINK_NEAR.
const BLINK_FAR := 36.0
const BLINK_NEAR := 5.0
const BLINK_SLOW_HZ := 1.5
const BLINK_FAST_HZ := 16.0
const BLINK_COLOR := Color(1.0, 0.08, 0.05)

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
# Missile warning blink (see current_blink_hz).
var _blink_phase := 0.0
var _blink_beacon: MeshInstance3D
var _blink_material: StandardMaterial3D
var _body_material: StandardMaterial3D
# Damage drop-off (see set_falloff); off unless a weapon sets it.
var _falloff_on := false
var _falloff_origin := Vector3.ZERO
var _falloff_start := 0.0
var _falloff_range := 0.0
var _falloff_min := 1.0


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


## Where shots and fighters are parented: the "projectile_root" group's node if the scene has
## one, else the current scene (or the root, in tests).
static func default_parent(from: Node) -> Node:
	var tree := from.get_tree()
	var root := tree.get_first_node_in_group(&"projectile_root")
	if root != null:
		return root
	return tree.current_scene if tree.current_scene != null else tree.root


## Turns on damage drop-off: hits further than [param start] metres from [param origin] (the
## muzzle) do less damage, down to [param min_mult] at [param max_range]. See
## WeaponData.falloff_multiplier.
func set_falloff(origin: Vector3, start: float, max_range: float, min_mult: float) -> void:
	_falloff_on = true
	_falloff_origin = Vector3(origin.x, 0.0, origin.z)
	_falloff_start = start
	_falloff_range = max_range
	_falloff_min = min_mult


## What a hit at [param point] deals, after drop-off.
func damage_at(point: Vector3) -> float:
	if not _falloff_on:
		return _damage_value
	var distance := AutoAim.flat(point - _falloff_origin).length()
	return _damage_value * WeaponData.falloff_multiplier(distance, _falloff_range, _falloff_start, _falloff_min)


func team() -> StringName:
	return _team


## Homing shots (missiles) can be shot down by interceptors.
func is_interceptable() -> bool:
	return data.homing_deg_per_sec > 0.0 and not is_queued_for_deletion()


## Blinks per second for a missile [param distance] metres from its target: BLINK_SLOW_HZ out
## at BLINK_FAR and beyond, ramping up to BLINK_FAST_HZ at BLINK_NEAR and inside.
static func blink_hz(distance: float) -> float:
	var closeness := 1.0 - clampf((distance - BLINK_NEAR) / (BLINK_FAR - BLINK_NEAR), 0.0, 1.0)
	return lerpf(BLINK_SLOW_HZ, BLINK_FAST_HZ, closeness * closeness)


## How fast this missile is blinking right now (0 for anything that isn't a missile).
func current_blink_hz() -> float:
	if data.homing_deg_per_sec <= 0.0:
		return 0.0
	return blink_hz(_distance_to_victim())


## Distance to the ship this missile is homing on, or to the nearest enemy ship if it has lost it.
func _distance_to_victim() -> float:
	if target != null and is_instance_valid(target) and target.is_alive():
		return AutoAim.flat(target.global_position - global_position).length()
	var best := INF
	for node in get_tree().get_nodes_in_group(Ship.GROUP):
		var ship := node as Ship
		if ship.team != _team and ship.is_alive():
			best = minf(best, AutoAim.flat(ship.global_position - global_position).length())
	return best


## Shot down mid-flight: a small puff, no damage.
func intercept() -> void:
	if is_queued_for_deletion():
		return
	Vfx.ring(get_parent(), global_position, 1.6, BLINK_COLOR, 0.3)
	queue_free()


func current_speed() -> float:
	return _speed


func _ready() -> void:
	add_to_group(GROUP)
	set_process(data.homing_deg_per_sec > 0.0)  # Only missiles blink.
	_build_visual()


func _process(delta: float) -> void:
	if _blink_beacon == null:
		return
	_blink_phase = fmod(_blink_phase + current_blink_hz() * delta, 1.0)
	var on := _blink_phase < 0.5
	_blink_beacon.visible = on
	if _body_material != null:
		_body_material.albedo_color = BLINK_COLOR if on else data.color


func _physics_process(delta: float) -> void:
	_age += delta
	if _age >= _lifetime:
		queue_free()
		return
	_steer(delta)
	var from := global_position
	var to := from + direction * _speed * delta
	var space := get_world_3d().direct_space_state
	var missile: Variant = _missile_in_path(from, to)
	while true:
		var query := PhysicsRayQueryParameters3D.create(from, to, HIT_MASK)
		query.exclude = _excluded
		var hit := space.intersect_ray(query)
		var hit_distance := INF if hit.is_empty() else from.distance_to(hit.position)
		if missile != null and missile.along <= hit_distance:
			# The bullet reaches an enemy missile before anything else: it is disarmed.
			(missile.node as Projectile).intercept()
			missile = null
			if pierce_left > 0:
				pierce_left -= 1
				continue
			queue_free()
			return
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
			_impact(point)
			if pierce_left > 0:
				pierce_left -= 1
				continue
			queue_free()
			return
		if collider is Fighter:
			var fighter := collider as Fighter
			_excluded.append(fighter.get_rid())
			if fighter.team == _team or not fighter.is_alive():
				continue
			if data.blast_radius > 0.0:
				_explode(point)
				return
			fighter.take_damage(damage_at(point))
			_impact(point)
			if pierce_left > 0:
				pierce_left -= 1
				continue
			queue_free()
			return
		# World geometry stops it.
		if data.blast_radius > 0.0:
			_explode(point)
		else:
			_impact(point)
			queue_free()
		return
	global_position = to
	_face_direction()


## The nearest enemy missile this bullet's path crosses this tick: {node, along} (metres from
## [param from]), or null. Missiles don't disarm each other.
func _missile_in_path(from: Vector3, to: Vector3) -> Variant:
	if data.homing_deg_per_sec > 0.0:
		return null
	var best: Variant = null
	var path := to - from
	var length_squared := path.length_squared()
	for node in get_tree().get_nodes_in_group(GROUP):
		var other := node as Projectile
		if other == self or other.team() == _team or not other.is_interceptable():
			continue
		var offset := other.global_position - from
		var t := clampf(offset.dot(path) / length_squared, 0.0, 1.0) if length_squared > 0.0 else 0.0
		var closest := from + path * t
		if AutoAim.flat(other.global_position - closest).length() <= MISSILE_HIT_RADIUS + data.radius:
			var along := path.length() * t
			if best == null or along < best.along:
				best = {"node": other, "along": along}
	return best


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
	ship.health.apply_hit(Hit.make(damage_at(point), data.damage_type, _source if is_instance_valid(_source) else null, point))


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
	for node in get_tree().get_nodes_in_group(Fighter.GROUP):
		var fighter := node as Fighter
		if fighter.team != _team and fighter.is_alive() and AutoAim.flat(fighter.global_position - point).length() <= data.blast_radius + Fighter.RADIUS:
			fighter.take_damage(damage_at(point))
	_impact(point)
	queue_free()


## Sound and effect where the shot ended. Blasts fall back to the placeholder ring.
func _impact(point: Vector3) -> void:
	var parent := get_parent()
	Sfx.play_3d(parent, ArtLookup.impact_sound(data), point)
	var scene := ArtLookup.impact_scene(data)
	if scene != null:
		Vfx.spawn_scene(parent, scene, point)
	elif data.blast_radius > 0.0:
		Vfx.ring(parent, point, data.blast_radius, data.color)


## A glowing red ball around a missile that blinks with the warning (works for any missile model).
func _build_beacon() -> void:
	var sphere := SphereMesh.new()
	sphere.radius = maxf(data.radius * 1.6, 0.3)
	sphere.height = sphere.radius * 2.0
	_blink_material = StandardMaterial3D.new()
	_blink_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_blink_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_blink_material.albedo_color = Color(BLINK_COLOR, 0.55)
	sphere.material = _blink_material
	_blink_beacon = MeshInstance3D.new()
	_blink_beacon.name = "BlinkBeacon"
	_blink_beacon.mesh = sphere
	add_child(_blink_beacon)


func _face_direction() -> void:
	global_basis = Basis.looking_at(direction, Vector3.UP)


func _build_visual() -> void:
	if data.homing_deg_per_sec > 0.0:
		_build_beacon()
	var scene := ArtLookup.projectile_scene(data)
	if scene != null:
		var model := scene.instantiate() as Node3D
		if model != null:
			add_child(model)
			return
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = data.color
	if data.homing_deg_per_sec > 0.0:
		_body_material = material
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
