class_name AIController
extends Node
## Controller: drives a Ship with the same commands the player uses (throttle, turn, aim, triggers,
## Hard Burn). Add as a child of the Ship. All behaviour comes from the AIProfile.
##
## It circles its target at the profile's preferred range, sees the target a moment late, holds
## each fire group's trigger when a weapon in it can actually shoot, lets go of weapons that are
## about to overheat, launches its fighter bays once the fight is close, leads and mis-aims its shots, and (if the profile allows) Hard Burns away
## from incoming projectiles.

## Heat at which the AI lets go of a weapon, and the heat it waits for before using it again.
const VENT_AT := 0.85
const VENT_UNTIL := 0.3
## Fighter bays launch when the target is within this multiple of the preferred range.
const BAY_LAUNCH_RANGE := 1.2

var profile: AIProfile
## Off while a duel is being introduced; the ship just sits there.
var enabled: bool = true
var rng := RandomNumberGenerator.new()

var _ship: Ship
var _orbit_sign: float = 1.0
var _flip_timer: float = 0.0
var _perceived_pos: Vector3 = Vector3.ZERO
var _perceived_vel: Vector3 = Vector3.ZERO
var _has_perception: bool = false
var _aim_error: float = 0.0  # radians, re-rolled after each shot
var _watched_weapon: WeaponController
## Weapons the AI is letting cool down (WeaponController -> true).
var _venting: Dictionary = {}


func _ready() -> void:
	_ship = get_parent() as Ship
	assert(_ship != null, "AIController must be a child of a Ship")


## Sets (or changes) the profile. [param p_rng] seeds this controller's own random stream.
func setup(p_profile: AIProfile, p_rng: RandomNumberGenerator = null) -> void:
	profile = p_profile
	if p_rng != null:
		rng.seed = p_rng.randi()  # Own stream, so AI draws never shift the run's loot rolls.
	_orbit_sign = 1.0 if rng.randf() < 0.5 else -1.0
	_flip_timer = _next_flip_time()
	_reroll_aim_error()


func _physics_process(delta: float) -> void:
	if profile == null or _ship == null:
		return
	if not enabled or not _ship.is_alive():
		_idle()
		return
	var target := _pick_target()
	if target == null:
		_idle()
		return

	_perceive(target, delta)
	_flip_timer -= delta
	if _flip_timer <= 0.0:
		_orbit_sign = -_orbit_sign
		_flip_timer = _next_flip_time()

	var point := AISteering.pursuit_point(_perceived_pos, _ship.global_position, profile.preferred_range, profile.range_band, _orbit_sign, profile.orbit_lead_deg)
	var command := AISteering.steer(_ship.global_position, _ship.global_rotation.y, point, profile.max_throttle)
	_ship.set_throttle(command.throttle)
	_ship.set_turn(command.turn)

	_handle_weapons(target)
	_handle_bays(target)
	if profile.dodge_burn:
		_try_dodge()


func _idle() -> void:
	_ship.set_throttle(0.0)
	_ship.set_turn(0.0)
	_ship.set_all_triggers(false)


func _pick_target() -> Ship:
	var best: Ship
	var best_distance := INF
	for candidate in _ship.enemies():
		var distance := _ship.global_position.distance_to(candidate.global_position)
		if distance < best_distance:
			best = candidate
			best_distance = distance
	return best


## The AI's picture of the target trails the truth by about reaction_time seconds.
func _perceive(target: Ship, delta: float) -> void:
	if not _has_perception:
		_perceived_pos = target.global_position
		_perceived_vel = target.velocity
		_has_perception = true
		return
	var blend := 1.0 - exp(-delta / maxf(profile.reaction_time, 0.01))
	_perceived_pos = _perceived_pos.lerp(target.global_position, blend)
	_perceived_vel = _perceived_vel.lerp(target.velocity, blend)


