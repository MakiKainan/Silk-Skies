class_name ActionBar
extends CanvasLayer
## The bottom bar of a real run: Hard Burn | weapons | fighter bays | techmods | crew, one
## ActionCell each with its own cooldown sweep. It follows the tracked ship's loadout and
## rebuilds when it changes. Fighter, crew and techmod actives have no runtime yet, so their
## cells are dimmed and take no fraction; give an ActionCell a `fraction` callable when they do.

const KEYS_FOR_ACTIVES: PackedStringArray = ["Q", "E", "R"]
const WEAPON_KEYS := {
	WeaponData.Targeting.AUTO: "AUTO",
	WeaponData.Targeting.MANUAL: "LMB",
	WeaponData.Targeting.LOCK_ON: "RMB",
}
const BURN_COLOR := Color(0.9, 0.8, 0.3)
const GROUP_GAP := 18.0
const BOTTOM_MARGIN := 14.0
const INERT_NOTE := "Active not online yet"

## Every cell, in bar order (Hard Burn first). Rebuilt with the loadout.
var cells: Array[ActionCell] = []

var _ship: Ship
var _row: HBoxContainer


func _ready() -> void:
	layer = 5  # Under the duel overlays and the refit screen.
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	_row = HBoxContainer.new()
	_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_row.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_row.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_row.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_row.offset_bottom = -BOTTOM_MARGIN
	_row.add_theme_constant_override(&"separation", 8)
	root.add_child(_row)


func track(ship: Ship) -> void:
	_ship = ship
	if not ship.loadout_changed.is_connected(_queue_rebuild):
		ship.loadout_changed.connect(_queue_rebuild)
	_rebuild.call_deferred()


func _queue_rebuild() -> void:
	_rebuild.call_deferred()


func _rebuild() -> void:
	for child in _row.get_children():
		_row.remove_child(child)
		child.queue_free()
	cells.clear()
	if _ship == null or not is_instance_valid(_ship) or _ship.loadout == null:
		return

	var burn: Array[ActionCell] = [_burn_cell()]
	var weapon_cells: Array[ActionCell] = []
	for controller in _ship.weapons():
		weapon_cells.append(_weapon_cell(controller))
	var bays: Array[ActionCell] = []
	var techmods: Array[ActionCell] = []
	var crew: Array[ActionCell] = []
	for item in _ship.loadout.equipped():
		var data := item.data()
		if data is FighterBayData:
			bays.append(_item_cell(item))
		elif data is TechmodData:
			techmods.append(_item_cell(item))
		elif data is CrewData:
			crew.append(_item_cell(item))

	var groups: Array[Array] = [burn, weapon_cells, bays, techmods, crew]
	_assign_active_keys(groups)
	for group in groups:
		_add_group(group)


func _add_group(group: Array) -> void:
	if group.is_empty():
		return
	if not cells.is_empty():
		var gap := Control.new()
		gap.custom_minimum_size.x = GROUP_GAP - 8.0  # The row's own separation adds the rest.
		gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_row.add_child(gap)
	for cell: ActionCell in group:
		_row.add_child(cell)
		cells.append(cell)


func _burn_cell() -> ActionCell:
	var movement := _ship.movement
	var cell := ActionCell.new()
	cell.icon = UiArt.status_icon("burn")
	cell.badge = "HB"
	cell.frame_color = BURN_COLOR
	cell.key_text = "Shift"
	cell.title = "Hard Burn"
	cell.description = "A short burst of speed in the direction you are holding. Cooldown follows your ship's burn stats."
	cell.fraction = movement.burn_ready_fraction
	cell.status = func() -> String: return "ready" if movement.burn_ready_fraction() >= 1.0 else "cooling"
	cell.seconds = func() -> float: return movement.model.burn_cooldown_left
	return cell


func _weapon_cell(controller: WeaponController) -> ActionCell:
	var weapon := controller.weapon
	var cell := _item_cell(controller.instance, weapon)
	cell.key_text = WEAPON_KEYS[weapon.targeting]
	cell.corner_icon = UiArt.damage_icon(weapon.projectile.damage_type)
	cell.corner_tint = Damage.TYPE_COLORS[weapon.projectile.damage_type]
	cell.fraction = func() -> float: return controller.ready_fraction() if _alive(controller) else 1.0
	cell.status = func() -> String: return controller.status_text() if _alive(controller) else "ready"
	cell.seconds = func() -> float: return controller.cooldown_left if _alive(controller) else 0.0
	return cell


## A cell for [param item]; [param fallback] is the bare definition for a weapon with no instance.
func _item_cell(item: ItemInstance, fallback: ItemData = null) -> ActionCell:
	var data := item.data() if item != null else fallback
	var cell := ActionCell.new()
	cell.item = item
	cell.title = data.display_name
	cell.icon = ArtLookup.item_icon(data)
	cell.badge = ItemVisuals.badge(data)
	var rarity := item.rarity if item != null else Rarity.Type.COMMON
	cell.frame_color = Rarity.color(rarity)
	cell.frame_fill = ItemVisuals.category_color(data.slot_type()).darkened(0.6)
	if not data is WeaponData and _has_active(data):
		cell.dimmed = true
		cell.note = INERT_NOTE
	return cell


## Fighter bays always have a launch; crew and techmods only when they name an active.
func _has_active(data: ItemData) -> bool:
	return data is FighterBayData or data.active_name != ""


## Q/E/R go to the first three dimmed (inert active) cells, in bar order.
func _assign_active_keys(groups: Array[Array]) -> void:
	var next := 0
	for group in groups:
		for cell: ActionCell in group:
			if cell.dimmed and next < KEYS_FOR_ACTIVES.size():
				cell.key_text = KEYS_FOR_ACTIVES[next]
				next += 1


func _alive(controller: WeaponController) -> bool:
	return is_instance_valid(controller) and not controller.is_queued_for_deletion()
