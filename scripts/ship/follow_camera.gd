class_name FollowCamera
extends Node3D
## Steep top-down battle camera. North-up (it never rotates with the ship), smoothly
## follows its target and drifts a little way ahead of where the target is heading.
## add_trauma() shakes it (HitFeel calls it on big hits); the shake fades on its own.

@export var target: Node3D
@export var height: float = 32.0
## Camera pitch in degrees: 90 looks straight down, lower tilts toward the horizon.
@export_range(50.0, 90.0, 1.0) var pitch_deg: float = 80.0
@export var follow_speed: float = 6.0
## Seconds of the target's velocity to look ahead by.
@export var lookahead: float = 0.35

## Metres of offset at full trauma.
@export var max_shake: float = 1.1
## Trauma lost per second.
@export var shake_decay: float = 2.2

var camera: Camera3D
## 0..1. The shake offset grows with its square, so small knocks stay subtle.
var trauma: float = 0.0

var _shake_time: float = 0.0


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


## Adds shake (0..1, capped at 1 in total).
func add_trauma(amount: float) -> void:
	trauma = clampf(trauma + amount, 0.0, 1.0)


func _process(delta: float) -> void:
	if trauma <= 0.0:
		camera.h_offset = 0.0
		camera.v_offset = 0.0
		return
	_shake_time += delta * 40.0
	var strength := trauma * trauma * max_shake
	camera.h_offset = sin(_shake_time * 1.3) * cos(_shake_time * 0.7) * strength
	camera.v_offset = sin(_shake_time * 0.9 + 1.7) * strength
	trauma = maxf(trauma - shake_decay * delta, 0.0)


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
