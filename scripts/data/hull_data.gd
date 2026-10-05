class_name HullData
extends Resource
## A hull: handling personality plus its typed hardpoints. Authored content: never
## modified at runtime (runtime tweaks go through StatsComponent).

@export var id: StringName
@export var display_name: String = ""
## Model scene with one Marker3D per hardpoint. The bow points toward -Z.
@export var model_scene: PackedScene
@export var collision_radius: float = 1.5

@export_group("Handling")
@export var mass: float = 100.0
## Force. Acceleration along the heading is thrust / mass.
@export var thrust: float = 900.0
@export var max_speed: float = 18.0
## Degrees per second at standstill. Falls to 40% at full speed.
@export var turn_rate: float = 120.0
## Passive speed loss per second while coasting.
@export var drag: float = 0.35
## How fast sideways drift is killed per second. Low = sailing slide, high = grip.
@export var lateral_grip: float = 2.0

@export_group("Hard Burn")
## Instant speed added in the burn direction.
@export var burn_impulse: float = 22.0
@export var burn_cooldown: float = 3.0

@export_group("Hardpoints")
@export var hardpoints: Array[HardpointData] = []


## The hull's base stat block, keyed by Stats constants. StatsComponent starts from this.
func base_stats() -> Dictionary:
	return {
		Stats.MASS: mass,
		Stats.THRUST: thrust,
		Stats.MAX_SPEED: max_speed,
		Stats.TURN_RATE: turn_rate,
		Stats.DRAG: drag,
		Stats.LATERAL_GRIP: lateral_grip,
		Stats.BURN_IMPULSE: burn_impulse,
		Stats.BURN_COOLDOWN: burn_cooldown,
	}
