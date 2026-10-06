class_name ItemSpec
extends Resource
## "This item, at this rarity, on this hardpoint." How enemy loadouts are authored. The actual
## drop (its rolled stat lines) is rolled when the enemy spawns, from the run's seeded RNG.

@export var item: ItemData
@export var rarity: Rarity.Type = Rarity.Type.COMMON
## Name of the hull's hardpoint marker to mount it on (e.g. "Turret_A").
@export var slot: StringName
