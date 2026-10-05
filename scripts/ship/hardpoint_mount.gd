class_name HardpointMount
extends Node3D
## The runtime end of a HardpointData: lives on the hull model's marker and shows what is
## mounted there. For now it's a coloured empty-slot cube per hardpoint type; weapons and
## other gear replace the placeholder as they arrive.

const TYPE_COLORS := {
	HardpointData.Type.TURRET: Color(1.0, 0.55, 0.15),
	HardpointData.Type.FIGHTER_BAY: Color(0.2, 0.85, 0.95),
	HardpointData.Type.TECHMOD: Color(0.35, 0.9, 0.4),
	HardpointData.Type.CREW_SEAT: Color(0.9, 0.35, 0.85),
}

var data: HardpointData


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
