class_name ThreatIndicators
extends CanvasLayer
## Arrows on the screen edge pointing at threats you can't see: enemy ships (grey), enemy
## missiles (orange) and enemy fighters (cyan). A ship charging a railgun or locking missiles on
## you pulses red. Arrows fade the further away the threat is. Duel and Sandbox add one.

enum Kind { SHIP, MISSILE, FIGHTER }

## Pixels between an arrow and the screen edge.
const INSET := 34.0
const ARROW_SIZE := 15.0
const COLORS := {
	Kind.SHIP: Color(0.85, 0.85, 0.9),
	Kind.MISSILE: Color(1.0, 0.55, 0.15),
	Kind.FIGHTER: Color(0.4, 0.9, 1.0),
}
const DANGER_COLOR := Color(1.0, 0.18, 0.15)
## Arrows are fully opaque up to this distance (metres from the player), then fade to FAR_ALPHA.
const NEAR_DISTANCE := 30.0
const FAR_DISTANCE := 110.0
const FAR_ALPHA := 0.35

var player: Ship

var _canvas: Control


func track(ship: Ship) -> void:
	player = ship


func _ready() -> void:
	layer = 4
	_canvas = Control.new()
	_canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.draw.connect(_draw_arrows)
	add_child(_canvas)


func _process(_delta: float) -> void:
	_canvas.queue_redraw()


## Everything worth an arrow: [{position, kind, danger}], enemies of the tracked ship only.
func threats() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if player == null or not is_instance_valid(player) or not player.is_inside_tree():
		return out
	for enemy in player.enemies():
		out.append({"position": enemy.global_position, "kind": Kind.SHIP, "danger": is_dangerous(enemy, player)})
	for node in get_tree().get_nodes_in_group(Projectile.GROUP):
		var projectile := node as Projectile
		if projectile.team() != player.team and projectile.is_interceptable():
			out.append({"position": projectile.global_position, "kind": Kind.MISSILE, "danger": false})
	for node in get_tree().get_nodes_in_group(Fighter.GROUP):
		var fighter := node as Fighter
		if fighter.team != player.team and fighter.is_alive():
			out.append({"position": fighter.global_position, "kind": Kind.FIGHTER, "danger": false})
	return out


## Is [param enemy] about to hit [param target] hard: a railgun charging, or a missile lock on it?
static func is_dangerous(enemy: Ship, target: Ship) -> bool:
	for controller in enemy.weapons():
		if controller.weapon.telegraph == WeaponData.Telegraph.CHARGE_BEAM and controller.charge > 0.0:
			return true
		if controller.lock_target == target:
			return true
	return false


## Where on the edge of [param rect] (pulled in by [param inset]) to draw the arrow for a threat
## at [param screen_point], or null if the point is comfortably on screen. The arrow sits on the
## line from the screen centre toward the threat.
static func edge_point(screen_point: Vector2, rect: Rect2, inset: float) -> Variant:
	var inner := rect.grow(-inset)
	if inner.has_point(screen_point):
		return null
	var center := rect.get_center()
	var direction := screen_point - center
	if direction.length_squared() < 0.0001:
		return null
	var half := inner.size * 0.5
	var scale_x := half.x / absf(direction.x) if absf(direction.x) > 0.0001 else INF
	var scale_y := half.y / absf(direction.y) if absf(direction.y) > 0.0001 else INF
	return center + direction * minf(scale_x, scale_y)


func _draw_arrows() -> void:
	var camera := get_viewport().get_camera_3d()
	if camera == null or player == null or not is_instance_valid(player):
		return
	var rect := Rect2(Vector2.ZERO, _canvas.size)
	var pulse := 0.55 + 0.45 * absf(sin(Time.get_ticks_msec() * 0.012))
	for threat in threats():
		var world: Vector3 = threat.position
		var point: Variant = edge_point(camera.unproject_position(world), rect, INSET)
		if point == null:
			continue
		var distance := AutoAim.flat(world - player.global_position).length()
		var alpha := lerpf(1.0, FAR_ALPHA, clampf((distance - NEAR_DISTANCE) / (FAR_DISTANCE - NEAR_DISTANCE), 0.0, 1.0))
		var color: Color = DANGER_COLOR if threat.danger else COLORS[threat.kind]
		var size := ARROW_SIZE * (1.3 if threat.danger else (0.75 if threat.kind != Kind.SHIP else 1.0))
		if threat.danger:
			alpha = maxf(alpha, pulse)
		_draw_arrow(point as Vector2, ((point as Vector2) - rect.get_center()).normalized(), size, Color(color, alpha))


func _draw_arrow(tip: Vector2, direction: Vector2, size: float, color: Color) -> void:
	var side := Vector2(-direction.y, direction.x)
	var back := tip - direction * size * 1.4
	var points := PackedVector2Array([tip, back + side * size * 0.75, back - side * size * 0.75])
	_canvas.draw_colored_polygon(points, color)
	_canvas.draw_polyline(PackedVector2Array([points[0], points[1], points[2], points[0]]), Color(0, 0, 0, color.a * 0.8), 2.0, true)
