extends "res://tests/helpers/ship_test.gd"
## The refit screen. Drag and drop is exercised by calling the same callbacks Godot calls
## (_get_drag_data / _can_drop_data / _drop_data) so no mouse is needed.

const SLOT := ShipLoadout.Kind.SLOT
const CARGO := ShipLoadout.Kind.CARGO

var ship: Ship
var screen: InventoryScreen


func before_each() -> void:
	ship = make_ship(Ship.TEAM_PLAYER, Vector3.ZERO)
	screen = InventoryScreen.new()
	add_child_autofree(screen)
	screen.bind(ship)
	screen.open(false)  # Don't pause the test runner.
	await wait_physics_frames(2)


func _item(id: StringName, rarity: Rarity.Type = Rarity.Type.COMMON) -> ItemInstance:
	return ItemInstance.make(ContentDB.get_by_id(id) as ItemData, rarity)


func _cell(kind: ShipLoadout.Kind, index: int) -> ItemSlot:
	for node in screen.find_children("*", "ItemSlot", true, false):
		var cell := node as ItemSlot
		if not cell.is_queued_for_deletion() and not cell.is_trash and cell.kind == kind and cell.index == index:
			return cell
	return null


func _trash() -> ItemSlot:
	for node in screen.find_children("*", "ItemSlot", true, false):
		if (node as ItemSlot).is_trash and not node.is_queued_for_deletion():
			return node
	return null


func _label_texts(root: Node) -> PackedStringArray:
	var out := PackedStringArray()
	for node in root.find_children("*", "Label", true, false):
		if not node.is_queued_for_deletion():
			out.append((node as Label).text)
	return out


func _settle() -> void:
	await wait_physics_frames(2)


func test_the_screen_shows_every_hardpoint_and_cargo_cell() -> void:
	assert_not_null(_cell(SLOT, 0))
	assert_not_null(_cell(SLOT, 4))
	assert_null(_cell(SLOT, 5))
	assert_not_null(_cell(CARGO, 3))
	assert_null(_cell(CARGO, 4), "run cargo is 4 cells")
	assert_not_null(_trash())


func test_dragging_from_cargo_to_a_fitting_slot_equips_it() -> void:
	ship.loadout.add_to_cargo(_item(&"autocannon"))
	await _settle()
	var drag: Variant = _cell(CARGO, 0)._get_drag_data(Vector2.ZERO)
	assert_not_null(drag)
	var target := _cell(SLOT, 0)
	assert_true(target._can_drop_data(Vector2.ZERO, drag))
	target._drop_data(Vector2.ZERO, drag)
	await _settle()
	assert_eq(ship.weapon_at(0).weapon.id, &"autocannon")
	assert_null(_cell(CARGO, 0).item())
	assert_eq(_cell(SLOT, 0).item().data_id, &"autocannon", "the screen redrew")


func test_slots_refuse_items_that_do_not_fit() -> void:
	ship.loadout.add_to_cargo(_item(&"railgun"))
	await _settle()
	var drag: Variant = _cell(CARGO, 0)._get_drag_data(Vector2.ZERO)
	assert_false(_cell(SLOT, 0)._can_drop_data(Vector2.ZERO, drag), "Large weapon, Small turret")
	assert_false(_cell(SLOT, 3)._can_drop_data(Vector2.ZERO, drag), "weapon, techmod slot")
	assert_true(_cell(SLOT, 1)._can_drop_data(Vector2.ZERO, drag), "Large turret is fine")
	assert_true(_cell(CARGO, 2)._can_drop_data(Vector2.ZERO, drag), "any cargo cell is fine")


func test_dragging_an_empty_cell_does_nothing() -> void:
	assert_null(_cell(CARGO, 0)._get_drag_data(Vector2.ZERO))


func test_dropping_on_the_cell_you_picked_up_from_is_not_allowed() -> void:
	ship.loadout.add_to_cargo(_item(&"autocannon"))
	await _settle()
	var cell := _cell(CARGO, 0)
	assert_false(cell._can_drop_data(Vector2.ZERO, cell._get_drag_data(Vector2.ZERO)))


func test_dropping_on_an_occupied_slot_swaps() -> void:
	ship.equip_item(0, _item(&"pulse_laser"))
	ship.loadout.add_to_cargo(_item(&"autocannon"))
	await _settle()
	var drag: Variant = _cell(CARGO, 0)._get_drag_data(Vector2.ZERO)
	_cell(SLOT, 0)._drop_data(Vector2.ZERO, drag)
	await _settle()
	assert_eq(ship.weapon_at(0).weapon.id, &"autocannon")
	assert_eq(_cell(CARGO, 0).item().data_id, &"pulse_laser")


