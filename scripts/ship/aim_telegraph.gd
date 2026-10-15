class_name AimTelegraph
extends MeshInstance3D
## Draws where an enemy weapon is about to fire, flat on the arena floor, so the player can read
## and dodge it. Each weapon has its own look (WeaponData.telegraph):
##   CHARGE_BEAM (Railgun): a line down the aim that starts thick and faint and thins and
##     brightens as the charge builds; it flashes white once the aim is committed.
##   TRACER (Pulse Laser): a short flickering dashed line along the aim.
##   CONE (Autocannon): a translucent wedge as wide as the spread, pulsing with each shot.
##   LOCK (Missile Pod): a dashed line to the ship being locked (the red ring sits on it).
## The player's own railgun shows a faint version of its beam while charging; nothing else of the
## player's is drawn. A WeaponController adds one of these when its weapon has a telegraph.

## Draw height above the floor, just over the arc wedges.
const FLOOR_Y := 0.06
const BEAM_START_WIDTH := 1.6
const BEAM_END_WIDTH := 0.08
## How strong the player's own charge line is compared to an enemy's.
const PLAYER_ALPHA := 0.3
const TRACER_FRACTION := 0.4
const DASH := 1.1
const GAP := 0.7
const CONE_EXTRA_DEG := 2.0
const COMMIT_COLOR := Color(1.0, 1.0, 1.0)

## Sandbox switch: when false no enemy telegraphs are drawn.
static var enemy_telegraphs_enabled: bool = true

var controller: WeaponController
## What the last refresh() drew: NONE when hidden.
var showing: WeaponData.Telegraph = WeaponData.Telegraph.NONE
## The beam width drawn by the last refresh() (CHARGE_BEAM only).
var beam_width: float = 0.0

var _mesh := ImmediateMesh.new()
var _material := StandardMaterial3D.new()
var _shot_pulse: float = 0.0
var _rng := RandomNumberGenerator.new()
var _points := PackedVector3Array()
var _colors := PackedColorArray()


func setup(p_controller: WeaponController) -> void:
	controller = p_controller
	controller.fired.connect(func() -> void: _shot_pulse = 1.0)


func _ready() -> void:
	top_level = true
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_material.vertex_color_use_as_albedo = true
	_material.no_depth_test = false
	mesh = _mesh
	global_transform = Transform3D.IDENTITY


func _process(delta: float) -> void:
	_shot_pulse = maxf(_shot_pulse - delta * 6.0, 0.0)
	refresh()


## Redraws for the weapon's current state. Called every frame; tests call it directly.
func refresh() -> void:
	_mesh.clear_surfaces()
	showing = WeaponData.Telegraph.NONE
	beam_width = 0.0
	if not is_instance_valid(controller) or controller.ship == null or not controller.ship.is_alive():
		return
	global_transform = Transform3D.IDENTITY
	var enemy := controller.ship.team != Ship.TEAM_PLAYER
	if enemy and not enemy_telegraphs_enabled:
		return
	var color := _color()
	match controller.weapon.telegraph:
		WeaponData.Telegraph.CHARGE_BEAM:
			if controller.charge > 0.0:
				_draw_beam(color, 1.0 if enemy else PLAYER_ALPHA)
		WeaponData.Telegraph.TRACER:
			if enemy and _firing():
				_draw_tracer(color)
		WeaponData.Telegraph.CONE:
			if enemy and _firing():
				_draw_cone(color)
		WeaponData.Telegraph.LOCK:
			if enemy and controller.lock_target != null and is_instance_valid(controller.lock_target):
				_draw_lock(color)


func _firing() -> bool:
	return controller.is_trigger_held() and not controller.overheated


func _color() -> Color:
	return controller.weapon.projectile.color if controller.weapon.projectile != null else Color.WHITE


# --- Shapes --------------------------------------------------------------------------

