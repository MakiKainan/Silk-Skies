extends GutTest
## The rules for what can go where, and how items move between slots and cargo.
## Starter frigate hardpoints: 0 Small turret, 1 Large turret, 2 fighter bay, 3 techmod, 4 crew.

const SLOT := ShipLoadout.Kind.SLOT
const CARGO := ShipLoadout.Kind.CARGO

var loadout: ShipLoadout


func before_each() -> void:
	loadout = ShipLoadout.new(ContentDB.get_hull(&"starter_frigate"))


func _item(id: StringName, rarity: Rarity.Type = Rarity.Type.COMMON) -> ItemInstance:
	return ItemInstance.make(ContentDB.get_by_id(id) as ItemData, rarity)


func test_a_new_loadout_is_empty_with_the_run_cargo_size() -> void:
	assert_eq(loadout.slots.size(), 5)
	assert_eq(loadout.cargo.size(), ShipLoadout.RUN_CARGO_SLOTS)
	assert_eq(loadout.cargo_count(), 0)
	assert_eq(loadout.equipped().size(), 0)


func test_items_only_fit_slots_of_their_own_type_and_size() -> void:
	assert_true(loadout.set_item(SLOT, 0, _item(&"pulse_laser")))
	assert_false(loadout.set_item(SLOT, 0, _item(&"railgun")), "Large weapon in a Small turret")
	assert_true(loadout.set_item(SLOT, 1, _item(&"railgun")))
	assert_false(loadout.set_item(SLOT, 0, _item(&"shield_capacitor")), "techmod in a turret")
	assert_true(loadout.set_item(SLOT, 3, _item(&"shield_capacitor")))
	assert_false(loadout.set_item(SLOT, 2, _item(&"gunner")), "crew in a fighter bay")
	assert_true(loadout.set_item(SLOT, 2, _item(&"strike_bay")))
	assert_true(loadout.set_item(SLOT, 4, _item(&"engineer")))
	assert_eq(loadout.equipped().size(), 5)


func test_a_failed_placement_changes_nothing() -> void:
	var laser := _item(&"pulse_laser")
	loadout.set_item(SLOT, 0, laser)
	loadout.set_item(SLOT, 0, _item(&"railgun"))
	assert_eq(loadout.get_item(SLOT, 0), laser)


func test_cargo_takes_anything() -> void:
	for id in [&"pulse_laser", &"railgun", &"shield_capacitor", &"strike_bay"]:
		assert_true(loadout.can_accept(CARGO, 0, _item(id)))


func test_bad_indexes_are_refused() -> void:
	assert_false(loadout.can_accept(SLOT, 9, _item(&"pulse_laser")))
	assert_false(loadout.can_accept(CARGO, -1, _item(&"pulse_laser")))
	assert_null(loadout.get_item(SLOT, 9))


# --- Moving ----------------------------------------------------------------------------

func test_move_from_cargo_to_a_slot() -> void:
	var laser := _item(&"pulse_laser")
	loadout.add_to_cargo(laser)
	assert_true(loadout.can_move(CARGO, 0, SLOT, 0))
	assert_true(loadout.move(CARGO, 0, SLOT, 0))
	assert_eq(loadout.get_item(SLOT, 0), laser)
	assert_null(loadout.get_item(CARGO, 0))


func test_move_from_a_slot_to_cargo_and_between_cargo_cells() -> void:
	var laser := _item(&"pulse_laser")
	loadout.set_item(SLOT, 0, laser)
	assert_true(loadout.move(SLOT, 0, CARGO, 2))
	assert_eq(loadout.get_item(CARGO, 2), laser)
	assert_true(loadout.move(CARGO, 2, CARGO, 0))
	assert_eq(loadout.get_item(CARGO, 0), laser)


func test_a_misfit_move_is_refused_and_changes_nothing() -> void:
	var railgun := _item(&"railgun")
	loadout.add_to_cargo(railgun)
	assert_false(loadout.can_move(CARGO, 0, SLOT, 0), "Large weapon, Small turret")
	assert_false(loadout.can_move(CARGO, 0, SLOT, 3), "weapon, techmod slot")
	assert_false(loadout.move(CARGO, 0, SLOT, 3))
	assert_eq(loadout.get_item(CARGO, 0), railgun)


