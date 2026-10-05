class_name FighterBayData
extends ItemData
## A fighter bay and the drones it launches. The stats are real data; launching fighters in
## combat arrives in a later milestone.

@export var fighter_name: String = "Fighter"
@export var fighter_count: int = 2
@export var fighter_hull: float = 20.0
@export var fighter_damage: float = 4.0
## Seconds a launched fighter stays alive.
@export var fighter_lifetime: float = 12.0
@export var launch_cooldown: float = 15.0
@export var role: String = ""


func slot_type() -> HardpointData.Type:
	return HardpointData.Type.FIGHTER_BAY


func category_name() -> String:
	return "Fighter Bay"
