class_name StatAggregator
extends RefCounted
## Pure stat math: base stats + modifiers -> final stats.
##
## final = (base + sum of FLAT) * (1 + sum of PERCENT), per stat. A stat that only appears
## in the mods is treated as having a base of 0.

## [param scopes] lists which StatMod.Scope values apply to this aggregation. The ship's own
## stats take SHIP; a weapon's stats will later also take THIS_ITEM and ALL_TURRETS.
static func aggregate(base: Dictionary, mods: Array[StatMod], scopes: Array = [StatMod.Scope.SHIP]) -> Dictionary:
	var flat: Dictionary = {}
	var percent: Dictionary = {}
	for mod: StatMod in mods:
		if mod == null or not scopes.has(mod.scope):
			continue
		var bucket: Dictionary = flat if mod.op == StatMod.Op.FLAT else percent
		bucket[mod.stat] = float(bucket.get(mod.stat, 0.0)) + mod.value

	var out: Dictionary = {}
	for stat: StringName in base:
		out[stat] = _combine(float(base[stat]), flat, percent, stat)
	for stat: StringName in flat:
		if not out.has(stat):
			out[stat] = _combine(0.0, flat, percent, stat)
	for stat: StringName in percent:
		if not out.has(stat):
			out[stat] = _combine(0.0, flat, percent, stat)
	return out


static func _combine(base_value: float, flat: Dictionary, percent: Dictionary, stat: StringName) -> float:
	return (base_value + float(flat.get(stat, 0.0))) * (1.0 + float(percent.get(stat, 0.0)))