func test_dropping_on_an_occupied_cell_swaps() -> void:
	var laser := _item(&"pulse_laser")
	var cannon := _item(&"autocannon")
	loadout.set_item(SLOT, 0, laser)
	loadout.add_to_cargo(cannon)
	assert_true(loadout.move(CARGO, 0, SLOT, 0))
	assert_eq(loadout.get_item(SLOT, 0), cannon)
	assert_eq(loadout.get_item(CARGO, 0), laser, "the displaced item takes the vacated cell")


func test_a_swap_is_refused_if_the_displaced_item_cannot_go_back() -> void:
	var railgun := _item(&"railgun")
	var laser := _item(&"pulse_laser")
	loadout.set_item(SLOT, 1, railgun)
	loadout.set_item(SLOT, 0, laser)
	# Railgun -> Small turret is illegal; the laser -> Large turret half would be fine.
	assert_false(loadout.can_move(SLOT, 1, SLOT, 0))
	# Laser -> Large turret displaces the railgun into the Small turret: also illegal.
	assert_false(loadout.can_move(SLOT, 0, SLOT, 1))
	assert_eq(loadout.get_item(SLOT, 1), railgun)


func test_two_small_weapons_can_swap_between_a_small_and_a_large_turret() -> void:
	loadout.set_item(SLOT, 0, _item(&"pulse_laser"))
	loadout.set_item(SLOT, 1, _item(&"autocannon"))
	assert_true(loadout.move(SLOT, 0, SLOT, 1))
	assert_eq(loadout.get_item(SLOT, 0).data_id, &"autocannon")
	assert_eq(loadout.get_item(SLOT, 1).data_id, &"pulse_laser")


func test_cannot_move_an_empty_cell_or_a_cell_onto_itself() -> void:
	loadout.add_to_cargo(_item(&"pulse_laser"))
	assert_false(loadout.can_move(CARGO, 1, CARGO, 2), "nothing to move")
	assert_false(loadout.can_move(CARGO, 0, CARGO, 0), "onto itself")


func test_changed_fires_once_per_successful_change_only() -> void:
	watch_signals(loadout)
	loadout.add_to_cargo(_item(&"pulse_laser"))
	assert_signal_emit_count(loadout, "changed", 1)
	loadout.move(CARGO, 0, SLOT, 3)  # Refused.
	assert_signal_emit_count(loadout, "changed", 1)
	loadout.move(CARGO, 0, SLOT, 0)
	assert_signal_emit_count(loadout, "changed", 2)


# --- Cargo and auto-equip ----------------------------------------------------------------

func test_add_to_cargo_fills_cells_in_order_and_reports_a_full_hold() -> void:
	for i in 4:
		assert_eq(loadout.add_to_cargo(_item(&"pulse_laser")), i)
	assert_eq(loadout.add_to_cargo(_item(&"pulse_laser")), -1)
	assert_eq(loadout.cargo_count(), 4)
	assert_eq(loadout.free_cargo_slots(), 0)


func test_cargo_cells_keep_their_positions_when_one_is_emptied() -> void:
	var a := _item(&"pulse_laser")
	var b := _item(&"autocannon")
	loadout.add_to_cargo(a)
	loadout.add_to_cargo(b)
	loadout.take(CARGO, 0)
	assert_eq(loadout.get_item(CARGO, 1), b, "b did not shuffle forward")
	assert_eq(loadout.add_to_cargo(_item(&"railgun")), 0, "the gap is reused")


func test_equip_auto_uses_the_first_empty_compatible_slot() -> void:
	assert_eq(loadout.equip_auto(_item(&"pulse_laser")), 0)
	assert_eq(loadout.equip_auto(_item(&"autocannon")), 1, "Small weapon overflows into the Large turret")
	assert_eq(loadout.equip_auto(_item(&"pulse_laser")), -1, "no free turret")
	assert_eq(loadout.equip_auto(_item(&"shield_capacitor")), 3)


