class_name WeaponController
extends Node3D
## One equipped weapon. Handles cooldown, heat, firing arc, the trigger mode (aimed / lock-on),
## the Railgun-style charge and salvo bursts, and spawns the projectiles. Lives under its
## HardpointMount and reads the owning Ship's trigger for its fire group, and its aim point.

signal fired
signal overheated_changed(is_overheated: bool)

## Seconds without firing before heat starts to bleed off.
const HEAT_COOL_DELAY := 0.3
## Enemy charged weapons stop tracking for this long at the end of a charge, so the player
## gets a fair moment to sidestep the telegraphed line.
const AIM_COMMIT_SECONDS := 0.2
## The AI only shoots where a drop-off weapon still does at least this share of its damage.
const USEFUL_DAMAGE := 0.5

var weapon: WeaponData
## The specific drop this weapon is (rarity, rolled stats, fire group); null for a bare WeaponData.
var instance: ItemInstance
## Final numbers: the weapon's data + its rolls + ship-wide modifiers (see WeaponStats).
var stats: Dictionary = {}
var hardpoint: HardpointData
var ship: Ship
var mount: HardpointMount
## Spread comes from here. Seed it for repeatable shots; the run RNG replaces it later.
var rng := RandomNumberGenerator.new()

var cooldown_left: float = 0.0
## Seconds of charge built so far (aimed weapons with a charge_time).
var charge: float = 0.0
var lock_target: Ship
var lock_progress: float = 0.0
## Where the barrel wants to point (world direction); drives the mount's visual.
var aim_direction: Vector3 = Vector3.FORWARD
## 0..1; at 1 the weapon overheats.
var heat: float = 0.0
var overheated: bool = false
var overheat_left: float = 0.0
## True while an enemy's charged shot has stopped tracking (see AIM_COMMIT_SECONDS).
var aim_committed: bool = false
## Draws this weapon's tell on the floor (enemies; the player's railgun faintly). Null if none.
var telegraph: AimTelegraph

var _burst_left: int = 0
var _burst_timer: float = 0.0
var _burst_direction: Vector3 = Vector3.FORWARD
var _burst_target: Ship
var _lock_marker: MeshInstance3D
var _since_fired: float = INF
## Trigger state last tick, for the cone flash on a fresh press.
var _flash_was_held: bool = false
## Was the trigger held on the previous aimed step? (the release edge of a primed charge)
var _was_held: bool = false


func setup(p_weapon: WeaponData, p_hardpoint: HardpointData, p_ship: Ship, p_mount: HardpointMount, p_instance: ItemInstance = null) -> void:
	weapon = p_weapon
	instance = p_instance
	refresh_stats([])
	hardpoint = p_hardpoint
	ship = p_ship
	mount = p_mount
	rng.randomize()
	aim_direction = _default_direction()
	if weapon.telegraph != WeaponData.Telegraph.NONE:
		telegraph = AimTelegraph.new()
		telegraph.name = "AimTelegraph"
		add_child(telegraph)
		telegraph.setup(self)


# --- Stats ---------------------------------------------------------------------------

## Recomputes final stats from the weapon's own rolls plus [param global_mods]
## (LoadoutStats.global_mods of everything equipped).
func refresh_stats(global_mods: Array[StatMod]) -> void:
	stats = WeaponStats.compute(weapon, LoadoutStats.own_mods(instance), global_mods)


func cooldown_seconds() -> float:
	var boost := ship.fire_rate_boost if ship != null else 1.0  # The Gunner's Overcharge.
	return 1.0 / maxf(float(stats[Stats.FIRE_RATE]) * boost, 0.001)


func effective_range() -> float:
	return float(stats[Stats.RANGE])


## Metres from the muzzle where damage starts to drop off (= range when it never does).
func falloff_start_distance() -> float:
	return effective_range() * weapon.falloff_start


## Damage multiplier for a hit [param distance] metres from the muzzle.
func damage_at(distance: float) -> float:
	return WeaponData.falloff_multiplier(distance, effective_range(), falloff_start_distance(), weapon.falloff_min)


