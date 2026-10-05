class_name FollowCamera
extends Node3D
## Steep top-down battle camera. North-up (it never rotates with the ship), smoothly
## follows its target and drifts a little way ahead of where the target is heading.

@export var target: Node3D
@export var height: float = 32.0
## Camera pitch in degrees: 90 looks straight down, lower tilts toward the horizon.
@export_range(50.0, 90.0, 1.0) var pitch_deg: float = 80.0
@export var follow_speed: float = 6.0
## Seconds of the target's velocity to look ahead by.
@export var lookahead: float = 0.35

var camera: Camera3D


func _ready() -> void:
	camera = Camera3D.new()
	camera.name = "Camera3D"
	camera.current = true
	add_child(camera)
	_place_camera()
	snap_to_target()


## Jumps straight to the target with no smoothing (use after spawning or teleporting).
func snap_to_target() -> void:
	if target != null:
		global_position = _goal()
		reset_physics_interpolation()


func _physics_process(delta: float) -> void:
	_place_camera()
	if target == null:
		return
	global_position = global_position.lerp(_goal(), 1.0 - exp(-follow_speed * delta))


func _place_camera() -> void:
	var pitch := deg_to_rad(pitch_deg)
	camera.position = Vector3(0.0, height * sin(pitch), height * cos(pitch))
	camera.rotation = Vector3(-pitch, 0.0, 0.0)


func _goal() -> Vector3:
	var ahead := Vector3.ZERO
	if target is CharacterBody3D:
		ahead = (target as CharacterBody3D).velocity * lookahead
	return Vector3(target.global_position.x + ahead.x, 0.0, target.global_position.z + ahead.z)
