class_name WeaponData
extends ItemData
## A turret weapon: targeting mode + what it fires + timing. Authored content.

enum Targeting { AUTO, MANUAL, LOCK_ON }

## The smallest turret hardpoint that can carry it. A Large hardpoint takes either size.
@export var size: HardpointData.Size = HardpointData.Size.SMALL
@export var targeting: Targeting = Targeting.AUTO
@export var projectile: ProjectileData
## Seconds between firings.
@export var cooldown: float = 1.0
## Projectiles per firing, spaced burst_interval apart (missile salvos).
@export var shots_per_fire: int = 1
@export var burst_interval: float = 0.1
## Manual weapons: seconds the trigger must be held before it fires. 0 = fires at once.
@export var charge_time: float = 0.0
## Lock-on weapons: seconds the target must stay under the cursor before a lock is made.
@export var lock_time: float = 0.8
## How close (metres) the cursor must be to an enemy to start locking it.
@export var lock_pick_radius: float = 6.0
## Auto and lock-on target selection distance.
@export var range: float = 40.0

@export_group("Art")
## Turret barrel model, pointing toward -Z. Empty = assets/models/weapons/<id>_barrel, else a box.
@export var barrel_scene: PackedScene
## Played at the muzzle per shot. Empty = assets/audio/sfx/<id>_fire, else silent.
@export var fire_sound: AudioStream


func slot_size() -> HardpointData.Size:
	return size


func category_name() -> String:
	return "Turret"
