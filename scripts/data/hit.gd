class_name Hit
extends RefCounted
## One packet of damage on its way to a ship's HealthComponent.

var damage: float = 0.0
var type: Damage.Type = Damage.Type.KINETIC
## The ship that caused it; may be freed by the time the hit lands, so check validity.
var source: Node
var position: Vector3 = Vector3.ZERO


static func make(p_damage: float, p_type: Damage.Type, p_source: Node, p_position: Vector3) -> Hit:
	var hit := Hit.new()
	hit.damage = p_damage
	hit.type = p_type
	hit.source = p_source
	hit.position = p_position
	return hit
