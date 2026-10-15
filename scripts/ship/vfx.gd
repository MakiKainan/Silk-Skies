class_name Vfx
extends RefCounted
## Throwaway placeholder effects: expanding rings for blasts and ship deaths, tracer lines.

## Drops a real effect scene at [param position]. The scene should free itself when done; a
## timer removes it after [param max_seconds] in case it does not.
static func spawn_scene(parent: Node, scene: PackedScene, position: Vector3, max_seconds: float = 5.0) -> void:
	if parent == null or not parent.is_inside_tree():
		return
	var node := scene.instantiate() as Node3D
	if node == null:
		return
	node.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	parent.add_child(node)
	node.global_position = position
	parent.get_tree().create_timer(max_seconds).timeout.connect(node.queue_free)


## An expanding, fading sphere centred on [param position]; frees itself when done.
static func ring(parent: Node, position: Vector3, radius: float, color: Color, duration: float = 0.35) -> void:
	var sphere := SphereMesh.new()
	sphere.radius = 1.0
	sphere.height = 2.0
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(color, 0.5)
	sphere.material = material
	var node := MeshInstance3D.new()
	node.mesh = sphere
	node.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	parent.add_child(node)
	node.global_position = Vector3(position.x, 0.0, position.z)
	node.scale = Vector3.ONE * radius * 0.2
	var tween := node.create_tween().set_parallel(true)
	tween.tween_property(node, "scale", Vector3.ONE * radius, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(material, "albedo_color:a", 0.0, duration)
	tween.chain().tween_callback(node.queue_free)


## A thin glowing line from [param from] to [param to] that fades out; frees itself when done.
static func line(parent: Node, from: Vector3, to: Vector3, color: Color, duration: float = 0.12) -> void:
	if parent == null or not parent.is_inside_tree():
		return
	var flat_from := Vector3(from.x, 0.6, from.z)
	var flat_to := Vector3(to.x, 0.6, to.z)
	var length := flat_from.distance_to(flat_to)
	if length < 0.01:
		return
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = color
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.08, 0.08, length)
	mesh.material = material
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	parent.add_child(node)
	node.global_position = (flat_from + flat_to) * 0.5
	node.look_at(flat_to, Vector3.UP)
	var tween := node.create_tween()
	tween.tween_property(material, "albedo_color:a", 0.0, duration)
	tween.tween_callback(node.queue_free)
