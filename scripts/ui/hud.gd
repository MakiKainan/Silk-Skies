class_name Hud
extends CanvasLayer
## Sandbox HUD: the tracked ship's speed, effective turn rate and Hard Burn cooldown.

var _ship: Ship
var _info: Label
var _burn_bar: ProgressBar


func _ready() -> void:
	var box := VBoxContainer.new()
	box.position = Vector2(16.0, 16.0)
	add_child(box)

	_info = _make_label()
	box.add_child(_info)

	_burn_bar = ProgressBar.new()
	_burn_bar.custom_minimum_size = Vector2(220.0, 12.0)
	_burn_bar.max_value = 1.0
	_burn_bar.show_percentage = false
	box.add_child(_burn_bar)

	var help := _make_label()
	help.text = "\nW/S thrust   A/D steer   mouse aims\nShift = Hard Burn (hold W/A/S/D to pick direction)\n1/2/3 hull   B spawn bot   X clear bots   R reset\n[ ] time scale   \\ reset time   F1 tuning panel   wheel zoom"
	help.modulate = Color(1.0, 1.0, 1.0, 0.65)
	box.add_child(help)


func track(ship: Ship) -> void:
	_ship = ship


func _process(_delta: float) -> void:
	if _ship == null or _ship.hull == null:
		return
	var move := _ship.movement
	var stats := _ship.stats
	_info.text = "%s\nspeed  %5.1f / %.0f m/s\nturn   %5.1f / %.0f deg/s\nhard burn  %s%s" % [
		_ship.hull.display_name,
		move.speed(),
		stats.get_stat(Stats.MAX_SPEED),
		move.effective_turn_rate_deg(),
		stats.get_stat(Stats.TURN_RATE),
		"READY" if move.burn_ready_fraction() >= 1.0 else "cooling",
		"" if Engine.time_scale == 1.0 else "\ntime scale x%.2f" % Engine.time_scale,
	]
	_burn_bar.value = move.burn_ready_fraction()


func _make_label() -> Label:
	var label := Label.new()
	label.add_theme_color_override(&"font_outline_color", Color.BLACK)
	label.add_theme_constant_override(&"outline_size", 4)
	return label
