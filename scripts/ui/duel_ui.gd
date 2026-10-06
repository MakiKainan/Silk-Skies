class_name DuelUI
extends CanvasLayer
## Everything on screen in a duel besides the HUD: the enemy preview before the fight, the enemy's
## health bar, banners ("FIGHT!", boss phase changes) and the result screen. Pure UI: it reports
## button presses through signals and the Duel scene decides what they do.

signal fight_pressed
signal refit_pressed
signal next_pressed
signal retry_pressed
signal menu_pressed
signal new_run_pressed

const MODE_NAMES := ["auto", "manual", "lock-on"]

var _preview: Control
var _result: Control
var _banner: Label
var _enemy_box: Control
var _enemy_name: Label
var _enemy_shield: Range
var _enemy_hull: Range
var _enemy_ship: Ship
var _banner_token := 0


func _ready() -> void:
	layer = 15
	process_mode = Node.PROCESS_MODE_ALWAYS  # Works while the game is paused behind the overlays.
	_build_banner()
	_build_enemy_bar()


func bind_enemy(ship: Ship, enemy: EnemyData) -> void:
	_enemy_ship = ship
	_enemy_name.text = enemy.display_name.to_upper()
	_build_enemy_bars(enemy.is_boss)
	_enemy_box.visible = true


func _process(_delta: float) -> void:
	if _enemy_ship != null and is_instance_valid(_enemy_ship):
		_enemy_shield.value = _enemy_ship.health.shield_fraction()
		_enemy_hull.value = _enemy_ship.health.hull_fraction()


# --- Banner --------------------------------------------------------------------------

func show_banner(text: String, seconds: float = 2.5) -> void:
	_banner.text = text
	_banner.visible = text != ""
	_banner_token += 1
	var token := _banner_token
	if seconds > 0.0 and text != "":
		await get_tree().create_timer(seconds, true).timeout
		if token == _banner_token:
			_banner.visible = false


# --- Preview -------------------------------------------------------------------------

func show_preview(enemy: EnemyData, index: int, total: int) -> void:
	hide_preview()
	_preview = _overlay()
	var box := _panel_box(_preview, 560.0)
	box.add_child(_label("DUEL %d / %d" % [index + 1, total], Color(1, 1, 1, 0.5), 14))
	box.add_child(_label(enemy.display_name.to_upper(), Color(1.0, 0.45, 0.35) if enemy.is_boss else Color.WHITE, 30))
	box.add_child(_wrapped(enemy.description, Color(1, 1, 1, 0.75), 14))
	box.add_child(HSeparator.new())

	var hull := enemy.hull
	box.add_child(_label("Hull %d     Shield %d     Armor %s     Speed %d" % [hull.max_hull, hull.max_shield, "%.0f" % hull.armor, hull.max_speed], Color(0.9, 0.9, 0.9), 15))
	if enemy.ai_profile != null:
		box.add_child(_label("Style: %s" % enemy.ai_profile.display_name, Color(1.0, 0.85, 0.4), 14))
		box.add_child(_wrapped(enemy.ai_profile.description, Color(1, 1, 1, 0.6), 13))
	box.add_child(_label("Weapons", Color(1, 1, 1, 0.5), 12))
	for spec in enemy.loadout:
		if spec.item == null:
			continue
		var line := spec.item.display_name
		if spec.item is WeaponData:
			line += "   (%s, %s)" % [MODE_NAMES[(spec.item as WeaponData).targeting], "large" if spec.item.slot_size() == HardpointData.Size.LARGE else "small"]
		var row := HBoxContainer.new()
		var picture := UiArt.icon_rect(ArtLookup.item_icon(spec.item), 32.0)
		if picture != null:
			row.add_child(picture)
		row.add_child(_label(line, Rarity.color(spec.rarity), 15))
		box.add_child(row)
	if enemy.is_boss:
		box.add_child(_label("Changes tactics when badly hurt.", Color(1.0, 0.45, 0.35), 13))
	box.add_child(HSeparator.new())

	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override(&"separation", 16)
	box.add_child(buttons)
	buttons.add_child(_button("Refit  (I)", func() -> void: refit_pressed.emit()))
	var fight := _button("FIGHT", func() -> void: fight_pressed.emit())
	fight.custom_minimum_size.x = 160.0
	buttons.add_child(fight)
	fight.grab_focus.call_deferred()


func hide_preview() -> void:
	if _preview != null:
		_preview.queue_free()
		_preview = null


# --- Result --------------------------------------------------------------------------

