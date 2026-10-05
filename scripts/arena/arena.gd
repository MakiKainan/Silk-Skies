class_name Arena
extends Node3D
## Circular bounded arena. One `radius` drives the floor, the edge ring and the bounds
## check. Ships (group "ships") that cross the edge are slid back along it.
## Asteroids are placed as child scenes in arena.tscn.

@export var radius: float = 50.0

const GRID_SHADER := preload("res://shaders/grid.gdshader")


func _ready() -> void:
	_build_floor()
	_build_edge_ring()


func _physics_process(_delta: float) -> void:
	for node in get_tree().get_nodes_in_group(Ship.GROUP):
		(node as Ship).enforce_bounds(global_position, radius)


func _build_floor() -> void:
	var plane := PlaneMesh.new()
	plane.size = Vector2.ONE * radius * 3.0
	var material := ShaderMaterial.new()
	material.shader = GRID_SHADER
	plane.material = material
	var floor_mesh := MeshInstance3D.new()
	floor_mesh.name = "Floor"
	floor_mesh.mesh = plane
	floor_mesh.position.y = -0.6
	add_child(floor_mesh)


func _build_edge_ring() -> void:
	var thickness := 0.3
	var torus := TorusMesh.new()
	torus.inner_radius = radius - thickness
	torus.outer_radius = radius + thickness
	torus.rings = 96
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(0.9, 0.3, 0.25)
	torus.material = material
	var ring := MeshInstance3D.new()
	ring.name = "EdgeRing"
	ring.mesh = torus
	ring.position.y = -0.3
	add_child(ring)
