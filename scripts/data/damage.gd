class_name Damage
extends RefCounted
## Damage vocabulary shared by projectiles, the damage model and the UI.

enum Type { ENERGY, KINETIC, EXPLOSIVE }

## Colour used for each type wherever it needs to read at a glance.
const TYPE_COLORS := {
	Type.ENERGY: Color(0.3, 0.9, 1.0),
	Type.KINETIC: Color(1.0, 0.85, 0.3),
	Type.EXPLOSIVE: Color(1.0, 0.45, 0.15),
}
