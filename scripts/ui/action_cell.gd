class_name ActionCell
extends PanelContainer
## One icon on the action bar: a rarity-framed item (or the Hard Burn glyph) with a radial
## cooldown sweep over it, the seconds left, a key tag and a hover tooltip. It knows nothing about
## ships: set the fields, add it to the tree, and it polls the callables each frame.
##
## [member fraction] returns 0..1 (1 = ready). Leave it invalid for an action that has no runtime
## yet; set [member dimmed] to grey the cell out in that case.

const CELL_SIZE := 64.0
const SWEEP_COLOR := Color(0.0, 0.0, 0.05, 0.62)
const RING_COLOR := Color(1.0, 0.85, 0.3)
const DIMMED := Color(0.62, 0.62, 0.68, 0.8)

## Icon art; without it the [member badge] letters stand in.
var icon: Texture2D
var badge: String = ""
## Frame colour (the item's rarity colour).
var frame_color: Color = Color(0.78, 0.78, 0.8)
var frame_fill: Color = Color(0.1, 0.11, 0.14)
## "LMB", "Q", ... Empty = no key tag.
var key_text: String = ""
## Small glyph in the top-left corner (a weapon's damage type).
var corner_icon: Texture2D
var corner_tint: Color = Color.WHITE
## The item shown in the tooltip, or null to use [member title] and [member description].
var item: ItemInstance
var title: String = ""
var description: String = ""
## Extra last line in the tooltip ("Active not online yet").
var note: String = ""
var dimmed: bool = false
var fraction: Callable = Callable()
## Returns the status word of the action: "cooling", "charging", "locking", "LOCKED" or "ready".
var status: Callable = Callable()
## Returns the seconds left on the cooldown (0 = none).
var seconds: Callable = Callable()

var _sweep: Control
var _seconds_label: Label
var _shown_fraction: float = 1.0
var _shown_ring: bool = false


func _ready() -> void:
	custom_minimum_size = Vector2(CELL_SIZE, CELL_SIZE)
	add_theme_stylebox_override(&"panel", ItemVisuals.slot_style(frame_color, frame_fill))
	mouse_filter = Control.MOUSE_FILTER_STOP
	tooltip_text = title if title != "" else (item.display_name() if item != null else "Action")

	if icon != null:
		add_child(UiArt.icon_rect(icon, CELL_SIZE - 12.0))
	else:
		var letters := _text(badge, 20, Color.WHITE)
		letters.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		letters.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		add_child(letters)
	if corner_icon != null:
		var corner := UiArt.icon_rect(corner_icon, 16.0, corner_tint)
		corner.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		corner.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		add_child(corner)

	_sweep = Control.new()
	_sweep.clip_contents = true
	_sweep.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sweep.draw.connect(_draw_sweep)
	add_child(_sweep)

	_seconds_label = _text("", 16, Color.WHITE)
	_seconds_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_seconds_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(_seconds_label)

	if key_text != "":
		var key := _text(key_text, 11, Color(1.0, 0.92, 0.6))
		key.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		key.size_flags_vertical = Control.SIZE_SHRINK_END
		add_child(key)
	if dimmed:
		modulate = DIMMED
	_poll()


func _process(_delta: float) -> void:
	_poll()


## The cooldown fraction the cell is currently showing (0..1, 1 = ready).
func shown_fraction() -> float:
	return _shown_fraction


## True while the action is building up rather than cooling (a charge or a lock).
func is_building() -> bool:
	return _shown_ring


func _poll() -> void:
	var ready_fraction := clampf(float(fraction.call()), 0.0, 1.0) if fraction.is_valid() else 1.0
	var word: String = str(status.call()) if status.is_valid() else "ready"
	var building := word == "charging" or word == "locking"
	var left := float(seconds.call()) if seconds.is_valid() else 0.0
	_seconds_label.text = "%.1f" % left if left > 0.05 and not building else ""
	if not is_equal_approx(ready_fraction, _shown_fraction) or building != _shown_ring:
		_shown_fraction = ready_fraction
		_shown_ring = building
		_sweep.queue_redraw()


func _draw_sweep() -> void:
	var size_now := _sweep.size
	var center := size_now * 0.5
	if _shown_ring:
		# A charge or a lock: a bright ring fills clockwise as it builds.
		_sweep.draw_arc(center, minf(size_now.x, size_now.y) * 0.5 - 2.0, -PI * 0.5, -PI * 0.5 + TAU * _shown_fraction, 40, RING_COLOR, 3.0, true)
		return
	if _shown_fraction >= 1.0:
		return
	# The not-ready part is a dark pie that shrinks clockwise from 12 o'clock as the action recharges.
	var start := -PI * 0.5 + TAU * _shown_fraction
	var end := PI * 1.5
	var radius := size_now.length()
	var points := PackedVector2Array([center])
	var steps := maxi(int((end - start) / TAU * 48.0), 2)
	for i in steps + 1:
		var angle := start + (end - start) * float(i) / float(steps)
		points.append(center + Vector2(cos(angle), sin(angle)) * radius)
	_sweep.draw_colored_polygon(points, SWEEP_COLOR)


func _make_custom_tooltip(_for_text: String) -> Object:
	var card: Control
	var box: VBoxContainer
	if item != null:
		card = ItemTooltip.build(item)
		box = card.get_child(0) as VBoxContainer
	else:
		var panel := PanelContainer.new()
		panel.custom_minimum_size.x = ItemTooltip.WIDTH
		panel.add_theme_stylebox_override(&"panel", ItemVisuals.panel_style())
		box = VBoxContainer.new()
		panel.add_child(box)
		box.add_child(_text(title, 18, frame_color))
		if description != "":
			var body := _text(description, 13, Color(1, 1, 1, 0.7))
			body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			body.custom_minimum_size.x = ItemTooltip.WIDTH - 16.0
			box.add_child(body)
		card = panel
	if note != "":
		box.add_child(_text(note, 13, Color(1.0, 0.55, 0.4)))
	return card


func _text(text: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override(&"font_size", size)
	label.add_theme_color_override(&"font_color", color)
	label.add_theme_color_override(&"font_outline_color", Color.BLACK)
	label.add_theme_constant_override(&"outline_size", 5)
	return label
