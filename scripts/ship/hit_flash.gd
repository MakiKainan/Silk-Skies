class_name HitFlash
extends MeshInstance3D
## A translucent bubble around a ship that flashes when it's hit: blue when the shield took
## it, red when it reached the hull. Add as a child of a Ship.

var _ship: Ship
var _material: StandardMaterial3D


func _ready() -> void:
	_ship = get_parent() as Ship
	assert(_ship != null, "HitFlash must be a child of a Ship")
	var sphere := SphereMesh.new()
	sphere.radius = 1.0
	sphere.height = 2.0
	_material = StandardMaterial3D.new()
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_material.albedo_color = Color(0.3, 0.6, 1.0, 0.0)
	sphere.material = _material
	mesh = sphere
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# The ship's own _ready hasn't run yet, so find its pieces by node path.
	_ship.get_node("HealthComponent").damaged.connect(_on_damaged)
	_ship.hull_changed.connect(_on_hull_changed)


func _on_hull_changed(hull: HullData) -> void:
	scale = Vector3.ONE * hull.collision_radius * 1.5


func _on_damaged(result: DamageResult) -> void:
	var color := Color(1.0, 0.25, 0.2) if result.hull_damage > 0.0 else Color(0.3, 0.6, 1.0)
	_material.albedo_color = Color(color, 0.45)
	var tween := create_tween()
	tween.tween_property(_material, "albedo_color:a", 0.0, 0.25)
