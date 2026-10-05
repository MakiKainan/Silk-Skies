class_name WeaponStats
extends RefCounted
## A weapon's final numbers: its data's base values plus modifiers. Pure.

const SCOPES := [StatMod.Scope.THIS_ITEM, StatMod.Scope.ALL_TURRETS, StatMod.Scope.SHIP]


static func base(weapon: WeaponData) -> Dictionary:
	return {
		Stats.DAMAGE: weapon.projectile.damage,
		Stats.FIRE_RATE: 1.0 / maxf(weapon.cooldown, 0.001),
		Stats.RANGE: weapon.range,
		Stats.PROJECTILE_SPEED: weapon.projectile.speed,
	}


## [param own] are the weapon's own THIS_ITEM mods; [param global] come from
## LoadoutStats.global_mods().
static func compute(weapon: WeaponData, own: Array[StatMod], global: Array[StatMod]) -> Dictionary:
	var mods: Array[StatMod] = []
	mods.append_array(own)
	mods.append_array(global)
	return StatAggregator.aggregate(base(weapon), mods, SCOPES)


## Damage per second if it fired continuously (salvos count every missile).
static func dps(weapon: WeaponData, stats: Dictionary) -> float:
	return float(stats[Stats.DAMAGE]) * weapon.shots_per_fire * float(stats[Stats.FIRE_RATE])