## [param next_available]: another duel follows. [param act_complete]: this was the last one.
## [param original]: a real run, where a defeat ends the run ("RUN OVER": New run / Main menu)
## instead of offering a retry, and the way out is the main menu rather than the sandbox.
func show_result(result: DuelResult, next_available: bool, act_complete: bool, original: bool = false) -> void:
	hide_result()
	_result = _overlay()
	var box := _panel_box(_result, 460.0)
	var run_over := original and not result.won
	var headline := "VICTORY" if result.won else ("RUN OVER" if run_over else "DEFEAT")
	var title := _label(headline, Color(0.4, 1.0, 0.5) if result.won else Color(1.0, 0.4, 0.35), 34)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	if act_complete:
		var done := _label("GAUNTLET COMPLETE", Color(1.0, 0.85, 0.4), 18)
		done.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(done)
	box.add_child(HSeparator.new())
	box.add_child(_label("vs %s" % result.enemy.display_name, Color.WHITE, 16))
	box.add_child(_label("Duel time      %d:%02d" % [int(result.seconds) / 60, int(result.seconds) % 60], Color(0.9, 0.9, 0.9), 15))
	box.add_child(_label("Damage dealt   %d" % roundi(result.damage_dealt), Color(0.9, 0.9, 0.9), 15))
	box.add_child(_label("Damage taken   %d" % roundi(result.damage_taken), Color(0.9, 0.9, 0.9), 15))
	box.add_child(HSeparator.new())

	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override(&"separation", 12)
	box.add_child(buttons)
	var primary: Button
	if run_over or (original and not next_available):
		primary = _button("New run", func() -> void: new_run_pressed.emit())
	else:
		buttons.add_child(_button("Refit  (I)", func() -> void: refit_pressed.emit()))
		if result.won and next_available:
			primary = _button("Next duel", func() -> void: next_pressed.emit())
		elif result.won:
			primary = _button("Restart gauntlet", func() -> void: retry_pressed.emit())
		else:
			primary = _button("Retry", func() -> void: retry_pressed.emit())
	buttons.add_child(primary)
	buttons.add_child(_button("Main menu" if original else "Sandbox", func() -> void: menu_pressed.emit()))
	primary.grab_focus.call_deferred()


func hide_result() -> void:
	if _result != null:
		_result.queue_free()
		_result = null


# --- Building blocks ----------------------------------------------------------------------

func _overlay() -> Control:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(root)
	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.02, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(dim)
	return root


func _panel_box(root: Control, width: float) -> VBoxContainer:
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size.x = width
	panel.add_theme_stylebox_override(&"panel", ItemVisuals.panel_style())
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override(&"separation", 6)
	panel.add_child(box)
	return box


func _build_banner() -> void:
	_banner = Label.new()
	_banner.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_banner.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_banner.position.y = 230.0
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.add_theme_font_size_override(&"font_size", 40)
	_banner.add_theme_color_override(&"font_color", Color(1.0, 0.85, 0.4))
	_banner.add_theme_color_override(&"font_outline_color", Color.BLACK)
	_banner.add_theme_constant_override(&"outline_size", 10)
	_banner.visible = false
	_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_banner)


func _build_enemy_bar() -> void:
	_enemy_box = VBoxContainer.new()
	_enemy_box.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_enemy_box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_enemy_box.position.y = 14.0
	_enemy_box.visible = false
	_enemy_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_enemy_box)
	_enemy_name = _label("", Color.WHITE, 16)
	_enemy_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_enemy_box.add_child(_enemy_name)
	_build_enemy_bars(false)


## (Re)builds the enemy's two bars. A boss gets the big ornate frame; anyone else gets the
## plain bar art, shield over hull. Without bar art both are flat ProgressBars.
func _build_enemy_bars(boss: bool) -> void:
	for bar in [_enemy_hull, _enemy_shield]:
		if bar != null:
			bar.queue_free()
	var red := Color(0.9, 0.25, 0.25)
	var blue := Color(0.3, 0.65, 1.0)
	if boss:
		_enemy_hull = UiArt.make_bar(red, Vector2(440.0, 108.0), true)
		_enemy_shield = UiArt.make_bar(blue, Vector2(380.0, 16.0))
	else:
		_enemy_hull = UiArt.make_bar(red, Vector2(420.0, 20.0))
		_enemy_shield = UiArt.make_bar(blue, Vector2(420.0, 20.0))
	if not _enemy_hull is ArtBar:  # Flat fallback: thin bars, as before.
		_enemy_hull.custom_minimum_size = Vector2(420.0, 10.0)
		_enemy_shield.custom_minimum_size = Vector2(420.0, 10.0)
	_enemy_shield.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_enemy_hull.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	if boss and _enemy_hull is ArtBar:  # The frame sits above; the shield tucks in under it.
		_enemy_box.add_child(_enemy_hull)
		_enemy_box.add_child(_enemy_shield)
	else:
		_enemy_box.add_child(_enemy_shield)
		_enemy_box.add_child(_enemy_hull)


func _button(text: String, handler: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(120.0, 36.0)
	button.pressed.connect(handler)
	return button


func _label(text: String, color: Color, size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_color_override(&"font_color", color)
	label.add_theme_font_size_override(&"font_size", size)
	return label


func _wrapped(text: String, color: Color, size: int) -> Label:
	var label := _label(text, color, size)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size.x = 500.0
	return label
