class_name PhaseData
extends Resource
## A boss phase change: when the hull drops to a fraction, switch behaviour and gear.

## Triggers once the hull fraction falls to this value or lower (0.5 = half health).
@export_range(0.05, 0.95, 0.05) var hull_threshold: float = 0.5
@export var banner: String = ""
## Replaces the enemy's AI profile (null = keep the current one).
@export var ai_profile: AIProfile
## Mounted at the moment of the change, replacing whatever sat on those hardpoints.
@export var added_items: Array[ItemSpec] = []
## The shield comes back up when the phase starts.
@export var refill_shield: bool = true
