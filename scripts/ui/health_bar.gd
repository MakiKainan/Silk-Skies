class_name HealthBar
extends Node3D
## Two thin billboard bars floating "above" a ship on screen: shield (blue) over hull (red).
## Doesn't rotate with the ship. Add as a child of a Ship.

const WIDTH := 4.0
const HEIGHT := 0.3

var _ship: Ship
var _shield_quad: QuadMesh
var _hull_quad: QuadMesh


func _ready() -> void:
	_ship = get_parent() as Ship
	assert(_ship != null, "HealthBar must be a child of a Ship")
	top_level = true
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	_make_bar(Vector3(0.0, 0.0, -0.18), Color(0.05, 0.05, 0.05, 0.7), 0).size.y = HEIGHT * 2.4  # background strip
	_hull_quad = _make_bar(Vector3.ZERO, Color(0.9, 0.2, 0.2), 1)
	_shield_quad = _make_bar(Vector3(0.0, 0.0, -0.36), Color(0.3, 0.65, 1.0), 2)


func _process(_delta: float) -> void:
	if _ship.hull == null:
		return
	var origin := _ship.get_global_transform_interpolated().origin
	var radius := _ship.hull.collision_radius
	global_position = Vector3(origin.x, 3.0, origin.z - radius - 1.6)
	_fill(_hull_quad, _ship.health.hull_fraction())
	_fill(_shield_quad, _ship.health.shield_fraction())


## A left-anchored bar quad at a world-space offset below this node.
func _make_bar(offset: Vector3, color: Color, priority: int) -> QuadMesh:
	var quad := QuadMesh.new()
	quad.size = Vector2(WIDTH, HEIGHT)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	material.no_depth_test = true
	material.render_priority = priority
	material.albedo_color = color
	quad.material = material
	var instance := MeshInstance3D.new()
	instance.mesh = quad
	instance.position = offset
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(instance)
	return quad


func _fill(quad: QuadMesh, fraction: float) -> void:
	var f := clampf(fraction, 0.0, 1.0)
	quad.size.x = maxf(WIDTH * f, 0.001)
	quad.center_offset = Vector3(-WIDTH * (1.0 - f) * 0.5, 0.0, 0.0)
