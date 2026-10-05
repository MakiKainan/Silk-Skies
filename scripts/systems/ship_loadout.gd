class_name ShipLoadout
extends RefCounted
## What a ship carries: one optional item per hull hardpoint, plus a fixed-size cargo hold.
## All the rules for moving items around live here, so the UI only asks "can I?" and "do it".
## Cargo is a fixed array with empty (null) cells, so every item keeps a stable position.

signal changed

enum Kind { SLOT, CARGO }

## The cargo hold size a run uses (spec 4.3). The sandbox uses a bigger one.
const RUN_CARGO_SLOTS := 4

var hull: HullData
## Parallel to hull.hardpoints; null = empty.
var slots: Array[ItemInstance] = []
var cargo: Array[ItemInstance] = []


func _init(p_hull: HullData, cargo_capacity: int = RUN_CARGO_SLOTS) -> void:
	hull = p_hull
	slots.resize(hull.hardpoints.size())
	cargo.resize(cargo_capacity)


# --- Reading -------------------------------------------------------------------------

func get_item(kind: Kind, index: int) -> ItemInstance:
	var list := _list(kind)
	return list[index] if index >= 0 and index < list.size() else null


## Everything mounted on the ship, in hardpoint order.
func equipped() -> Array[ItemInstance]:
	var out: Array[ItemInstance] = []
	for item in slots:
		if item != null:
			out.append(item)
	return out


func cargo_count() -> int:
	return cargo.size() - free_cargo_slots()


func free_cargo_slots() -> int:
	return cargo.count(null)


# --- Rules ---------------------------------------------------------------------------

## Could [param item] sit in that cell? (null is always fine: it empties the cell.)
func can_accept(kind: Kind, index: int, item: ItemInstance) -> bool:
	if index < 0 or index >= _list(kind).size():
		return false
	if item == null or kind == Kind.CARGO:
		return true
	return Loadout.can_equip(hull.hardpoints[index], item.data())


## Can the item in one cell be dragged onto another? A move into an occupied cell swaps, so
## both items must be acceptable in their new homes.
func can_move(from_kind: Kind, from_index: int, to_kind: Kind, to_index: int) -> bool:
	if from_kind == to_kind and from_index == to_index:
		return false
	var moving := get_item(from_kind, from_index)
	if moving == null:
		return false
	var displaced := get_item(to_kind, to_index)
	return can_accept(to_kind, to_index, moving) and can_accept(from_kind, from_index, displaced)


## Moves (or swaps) items between cells. Returns false, changing nothing, if not allowed.
func move(from_kind: Kind, from_index: int, to_kind: Kind, to_index: int) -> bool:
	if not can_move(from_kind, from_index, to_kind, to_index):
		return false
	var moving := get_item(from_kind, from_index)
	var displaced := get_item(to_kind, to_index)
	_list(to_kind)[to_index] = moving
	_list(from_kind)[from_index] = displaced
	changed.emit()
	return true


## Puts an item straight into a cell (replacing whatever was there). False if it doesn't fit.
func set_item(kind: Kind, index: int, item: ItemInstance) -> bool:
	if not can_accept(kind, index, item):
		return false
	_list(kind)[index] = item
	changed.emit()
	return true


## Removes and returns the item in a cell.
func take(kind: Kind, index: int) -> ItemInstance:
	var item := get_item(kind, index)
	if item != null:
		_list(kind)[index] = null
		changed.emit()
	return item


## Adds to the first free cargo cell. Returns its index, or -1 if the hold is full.
func add_to_cargo(item: ItemInstance, notify: bool = true) -> int:
	var index := cargo.find(null)
	if index < 0:
		return -1
	cargo[index] = item
	if notify:
		changed.emit()
	return index


## Mounts the item in the first empty hardpoint it fits. Returns that index, or -1.
func equip_auto(item: ItemInstance, notify: bool = true) -> int:
	for i in slots.size():
		if slots[i] == null and can_accept(Kind.SLOT, i, item):
			slots[i] = item
			if notify:
				changed.emit()
			return i
	return -1


## Switches to a different hull, keeping what fits: mounted items re-mount on the first
## compatible empty hardpoint, the rest go to cargo, and anything left over with no room is lost.
func rebind_hull(new_hull: HullData, notify: bool = true) -> void:
	var carried := equipped()
	hull = new_hull
	slots.clear()
	slots.resize(hull.hardpoints.size())
	for item in carried:
		if equip_auto(item, false) < 0:
			add_to_cargo(item, false)
	if notify:
		changed.emit()


# --- Saving --------------------------------------------------------------------------

func to_dict() -> Dictionary:
	var slot_dicts: Array = []
	for item in slots:
		slot_dicts.append(item.to_dict() if item != null else null)
	var cargo_dicts: Array = []
	for item in cargo:
		cargo_dicts.append(item.to_dict() if item != null else null)
	return {"hull": String(hull.id), "slots": slot_dicts, "cargo": cargo_dicts}


## Rebuilds a loadout for [param p_hull]. Items whose definitions are gone are skipped;
## mounted items that no longer fit move to cargo.
static func from_dict(dict: Dictionary, p_hull: HullData, lookup: Callable = Callable()) -> ShipLoadout:
	var cargo_dicts: Array = dict.get("cargo", [])
	var loadout := ShipLoadout.new(p_hull, maxi(cargo_dicts.size(), 1))
	# Cargo first so it keeps its cells; mounted items that no longer fit take the free ones.
	for i in cargo_dicts.size():
		if cargo_dicts[i] != null:
			loadout.cargo[i] = ItemInstance.from_dict(cargo_dicts[i], lookup)
	var slot_dicts: Array = dict.get("slots", [])
	for i in slot_dicts.size():
		if slot_dicts[i] == null:
			continue
		var item := ItemInstance.from_dict(slot_dicts[i], lookup)
		if item == null:
			continue
		if i >= loadout.slots.size() or not loadout.can_accept(Kind.SLOT, i, item):
			loadout.add_to_cargo(item, false)
		else:
			loadout.slots[i] = item
	return loadout


func _list(kind: Kind) -> Array[ItemInstance]:
	return slots if kind == Kind.SLOT else cargo
