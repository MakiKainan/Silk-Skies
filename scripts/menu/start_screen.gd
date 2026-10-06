class_name StartScreen
extends Control
## The title screen and the project's main scene: Original starts a real run (the reward loop),
## Debug opens the sandbox, Quit leaves.

const DUEL_SCENE := "res://scenes/duel/duel.tscn"
const SANDBOX_SCENE := "res://scenes/debug/sandbox.tscn"
const DEFAULT_ACT_ID := &"slice_act"

## Tests turn this off so pressing a button doesn't swap the test runner's scene.
var change_scenes: bool = true

var _original_button: Button


func _ready() -> void:
	_build()
	_original_button.grab_focus.call_deferred()


## Begins a fresh run of the slice act in Original mode and heads to the first duel.
func start_original() -> void:
	RunState.new_run(ContentDB.get_by_id(DEFAULT_ACT_ID) as ActData)
	_go(DUEL_SCENE)


## Opens the debug sandbox with a fresh roomy hold.
func start_debug() -> void:
	RunState.start_debug()
	_go(SANDBOX_SCENE)


func quit() -> void:
	if change_scenes:
		get_tree().quit()


func _go(path: String) -> void:
	if change_scenes:
		get_tree().change_scene_to_file(path)


func _build() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var background := ColorRect.new()
	background.color = Color(0.015, 0.02, 0.04)
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size.x = 420.0
	panel.add_theme_stylebox_override(&"panel", ItemVisuals.panel_style())
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override(&"separation", 12)
	panel.add_child(box)

	box.add_child(_spacer(6.0))
	var title := _label("SILK SKIES", Color(1.0, 0.85, 0.4), 44)
	box.add_child(title)
	var subtitle := _label("a ship-duel roguelite", Color(1, 1, 1, 0.5), 14)
	box.add_child(subtitle)
	box.add_child(HSeparator.new())

	_original_button = _button("Original", start_original)
	box.add_child(_original_button)
	box.add_child(_hint("A run through the gauntlet: win duels, pick salvage."))
	box.add_child(_button("Debug", start_debug))
	box.add_child(_hint("The sandbox: spawn bots, swap hulls, tune."))
	box.add_child(_button("Quit", quit))
	box.add_child(_spacer(6.0))


func _spacer(height: float) -> Control:
	var spacer := Control.new()
	spacer.custom_minimum_size.y = height
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return spacer


func _button(text: String, handler: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(240.0, 44.0)
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	button.pressed.connect(handler)
	return button


func _label(text: String, color: Color, size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_color_override(&"font_color", color)
	label.add_theme_font_size_override(&"font_size", size)
	return label


func _hint(text: String) -> Label:
	var label := _label(text, Color(1, 1, 1, 0.45), 12)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label
