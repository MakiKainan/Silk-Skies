class_name Loadout
extends RefCounted
## Which gear fits which hardpoint.

## An item needs a hardpoint of its own type; turret items also need one at least as big.
static func can_equip(hardpoint: HardpointData, item: ItemData) -> bool:
	if hardpoint == null or item == null:
		return false
	if hardpoint.type != item.slot_type():
		return false
	return hardpoint.type != HardpointData.Type.TURRET or item.slot_size() <= hardpoint.size
