class_name StatsComponent
extends Node
## Holds a ship's final stats: hull base stats + modifiers, recomputed only when the
## loadout changes. The HullData resource itself is never touched.

signal stats_changed

## Final stat values, keyed by Stats constants.
var values: Dictionary = {}

var _base: Dictionary = {}
var _mods: Array[StatMod] = []


func setup(hull: HullData, mods: Array[StatMod] = []) -> void:
	_base = hull.base_stats()
	_mods.assign(mods)
	recompute()


func set_mods(mods: Array[StatMod]) -> void:
	_mods.assign(mods)
	recompute()


## Live override of one base stat (used by the sandbox tuning panel).
func set_base_stat(stat: StringName, value: float) -> void:
	_base[stat] = value
	recompute()


func base_stat(stat: StringName) -> float:
	return float(_base.get(stat, 0.0))


func get_stat(stat: StringName) -> float:
	return float(values.get(stat, 0.0))


func recompute() -> void:
	values = StatAggregator.aggregate(_base, _mods)
	stats_changed.emit()