## How far this weapon still does at least half damage: the range the AI shoots within.
func useful_range() -> float:
	var reach := effective_range()
	if not weapon.has_falloff() or weapon.falloff_min >= USEFUL_DAMAGE:
		return reach
	# Invert the ease-out curve of WeaponData.falloff_multiplier at USEFUL_DAMAGE.
	var eased := (1.0 - USEFUL_DAMAGE) / (1.0 - weapon.falloff_min)
	var t := 1.0 - sqrt(1.0 - eased)
	var start := falloff_start_distance()
	return start + t * (reach - start)


func projectile_speed() -> float:
	return float(stats[Stats.PROJECTILE_SPEED])


func shot_damage() -> float:
	return float(stats[Stats.DAMAGE])


# --- Queries -------------------------------------------------------------------------

func is_ready() -> bool:
	return cooldown_left <= 0.0 and _burst_left == 0 and not overheated


## The mouse button that fires this weapon (the item's choice, else the weapon's default).
func fire_group() -> WeaponData.FireGroup:
	return instance.fire_group_of() if instance != null else weapon.default_group()


func is_trigger_held() -> bool:
	return ship != null and ship.is_trigger_held(fire_group()) and ship.can_fire()


## 0..1: how close the weapon is to being able to act (overheat, cooldown, charge or lock).
func ready_fraction() -> float:
	if overheated:
		return 1.0 - overheat_left / maxf(weapon.overheat_lockout, 0.001)
	if cooldown_left > 0.0:
		return 1.0 - cooldown_left / maxf(cooldown_seconds(), 0.001)
	if weapon.targeting == WeaponData.Targeting.AIMED and weapon.charge_time > 0.0 and charge > 0.0:
		return charge_fraction()
	if weapon.targeting == WeaponData.Targeting.LOCK_ON and lock_target != null:
		return clampf(lock_progress / maxf(weapon.lock_time, 0.001), 0.0, 1.0)
	return 1.0


## 0..1 progress of the current charge (0 for weapons that don't charge).
func charge_fraction() -> float:
	return clampf(charge / weapon.charge_time, 0.0, 1.0) if weapon.charge_time > 0.0 else 0.0


func heat_fraction() -> float:
	return 1.0 if overheated else clampf(heat, 0.0, 1.0)


func status_text() -> String:
	if overheated:
		return "OVERHEAT"
	if cooldown_left > 0.0 or _burst_left > 0:
		return "cooling"
	if charge > 0.0:
		return "charging"
	if lock_target != null:
		return "LOCKED" if lock_progress >= weapon.lock_time else "locking"
	return "ready"


func muzzle_position() -> Vector3:
	var p := mount.global_position if mount != null else global_position
	return Vector3(p.x, 0.0, p.z)


func ship_yaw() -> float:
	return ship.global_rotation.y


func in_arc(direction: Vector3) -> bool:
	return Arc.contains(ship_yaw(), hardpoint.arc_center_deg, hardpoint.arc_deg, direction)


func _default_direction() -> Vector3:
	return Arc.direction_at(ship_yaw(), hardpoint.arc_center_deg)


## Lock-on: is [param candidate] a living enemy within max range and inside the arc?
func can_target(candidate: Ship) -> bool:
	return _within(candidate, effective_range())


## Could this weapon usefully shoot [param candidate] right now: within useful range (scaled by
## [param range_fraction]) and inside the arc? Used by AI to decide when to pull a trigger, so it
## doesn't plink from where a drop-off weapon barely scratches.
func weapon_in_reach(candidate: Ship, range_fraction: float = 1.0) -> bool:
	return _within(candidate, useful_range() * range_fraction)


func _within(candidate: Ship, reach: float) -> bool:
	if candidate == null or not is_instance_valid(candidate) or not candidate.is_alive() or candidate.team == ship.team:
		return false
	var offset := _flat(candidate.global_position - muzzle_position())
	return offset.length() <= reach and in_arc(offset)


## The enemy closest to the aim point, if it's within the lock pick radius and targetable.
func pick_lock_candidate() -> Ship:
	var locked := ship.locked()  # A Tab lock stands in for hovering the cursor over the ship.
	if locked != null and can_target(locked):
		return locked
	var best: Ship
	var best_distance := INF
	for candidate in ship.enemies():
		if not can_target(candidate):
			continue
		var distance := _flat(candidate.global_position - ship.aim_point).length()
		var reach := weapon.lock_pick_radius + candidate.hull.collision_radius
		if distance <= reach and distance < best_distance:
			best = candidate
			best_distance = distance
	return best


