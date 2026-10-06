class_name EnemyData
extends Resource
## A fightable enemy: a hull, a loadout of real items, an AI profile, and optional boss
## phases. Enemies are ordinary ships (spec 4.2); this is the recipe.

@export var id: StringName
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var hull: HullData
@export var loadout: Array[ItemSpec] = []
@export var ai_profile: AIProfile
## Health-gated phase changes, in descending threshold order. Empty for ordinary enemies.
@export var phases: Array[PhaseData] = []
@export var is_boss: bool = false
