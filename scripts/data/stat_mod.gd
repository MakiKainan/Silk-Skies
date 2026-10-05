class_name StatMod
extends Resource
## One modifier to one stat. Item rolls and (later) synergy bonuses are lists of these.
##
## Aggregation order is (base + sum of FLAT) * (1 + sum of PERCENT); a PERCENT value of
## 0.25 means +25%. See StatAggregator.

enum Op { FLAT, PERCENT }
enum Scope { THIS_ITEM, ALL_TURRETS, SHIP }

@export var stat: StringName
@export var op: Op = Op.FLAT
@export var value: float = 0.0
@export var scope: Scope = Scope.SHIP


static func make(p_stat: StringName, p_op: Op, p_value: float, p_scope: Scope = Scope.SHIP) -> StatMod:
	var mod := StatMod.new()
	mod.stat = p_stat
	mod.op = p_op
	mod.value = p_value
	mod.scope = p_scope
	return mod
