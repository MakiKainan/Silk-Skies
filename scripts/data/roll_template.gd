class_name RollTemplate
extends Resource
## One possible rolled stat line: which stat, how it applies, and the range it rolls in.

@export var stat: StringName
@export var op: StatMod.Op = StatMod.Op.PERCENT
@export var scope: StatMod.Scope = StatMod.Scope.THIS_ITEM
## Percent values are fractions: 0.10 is +10%.
@export var min_value: float = 0.05
@export var max_value: float = 0.15
