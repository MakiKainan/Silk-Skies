class_name ActionBar
extends CanvasLayer
## The action bar of a real run, split into two slim columns at the screen edges so it never
## blocks the fight: Hard Burn and the weapons on the left, the Q/E/R side (fighter bays, techmods,
## crew) on the right. One ActionCell each with its own cooldown sweep. The columns sit
## semi-transparent and turn opaque under the mouse. It follows the tracked ship's loadout and
## rebuilds when it changes. Every active (fighter bays, techmods, crew) fires on its Q/E/R key and
## shows its cooldown; an item that names an active but has no runtime is dimmed.

const KEYS_FOR_ACTIVES: PackedStringArray = ["Q", "E", "R"]
const BURN_COLOR := Color(0.9, 0.8, 0.3)
const GROUP_GAP := 14.0
const CELL_GAP := 6.0
const SIDE_MARGIN := 14.0
## Column opacity while the mouse is elsewhere / over it.
const IDLE_ALPHA := 0.7
const HOVER_ALPHA := 1.0
const INERT_NOTE := "Active not online yet"

## Every cell, in bar order (Hard Burn first). Rebuilt with the loadout.
var cells: Array[ActionCell] = []

var _ship: Ship
var _left: VBoxContainer
var _right: VBoxContainer


func _ready() -> void:
	layer = 5  # Under the duel overlays and the refit screen.
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	_left = _column(root, Control.PRESET_CENTER_LEFT, SIDE_MARGIN)
	_right = _column(root, Control.PRESET_CENTER_RIGHT, -SIDE_MARGIN)


func _column(root: Control, preset: Control.LayoutPreset, margin: float) -> VBoxContainer:
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.set_anchors_preset(preset)
	column.grow_horizontal = Control.GROW_DIRECTION_END if margin > 0.0 else Control.GROW_DIRECTION_BEGIN
	column.grow_vertical = Control.GROW_DIRECTION_BOTH
	column.offset_left = margin
	column.offset_right = margin
	column.add_theme_constant_override(&"separation", int(CELL_GAP))
	column.modulate.a = IDLE_ALPHA
	root.add_child(column)
	return column


## The cells' column, so a test (or the hover fade) can find it.
func column_of(cell: ActionCell) -> VBoxContainer:
	return cell.get_parent() as VBoxContainer


func track(ship: Ship) -> void:
	_ship = ship
	if not ship.loadout_changed.is_connected(_queue_rebuild):
		ship.loadout_changed.connect(_queue_rebuild)
	_rebuild.call_deferred()


func _queue_rebuild() -> void:
	_rebuild.call_deferred()


func _rebuild() -> void:
	for column in [_left, _right]:
		for child in column.get_children():
			column.remove_child(child)
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
			bays.append(_bay_cell(item))
		elif data is TechmodData:
			techmods.append(_item_cell_for(item))
		elif data is CrewData:
			crew.append(_item_cell_for(item))

	var groups: Array[Array] = [burn, weapon_cells, bays, techmods, crew]
	_assign_active_keys(groups)
	_add_group(_left, burn)
	_add_group(_left, weapon_cells)
	_add_group(_right, bays)
	_add_group(_right, techmods)
	_add_group(_right, crew)


func _add_group(column: VBoxContainer, group: Array) -> void:
	if group.is_empty():
		return
	if column.get_child_count() > 0:
		var gap := Control.new()
		gap.custom_minimum_size.y = GROUP_GAP - CELL_GAP  # The column's own separation adds the rest.
		gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
		column.add_child(gap)
	for cell: ActionCell in group:
		column.add_child(cell)
		cells.append(cell)
		cell.mouse_entered.connect(func() -> void: column.modulate.a = HOVER_ALPHA)
		cell.mouse_exited.connect(func() -> void: column.modulate.a = IDLE_ALPHA)


func _burn_cell() -> ActionCell:
	var movement := _ship.movement
	var cell := ActionCell.new()
	cell.icon = UiArt.status_icon("burn")
	cell.badge = "HB"
	cell.frame_color = BURN_COLOR
	cell.key_text = "Shift"
	cell.title = "Hard Burn"
	cell.description = "A short burst of speed relative to your mouse: W toward the cursor, S away, A/D to either side, whichever way the ship faces. Cooldown follows your ship's burn stats."
	cell.fraction = movement.burn_ready_fraction
	cell.status = func() -> String: return "ready" if movement.burn_ready_fraction() >= 1.0 else "cooling"
	cell.seconds = func() -> float: return movement.model.burn_cooldown_left
	return cell


func _weapon_cell(controller: WeaponController) -> ActionCell:
	var weapon := controller.weapon
	var cell := _item_cell(controller.instance, weapon)
	cell.key_text = WeaponData.group_key(controller.fire_group())
	cell.corner_icon = UiArt.damage_icon(weapon.projectile.damage_type)
	cell.corner_tint = Damage.TYPE_COLORS[weapon.projectile.damage_type]
	cell.fraction = func() -> float: return controller.ready_fraction() if _alive(controller) else 1.0
	cell.status = func() -> String: return controller.status_text() if _alive(controller) else "ready"
	cell.seconds = func() -> float: return controller.overheat_left if _alive(controller) and controller.overheated else (controller.cooldown_left if _alive(controller) else 0.0)
	if weapon.heat_per_shot > 0.0:
		cell.heat = func() -> float: return controller.heat_fraction() if _alive(controller) else 0.0
	return cell


func _bay_cell(item: ItemInstance) -> ActionCell:
	var cell := _item_cell(item)
	var controller: FighterBayController
	for bay in _ship.bays():
		if bay.instance == item:
			controller = bay
	if controller == null:
		return cell
	cell.dimmed = false
	cell.note = ""
	cell.fraction = func() -> float: return controller.ready_fraction() if _alive(controller) else 1.0
	cell.status = func() -> String: return controller.status_text() if _alive(controller) else "ready"
	cell.seconds = func() -> float: return controller.cooldown_left if _alive(controller) else 0.0
	return cell


## A techmod or crew cell: live when an ActiveController runs it, else dimmed if it names an active.
func _item_cell_for(item: ItemInstance) -> ActionCell:
	for controller in _ship.active_controllers():
		if controller.instance == item:
			return _active_cell(item, controller)
	return _item_cell(item)


func _active_cell(item: ItemInstance, controller: ActiveController) -> ActionCell:
	var cell := _item_cell(item)
	cell.dimmed = false
	cell.note = ""
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


## Q/E/R label the first three actives, in the order Ship.activate() uses.
func _assign_active_keys(groups: Array[Array]) -> void:
	var actives := _ship.active_items()
	for group in groups:
		for cell: ActionCell in group:
			var index := actives.find(cell.item) if cell.item != null else -1
			if index >= 0 and index < KEYS_FOR_ACTIVES.size():
				cell.key_text = KEYS_FOR_ACTIVES[index]


func _alive(controller: Node) -> bool:
	return is_instance_valid(controller) and not controller.is_queued_for_deletion()
