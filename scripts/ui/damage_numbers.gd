class_name DamageNumbers
extends Node3D
## Floats a number up from every hit, coloured by what it hit: shield damage blue, armor
## soak grey (shown as a minus), hull damage red. Listens to the EventBus; add one to a scene.

const SHIELD_COLOR := Color(0.4, 0.7, 1.0)
const ARMOR_COLOR := Color(0.75, 0.75, 0.75)
const HULL_COLOR := Color(1.0, 0.3, 0.25)


func _ready() -> void:
	EventBus.ship_hit.connect(_on_ship_hit)


func _exit_tree() -> void:
	if EventBus.ship_hit.is_connected(_on_ship_hit):
		EventBus.ship_hit.disconnect(_on_ship_hit)


func _on_ship_hit(_ship: Node, result: DamageResult) -> void:
	var row := 0
	if result.shield_damage > 0.0:
		_spawn("%d" % roundi(result.shield_damage), SHIELD_COLOR, result.position, row, 1.0)
		row += 1
	if result.armor_absorbed > 0.0:
		_spawn("-%d" % roundi(result.armor_absorbed), ARMOR_COLOR, result.position, row, 0.75)
		row += 1
	if result.hull_damage > 0.0:
		_spawn("%d" % roundi(result.hull_damage), HULL_COLOR, result.position, row, 1.25)


func _spawn(text: String, color: Color, at: Vector3, row: int, scale_factor: float) -> void:
	var label := Label3D.new()
	label.text = text
	label.modulate = color
	label.outline_modulate = Color.BLACK
	label.outline_size = 10
	label.font_size = 48
	label.pixel_size = 0.032 * scale_factor
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	add_child(label)
	# Rows stack toward the top of the screen (-Z) so simultaneous numbers don't overlap.
	var start := Vector3(at.x, 2.5, at.z - float(row) * 1.6)
	label.global_position = start
	var tween := label.create_tween().set_parallel(true)
	tween.tween_property(label, "global_position", start + Vector3(0.0, 0.0, -2.5), 0.8).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "modulate:a", 0.0, 0.8).set_delay(0.3)
	tween.chain().tween_callback(label.queue_free)
