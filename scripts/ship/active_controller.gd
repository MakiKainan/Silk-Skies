class_name ActiveController
extends Node
## One equipped techmod or crew member with a Q/E/R active (see ItemData.ActiveKind). Press the
## key -> activate(): the effect starts, then the item cools down. Lives under the Ship, like a
## FighterBayController lives under a mount. Fighter bays have their own controller instead.
##
## EMP_PULSE disables every enemy weapon, fighter bay and fighter in range for a few seconds,
## EMERGENCY_REPAIR heals a share of max hull, OVERCHARGE speeds up every turret for a few
## seconds. The Engineer's techmod_potency makes a techmod's active stronger.

signal activated

## The ring flashed at the ship when an active goes off.
const COLORS := {
	ItemData.ActiveKind.EMP_PULSE: Color(0.45, 0.6, 1.0),
	ItemData.ActiveKind.EMERGENCY_REPAIR: Color(0.35, 1.0, 0.5),
	ItemData.ActiveKind.OVERCHARGE: Color(1.0, 0.75, 0.25),
}

var data: ItemData
var instance: ItemInstance
var ship: Ship
var cooldown_left: float = 0.0
## Seconds an ongoing effect (overcharge) still has to run.
var effect_left: float = 0.0


func setup(p_data: ItemData, p_ship: Ship, p_instance: ItemInstance = null) -> void:
	data = p_data
	ship = p_ship
	instance = p_instance


func is_ready() -> bool:
	return cooldown_left <= 0.0 and ship != null and ship.is_alive() and ship.can_fire()


## 0..1, 1 = ready to use.
func ready_fraction() -> float:
	return 1.0 - cooldown_left / maxf(data.active_cooldown, 0.001)


func status_text() -> String:
	if effect_left > 0.0:
		return "active"
	return "ready" if cooldown_left <= 0.0 else "cooling"


## Strength multiplier: techmod actives grow with the ship's techmod_potency (Engineer).
func potency() -> float:
	if ship == null or not data is TechmodData:
		return 1.0
	return 1.0 + ship.stats.get_stat(Stats.TECHMOD_POTENCY)


func power() -> float:
	return data.active_power * potency()


func duration() -> float:
	return data.active_duration * potency()


func reach() -> float:
	return data.active_range * potency()


## Uses the active if it is ready. Returns false (doing nothing) otherwise.
func activate() -> bool:
	if not is_ready():
		return false
	match data.active_kind:
		ItemData.ActiveKind.EMP_PULSE:
			_emp()
		ItemData.ActiveKind.EMERGENCY_REPAIR:
			ship.health.heal_hull(ship.health.max_hull() * power())
		ItemData.ActiveKind.OVERCHARGE:
			effect_left = duration()
			ship.set_fire_rate_boost(1.0 + power())
		_:
			return false
	cooldown_left = data.active_cooldown
	if ship.is_inside_tree():
		Vfx.ring(ship.get_parent(), ship.global_position, maxf(ship.hull.collision_radius * 2.0, 3.0), COLORS.get(data.active_kind, Color.WHITE), 0.45)
	activated.emit()
	EventBus.active_used.emit(ship, data)
	return true


func _physics_process(delta: float) -> void:
	step(delta)


func step(delta: float) -> void:
	cooldown_left = maxf(cooldown_left - delta, 0.0)
	if effect_left > 0.0:
		effect_left = maxf(effect_left - delta, 0.0)
		if effect_left <= 0.0:
			_end_effect()


func _exit_tree() -> void:
	if effect_left > 0.0 and ship != null and is_instance_valid(ship):
		_end_effect()


func _end_effect() -> void:
	effect_left = 0.0
	if data.active_kind == ItemData.ActiveKind.OVERCHARGE and ship != null:
		ship.set_fire_rate_boost(1.0)


func _emp() -> void:
	for enemy in ship.enemies():
		if AutoAim.flat(enemy.global_position - ship.global_position).length() <= reach() + enemy.hull.collision_radius:
			enemy.disable_weapons(duration())
	for node in get_tree().get_nodes_in_group(Fighter.GROUP):
		var fighter := node as Fighter
		if fighter.team != ship.team and fighter.is_alive() and AutoAim.flat(fighter.global_position - ship.global_position).length() <= reach():
			fighter.disable(duration())
