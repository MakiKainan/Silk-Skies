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
	return 1.0 / maxf(float(stats[Stats.FIRE_RATE]), 0.001)


func effective_range() -> float:
	return float(stats[Stats.RANGE])


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
	return ship != null and ship.is_trigger_held(fire_group()) and ship.weapons_enabled


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


## Lock-on: is [param candidate] a living enemy within range and inside the arc?
func can_target(candidate: Ship) -> bool:
	return weapon_in_reach(candidate)


## Could this weapon plausibly shoot [param candidate] right now: in range (scaled by
## [param range_fraction]) and inside the arc? Used by AI to decide when to pull a trigger.
func weapon_in_reach(candidate: Ship, range_fraction: float = 1.0) -> bool:
	if candidate == null or not is_instance_valid(candidate) or not candidate.is_alive() or candidate.team == ship.team:
		return false
	var offset := _flat(candidate.global_position - muzzle_position())
	return offset.length() <= effective_range() * range_fraction and in_arc(offset)


## The enemy closest to the aim point, if it's within the lock pick radius and targetable.
func pick_lock_candidate() -> Ship:
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
	# Charged weapon: build while held, in arc and off cooldown; letting go or leaving the arc cancels.
	if held and inside and is_ready():
		charge = minf(charge + delta, weapon.charge_time)
		if charge >= weapon.charge_time:
			charge = 0.0
			aim_committed = false
			_fire(direction, null)
			return
		aim_committed = commits_aim() and charge >= weapon.charge_time - AIM_COMMIT_SECONDS
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
	# A longer-ranged weapon's shots live proportionally longer so they actually reach.
	var lifetime := data.lifetime * effective_range() / maxf(weapon.range, 0.001)
	var parent := Projectile.default_parent(self)
	Sfx.play_3d(parent, ArtLookup.fire_sound(weapon), origin)
	Projectile.spawn(parent, data, ship, origin, shot_direction, target, shot_damage(), projectile_speed(), lifetime)


func _cancel() -> void:
	charge = 0.0
	aim_committed = false
	lock_target = null
	lock_progress = 0.0
	_burst_left = 0


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
