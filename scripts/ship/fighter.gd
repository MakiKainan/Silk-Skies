class_name Fighter
extends AnimatableBody3D
## One drone launched by a FighterBayController. It flies and fires on its own (auto-aim lives
## here: AutoAim picks and leads its targets) until its lifetime runs out, it is shot down, or its
## carrier dies. Interceptors escort the carrier and zap enemy missiles in point-defense range,
## then shoot enemy fighters and ships; bombers make diving runs at the enemy ship.
##
## It sits on physics layer 4 ("fighters") so Projectile rays can hit it, and collides with nothing.

signal destroyed

const GROUP := &"fighters"
## Physics layer 4, "fighters".
const LAYER := 8
const RADIUS := 0.7
## Interceptors destroy enemy missiles within this distance.
const POINT_DEFENSE_RANGE := 12.0
## Interceptors look for missiles this far out, and fly to meet them.
const MISSILE_WATCH_RANGE := 22.0
const ESCORT_RANGE := 6.0
## Seconds a bomber flies away after releasing, before turning in for the next run.
const PULL_AWAY_SECONDS := 1.4
const COLORS := {
	FighterBayData.Role.INTERCEPTOR: Color(0.35, 0.9, 1.0),
	FighterBayData.Role.BOMBER: Color(1.0, 0.55, 0.25),
}

var bay: FighterBayData
var carrier: Ship
var team: StringName
var hull: float = 1.0
var velocity: Vector3 = Vector3.ZERO
var age: float = 0.0
var fire_cooldown_left: float = 0.0
## Seconds this fighter is offline after an EMP: it drifts and does nothing.
var emp_left: float = 0.0
## True from release until the bomber has flown clear for PULL_AWAY_SECONDS.
var pulling_away: bool = false

var _orbit_sign: float = 1.0
var _pull_away_left: float = 0.0
var _dead: bool = false


## Creates a fighter under [param parent] at [param origin], flying along [param heading].
static func spawn(parent: Node, p_bay: FighterBayData, p_carrier: Ship, origin: Vector3, heading: Vector3, orbit_sign: float = 1.0) -> Fighter:
	var fighter := Fighter.new()
	fighter.bay = p_bay
	fighter.carrier = p_carrier
	fighter.team = p_carrier.team
	fighter.hull = p_bay.fighter_hull
	fighter._orbit_sign = signf(orbit_sign) if orbit_sign != 0.0 else 1.0
	var flat_heading := AutoAim.flat(heading).normalized()
	fighter.velocity = (flat_heading if flat_heading != Vector3.ZERO else Vector3.FORWARD) * p_bay.fighter_speed
	parent.add_child(fighter)
	fighter.global_position = Vector3(origin.x, 0.0, origin.z)
	fighter._face(fighter.velocity)
	fighter.reset_physics_interpolation()
	return fighter


func _ready() -> void:
	add_to_group(GROUP)
	sync_to_physics = false
	collision_layer = LAYER
	collision_mask = 0
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = RADIUS
	shape.shape = sphere
	add_child(shape)
	_build_visual()


func is_alive() -> bool:
	return not _dead and hull > 0.0


func take_damage(amount: float) -> void:
	if not is_alive():
		return
	hull -= amount
	if hull <= 0.0:
		hull = 0.0
		_die(true)


## An EMP hit: the fighter goes dead in the air for [param seconds].
func disable(seconds: float) -> void:
	emp_left = maxf(emp_left, seconds)


func _physics_process(delta: float) -> void:
	step(delta)


func step(delta: float) -> void:
	if not is_alive():
		return
	age += delta
	if age >= bay.fighter_lifetime or not is_instance_valid(carrier) or not carrier.is_alive():
		_die(false)
		return
	if emp_left > 0.0:
		emp_left = maxf(emp_left - delta, 0.0)
		velocity *= 0.96
		global_position += velocity * delta
		return
	fire_cooldown_left = maxf(fire_cooldown_left - delta, 0.0)
	match bay.role_kind:
		FighterBayData.Role.INTERCEPTOR:
			_step_interceptor(delta)
		FighterBayData.Role.BOMBER:
			_step_bomber(delta)


# --- Behaviour -----------------------------------------------------------------------

func _step_interceptor(delta: float) -> void:
	var missile := nearest_enemy_missile(MISSILE_WATCH_RANGE)
	if missile != null:
		_fly_toward(missile.global_position, delta)
	else:
		_fly_toward(AISteering.pursuit_point(carrier.global_position, global_position, ESCORT_RANGE, 2.0, _orbit_sign, 55.0), delta)
	if fire_cooldown_left > 0.0:
		return
	if missile != null and _distance_to(missile) <= POINT_DEFENSE_RANGE:
		_zap(missile)
		return
	var fighter := _nearest_enemy_fighter(bay.attack_range)
	if fighter != null:
		_shoot(fighter, null)
		return
	var ship := _nearest_enemy_ship(bay.attack_range)
	if ship != null:
		_shoot(ship, null)


