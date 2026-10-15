class_name FighterBayData
extends ItemData
## A fighter bay and the drones it launches. The player launches them with the bay's action key
## (Q/E/R); the fighters then fly and shoot on their own (this is where auto-aim lives now).

## INTERCEPTOR escorts its ship and shoots down enemy missiles first, then enemy fighters, then
## ships. BOMBER makes diving runs at the enemy ship and drops one heavy shot per run.
enum Role { INTERCEPTOR, BOMBER }

@export var fighter_name: String = "Fighter"
@export var fighter_count: int = 2
@export var fighter_hull: float = 20.0
## Damage per shot (overrides the projectile's own damage).
@export var fighter_damage: float = 4.0
## Seconds a launched fighter stays alive.
@export var fighter_lifetime: float = 12.0
@export var launch_cooldown: float = 15.0
## One-line summary shown in the tooltip.
@export var role: String = ""

@export_group("Behaviour")
@export var role_kind: Role = Role.INTERCEPTOR
## What the fighter fires. Interceptors also zap missiles in point-defense range without one.
@export var projectile: ProjectileData
@export var fighter_speed: float = 24.0
## Degrees per second the fighter can turn.
@export var fighter_turn_deg: float = 260.0
## Seconds between a fighter's shots (bombers: between runs).
@export var fire_cooldown: float = 0.6
## Distance at which it opens fire (bombers: where they release).
@export var attack_range: float = 20.0


func slot_type() -> HardpointData.Type:
	return HardpointData.Type.FIGHTER_BAY


func category_name() -> String:
	return "Fighter Bay"
