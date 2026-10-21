class_name WeaponData
extends ItemData
## A turret weapon: how it's triggered + what it fires + timing. Authored content.
## Every weapon is fired by the player (or the AI) with a mouse button; auto-aim lives on fighters.

## AIMED fires toward the cursor while its button is held (charging first, if it has a
## charge_time; the player's charged shot waits primed and fires on release, see
## Ship.release_to_fire). LOCK_ON locks an enemy under the cursor while held and fires on release.
enum Targeting { AIMED, LOCK_ON }
## Which mouse button fires it: PRIMARY = left, SECONDARY = right. Set per item in the refit screen.
enum FireGroup { PRIMARY, SECONDARY }
## How an enemy telegraphs this weapon before it fires (see AimTelegraph).
enum Telegraph { NONE, CHARGE_BEAM, TRACER, CONE, LOCK }

## What kind of weapon this is ("Pulse Laser", "Cannon"); display_name is its own name.
@export var weapon_label: String = ""
## The smallest turret hardpoint that can carry it. A Large hardpoint takes either size.
@export var size: HardpointData.Size = HardpointData.Size.SMALL
@export var targeting: Targeting = Targeting.AIMED
## The button a fresh drop uses. Lock-on weapons always use SECONDARY.
@export var default_fire_group: FireGroup = FireGroup.PRIMARY
@export var projectile: ProjectileData
## Seconds between firings.
@export var cooldown: float = 1.0
## Projectiles per firing, spaced burst_interval apart (missile salvos).
@export var shots_per_fire: int = 1
@export var burst_interval: float = 0.1
## Aimed weapons: seconds the trigger must be held before it fires. 0 = fires at once.
@export var charge_time: float = 0.0
## Lock-on weapons: seconds the target must stay under the cursor before a lock is made.
@export var lock_time: float = 0.8
## How close (metres) the cursor must be to an enemy to start locking it.
@export var lock_pick_radius: float = 6.0
## Max range in metres: straight shots fly exactly this far, the firing cone is drawn this long,
## and lock-on picks targets within it. The AI shoots within useful range (see falloff).
@export var range: float = 40.0

@export_group("Falloff")
## Fraction of range where damage starts to drop off. 1.0 = full damage all the way out.
@export_range(0.05, 1.0, 0.01) var falloff_start: float = 1.0
## Damage multiplier at max range.
@export_range(0.05, 1.0, 0.01) var falloff_min: float = 1.0

@export_group("Heat")
## Heat added per firing (1.0 = overheated). 0 = this weapon never heats up.
@export var heat_per_shot: float = 0.0
## Heat lost per second while not overheated.
@export var heat_cool_rate: float = 0.5
## Seconds the weapon is locked out once it overheats; heat then drops to 0.
@export var overheat_lockout: float = 1.5

@export_group("Telegraph")
@export var telegraph: Telegraph = Telegraph.NONE

@export_group("Art")
## Turret barrel model, pointing toward -Z. Empty = assets/models/weapons/<id>_barrel, else a box.
@export var barrel_scene: PackedScene
## Played at the muzzle per shot. Empty = assets/audio/sfx/<id>_fire, else silent.
@export var fire_sound: AudioStream


func slot_size() -> HardpointData.Size:
	return size


func category_name() -> String:
	return "Turret"


func full_name() -> String:
	return "%s (%s)" % [display_name, weapon_label] if weapon_label != "" else display_name


## The button this weapon uses when the item doesn't override it.
func default_group() -> FireGroup:
	return FireGroup.SECONDARY if targeting == Targeting.LOCK_ON else default_fire_group


func has_falloff() -> bool:
	return falloff_start < 1.0 and falloff_min < 1.0


## Damage multiplier for a hit [param distance] metres from the muzzle: 1.0 up to
## [param start] metres, then an ease-out curve down to [param min_mult] at [param max_range],
## so damage falls fastest right after the drop-off starts.
static func falloff_multiplier(distance: float, max_range: float, start: float, min_mult: float) -> float:
	if distance <= start or max_range <= start:
		return 1.0
	var t := clampf((distance - start) / (max_range - start), 0.0, 1.0)
	var eased := 1.0 - (1.0 - t) * (1.0 - t)
	return lerpf(1.0, min_mult, eased)


static func group_key(group: FireGroup) -> String:
	return "RMB" if group == FireGroup.SECONDARY else "LMB"
