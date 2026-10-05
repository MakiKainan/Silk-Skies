class_name DamageResult
extends RefCounted
## What one hit actually did, layer by layer. UI reads this to show exactly what happened.

var type: Damage.Type = Damage.Type.KINETIC
var position: Vector3 = Vector3.ZERO
## Shield points removed.
var shield_damage: float = 0.0
## Flat damage the armor soaked up (0 if the hit never reached the armor layer).
var armor_absorbed: float = 0.0
## Hull points removed.
var hull_damage: float = 0.0
var shield_left: float = 0.0
var hull_left: float = 0.0
var destroyed: bool = false


func total_dealt() -> float:
	return shield_damage + hull_damage
