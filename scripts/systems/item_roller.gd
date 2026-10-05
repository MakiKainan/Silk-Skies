class_name ItemRoller
extends RefCounted
## Turns an item definition + a rarity into a concrete ItemInstance by rolling stat lines
## from the item's pool. All randomness comes from the RNG you pass in, so a seeded RNG
## reproduces the same drop (spec 5.8).

## Common 0 lines, Rare 1, Epic 2 (and Epic rolls are Rarity.EPIC_SCALE times bigger).
static func roll(data: ItemData, rarity: Rarity.Type, rng: RandomNumberGenerator) -> ItemInstance:
	var rolled: Array[StatMod] = []
	if data.roll_pool != null:
		var templates := data.roll_pool.templates.duplicate()
		_shuffle(templates, rng)
		var count := mini(Rarity.roll_count(rarity), templates.size())
		for i in count:
			rolled.append(_roll_line(templates[i], Rarity.roll_scale(rarity), rng))
	return ItemInstance.make(data, rarity, rolled)


static func _roll_line(template: RollTemplate, scale: float, rng: RandomNumberGenerator) -> StatMod:
	var value := rng.randf_range(template.min_value, template.max_value) * scale
	value = snappedf(value, 0.01 if template.op == StatMod.Op.PERCENT else 0.5)
	return StatMod.make(template.stat, template.op, value, template.scope)


## Fisher-Yates driven by the given RNG (Array.shuffle() uses the global one).
static func _shuffle(items: Array, rng: RandomNumberGenerator) -> void:
	for i in range(items.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var swap: Variant = items[i]
		items[i] = items[j]
		items[j] = swap