func test_the_discard_bin_deletes_an_item() -> void:
	ship.loadout.add_to_cargo(_item(&"autocannon"))
	await _settle()
	var drag: Variant = _cell(CARGO, 0)._get_drag_data(Vector2.ZERO)
	assert_true(_trash()._can_drop_data(Vector2.ZERO, drag))
	_trash()._drop_data(Vector2.ZERO, drag)
	assert_eq(ship.loadout.cargo_count(), 0)


func test_the_discard_bin_refuses_an_empty_drag() -> void:
	assert_false(_trash()._can_drop_data(Vector2.ZERO, {"loadout": ship.loadout, "kind": CARGO, "index": 0}))


func test_drags_from_some_other_loadout_are_ignored() -> void:
	var other := ShipLoadout.new(ship.hull)
	other.add_to_cargo(_item(&"pulse_laser"))
	var foreign := {"loadout": other, "kind": CARGO, "index": 0}
	assert_false(_cell(SLOT, 0)._can_drop_data(Vector2.ZERO, foreign))
	assert_false(_cell(SLOT, 0)._can_drop_data(Vector2.ZERO, "not a dictionary"))


func test_the_stats_panel_shows_changes_from_the_bare_hull() -> void:
	var before := _label_texts(screen)
	assert_false("+50" in before)
	ship.equip_item(3, _item(&"shield_capacitor"))
	await _settle()
	var texts := _label_texts(screen)
	assert_true("Shield" in texts)
	assert_true("150" in texts, "new shield value")
	assert_true("+50" in texts, "delta against the hull")
	assert_true("+4" in texts, "regen delta")


func test_the_stats_panel_lists_weapon_dps() -> void:
	ship.equip(0, weapon(&"pulse_laser"))
	await _settle()
	var found := false
	for text in _label_texts(screen):
		if text.begins_with("Pulse Laser") and "DPS" in text:
			found = true
	assert_true(found)


func test_the_stats_panel_says_so_when_there_are_no_weapons() -> void:
	assert_true("no weapons mounted" in _label_texts(screen))


func test_the_cargo_header_counts_items() -> void:
	ship.loadout.add_to_cargo(_item(&"autocannon"))
	ship.loadout.add_to_cargo(_item(&"gunner"))
	await _settle()
	assert_true("CARGO HOLD  2 / 4" in _label_texts(screen))


func test_the_screen_follows_a_hull_swap() -> void:
	ship.swap_hull(ContentDB.get_hull(&"debug_skiff"))
	await _settle()
	assert_not_null(_cell(SLOT, 1))
	assert_null(_cell(SLOT, 2), "the skiff has two hardpoints")
	assert_true("REFIT  -  Debug Skiff (light, nimble)" in _label_texts(screen))


# --- Tooltips and visuals ----------------------------------------------------------------

func test_a_weapon_tooltip_shows_its_numbers_and_rolls() -> void:
	var rolls: Array[StatMod] = [StatMod.make(Stats.DAMAGE, StatMod.Op.PERCENT, 0.2, StatMod.Scope.THIS_ITEM)]
	var item := ItemInstance.make(ContentDB.get_by_id(&"railgun") as ItemData, Rarity.Type.RARE, rolls)
	var tip := ItemTooltip.build(item)
	add_child_autofree(tip)
	var texts := _label_texts(tip)
	assert_true("Railgun" in texts)
	assert_true("Rare Turret - Large, manual" in texts)
	assert_true("* +20% Damage" in texts)
	assert_true("Pierces 2 ships" in texts)
	var has_dps := false
	for text in texts:
		has_dps = has_dps or text.begins_with("DPS")
	assert_true(has_dps)


func test_a_crew_tooltip_shows_the_station_bonus_and_active() -> void:
	var tip := ItemTooltip.build(_item(&"gunner", Rarity.Type.EPIC))
	add_child_autofree(tip)
	var texts := _label_texts(tip)
	assert_true("Station: turret fire rate" in texts)
	assert_true("+15% Fire rate (all turrets)" in texts)
	assert_true("Active: Overcharge" in texts)


func test_a_fighter_bay_tooltip_shows_its_fighters() -> void:
	var tip := ItemTooltip.build(_item(&"strike_bay"))
	add_child_autofree(tip)
	assert_true("2 x Bomber" in _label_texts(tip))


func test_empty_slots_explain_themselves_and_filled_ones_use_the_custom_tooltip() -> void:
	var empty := _cell(SLOT, 1)
	assert_string_contains(empty.tooltip_text, "Large")
	assert_null(empty._make_custom_tooltip(""))
	ship.equip_item(1, _item(&"railgun"))
	await _settle()
	var tip: Object = _cell(SLOT, 1)._make_custom_tooltip("x")
	assert_not_null(tip)
	tip.free()


func test_item_badges() -> void:
	assert_eq(ItemVisuals.badge(ContentDB.get_by_id(&"pulse_laser") as ItemData), "PL")
	assert_eq(ItemVisuals.badge(ContentDB.get_by_id(&"gunner") as ItemData), "GU")
