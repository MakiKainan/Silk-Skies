class_name PlayerInput
extends Node
## Controller: turns keyboard + mouse into Ship commands. Add as a child of the Ship.
## W/S throttle, A/D steer, Shift Hard Burn (the held keys pick its direction), mouse aims.

var _ship: Ship


func _ready() -> void:
	_ship = get_parent() as Ship
	assert(_ship != null, "PlayerInput must be a child of a Ship")


func _physics_process(_delta: float) -> void:
	var steer := Input.get_axis(&"turn_left", &"turn_right")
	var drive := Input.get_axis(&"thrust_back", &"thrust_fwd")
	_ship.set_throttle(drive)
	_ship.set_turn(steer)
	if Input.is_action_just_pressed(&"hard_burn"):
		_ship.request_hard_burn(Vector2(steer, drive))

	var camera := get_viewport().get_camera_3d()
	if camera != null:
		var point: Variant = MouseAim.ground_point(camera, get_viewport().get_mouse_position())
		if point != null:
			_ship.aim_at(point)
