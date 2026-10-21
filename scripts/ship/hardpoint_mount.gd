class_name HardpointMount
extends Node3D
## The runtime end of a HardpointData: lives on the hull model's marker and shows what is
## mounted there. Empty, it's a coloured cube per hardpoint type. With a weapon, it grows a
## barrel that swings toward the aim direction inside the arc, glows while charging, and can
## draw its firing arc as a flat wedge: always (the debug "show arcs" switch) or as a short
## flash (flash_cone), which the player's weapons use only while aimed outside it (a subtle red).
## The wedge reaches the weapon's max range and fades with its damage drop-off.

const TYPE_COLORS := {
	HardpointData.Type.TURRET: Color(1.0, 0.55, 0.15),
	HardpointData.Type.FIGHTER_BAY: Color(0.2, 0.85, 0.95),
	HardpointData.Type.TECHMOD: Color(0.35, 0.9, 0.4),
	HardpointData.Type.CREW_SEAT: Color(0.9, 0.35, 0.85),
}
## How fast the barrel can swing, degrees per second.
const BARREL_TURN_DEG := 540.0
## Barrel tint as a weapon nears overheating.
const HEAT_COLOR := Color(1.0, 0.22, 0.08)
## The flashed cone: seconds fully shown, then seconds fading out.
const FLASH_HOLD := 0.3
const FLASH_FADE := 0.2
## Wedge length for a turret with no weapon mounted.
const EMPTY_RADIUS := 12.0
## Radial rings across the drop-off part of a wedge (more = smoother fade).
const FALLOFF_RINGS := 8
const FLASH_COLOR := Color(1.0, 0.8, 0.45, 0.1)
const FLASH_BLOCKED_COLOR := Color(0.9, 0.3, 0.25, 0.12)

var data: HardpointData
var weapon_controller: WeaponController
## Set while a fighter bay is mounted here.
var bay_controller: FighterBayController

var _barrel_pivot: Node3D
var _barrel_material: StandardMaterial3D
var _barrel_base_color := Color.WHITE
var _arc_wedge: MeshInstance3D
var _flash_wedge: MeshInstance3D
var _flash_material: StandardMaterial3D
var _flash_color := FLASH_COLOR
var _flash_left: float = 0.0
## The [radius, falloff start, falloff min] the flash wedge was built for.
var _flash_shape := Vector3.ZERO


func setup(p_data: HardpointData) -> void:
	data = p_data
	var edge := 0.35
	if data.type == HardpointData.Type.TURRET and data.size == HardpointData.Size.LARGE:
		edge = 0.6
	var mesh := BoxMesh.new()
	mesh.size = Vector3(edge, edge, edge)
	var material := StandardMaterial3D.new()
	material.albedo_color = TYPE_COLORS[data.type]
	mesh.material = material
	var visual := MeshInstance3D.new()
	visual.name = "Placeholder"
	visual.mesh = mesh
	add_child(visual)


## Mounts [param weapon] (or empties the slot if null). The caller has already checked fit.
func equip(weapon: WeaponData, ship: Ship, instance: ItemInstance = null) -> void:
	if weapon_controller != null:
		weapon_controller.queue_free()
		weapon_controller = null
	if _barrel_pivot != null:
		_barrel_pivot.queue_free()
		_barrel_pivot = null
	if weapon == null:
		return
	_build_barrel(weapon)
	weapon_controller = WeaponController.new()
	weapon_controller.name = "WeaponController"
	add_child(weapon_controller)
	weapon_controller.setup(weapon, data, ship, self, instance)


## Mounts fighter bay [param bay] (or removes it if null). The caller has already checked fit.
func equip_bay(bay: FighterBayData, ship: Ship, instance: ItemInstance = null) -> void:
	if bay_controller != null:
		bay_controller.queue_free()
		bay_controller = null
	if bay == null:
		return
	bay_controller = FighterBayController.new()
	bay_controller.name = "FighterBayController"
	add_child(bay_controller)
	bay_controller.setup(bay, ship, self, instance)


