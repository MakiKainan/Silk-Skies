class_name DamageModel
extends RefCounted
## Pure damage maths (spec 2.2). A hit goes Shields -> Armor -> Hull.
##
## - Shields take damage * the type's shield multiplier. If they run out mid-hit, the
##   unabsorbed part carries on as a *fraction of the raw hit*, so no multiplier is applied twice.
## - Armor removes a flat amount from what's left (kinetic ignores half of it), but a hit that
##   reaches the armor layer is never reduced below min(what's left, 1).
## - Hull takes the rest * the type's hull multiplier.
##
## These are starting tuning values; edit the tables to rebalance.

const SHIELD_MULT := {
	Damage.Type.ENERGY: 1.5,
	Damage.Type.KINETIC: 0.75,
	Damage.Type.EXPLOSIVE: 0.5,
}
## Fraction of armor ignored by the type.
const ARMOR_IGNORE := {
	Damage.Type.ENERGY: 0.0,
	Damage.Type.KINETIC: 0.5,
	Damage.Type.EXPLOSIVE: 0.0,
}
const HULL_MULT := {
	Damage.Type.ENERGY: 0.75,
	Damage.Type.KINETIC: 1.0,
	Damage.Type.EXPLOSIVE: 1.5,
}
## No hit that reaches the armor layer is reduced below this (or below what's left of it).
const MIN_ARMORED_DAMAGE := 1.0


static func resolve(damage: float, type: Damage.Type, shield: float, armor: float, hull: float) -> DamageResult:
	var result := DamageResult.new()
	result.type = type
	result.shield_left = shield
	result.hull_left = hull
	if damage <= 0.0:
		return result

	# Shields.
	var leftover := damage
	var shield_hit: float = damage * SHIELD_MULT[type]
	if shield > 0.0:
		if shield >= shield_hit:
			result.shield_damage = shield_hit
			result.shield_left = shield - shield_hit
			return result
		result.shield_damage = shield
		result.shield_left = 0.0
		leftover = damage * (1.0 - shield / shield_hit)

	# Armor.
	var effective_armor: float = armor * (1.0 - float(ARMOR_IGNORE[type]))
	var after_armor := maxf(leftover - effective_armor, minf(leftover, MIN_ARMORED_DAMAGE))
	result.armor_absorbed = leftover - after_armor

	# Hull.
	var hull_hit := minf(after_armor * float(HULL_MULT[type]), hull)
	result.hull_damage = hull_hit
	result.hull_left = hull - hull_hit
	result.destroyed = result.hull_left <= 0.0
	return result
