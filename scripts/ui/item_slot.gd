class_name ItemSlot
extends PanelContainer
## One cell in the refit screen: a hardpoint slot, a cargo cell, or the discard bin.
## Drag an item off it and drop it on another cell; cells light up green when the dragged
## item fits and dim when it can't go there. The rules live in ShipLoadout.

const EMPTY_FILL := Color(0.09, 0.1, 0.14)

var loadout: ShipLoadout
var kind: ShipLoadout.Kind = ShipLoadout.Kind.CARGO
var index: int = 0
## Discard bin: accepts any item from any cell and deletes it.
var is_trash: bool = false
var empty_tooltip: String = ""
var empty_color: Color = Color(0.4, 0.4, 0.45)

var _badge: Label
var _tag: Label


func setup(p_loadout: ShipLoadout, p_kind: ShipLoadout.Kind, p_index: int, p_empty_color: Color, p_empty_tooltip: String) -> void:
	loadout = p_loadout
	kind = p_kind
	index = p_index
	empty_color = p_empty_color
	empty_tooltip = p_empty_tooltip
	custom_minimum_size = ItemVisuals.SLOT_SIZE
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(box)
	_badge = Label.new()
	_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_badge.add_theme_font_size_override(&"font_size", 24)
	_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(_badge)
	_tag = Label.new()
	_tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tag.add_theme_font_size_override(&"font_size", 11)
	_tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(_tag)
	refresh()


func item() -> ItemInstance:
	return null if is_trash else loadout.get_item(kind, index)


func refresh() -> void:
	modulate = Color.WHITE
	var current := item()
	if is_trash:
		_badge.text = "X"
		_tag.text = "discard"
		add_theme_stylebox_override(&"panel", ItemVisuals.slot_style(Color(0.7, 0.3, 0.3), EMPTY_FILL))
		tooltip_text = "Drop an item here to discard it"
		return
	if current == null:
		_badge.text = ""
		_tag.text = "empty"
		_tag.modulate = Color(1, 1, 1, 0.4)
		add_theme_stylebox_override(&"panel", ItemVisuals.slot_style(empty_color.darkened(0.35), EMPTY_FILL, 2))
		tooltip_text = empty_tooltip
		return
	var data := current.data()
	_badge.text = ItemVisuals.badge(data)
	_tag.text = Rarity.display_name(current.rarity)
	_tag.modulate = Rarity.color(current.rarity)
	var category := ItemVisuals.category_color(data.slot_type())
	add_theme_stylebox_override(&"panel", ItemVisuals.slot_style(Rarity.color(current.rarity), category.darkened(0.6)))
	tooltip_text = data.display_name  # Any non-empty text triggers _make_custom_tooltip.


func _make_custom_tooltip(_for_text: String) -> Object:
	var current := item()
	return ItemTooltip.build(current) if current != null else null


# --- Drag and drop -------------------------------------------------------------------

func _get_drag_data(_at_position: Vector2) -> Variant:
	var current := item()
	if current == null:
		return null
	var preview := PanelContainer.new()
	preview.add_theme_stylebox_override(&"panel", ItemVisuals.slot_style(Rarity.color(current.rarity), ItemVisuals.category_color(current.data().slot_type()).darkened(0.4)))
	var label := Label.new()
	label.text = current.display_name()
	preview.add_child(label)
	if get_viewport().gui_is_dragging():  # False only when called by hand, as the tests do.
		set_drag_preview(preview)
	else:
		preview.free()
	return {"loadout": loadout, "kind": kind, "index": index}


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if not _is_ours(data):
		return false
	if is_trash:
		return loadout.get_item(data.kind, data.index) != null
	return loadout.can_move(data.kind, data.index, kind, index)


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	if is_trash:
		loadout.take(data.kind, data.index)
	else:
		loadout.move(data.kind, data.index, kind, index)


func _is_ours(data: Variant) -> bool:
	return data is Dictionary and data.get("loadout") == loadout and data.has("kind") and data.has("index")


func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_BEGIN:
		var data: Variant = get_viewport().gui_get_drag_data()
		if _is_ours(data):
			var is_source: bool = not is_trash and data.kind == kind and data.index == index
			if is_source:
				return
			if _can_drop_data(Vector2.ZERO, data):
				add_theme_stylebox_override(&"panel", ItemVisuals.slot_style(Color(0.3, 1.0, 0.45), Color(0.12, 0.25, 0.16), 4))
			else:
				modulate = Color(1, 1, 1, 0.4)
	elif what == NOTIFICATION_DRAG_END:
		if loadout != null:
			refresh()
