class_name SandboxPanel
extends CanvasLayer
## F2 debug panel: swap the player's hull, spawn items into the cargo hold, spawn dummies and bots, and flip the
## god-mode / bots-fire / show-arcs switches. Pure UI: every action calls into the Sandbox.

var _sandbox: Node
var _hull_picker: OptionButton
var _item_picker: OptionButton
var _rarity_picker: OptionButton
var _items: Array[ItemData] = []
var _enemy_picker: OptionButton
var _enemies: Array[EnemyData] = []


func _ready() -> void:
	layer = 10
	visible = false

	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	var panel := PanelContainer.new()
	root.add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT, Control.PRESET_MODE_MINSIZE, 16)
	panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	panel.grow_vertical = Control.GROW_DIRECTION_BEGIN

	var box := VBoxContainer.new()
	panel.add_child(box)
	var title := Label.new()
	title.text = "Sandbox (F2 to hide)"
	box.add_child(title)

	_hull_picker = OptionButton.new()
	_hull_picker.focus_mode = Control.FOCUS_NONE
	_hull_picker.item_selected.connect(func(i: int) -> void: _sandbox.set_player_hull(i))
	box.add_child(_labelled("Player hull", _hull_picker))

	box.add_child(HSeparator.new())
	_item_picker = OptionButton.new()
	_item_picker.focus_mode = Control.FOCUS_NONE
	box.add_child(_labelled("Item", _item_picker))
	_rarity_picker = OptionButton.new()
	_rarity_picker.focus_mode = Control.FOCUS_NONE
	for rarity in [Rarity.Type.COMMON, Rarity.Type.RARE, Rarity.Type.EPIC]:
		_rarity_picker.add_item(Rarity.display_name(rarity))
	box.add_child(_labelled("Rarity", _rarity_picker))
	var item_row := HBoxContainer.new()
	box.add_child(item_row)
	item_row.add_child(_button("Add to cargo", func() -> void: _add_selected_item()))
	item_row.add_child(_button("Random item", func() -> void: _sandbox.spawn_random_item()))
	item_row.add_child(_button("Open refit (I)", func() -> void: _sandbox.open_inventory()))
	box.add_child(HSeparator.new())

	_enemy_picker = OptionButton.new()
	_enemy_picker.focus_mode = Control.FOCUS_NONE
	box.add_child(_labelled("Enemy", _enemy_picker))
	var enemy_row := HBoxContainer.new()
	box.add_child(enemy_row)
	enemy_row.add_child(_button("Spawn enemy", func() -> void: _spawn_selected_enemy()))
	enemy_row.add_child(_button("Start gauntlet", func() -> void: _sandbox.start_gauntlet()))
	box.add_child(HSeparator.new())

	var spawn_row := HBoxContainer.new()
	box.add_child(spawn_row)
	spawn_row.add_child(_button("Spawn dummy", func() -> void: _sandbox.spawn_dummy()))
	spawn_row.add_child(_button("Spawn bot", func() -> void: _sandbox.spawn_bot()))
	spawn_row.add_child(_button("Clear", func() -> void: _sandbox.clear_enemies()))
	spawn_row.add_child(_button("Main menu", func() -> void: _sandbox.back_to_menu()))

	box.add_child(_toggle("God mode (player)", func(on: bool) -> void: _sandbox.set_god_mode(on)))
	box.add_child(_toggle("Bots fire", func(on: bool) -> void: _sandbox.set_bots_fire(on), true))
	box.add_child(_toggle("Show firing arcs", func(on: bool) -> void: _sandbox.set_show_arcs(on)))


func bind(sandbox: Node) -> void:
	_sandbox = sandbox
	_hull_picker.clear()
	for hull: HullData in sandbox.hulls:
		_hull_picker.add_item(hull.display_name)
	_enemies = ContentDB.enemies()
	for enemy in _enemies:
		_enemy_picker.add_item(enemy.display_name)
	_items = ContentDB.items()
	for item in _items:
		_item_picker.add_item("%s: %s" % [item.category_name(), item.display_name])
	sync_hull()


func toggle() -> void:
	visible = not visible


## Points the hull picker at the player's current hull.
func sync_hull() -> void:
	if _sandbox == null or _sandbox.player == null or _sandbox.player.hull == null:
		return
	_hull_picker.select(_sandbox.hulls.find(_sandbox.player.hull))


func _spawn_selected_enemy() -> void:
	if _enemy_picker.selected >= 0:
		_sandbox.spawn_enemy(_enemies[_enemy_picker.selected])


func _add_selected_item() -> void:
	if _item_picker.selected < 0:
		return
	_sandbox.spawn_item(_items[_item_picker.selected], _rarity_picker.selected as Rarity.Type)


func _labelled(text: String, control: Control) -> HBoxContainer:
	var row := HBoxContainer.new()
	var label := Label.new()
	label.text = text
	label.custom_minimum_size.x = 150.0
	row.add_child(label)
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(control)
	return row


func _button(text: String, handler: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(handler)
	return button


func _toggle(text: String, handler: Callable, initial: bool = false) -> CheckButton:
	var check := CheckButton.new()
	check.text = text
	check.focus_mode = Control.FOCUS_NONE
	check.button_pressed = initial
	check.toggled.connect(handler)
	return check
