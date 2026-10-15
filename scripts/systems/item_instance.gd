class_name ItemInstance
extends RefCounted
## One specific drop: an item definition plus its rarity and rolled stat lines (spec 5.2).
## Saves as a plain dictionary holding the item's id, never the definition itself.

var data_id: StringName
var rarity: Rarity.Type = Rarity.Type.COMMON
var rolls: Array[StatMod] = []
## Weapons only: the mouse button that fires it (a WeaponData.FireGroup), or -1 for the
## weapon's own default. Set in the refit screen.
var fire_group: int = -1

var _data: ItemData


static func make(p_data: ItemData, p_rarity: Rarity.Type = Rarity.Type.COMMON, p_rolls: Array[StatMod] = []) -> ItemInstance:
	var item := ItemInstance.new()
	item._data = p_data
	item.data_id = p_data.id
	item.rarity = p_rarity
	item.rolls = p_rolls.duplicate()
	return item


func data() -> ItemData:
	if _data == null:
		_data = ContentDB.get_by_id(data_id) as ItemData
	return _data


## The button that fires this weapon. Lock-on weapons are always SECONDARY.
func fire_group_of() -> WeaponData.FireGroup:
	var weapon := data() as WeaponData
	if weapon == null:
		return WeaponData.FireGroup.PRIMARY
	if weapon.targeting == WeaponData.Targeting.LOCK_ON or fire_group < 0:
		return weapon.default_group()
	return fire_group as WeaponData.FireGroup


## Can the player move this weapon to the other mouse button?
func can_toggle_fire_group() -> bool:
	var weapon := data() as WeaponData
	return weapon != null and weapon.targeting != WeaponData.Targeting.LOCK_ON


## Moves this weapon to the other mouse button. Returns false for lock-on weapons and non-weapons.
func toggle_fire_group() -> bool:
	if not can_toggle_fire_group():
		return false
	fire_group = WeaponData.FireGroup.PRIMARY if fire_group_of() == WeaponData.FireGroup.SECONDARY else WeaponData.FireGroup.SECONDARY
	return true


func display_name() -> String:
	return data().display_name if data() != null else str(data_id)


## Everything this item does to the ship while equipped: its built-in effects, then its rolls.
func all_mods() -> Array[StatMod]:
	var out: Array[StatMod] = []
	if data() != null:
		out.append_array(data().base_mods)
	out.append_array(rolls)
	return out


func to_dict() -> Dictionary:
	var lines: Array = []
	for roll in rolls:
		lines.append({"stat": String(roll.stat), "op": roll.op, "value": roll.value, "scope": roll.scope})
	var out := {"data_id": String(data_id), "rarity": rarity, "rolls": lines}
	if fire_group >= 0:
		out["fire_group"] = fire_group
	return out


## Rebuilds an item from to_dict(). Returns null (with a warning) if the item no longer
## exists, so removed content is skipped instead of crashing a load.
## [param lookup] maps an id to an ItemData; defaults to ContentDB.
static func from_dict(dict: Dictionary, lookup: Callable = Callable()) -> ItemInstance:
	var id := StringName(dict.get("data_id", ""))
	var found: ItemData
	if lookup.is_valid():
		found = lookup.call(id) as ItemData
	else:
		found = ContentDB.get_by_id(id) as ItemData
	if found == null:
		push_warning("ItemInstance: unknown item id '%s', skipping" % id)
		return null
	var rolled: Array[StatMod] = []
	for line: Dictionary in dict.get("rolls", []):
		rolled.append(StatMod.make(StringName(line.get("stat", "")), int(line.get("op", 0)) as StatMod.Op, float(line.get("value", 0.0)), int(line.get("scope", 0)) as StatMod.Scope))
	var item := make(found, clampi(int(dict.get("rarity", 0)), 0, Rarity.Type.LEGENDARY) as Rarity.Type, rolled)
	item.fire_group = clampi(int(dict.get("fire_group", -1)), -1, WeaponData.FireGroup.SECONDARY)
	return item