## Swings the barrel toward [param world_direction]; [param glow] (0..1, charge) brightens it and
## [param heat] (0..1) shifts it toward red-hot.
func aim_barrel(world_direction: Vector3, glow: float, delta: float, heat: float = 0.0) -> void:
	if _barrel_pivot == null:
		return
	var wanted_yaw := atan2(-world_direction.x, -world_direction.z)
	var diff := angle_difference(_barrel_pivot.global_rotation.y, wanted_yaw)
	var step := deg_to_rad(BARREL_TURN_DEG) * delta
	_barrel_pivot.global_rotation.y += clampf(diff, -step, step)
	if _barrel_material != null:  # Real barrel models bring their own look: no glow tint.
		var hot := clampf((heat - 0.35) / 0.65, 0.0, 1.0)  # Cool barrels don't tint.
		_barrel_material.emission = _barrel_base_color.lerp(HEAT_COLOR, hot)
		_barrel_material.emission_energy_multiplier = maxf(glow * 5.0, hot * 3.0)


func set_arc_visible(on: bool) -> void:
	_clear_arc()
	if on and data != null and data.type == HardpointData.Type.TURRET:
		_build_arc()


## Shows this turret's firing cone for a moment (FLASH_HOLD, then a FLASH_FADE fade); red when
## [param blocked] (the shot is aimed outside it). Calling it again restarts the flash.
func flash_cone(blocked: bool = false) -> void:
	if data == null or data.type != HardpointData.Type.TURRET:
		return
	var shape := _cone_shape()
	if _flash_wedge != null and shape != _flash_shape:  # Range changed (refit, new roll): rebuild.
		_flash_wedge.queue_free()
		_flash_wedge = null
	if _flash_wedge == null:
		_flash_material = _wedge_material(FLASH_COLOR)
		_flash_wedge = _make_wedge(_flash_material, "ConeFlash")
		_flash_shape = shape
	_flash_color = FLASH_BLOCKED_COLOR if blocked else FLASH_COLOR
	_flash_left = FLASH_HOLD + FLASH_FADE
	_flash_wedge.visible = true
	_paint_flash()


## True while a flash is on screen (and whether it is the red one).
func is_cone_flashing() -> bool:
	return _flash_left > 0.0


func is_cone_blocked() -> bool:
	return is_cone_flashing() and _flash_color == FLASH_BLOCKED_COLOR


func _process(delta: float) -> void:
	if _flash_left <= 0.0:
		return
	_flash_left = maxf(_flash_left - delta, 0.0)
	_paint_flash()
	if _flash_left <= 0.0:
		_flash_wedge.visible = false


func _paint_flash() -> void:
	var fade := clampf(_flash_left / FLASH_FADE, 0.0, 1.0)
	_flash_material.albedo_color = Color(_flash_color, _flash_color.a * fade)


func _build_barrel(weapon: WeaponData) -> void:
	_barrel_material = null
	var barrel_scene := ArtLookup.barrel_scene(weapon)
	if barrel_scene != null:
		var model := barrel_scene.instantiate() as Node3D
		if model != null:
			model.position = Vector3(0.0, 0.2, 0.0)  # Authored facing -Z, origin at the pivot.
			_barrel_pivot = Node3D.new()
			_barrel_pivot.name = "BarrelPivot"
			_barrel_pivot.add_child(model)
			add_child(_barrel_pivot)
			return
	var large := weapon.size == HardpointData.Size.LARGE
	var length := 1.6 if large else 1.0
	var thickness := 0.28 if large else 0.16
	_barrel_material = StandardMaterial3D.new()
	_barrel_material.albedo_color = Damage.TYPE_COLORS[weapon.projectile.damage_type]
	_barrel_material.emission_enabled = true
	_barrel_material.emission = _barrel_material.albedo_color
	_barrel_base_color = _barrel_material.albedo_color
	_barrel_material.emission_energy_multiplier = 0.0
	var mesh := BoxMesh.new()
	mesh.size = Vector3(thickness, thickness, length)
	mesh.material = _barrel_material
	var visual := MeshInstance3D.new()
	visual.mesh = mesh
	visual.position = Vector3(0.0, 0.2, -length * 0.5)  # Sticks out toward -Z, which is "forward".
	_barrel_pivot = Node3D.new()
	_barrel_pivot.name = "BarrelPivot"
	_barrel_pivot.add_child(visual)
	add_child(_barrel_pivot)