## See AutoAim.intercept_direction.
static func intercept_direction(from: Vector3, target_pos: Vector3, target_velocity: Vector3, speed: float) -> Vector3:
	return AutoAim.intercept_direction(from, target_pos, target_velocity, speed)


## Enemy ships commit to their charged shots near the end of the charge; the player never does.
func commits_aim() -> bool:
	return ship != null and ship.team != Ship.TEAM_PLAYER and weapon.charge_time > 0.0


# --- Per-tick behaviour --------------------------------------------------------------

func _physics_process(delta: float) -> void:
	step(delta)
	_update_cone_flash()
	if mount != null:
		mount.aim_barrel(aim_direction, charge_fraction(), delta, heat_fraction())
	_update_lock_marker()


func step(delta: float) -> void:
	cooldown_left = maxf(cooldown_left - delta, 0.0)
	_step_heat(delta)
	# A target that was destroyed (and freed) mid-lock or mid-salvo must not be touched again.
	# (is_instance_valid alone: a freed object does not reliably compare equal to null.)
	if not is_instance_valid(lock_target):
		if lock_target != null or lock_progress > 0.0:
			lock_progress = 0.0
		lock_target = null
	if not is_instance_valid(_burst_target):
		_burst_target = null
	if ship == null or not ship.is_alive():
		_cancel()
		return
	_step_burst(delta)
	match weapon.targeting:
		WeaponData.Targeting.AIMED:
			_step_aimed(delta)
		WeaponData.Targeting.LOCK_ON:
			_step_lock(delta)


## Player weapons (Ship.flash_cones): the firing cone only shows while the button is held with the
## cursor outside it, as a subtle red wedge. Firing inside the cone shows nothing.
func _update_cone_flash() -> void:
	var held := is_trigger_held()
	if ship != null and ship.flash_cones and mount != null and ship.is_alive():
		var to_aim := _flat(ship.aim_point - muzzle_position())
		var outside := to_aim.length_squared() > 0.01 and not in_arc(to_aim)
		if held and outside:
			mount.flash_cone(true)
	_flash_was_held = held


func _step_heat(delta: float) -> void:
	_since_fired += delta
	if overheated:
		overheat_left -= delta
		if overheat_left <= 0.0:
			overheated = false
			overheat_left = 0.0
			heat = 0.0
			overheated_changed.emit(false)
	elif _since_fired >= HEAT_COOL_DELAY:
		heat = maxf(heat - weapon.heat_cool_rate * delta, 0.0)


func _step_aimed(delta: float) -> void:
	var held := is_trigger_held()
	var was_held := _was_held
	_was_held = held
	var to_aim := _flat(ship.aim_point - muzzle_position())
	var wanted := to_aim.normalized() if to_aim.length_squared() > 0.01 else _default_direction()
	# An enemy at the end of its charge holds its line: the telegraph shows exactly where it goes.
	var direction := aim_direction if aim_committed and held else wanted
	var inside := in_arc(direction)
	aim_direction = direction if inside else Arc.clamp_direction(ship_yaw(), hardpoint.arc_center_deg, hardpoint.arc_deg, direction)
	if weapon.charge_time <= 0.0:
		if held and inside and is_ready():
			_fire(direction, null)
		return
	# Charged weapon: build while held, in arc and off cooldown; leaving the arc cancels. It fires
	# on reaching full charge, or (release_to_fire) stays primed and fires when the trigger is
	# let go; letting go before full cancels.
	if held and inside and is_ready():
		charge = minf(charge + delta, weapon.charge_time)
		if charge >= weapon.charge_time and not ship.release_to_fire:
			charge = 0.0
			aim_committed = false
			_fire(direction, null)
			return
		aim_committed = commits_aim() and charge >= weapon.charge_time - AIM_COMMIT_SECONDS
	elif ship.release_to_fire and was_held and not held and ship.can_fire() \
			and inside and charge >= weapon.charge_time and is_ready():
		charge = 0.0
		aim_committed = false
		_fire(direction, null)
	else:
		charge = 0.0
		aim_committed = false