func test_take_removes_and_returns_the_item() -> void:
	var laser := _item(&"pulse_laser")
	loadout.set_item(SLOT, 0, laser)
	assert_eq(loadout.take(SLOT, 0), laser)
	assert_null(loadout.get_item(SLOT, 0))
	assert_null(loadout.take(SLOT, 0))


# --- Hull change -------------------------------------------------------------------------

func test_rebinding_to_another_hull_keeps_what_fits_and_cargos_the_rest() -> void:
	var laser := _item(&"pulse_laser")
	var railgun := _item(&"railgun")
	var capacitor := _item(&"shield_capacitor")
	var gunner := _item(&"gunner")
	loadout.set_item(SLOT, 0, laser)
	loadout.set_item(SLOT, 1, railgun)
	loadout.set_item(SLOT, 3, capacitor)
	loadout.set_item(SLOT, 4, gunner)
	loadout.rebind_hull(ContentDB.get_hull(&"debug_skiff"))  # 1 Small turret + 1 techmod
	assert_eq(loadout.slots.size(), 2)
	assert_eq(loadout.get_item(SLOT, 0), laser)
	assert_eq(loadout.get_item(SLOT, 1), capacitor)
	assert_true(loadout.cargo.has(railgun), "Large weapon has no Large turret now")
	assert_true(loadout.cargo.has(gunner), "no crew seat on the skiff")


func test_items_with_no_room_when_changing_hull_are_lost_not_duplicated() -> void:
	loadout.set_item(SLOT, 4, _item(&"gunner"))
	for i in 4:
		loadout.add_to_cargo(_item(&"pulse_laser"))
	loadout.rebind_hull(ContentDB.get_hull(&"debug_skiff"))
	assert_eq(loadout.cargo_count(), 4)
	assert_eq(loadout.equipped().size(), 0)


# --- Saving ------------------------------------------------------------------------------

func test_a_loadout_survives_a_save_round_trip() -> void:
	loadout.set_item(SLOT, 0, _item(&"pulse_laser", Rarity.Type.RARE))
	loadout.set_item(SLOT, 3, _item(&"shield_capacitor"))
	loadout.add_to_cargo(_item(&"railgun", Rarity.Type.EPIC))
	loadout.take(CARGO, 0)
	loadout.add_to_cargo(_item(&"missile_pod"))
	loadout.cargo[2] = _item(&"gunner")
	var copy := ShipLoadout.from_dict(JSON.parse_string(JSON.stringify(loadout.to_dict())), loadout.hull)
	assert_eq(copy.get_item(SLOT, 0).data_id, &"pulse_laser")
	assert_eq(copy.get_item(SLOT, 0).rarity, Rarity.Type.RARE)
	assert_eq(copy.get_item(SLOT, 3).data_id, &"shield_capacitor")
	assert_eq(copy.get_item(CARGO, 0).data_id, &"missile_pod")
	assert_null(copy.get_item(CARGO, 1))
	assert_eq(copy.get_item(CARGO, 2).data_id, &"gunner")
	assert_eq(copy.cargo.size(), loadout.cargo.size())


func test_loading_skips_items_that_no_longer_exist() -> void:
	var data := loadout.to_dict()
	data.slots[0] = {"data_id": "deleted_gun", "rarity": 0, "rolls": []}
	data.cargo[1] = {"data_id": "deleted_gun", "rarity": 0, "rolls": []}
	data.cargo[0] = _item(&"railgun").to_dict()
	var copy := ShipLoadout.from_dict(data, loadout.hull)
	assert_null(copy.get_item(SLOT, 0))
	assert_null(copy.get_item(CARGO, 1))
	assert_eq(copy.get_item(CARGO, 0).data_id, &"railgun")


func test_a_saved_item_that_no_longer_fits_its_slot_goes_to_cargo() -> void:
	var data := loadout.to_dict()
	data.slots[0] = _item(&"railgun").to_dict()  # Large weapon in the Small turret.
	var copy := ShipLoadout.from_dict(data, loadout.hull)
	assert_null(copy.get_item(SLOT, 0))
	assert_eq(copy.cargo_count(), 1)
