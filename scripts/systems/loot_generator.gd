class_name LootGenerator
extends RefCounted
## The post-duel salvage offers (spec 4.2): three items to choose from, one of them something the
## defeated enemy was using, the rest from the whole item pool. Pure and seeded: the same
## RNG state gives the same three offers, so a retry or a reload shows the same choice.

const OFFER_COUNT := 3
## Common / Rare / Epic odds (in percent) for the first duel.
const BASE_WEIGHTS: Array[int] = [60, 30, 10]
## Each later duel moves this many percent from Common to Epic.
const SHIFT_PER_DUEL := 10


## [param enemy] is the one just beaten, [param pool] every item that may appear, [param duel_index]
## the zero-based duel just won. Items are distinct. Fewer than three come back only if the
## pool is too small.
static func offers(enemy: EnemyData, pool: Array[ItemData], duel_index: int, rng: RandomNumberGenerator) -> Array[ItemInstance]:
	var out: Array[ItemInstance] = []
	var remaining: Array[ItemData] = pool.duplicate()

	var drops := enemy_drops(enemy, pool)
	if not drops.is_empty():
		var spec := drops[rng.randi_range(0, drops.size() - 1)]
		out.append(ItemRoller.roll(spec.item, spec.rarity, rng))
		_remove_item(remaining, spec.item)

	while out.size() < OFFER_COUNT and not remaining.is_empty():
		var data := remaining[rng.randi_range(0, remaining.size() - 1)]
		remaining.erase(data)
		out.append(ItemRoller.roll(data, roll_rarity(duel_index, rng), rng))
	return out


## What an enemy used and can therefore drop: its loadout plus anything its phases add, one spec
## per distinct item and only items that are in [param pool].
static func enemy_drops(enemy: EnemyData, pool: Array[ItemData]) -> Array[ItemSpec]:
	var specs: Array[ItemSpec] = []
	specs.append_array(enemy.loadout)
	for phase in enemy.phases:
		specs.append_array(phase.added_items)
	var pool_ids := {}
	for data in pool:
		pool_ids[data.id] = true
	var out: Array[ItemSpec] = []
	var seen := {}
	for spec in specs:
		if spec.item == null or seen.has(spec.item.id) or not pool_ids.has(spec.item.id):
			continue
		seen[spec.item.id] = true
		out.append(spec)
	return out


## Common / Rare / Epic weights after [param duel_index] duels: 60/30/10, then Epic gains and
## Common loses [constant SHIFT_PER_DUEL] per duel (Common stops at zero).
static func rarity_weights(duel_index: int) -> Array[int]:
	var shift := mini(SHIFT_PER_DUEL * maxi(duel_index, 0), BASE_WEIGHTS[0])
	return [BASE_WEIGHTS[0] - shift, BASE_WEIGHTS[1], BASE_WEIGHTS[2] + shift]


static func roll_rarity(duel_index: int, rng: RandomNumberGenerator) -> Rarity.Type:
	var weights := rarity_weights(duel_index)
	var pick := rng.randi_range(1, weights[0] + weights[1] + weights[2])
	if pick <= weights[0]:
		return Rarity.Type.COMMON
	if pick <= weights[0] + weights[1]:
		return Rarity.Type.RARE
	return Rarity.Type.EPIC


static func _remove_item(list: Array[ItemData], data: ItemData) -> void:
	for i in range(list.size() - 1, -1, -1):
		if list[i].id == data.id:
			list.remove_at(i)
