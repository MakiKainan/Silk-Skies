class_name TuningPanel
extends CanvasLayer
## Sandbox tool: live sliders for the bound ship's base stats. Changes only touch the
## ship's StatsComponent, never the HullData resource. "Print values" outputs them in
## .tres form (to the console and clipboard) so good numbers can be pasted into the hull.

## [stat, label, min, max, step]
const ROWS := [
	[Stats.MASS, "mass", 20.0, 400.0, 1.0],
	[Stats.THRUST, "thrust", 200.0, 4000.0, 10.0],
	[Stats.MAX_SPEED, "max_speed", 5.0, 50.0, 0.5],
	[Stats.TURN_RATE, "turn_rate", 30.0, 360.0, 1.0],
	[Stats.DRAG, "drag", 0.0, 2.0, 0.01],
	[Stats.LATERAL_GRIP, "lateral_grip", 0.0, 10.0, 0.1],
	[Stats.BURN_IMPULSE, "burn_impulse", 0.0, 60.0, 0.5],
	[Stats.BURN_COOLDOWN, "burn_cooldown", 0.5, 10.0, 0.1],
]

var _ship: Ship
var _sliders: Dictionary = {}  # StringName -> HSlider
var _value_labels: Dictionary = {}  # StringName -> Label
var _derived: Label
var _syncing := false


func _ready() -> void:
	layer = 10
	visible = false

	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	var panel := PanelContainer.new()
	root.add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT, Control.PRESET_MODE_MINSIZE, 16)
	panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN

	var box := VBoxContainer.new()
	panel.add_child(box)
	var title := Label.new()
	title.text = "Sailing tuning (F1 to hide)"
	box.add_child(title)

	for row: Array in ROWS:
		var stat: StringName = row[0]
		var line := HBoxContainer.new()
		box.add_child(line)
		var name_label := Label.new()
		name_label.text = row[1]
		name_label.custom_minimum_size.x = 110.0
		line.add_child(name_label)
		var slider := HSlider.new()
		slider.min_value = row[2]
		slider.max_value = row[3]
		slider.step = row[4]
		slider.custom_minimum_size = Vector2(170.0, 20.0)
		slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		slider.focus_mode = Control.FOCUS_NONE  # Keep the keyboard on the ship.
		slider.value_changed.connect(_on_slider_changed.bind(stat))
		line.add_child(slider)
		var value_label := Label.new()
		value_label.custom_minimum_size.x = 56.0
		line.add_child(value_label)
		_sliders[stat] = slider
		_value_labels[stat] = value_label

	_derived = Label.new()
	_derived.modulate = Color(1.0, 1.0, 1.0, 0.7)
	box.add_child(_derived)

	var buttons := HBoxContainer.new()
	box.add_child(buttons)
	buttons.add_child(_make_button("Reset to hull", _on_reset))
	buttons.add_child(_make_button("Print values", _on_print))


func bind(ship: Ship) -> void:
	_ship = ship
	if not ship.hull_changed.is_connected(_on_hull_changed):
		ship.hull_changed.connect(_on_hull_changed)
	_refresh()


func toggle() -> void:
	visible = not visible


func _make_button(text: String, handler: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(handler)
	return button


func _on_hull_changed(_hull: HullData) -> void:
	_refresh()


func _refresh() -> void:
	if _ship == null or _ship.hull == null:
		return
	_syncing = true
	for stat: StringName in _sliders:
		(_sliders[stat] as HSlider).value = _ship.stats.base_stat(stat)
	_syncing = false
	_update_labels()


func _update_labels() -> void:
	for stat: StringName in _sliders:
		(_value_labels[stat] as Label).text = "%.2f" % _ship.stats.base_stat(stat)
	var accel := _ship.stats.base_stat(Stats.THRUST) / maxf(_ship.stats.base_stat(Stats.MASS), 0.001)
	var drag := _ship.stats.base_stat(Stats.DRAG)
	var terminal := accel / drag if drag > 0.0 else INF
	_derived.text = "accel %.1f m/s^2   thrust-vs-drag top speed %.1f m/s\n(ship tops out at the lower of that and max_speed)" % [accel, terminal]


func _on_slider_changed(value: float, stat: StringName) -> void:
	if _syncing or _ship == null:
		return
	_ship.stats.set_base_stat(stat, value)
	_update_labels()


func _on_reset() -> void:
	if _ship != null and _ship.hull != null:
		_ship.refresh_stats()
		_refresh()


func _on_print() -> void:
	if _ship == null or _ship.hull == null:
		return
	var lines := PackedStringArray()
	for row: Array in ROWS:
		lines.append("%s = %s" % [row[1], snappedf(_ship.stats.base_stat(row[0]), 0.001)])
	var text := "\n".join(lines)
	DisplayServer.clipboard_set(text)
	print("--- tuned values for %s (copied to clipboard) ---\n%s" % [_ship.hull.id, text])
