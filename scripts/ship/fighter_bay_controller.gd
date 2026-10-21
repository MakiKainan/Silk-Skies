class_name FighterBayController
extends Node3D
## One equipped fighter bay. launch() (the bay's action key, or the AI) sends out the bay's
## fighters and starts the relaunch cooldown. Lives under its HardpointMount, like a
## WeaponController does for a turret.

signal launched

## Degrees between fighters in one launch, fanned around the bow.
const FAN_DEG := 30.0

var bay: FighterBayData
## The specific drop (rarity, rolls); null for a bare FighterBayData.
var instance: ItemInstance
var ship: Ship
var mount: HardpointMount
var cooldown_left: float = 0.0
## Fighters from launches that are still flying.
var fighters: Array[Fighter] = []


func setup(p_bay: FighterBayData, p_ship: Ship, p_mount: HardpointMount, p_instance: ItemInstance = null) -> void:
	bay = p_bay
	ship = p_ship
	mount = p_mount
	instance = p_instance


func is_ready() -> bool:
	return cooldown_left <= 0.0 and ship != null and ship.is_alive() and ship.can_fire()


## 0..1, 1 = ready to launch.
func ready_fraction() -> float:
	return 1.0 - cooldown_left / maxf(bay.launch_cooldown, 0.001)


func status_text() -> String:
	return "ready" if cooldown_left <= 0.0 else "cooling"


## The fighters from this bay that are still alive.
func live_fighters() -> Array[Fighter]:
	var out: Array[Fighter] = []
	for fighter in fighters:
		if is_instance_valid(fighter) and fighter.is_alive():
			out.append(fighter)
	fighters = out
	return out


## Launches the bay's fighters if it's ready. Returns false (doing nothing) otherwise.
func launch() -> bool:
	if not is_ready():
		return false
	var parent := Projectile.default_parent(self)
	var origin := AutoAim.flat(mount.global_position if mount != null else ship.global_position)
	var bow := SailingModel.forward_of(ship.global_rotation.y)
	for i in bay.fighter_count:
		var offset := float(i) - float(bay.fighter_count - 1) * 0.5
		var heading := bow.rotated(Vector3.UP, deg_to_rad(FAN_DEG * offset))
		fighters.append(Fighter.spawn(parent, bay, ship, origin + heading * 1.5, heading, 1.0 if i % 2 == 0 else -1.0))
	cooldown_left = bay.launch_cooldown
	launched.emit()
	EventBus.fighters_launched.emit(ship, bay)
	return true


func _physics_process(delta: float) -> void:
	step(delta)


func step(delta: float) -> void:
	cooldown_left = maxf(cooldown_left - delta, 0.0)