func _build_arc() -> void:
	_arc_wedge = _make_wedge(_wedge_material(Color(TYPE_COLORS[data.type], 0.14)), "ArcWedge")


## [radius, falloff start, damage at max range] of the mounted weapon's cone, in metres.
func _cone_shape() -> Vector3:
	if weapon_controller == null or weapon_controller.weapon == null:
		return Vector3(EMPTY_RADIUS, EMPTY_RADIUS, 1.0)
	var reach := weapon_controller.effective_range()
	var weapon := weapon_controller.weapon
	if not weapon.has_falloff():
		return Vector3(reach, reach, 1.0)
	return Vector3(reach, weapon_controller.falloff_start_distance(), weapon.falloff_min)


func _wedge_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.vertex_color_use_as_albedo = true  # The wedge's vertex alpha carries the drop-off fade.
	material.albedo_color = color
	return material


## A flat wedge of this hardpoint's arc out to the weapon's max range, lying just above the floor.
## It is built in rings: opaque out to where the drop-off starts, then each ring's alpha is the
## damage multiplier there, so the cone fades exactly as the damage does.
func _make_wedge(material: StandardMaterial3D, node_name: String) -> MeshInstance3D:
	var shape := _cone_shape()
	var radius := shape.x
	var radii := PackedFloat32Array([0.0, shape.y])
	if shape.y < radius:
		for i in FALLOFF_RINGS:
			radii.append(lerpf(shape.y, radius, float(i + 1) / FALLOFF_RINGS))
	var half := deg_to_rad(data.arc_deg * 0.5)
	var center := deg_to_rad(data.arc_center_deg)
	var steps := maxi(int(data.arc_deg / 6.0), 3)
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for ring in radii.size() - 1:
		var r0 := radii[ring]
		var r1 := radii[ring + 1]
		var c0 := Color(1, 1, 1, WeaponData.falloff_multiplier(r0, radius, shape.y, shape.z))
		var c1 := Color(1, 1, 1, WeaponData.falloff_multiplier(r1, radius, shape.y, shape.z))
		for i in steps:
			var a0 := center - half + 2.0 * half * float(i) / steps
			var a1 := center - half + 2.0 * half * float(i + 1) / steps
			_wedge_quad(surface, a0, a1, r0, r1, c0, c1)
	var mesh := surface.commit()
	mesh.surface_set_material(0, material)
	var wedge := MeshInstance3D.new()
	wedge.name = node_name
	wedge.mesh = mesh
	add_child(wedge)
	wedge.global_position.y = 0.05
	wedge.reset_physics_interpolation()
	return wedge


## One cell of the wedge between bearings [param a0]..[param a1] and radii [param r0]..[param r1].
## Bearing b: starboard (+X) is sin b, forward (-Z) is cos b.
func _wedge_quad(surface: SurfaceTool, a0: float, a1: float, r0: float, r1: float, c0: Color, c1: Color) -> void:
	var inner0 := Vector3(sin(a0) * r0, 0.0, -cos(a0) * r0)
	var inner1 := Vector3(sin(a1) * r0, 0.0, -cos(a1) * r0)
	var outer0 := Vector3(sin(a0) * r1, 0.0, -cos(a0) * r1)
	var outer1 := Vector3(sin(a1) * r1, 0.0, -cos(a1) * r1)
	for vertex in [[inner0, c0], [outer1, c1], [outer0, c1], [inner0, c0], [inner1, c0], [outer1, c1]]:
		surface.set_color(vertex[1])
		surface.add_vertex(vertex[0])


func _clear_arc() -> void:
	if _arc_wedge != null:
		_arc_wedge.queue_free()
		_arc_wedge = null
