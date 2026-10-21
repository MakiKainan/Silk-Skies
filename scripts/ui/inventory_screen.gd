class_name InventoryScreen
extends CanvasLayer
## The hangar refit screen (press I). Middle: the ship's 3D model, which you spin by dragging;
## each hardpoint is a drop target sitting on its spot on the hull. Below: the cargo hold as a
## scrolling carousel with filter tabs (weapons, fighters, utilities, crew) and the discard bin.
## Right: the ship's final stats. Drag items between cells; the ship updates as you do.
## Pauses the game while open. Later this same screen becomes the between-duels Refit.

signal closed

## Filter tabs over the cargo carousel: label and the item category it shows (-1 = everything).
const TABS := [
	["All", -1],
	["Weapons", HardpointData.Type.TURRET],
	["Fighters", HardpointData.Type.FIGHTER_BAY],
	["Utilities", HardpointData.Type.TECHMOD],
	["Crew", HardpointData.Type.CREW_SEAT],
]
## How many cells one press of a carousel arrow scrolls past.
const SCROLL_CELLS := 3
const CELL_GAP := 6

## The item category the carousel shows (HardpointData.Type), or -1 for all. Empty cells always show.
var filter: int = -1

var _ship: Ship
var _root: Control
var _title: Label
var _view: HangarView
var _cargo_header: Label
var _cargo_row: HBoxContainer
var _carousel: ScrollContainer
var _strip: HBoxContainer
var _prev: Button
var _next: Button
var _trash: ItemSlot
var _tab_buttons: Array[Button] = []
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

	# One drop target per hardpoint, sitting on its marker on the 3D model.
	_view.show_hull(_ship.hull)
	_view.clear_hotspots()
	for index in _ship.hull.hardpoints.size():
		var hardpoint := _ship.hull.hardpoints[index]
		var cell := ItemSlot.new()
		cell.compact = true
		_view.add_hotspot(index, cell)
		cell.setup(loadout, ShipLoadout.Kind.SLOT, index, ItemVisuals.category_color(hardpoint.type), "%s: %s slot" % [ItemVisuals.slot_caption(hardpoint), ItemVisuals.category_name(hardpoint.type)])

	for child in _cargo_row.get_children():
		_cargo_row.remove_child(child)
		child.queue_free()
	_cargo_header.text = "CARGO HOLD  %d / %d" % [loadout.cargo_count(), loadout.cargo.size()]
	for index in loadout.cargo.size():
		var cell := ItemSlot.new()
		_cargo_row.add_child(cell)
		cell.setup(loadout, ShipLoadout.Kind.CARGO, index, Color(0.5, 0.5, 0.55), "Cargo - drop any item here")
		cell.visible = _passes_filter(cell.item())

	if _trash != null:
		_strip.remove_child(_trash)
		_trash.queue_free()
	_trash = ItemSlot.new()
	_trash.is_trash = true
	_strip.add_child(_trash)
	_trash.setup(loadout, ShipLoadout.Kind.CARGO, -1, Color.WHITE, "")

	_update_arrows.call_deferred()
	_stats.bind(_ship)


## Narrows the cargo carousel to one item category ([param type] is a HardpointData.Type), or
## shows everything for -1. Empty cells always show so there is somewhere to drop.
func set_filter(type: int) -> void:
	filter = type
	for index in _tab_buttons.size():
		_tab_buttons[index].set_pressed_no_signal(TABS[index][1] == type)
	for cell in _cargo_row.get_children():
		var slot := cell as ItemSlot
		if slot != null and not slot.is_queued_for_deletion():
			slot.visible = _passes_filter(slot.item())
	_carousel.scroll_horizontal = 0
	_update_arrows.call_deferred()


func _passes_filter(item: ItemInstance) -> bool:
	return filter < 0 or item == null or int(item.data().slot_type()) == filter