func _step_lock(delta: float) -> void:
	if is_trigger_held():
		var candidate := pick_lock_candidate()
		if candidate != null and candidate == lock_target:
			lock_progress += delta
		else:
			lock_target = candidate
			lock_progress = 0.0
		if lock_target != null:
			aim_direction = _flat(lock_target.global_position - muzzle_position()).normalized()
		else:
			aim_direction = _default_direction()
		return
	# Trigger released: a full lock fires, anything less does nothing and costs no cooldown.
	if lock_target != null and lock_progress >= weapon.lock_time and is_ready() and can_target(lock_target):
		var direction := _flat(lock_target.global_position - muzzle_position()).normalized()
		_fire(direction, lock_target)
	lock_target = null
	lock_progress = 0.0
	aim_direction = _default_direction()


func _fire(direction: Vector3, target: Ship) -> void:
	cooldown_left = cooldown_seconds()
	_since_fired = 0.0
	if weapon.heat_per_shot > 0.0:
		heat += weapon.heat_per_shot
		if heat >= 1.0:
			heat = 1.0
			overheated = true
			overheat_left = weapon.overheat_lockout
			overheated_changed.emit(true)
	_spawn_shot(direction, target)
	if weapon.shots_per_fire > 1:
		_burst_left = weapon.shots_per_fire - 1
		_burst_timer = weapon.burst_interval
		_burst_direction = direction
		_burst_target = target
	fired.emit()
	EventBus.weapon_fired.emit(ship, weapon)


func _step_burst(delta: float) -> void:
	if _burst_left <= 0:
		return
	_burst_timer -= delta
	while _burst_left > 0 and _burst_timer <= 0.0:
		_spawn_shot(_burst_direction, _burst_target)
		_burst_left -= 1
		_burst_timer += weapon.burst_interval


func _spawn_shot(direction: Vector3, target: Ship) -> void:
	var data := weapon.projectile
	var angle := deg_to_rad(rng.randf_range(-data.spread_deg, data.spread_deg))
	var shot_direction := direction.rotated(Vector3.UP, angle)
	var origin := muzzle_position() + shot_direction * 1.0
	# Straight shots die exactly at max range (measured from the muzzle, the spawn point is 1 m
	# out); homing shots curve, so they keep their own lifetime, stretched by range rolls.
	var lifetime := (effective_range() - 1.0) / maxf(projectile_speed(), 0.001)
	if data.homing_deg_per_sec > 0.0:
		lifetime = data.lifetime * effective_range() / maxf(weapon.range, 0.001)
	var parent := Projectile.default_parent(self)
	Sfx.play_3d(parent, ArtLookup.fire_sound(weapon), origin)
	var shot := Projectile.spawn(parent, data, ship, origin, shot_direction, target, shot_damage(), projectile_speed(), lifetime)
	if weapon.has_falloff():
		shot.set_falloff(muzzle_position(), falloff_start_distance(), effective_range(), weapon.falloff_min)


func _cancel() -> void:
	charge = 0.0
	aim_committed = false
	lock_target = null
	lock_progress = 0.0
	_burst_left = 0
	_was_held = false


func _flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)


# --- Lock-on marker (placeholder visual) ---------------------------------------------

func _update_lock_marker() -> void:
	if weapon.targeting != WeaponData.Targeting.LOCK_ON:
		return
	if lock_target == null or not is_instance_valid(lock_target):
		if _lock_marker != null:
			_lock_marker.visible = false
		return
	if _lock_marker == null:
		var ring := TorusMesh.new()
		ring.inner_radius = 0.9
		ring.outer_radius = 1.0
		var material := StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		ring.material = material
		_lock_marker = MeshInstance3D.new()
		_lock_marker.mesh = ring
		_lock_marker.top_level = true
		_lock_marker.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
		add_child(_lock_marker)
	var progress := clampf(lock_progress / maxf(weapon.lock_time, 0.001), 0.0, 1.0)
	var locked := progress >= 1.0
	_lock_marker.visible = true
	_lock_marker.global_position = lock_target.global_position + Vector3(0.0, 0.3, 0.0)
	# The ring closes in on the target as the lock builds, then goes red.
	_lock_marker.scale = Vector3.ONE * (lock_target.hull.collision_radius * (1.0 + 2.0 * (1.0 - progress)) + 0.5)
	# An enemy locking you is always red; your own lock is gold until it's complete.
	var hostile := ship.team != Ship.TEAM_PLAYER
	((_lock_marker.mesh as TorusMesh).material as StandardMaterial3D).albedo_color = Color(1.0, 0.2, 0.2) if locked or hostile else Color(1.0, 0.85, 0.3)