func _draw_beam(color: Color, strength: float) -> void:
	var progress := controller.charge_fraction()
	beam_width = lerpf(BEAM_START_WIDTH, BEAM_END_WIDTH, progress)
	var tint := color
	var alpha := lerpf(0.12, 0.75, progress)
	if controller.aim_committed:
		# Committed: the line stops tracking and flickers white just before the slug.
		tint = COMMIT_COLOR
		alpha = 0.6 + 0.4 * absf(sin(Time.get_ticks_msec() * 0.04))
	var from := controller.muzzle_position()
	var to := from + controller.aim_direction * controller.effective_range()
	_begin()
	_quad(from, to, beam_width, Color(tint, alpha * strength))
	_end()
	showing = WeaponData.Telegraph.CHARGE_BEAM


func _draw_tracer(color: Color) -> void:
	var from := controller.muzzle_position()
	var length := controller.effective_range() * TRACER_FRACTION
	var direction := controller.aim_direction
	var flicker := _rng.randf_range(0.35, 0.7)
	_begin()
	var at := 0.0
	while at < length:
		var dash_end := minf(at + DASH, length)
		var fade := 1.0 - at / length
		_quad(from + direction * at, from + direction * dash_end, 0.18, Color(color, flicker * fade))
		at = dash_end + GAP
	_end()
	showing = WeaponData.Telegraph.TRACER


func _draw_cone(color: Color) -> void:
	var from := controller.muzzle_position()
	var reach := controller.effective_range()
	var half := deg_to_rad(controller.weapon.projectile.spread_deg + CONE_EXTRA_DEG)
	var steps := 8
	var alpha := 0.1 + 0.18 * _shot_pulse
	_begin()
	for i in steps:
		var a0 := -half + 2.0 * half * float(i) / steps
		var a1 := -half + 2.0 * half * float(i + 1) / steps
		var p0 := from + controller.aim_direction.rotated(Vector3.UP, a0) * reach
		var p1 := from + controller.aim_direction.rotated(Vector3.UP, a1) * reach
		_vertex(from, Color(color, alpha * 2.0))
		_vertex(p0, Color(color, 0.0))
		_vertex(p1, Color(color, 0.0))
	_end()
	showing = WeaponData.Telegraph.CONE


func _draw_lock(color: Color) -> void:
	var from := controller.muzzle_position()
	var to := AutoAim.flat(controller.lock_target.global_position)
	var direction := (to - from).normalized()
	var length := from.distance_to(to)
	var progress := clampf(controller.lock_progress / maxf(controller.weapon.lock_time, 0.001), 0.0, 1.0)
	var tint := Color(1.0, 0.25, 0.2) if progress >= 1.0 else color
	_begin()
	var at := 0.0
	while at < length:
		var dash_end := minf(at + DASH, length)
		_quad(from + direction * at, from + direction * dash_end, 0.14, Color(tint, 0.35 + 0.45 * progress))
		at = dash_end + GAP
	_end()
	showing = WeaponData.Telegraph.LOCK


# --- Mesh helpers --------------------------------------------------------------------

func _begin() -> void:
	_points.clear()
	_colors.clear()


## Emits the buffered triangles (an empty surface is an error, so nothing is emitted then).
func _end() -> void:
	if _points.is_empty():
		return
	_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES, _material)
	for i in _points.size():
		_mesh.surface_set_color(_colors[i])
		_mesh.surface_add_vertex(_points[i])
	_mesh.surface_end()


func _vertex(point: Vector3, color: Color) -> void:
	_points.append(Vector3(point.x, FLOOR_Y, point.z))
	_colors.append(color)


## A flat strip from [param from] to [param to], [param width] metres wide.
func _quad(from: Vector3, to: Vector3, width: float, color: Color) -> void:
	var along := AutoAim.flat(to - from)
	if along.length_squared() < 0.0001:
		return
	var side := along.normalized().cross(Vector3.UP) * width * 0.5
	_vertex(from - side, color)
	_vertex(from + side, color)
	_vertex(to + side, color)
	_vertex(from - side, color)
	_vertex(to + side, color)
	_vertex(to - side, color)
