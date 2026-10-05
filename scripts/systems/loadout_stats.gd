class_name LoadoutStats
extends RefCounted
## Turns a set of equipped items into the modifier lists the ship and its weapons use.
##
## Scopes: SHIP mods change the ship's own stats (and apply to weapon stats too, so a ship-wide
## +damage works); ALL_TURRETS mods change every weapon; THIS_ITEM mods only affect the item
## that carries them. The Engineer's TECHMOD_POTENCY scales every techmod's effects.


## Mods that apply beyond their own item: SHIP and ALL_TURRETS scopes, with techmod potency
## already applied.
static func global_mods(equipped: Array[ItemInstance]) -> Array[StatMod]:
	var potency := 0.0
	for item in equipped:
		for mod in item.all_mods():
			if mod.stat == Stats.TECHMOD_POTENCY and mod.scope == StatMod.Scope.SHIP:
				potency += mod.value
	var out: Array[StatMod] = []
	for item in equipped:
		var scale := 1.0 + potency if item.data() is TechmodData else 1.0
		for mod in item.all_mods():
			if mod.scope == StatMod.Scope.THIS_ITEM:
				continue
			if scale == 1.0 or mod.stat == Stats.TECHMOD_POTENCY:
				out.append(mod)
			else:
				out.append(StatMod.make(mod.stat, mod.op, mod.value * scale, mod.scope))
	return out


## Mods that only affect [param item] itself (its THIS_ITEM lines).
static func own_mods(item: ItemInstance) -> Array[StatMod]:
	var out: Array[StatMod] = []
	if item == null:
		return out
	for mod in item.all_mods():
		if mod.scope == StatMod.Scope.THIS_ITEM:
			out.append(mod)
	return out