func _step_bomber(delta: float) -> void:
	var target := _nearest_enemy_ship(INF)
	if target == null:
		_fly_toward(AISteering.pursuit_point(carrier.global_position, global_position, ESCORT_RANGE, 2.0, _orbit_sign, 55.0), delta)
		return
	if pulling_away:
		_pull_away_left -= delta
		var away := AutoAim.flat(global_position - target.global_position).normalized()
		_fly_toward(global_position + away.rotated(Vector3.UP, 0.5 * _orbit_sign) * 10.0, delta)
		if _pull_away_left <= 0.0:
			pulling_away = false
		return
	_fly_toward(target.global_position, delta)
	if fire_cooldown_left <= 0.0 and _distance_to(target) <= bay.attack_range:
		_shoot(target, target)
		pulling_away = true
		_pull_away_left = PULL_AWAY_SECONDS


## The nearest enemy homing projectile (a missile) within [param max_range], or null.
func nearest_enemy_missile(max_range: float) -> Projectile:
	var accept := func(node: Node3D) -> bool:
		var projectile := node as Projectile
		return projectile != null and projectile.team() != team and projectile.is_interceptable()
	return AutoAim.nearest(global_position, get_tree().get_nodes_in_group(Projectile.GROUP), max_range, accept) as Projectile


func _nearest_enemy_fighter(max_range: float) -> Fighter:
	var accept := func(node: Node3D) -> bool:
		var other := node as Fighter
		return other != null and other.team != team and other.is_alive()
	return AutoAim.nearest(global_position, get_tree().get_nodes_in_group(GROUP), max_range, accept) as Fighter


func _nearest_enemy_ship(max_range: float) -> Ship:
	return AutoAim.nearest(global_position, carrier.enemies(), max_range) as Ship


## Fires the bay's projectile at [param target], leading it. [param homing_target] is passed on
## to homing projectiles (bomber payloads).
func _shoot(target: Node3D, homing_target: Ship) -> void:
	if bay.projectile == null:
		return
	var target_velocity: Vector3 = target.get(&"velocity") if target.get(&"velocity") != null else Vector3.ZERO
	var direction := AutoAim.intercept_direction(global_position, target.global_position, target_velocity, bay.projectile.speed)
	Projectile.spawn(Projectile.default_parent(self), bay.projectile, carrier, global_position + direction * (RADIUS + 0.3), direction, homing_target, bay.fighter_damage)
	fire_cooldown_left = bay.fire_cooldown


## Point defense: destroys [param missile] outright and draws a short tracer to it.
func _zap(missile: Projectile) -> void:
	Vfx.line(Projectile.default_parent(self), global_position, missile.global_position, COLORS[bay.role_kind], 0.12)
	missile.intercept()
	fire_cooldown_left = bay.fire_cooldown


# --- Movement ------------------------------------------------------------------------

## Turns (at most fighter_turn_deg per second) toward [param goal] and moves at full speed.
func _fly_toward(goal: Vector3, delta: float) -> void:
	var heading := velocity.normalized() if velocity.length_squared() > 0.0001 else -global_basis.z
	var to_goal := AutoAim.flat(goal - global_position)
	if to_goal.length() > 0.3:
		var angle := heading.signed_angle_to(to_goal.normalized(), Vector3.UP)
		var max_turn := deg_to_rad(bay.fighter_turn_deg) * delta
		heading = heading.rotated(Vector3.UP, clampf(angle, -max_turn, max_turn)).normalized()
	velocity = heading * bay.fighter_speed
	global_position += velocity * delta
	_face(velocity)


func _face(direction: Vector3) -> void:
	if direction.length_squared() > 0.0001:
		rotation.y = atan2(-direction.x, -direction.z)


func _distance_to(node: Node3D) -> float:
	return AutoAim.flat(node.global_position - global_position).length()


func _die(shot_down: bool) -> void:
	if _dead:
		return
	_dead = true
	hull = 0.0
	if shot_down and is_inside_tree():
		Vfx.ring(get_parent(), global_position, 1.6, COLORS[bay.role_kind], 0.3)
	destroyed.emit()
	queue_free()


func _build_visual() -> void:
	var scene := ArtLookup.fighter_scene(bay)
	if scene != null:
		var model := scene.instantiate() as Node3D
		if model != null:
			model.position.y = 0.6
			add_child(model)
			return
	var material := StandardMaterial3D.new()
	material.albedo_color = COLORS[bay.role_kind]
	material.emission_enabled = true
	material.emission = COLORS[bay.role_kind]
	material.emission_energy_multiplier = 0.6
	var mesh := PrismMesh.new()  # A little arrowhead pointing along -Z.
	mesh.size = Vector3(0.9, 1.3, 0.3)
	mesh.material = material
	var visual := MeshInstance3D.new()
	visual.mesh = mesh
	visual.rotation.x = -PI / 2.0
	visual.position.y = 0.6
	add_child(visual)
