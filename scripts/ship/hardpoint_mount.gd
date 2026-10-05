class_name HardpointMount
extends Node3D
## The runtime end of a HardpointData: lives on the hull model's marker and shows what is
## mounted there. Empty, it's a coloured cube per hardpoint type. With a weapon, it grows a
## barrel that swings toward the aim direction inside the arc, glows while charging, and can
## draw its firing arc as a flat wedge.

const TYPE_COLORS := {
	HardpointData.Type.TURRET: Color(1.0, 0.55, 0.15),
	HardpointData.Type.FIGHTER_BAY: Color(0.2, 0.85, 0.95),
	HardpointData.Type.TECHMOD: Color(0.35, 0.9, 0.4),
	HardpointData.Type.CREW_SEAT: Color(0.9, 0.35, 0.85),
}
## How fast the barrel can swing, degrees per second.
const BARREL_TURN_DEG := 540.0

var data: HardpointData
var weapon_controller: WeaponController

var _barrel_pivot: Node3D
var _barrel_material: StandardMaterial3D
var _arc_wedge: MeshInstance3D


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


## Swings the barrel toward [param world_direction]; [param glow] (0..1) brightens it.
func aim_barrel(world_direction: Vector3, glow: float, delta: float) -> void:
	if _barrel_pivot == null:
		return
	var wanted_yaw := atan2(-world_direction.x, -world_direction.z)
	var diff := angle_difference(_barrel_pivot.global_rotation.y, wanted_yaw)
	var step := deg_to_rad(BARREL_TURN_DEG) * delta
	_barrel_pivot.global_rotation.y += clampf(diff, -step, step)
	_barrel_material.emission_energy_multiplier = glow * 5.0


func set_arc_visible(on: bool) -> void:
	_clear_arc()
	if on and data != null and data.type == HardpointData.Type.TURRET:
		_build_arc()


func _build_barrel(weapon: WeaponData) -> void:
	var large := weapon.size == HardpointData.Size.LARGE
	var length := 1.6 if large else 1.0
	var thickness := 0.28 if large else 0.16
	_barrel_material = StandardMaterial3D.new()
	_barrel_material.albedo_color = Damage.TYPE_COLORS[weapon.projectile.damage_type]
	_barrel_material.emission_enabled = true
	_barrel_material.emission = _barrel_material.albedo_color
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
	var radius := 14.0
	var half := deg_to_rad(data.arc_deg * 0.5)
	var center := deg_to_rad(data.arc_center_deg)
	var steps := maxi(int(data.arc_deg / 6.0), 3)
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in steps:
		var a0 := center - half + 2.0 * half * float(i) / steps
		var a1 := center - half + 2.0 * half * float(i + 1) / steps
		# Bearing b: starboard (+X) is sin b, forward (-Z) is cos b.
		surface.add_vertex(Vector3.ZERO)
		surface.add_vertex(Vector3(sin(a1) * radius, 0.0, -cos(a1) * radius))
		surface.add_vertex(Vector3(sin(a0) * radius, 0.0, -cos(a0) * radius))
	var mesh := surface.commit()
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.albedo_color = Color(TYPE_COLORS[data.type], 0.14)
	mesh.surface_set_material(0, material)
	_arc_wedge = MeshInstance3D.new()
	_arc_wedge.name = "ArcWedge"
	_arc_wedge.mesh = mesh
	add_child(_arc_wedge)
	_arc_wedge.global_position.y = 0.05
	_arc_wedge.reset_physics_interpolation()


func _clear_arc() -> void:
	if _arc_wedge != null:
		_arc_wedge.queue_free()
		_arc_wedge = null