func _handle_weapons(target: Ship) -> void:
	var held := {WeaponData.FireGroup.PRIMARY: false, WeaponData.FireGroup.SECONDARY: false}
	var lead_with: WeaponController  # The in-reach aimed weapon with the slowest shot.
	var lock_group := -1
	var lock_complete := false
	for controller in _ship.weapons():
		if not controller.weapon_in_reach(target, profile.fire_range_fraction):
			continue
		if controller.weapon.targeting == WeaponData.Targeting.LOCK_ON:
			lock_group = controller.fire_group()
			if controller.lock_target != null and controller.lock_progress >= controller.weapon.lock_time:
				lock_complete = true
			continue
		if _is_venting(controller):
			continue
		held[controller.fire_group()] = true
		if lead_with == null or controller.projectile_speed() < lead_with.projectile_speed():
			lead_with = controller

	if lock_group >= 0:
		# Lock-on fires when the trigger is released, so let go once the lock is made (that also
		# drops any charge sharing the button: the salvo matters more).
		held[lock_group] = not lock_complete
	for group: WeaponData.FireGroup in held:
		_ship.set_trigger(group, held[group])
	if lead_with != null and lock_group < 0:
		# Lead the target, then miss by this shot's error.
		var muzzle := lead_with.muzzle_position()
		var estimate := _estimated_position()
		var direction := AutoAim.intercept_direction(muzzle, estimate, _perceived_vel, lead_with.projectile_speed())
		direction = direction.rotated(Vector3.UP, _aim_error)
		_ship.aim_at(muzzle + direction * maxf(muzzle.distance_to(estimate), 1.0))
		_watch_for_shots(lead_with)
	else:
		_ship.aim_at(target.global_position)  # Lock-on needs the cursor on the target.


## Where the AI thinks the target is right now. The smoothed picture trails a steady target by
## about velocity * reaction_time, so it projects that much forward: it tracks straight runs well
## and is fooled for a moment by every turn or Hard Burn.
func _estimated_position() -> Vector3:
	return _perceived_pos + _perceived_vel * profile.reaction_time


## Hysteresis: stop firing a weapon at VENT_AT heat (or overheated), resume at VENT_UNTIL.
func _is_venting(controller: WeaponController) -> bool:
	if controller.overheated or controller.heat >= VENT_AT:
		_venting[controller] = true
	elif _venting.get(controller, false) and controller.heat <= VENT_UNTIL:
		_venting.erase(controller)
	return _venting.get(controller, false)


## Launches every ready fighter bay once the target is within reach of the fight.
func _handle_bays(target: Ship) -> void:
	if _ship.global_position.distance_to(target.global_position) > profile.preferred_range * BAY_LAUNCH_RANGE:
		return
	for bay in _ship.bays():
		bay.launch()


## Re-roll the aiming error each time the manual weapon fires.
func _watch_for_shots(controller: WeaponController) -> void:
	if _watched_weapon == controller:
		return
	if _watched_weapon != null and is_instance_valid(_watched_weapon) and _watched_weapon.fired.is_connected(_reroll_aim_error):
		_watched_weapon.fired.disconnect(_reroll_aim_error)
	_watched_weapon = controller
	controller.fired.connect(_reroll_aim_error)


## Sidestep a projectile that's about to hit, if Hard Burn is ready.
func _try_dodge() -> void:
	if _ship.movement.burn_ready_fraction() < 1.0:
		return
	for node in get_tree().get_nodes_in_group(Projectile.GROUP):
		var projectile := node as Projectile
		if projectile.team() == _ship.team:
			continue
		var away := AISteering.dodge_direction(_ship.global_position, _ship.hull.collision_radius, projectile.global_position, projectile.direction, projectile.current_speed())
		if away != Vector3.ZERO:
			var yaw := _ship.global_rotation.y
			_ship.request_hard_burn(Vector2(away.dot(SailingModel.right_of(yaw)), away.dot(SailingModel.forward_of(yaw))))
			return


func _reroll_aim_error() -> void:
	_aim_error = deg_to_rad(rng.randf_range(-1.0, 1.0) * (profile.aim_error_deg if profile != null else 0.0))


func _next_flip_time() -> float:
	return rng.randf_range(profile.orbit_flip_min, maxf(profile.orbit_flip_max, profile.orbit_flip_min))
