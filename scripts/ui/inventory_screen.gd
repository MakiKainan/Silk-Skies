class_name InventoryScreen
extends CanvasLayer
## The refit screen (press I). Left: the ship's hardpoint slots by type. Middle: the cargo hold.
## Right: the ship's final stats. Drag items between cells; the ship updates as you do.
## Pauses the game while open. Later this same screen becomes the between-duels Refit.

signal closed

const COLUMNS := 4
const SECTION_TITLES := {
	HardpointData.Type.TURRET: "TURRETS",
	HardpointData.Type.FIGHTER_BAY: "FIGHTER BAYS",
	HardpointData.Type.TECHMOD: "TECHMODS",
	HardpointData.Type.CREW_SEAT: "CREW",
}

var _ship: Ship
var _root: Control
var _title: Label
var _slot_box: VBoxContainer
var _cargo_header: Label
var _cargo_grid: GridContainer
var _stats: StatsPanel
var _refresh_queued := false


func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS  # Keep working while the game is paused behind it.
	visible = false
	_build()


func bind(ship: Ship) -> void:
	_ship = ship
	ship.loadout_changed.connect(queue_refresh)
	ship.hull_changed.connect(func(_h: HullData) -> void: queue_refresh())
	refresh()


## [param pause]: freeze the game behind the screen (off in tests).
func open(pause: bool = true) -> void:
	visible = true
	if pause:
		get_tree().paused = true
	refresh()


func close() -> void:
	visible = false
	get_tree().paused = false
	closed.emit()


func toggle() -> void:
	if visible:
		close()
	else:
		open()


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	if key.physical_keycode == KEY_I:
		toggle()
		get_viewport().set_input_as_handled()
	elif key.physical_keycode == KEY_ESCAPE and visible:
		close()
		get_viewport().set_input_as_handled()


## Rebuild at the end of the frame. Dropping an item changes the loadout from inside a drag
## callback, and the slot that started the drag must not be freed mid-callback.
func queue_refresh() -> void:
	if _refresh_queued:
		return
	_refresh_queued = true
	refresh.call_deferred()


func refresh() -> void:
	_refresh_queued = false
	if _ship == null or _ship.loadout == null:
		return
	var loadout := _ship.loadout
	_title.text = "REFIT  -  %s" % _ship.hull.display_name

	for child in _slot_box.get_children():
		child.queue_free()
	for type in [HardpointData.Type.TURRET, HardpointData.Type.FIGHTER_BAY, HardpointData.Type.TECHMOD, HardpointData.Type.CREW_SEAT]:
		var first := true
		for index in _ship.hull.hardpoints.size():
			var hardpoint := _ship.hull.hardpoints[index]
			if hardpoint.type != type:
				continue
			if first:
				_slot_box.add_child(_header(SECTION_TITLES[type], ItemVisuals.category_color(type)))
				first = false
			_slot_box.add_child(_slot_row(loadout, index, hardpoint))

	for child in _cargo_grid.get_children():
		child.queue_free()
	_cargo_header.text = "CARGO HOLD  %d / %d" % [loadout.cargo_count(), loadout.cargo.size()]
	for index in loadout.cargo.size():
		var cell := ItemSlot.new()
		_cargo_grid.add_child(cell)
		cell.setup(loadout, ShipLoadout.Kind.CARGO, index, Color(0.5, 0.5, 0.55), "Cargo - drop any item here")
	var trash := ItemSlot.new()
	trash.is_trash = true
	_cargo_grid.add_child(trash)
	trash.setup(loadout, ShipLoadout.Kind.CARGO, -1, Color.WHITE, "")

	_stats.bind(_ship)


func _slot_row(loadout: ShipLoadout, index: int, hardpoint: HardpointData) -> Control:
	var row := HBoxContainer.new()
	var cell := ItemSlot.new()
	row.add_child(cell)
	var color := ItemVisuals.category_color(hardpoint.type)
	cell.setup(loadout, ShipLoadout.Kind.SLOT, index, color, "%s: %s slot" % [ItemVisuals.slot_caption(hardpoint), ItemVisuals.category_name(hardpoint.type)])
	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(text)
	text.add_child(_label(ItemVisuals.slot_caption(hardpoint), Color(1, 1, 1, 0.55), 12))
	var item := loadout.get_item(ShipLoadout.Kind.SLOT, index)
	text.add_child(_label(item.display_name() if item != null else "empty", Rarity.color(item.rarity) if item != null else Color(1, 1, 1, 0.3), 15))
	return row


func _build() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP  # Don't let clicks fall through to the game.
	add_child(_root)

	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.02, 0.75)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(1100.0, 610.0)
	panel.add_theme_stylebox_override(&"panel", ItemVisuals.slot_style(Color(0.3, 0.34, 0.45), Color(0.06, 0.07, 0.1), 2))
	center.add_child(panel)
	var outer := VBoxContainer.new()
	panel.add_child(outer)

	var top := HBoxContainer.new()
	outer.add_child(top)
	_title = _label("REFIT", Color.WHITE, 22)
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(_title)
	top.add_child(_label("drag items between slots   -   I or Esc to close", Color(1, 1, 1, 0.5), 13))
	outer.add_child(HSeparator.new())

	var columns := HBoxContainer.new()
	columns.add_theme_constant_override(&"separation", 28)
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer.add_child(columns)

	var ship_scroll := ScrollContainer.new()
	ship_scroll.custom_minimum_size.x = 330.0
	ship_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	columns.add_child(ship_scroll)
	_slot_box = VBoxContainer.new()
	_slot_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ship_scroll.add_child(_slot_box)

	var cargo_col := VBoxContainer.new()
	cargo_col.custom_minimum_size.x = 340.0
	columns.add_child(cargo_col)
	_cargo_header = _label("CARGO HOLD", Color(1.0, 0.85, 0.4), 13)
	cargo_col.add_child(_cargo_header)
	_cargo_grid = GridContainer.new()
	_cargo_grid.columns = COLUMNS
	_cargo_grid.add_theme_constant_override(&"h_separation", 6)
	_cargo_grid.add_theme_constant_override(&"v_separation", 6)
	cargo_col.add_child(_cargo_grid)

	var stats_scroll := ScrollContainer.new()
	stats_scroll.custom_minimum_size.x = 340.0
	stats_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stats_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	columns.add_child(stats_scroll)
	_stats = StatsPanel.new()
	_stats.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stats_scroll.add_child(_stats)


func _header(text: String, color: Color) -> Label:
	return _label(text, color, 13)


func _label(text: String, color: Color, size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_color_override(&"font_color", color)
	label.add_theme_font_size_override(&"font_size", size)
	return label
