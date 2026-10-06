class_name RewardScreen
extends CanvasLayer
## "SALVAGE": the pick-one-of-three screen after a won duel. Each card is the item's tooltip with
## a Take button; Skip passes, Refit opens the inventory so there is room to take something.
## Taking mounts the item on a free matching hardpoint, else puts it in the hold. Pure UI: the
## Duel decides what happens next when [signal finished] fires.

## Emitted when the player has chosen. [param taken] is null when they skipped.
signal finished(taken: ItemInstance)
signal refit_pressed

var _root: Control
var _loadout: ShipLoadout
var _offers: Array[ItemInstance] = []
var _take_buttons: Array[Button] = []
var _hold_label: Label


func _ready() -> void:
	layer = 16
	process_mode = Node.PROCESS_MODE_ALWAYS  # Works while the game is paused behind it.


## Shows [param offers] for the player's [param loadout].
func show_offers(offers: Array[ItemInstance], loadout: ShipLoadout) -> void:
	hide_screen()
	_offers = offers
	_loadout = loadout
	if not _loadout.changed.is_connected(_refresh):
		_loadout.changed.connect(_refresh)
	_build()
	_refresh()


func hide_screen() -> void:
	if _loadout != null and _loadout.changed.is_connected(_refresh):
		_loadout.changed.disconnect(_refresh)
	_take_buttons.clear()
	if _root != null:
		_root.queue_free()
		_root = null


func is_open() -> bool:
	return _root != null


## Is there somewhere for [param item] to go: a free matching hardpoint or a free hold cell?
func has_room_for(item: ItemInstance) -> bool:
	if _loadout.free_cargo_slots() > 0:
		return true
	for i in _loadout.slots.size():
		if _loadout.slots[i] == null and _loadout.can_accept(ShipLoadout.Kind.SLOT, i, item):
			return true
	return false


## Takes offer [param index]. Returns false (changing nothing) if there is no room for it.
func take(index: int) -> bool:
	if index < 0 or index >= _offers.size() or not has_room_for(_offers[index]):
		return false
	var item := _offers[index]
	if _loadout.equip_auto(item) < 0:
		_loadout.add_to_cargo(item)
	_close(item)
	return true


func skip() -> void:
	_close(null)


func _close(taken: ItemInstance) -> void:
	hide_screen()
	finished.emit(taken)


func _refresh() -> void:
	for i in _take_buttons.size():
		var fits := has_room_for(_offers[i])
		_take_buttons[i].disabled = not fits
		_take_buttons[i].text = "Take" if fits else "Hold full"
	if _hold_label != null:
		_hold_label.text = "Hold  %d / %d" % [_loadout.cargo_count(), _loadout.cargo.size()]


func _build() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)
	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.02, 0.92)  # Dense enough to hide the HUD bars behind the cards.
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(center)
	var column := VBoxContainer.new()
	column.add_theme_constant_override(&"separation", 10)
	center.add_child(column)

	column.add_child(_label("SALVAGE", Color(1.0, 0.85, 0.4), 34))

	var cards := HBoxContainer.new()
	cards.add_theme_constant_override(&"separation", 16)
	cards.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_child(cards)
	for i in _offers.size():
		var card := VBoxContainer.new()
		card.add_theme_constant_override(&"separation", 8)
		cards.add_child(card)
		var tooltip := ItemTooltip.build(_offers[i])
		tooltip.size_flags_vertical = Control.SIZE_EXPAND_FILL  # Equal-height cards, buttons in a line.
		card.add_child(tooltip)
		var button := Button.new()
		button.custom_minimum_size = Vector2(160.0, 38.0)
		button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		button.pressed.connect(take.bind(i))
		card.add_child(button)
		_take_buttons.append(button)

	var footer := HBoxContainer.new()
	footer.alignment = BoxContainer.ALIGNMENT_CENTER
	footer.add_theme_constant_override(&"separation", 16)
	column.add_child(footer)
	_hold_label = _label("", Color(0.9, 0.9, 0.9), 15)
	_hold_label.custom_minimum_size.x = 90.0
	footer.add_child(_hold_label)
	footer.add_child(_button("Refit  (I)", func() -> void: refit_pressed.emit()))
	var skip_button := _button("Skip", skip)
	footer.add_child(skip_button)
	if not _take_buttons.is_empty():
		_take_buttons[0].grab_focus.call_deferred()
	else:
		skip_button.grab_focus.call_deferred()


func _button(text: String, handler: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(120.0, 36.0)
	button.pressed.connect(handler)
	return button


func _label(text: String, color: Color, size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_color_override(&"font_color", color)
	label.add_theme_font_size_override(&"font_size", size)
	return label