## Scrolls the carousel by [param cells] cells (negative = back), easing there.
func scroll_carousel(cells: int) -> void:
	var step := ItemVisuals.SLOT_SIZE.x + CELL_GAP
	var most := maxf(_cargo_row.get_combined_minimum_size().x - _carousel.size.x, 0.0)
	var target := clampf(float(_carousel.scroll_horizontal) + cells * step, 0.0, most)
	var tween := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(_carousel, "scroll_horizontal", int(target), 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.finished.connect(_update_arrows)


## True when the cargo row is wider than the carousel window, so the arrows have work to do.
func carousel_overflows() -> bool:
	return _cargo_row.get_combined_minimum_size().x > _carousel.size.x + 1.0


func _update_arrows() -> void:
	if _carousel == null or not is_instance_valid(_carousel):
		return
	var overflow := carousel_overflows()
	_prev.visible = overflow
	_next.visible = overflow
	if overflow:
		var most := _cargo_row.get_combined_minimum_size().x - _carousel.size.x
		_prev.disabled = _carousel.scroll_horizontal <= 0
		_next.disabled = _carousel.scroll_horizontal >= most - 1.0


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
	panel.add_theme_stylebox_override(&"panel", ItemVisuals.panel_style())
	center.add_child(panel)
	var outer := VBoxContainer.new()
	panel.add_child(outer)

	var top := HBoxContainer.new()
	outer.add_child(top)
	_title = _label("REFIT", Color.WHITE, 22)
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(_title)
	top.add_child(_label("drag items onto the ship   -   drag the ship to turn it   -   I or Esc to close", Color(1, 1, 1, 0.5), 13))
	outer.add_child(HSeparator.new())

	var middle := HBoxContainer.new()
	middle.add_theme_constant_override(&"separation", 16)
	middle.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer.add_child(middle)

	var stage := PanelContainer.new()  # A dark stage behind the ship.
	stage.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stage.add_theme_stylebox_override(&"panel", ItemVisuals.flat_style(Color(0.16, 0.19, 0.27), Color(0.035, 0.045, 0.07), 2))
	middle.add_child(stage)
	_view = HangarView.new()
	stage.add_child(_view)

	var stats_scroll := ScrollContainer.new()
	stats_scroll.custom_minimum_size.x = 320.0
	stats_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	middle.add_child(stats_scroll)
	_stats = StatsPanel.new()
	_stats.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stats_scroll.add_child(_stats)

	outer.add_child(HSeparator.new())
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override(&"separation", 6)
	outer.add_child(tabs)
	for tab in TABS:
		var button := Button.new()
		button.text = tab[0]
		button.toggle_mode = true
		button.button_pressed = tab[1] == filter
		button.focus_mode = Control.FOCUS_NONE
		button.custom_minimum_size = Vector2(92.0, 28.0)
		button.pressed.connect(set_filter.bind(tab[1]))
		tabs.add_child(button)
		_tab_buttons.append(button)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tabs.add_child(spacer)
	_cargo_header = _label("CARGO HOLD", Color(1.0, 0.85, 0.4), 13)
	tabs.add_child(_cargo_header)

	_strip = HBoxContainer.new()
	_strip.add_theme_constant_override(&"separation", 8)
	outer.add_child(_strip)
	_prev = _arrow("<", -SCROLL_CELLS)
	_strip.add_child(_prev)
	_carousel = ScrollContainer.new()
	_carousel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_carousel.custom_minimum_size.y = ItemVisuals.SLOT_SIZE.y + 16.0
	_carousel.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_carousel.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	_strip.add_child(_carousel)
	_carousel.resized.connect(_update_arrows)  # The first layout arrives after the first refresh.
	_cargo_row = HBoxContainer.new()
	_cargo_row.add_theme_constant_override(&"separation", CELL_GAP)
	_carousel.add_child(_cargo_row)
	_next = _arrow(">", SCROLL_CELLS)
	_strip.add_child(_next)


func _arrow(text: String, cells: int) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = Vector2(34.0, ItemVisuals.SLOT_SIZE.y)
	button.pressed.connect(scroll_carousel.bind(cells))
	return button


func _label(text: String, color: Color, size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_color_override(&"font_color", color)
	label.add_theme_font_size_override(&"font_size", size)
	return label
