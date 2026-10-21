class_name HangarView
extends Control
## The hangar's 3D ship: the hull model on a pivot in its own little world, framed by a fixed
## camera. Drag the mouse over it to spin the ship around its vertical axis (nothing else
## moves). Controls handed to [method add_hotspot] follow their hardpoint's marker on screen, so
## they can be drop targets sitting right on the part of the ship they belong to.

const PITCH_DEG := 36.0
const DEFAULT_YAW_DEG := -78.0
const FOV_DEG := 38.0
const DRAG_DEG_PER_PIXEL := 0.45
## The hangar spreads the hotspots outward from the middle of the ship by this much (clamped to
## the hull's bounds) so they don't pile up: a hull's markers sit close together for gameplay.
const HOTSPOT_SPREAD := 1.7
## Hotspots closer than this (centre to centre, pixels) are nudged apart so none hides another.
const MIN_HOTSPOT_GAP := 68.0
## How much of the view height the ship's bounding sphere takes (under 1: the bounding sphere
## of a long, flat ship is much bigger than the ship, so it may overflow a little).
const FRAMING := 0.8

## Radians around +Y. Positive turns the bow toward the viewer's left.
var yaw: float = deg_to_rad(DEFAULT_YAW_DEG):
	set(value):
		yaw = wrapf(value, -PI, PI)
		if _pivot != null:
			_pivot.rotation.y = yaw

var _container: SubViewportContainer
var _viewport: SubViewport
var _pivot: Node3D
var _camera: Camera3D
var _model: Node3D
var _hull: HullData
var _bounds_local := AABB()
var _hotspots: Array[Dictionary] = []


func _ready() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_container = SubViewportContainer.new()
	_container.stretch = true
	_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	_container.mouse_filter = Control.MOUSE_FILTER_STOP
	_container.mouse_default_cursor_shape = Control.CURSOR_HSIZE
	_container.gui_input.connect(_on_container_input)
	add_child(_container)

	_viewport = SubViewport.new()
	_viewport.own_world_3d = true
	_viewport.transparent_bg = true
	_viewport.msaa_3d = Viewport.MSAA_4X
	_viewport.handle_input_locally = false
	_container.add_child(_viewport)

	var environment := Environment.new()
	environment.background_mode = Environment.BG_CLEAR_COLOR
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.55, 0.6, 0.75)
	environment.ambient_light_energy = 0.7
	_camera = Camera3D.new()
	_camera.fov = FOV_DEG
	_camera.environment = environment
	_viewport.add_child(_camera)

	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-50.0, 35.0, 0.0)
	key.light_energy = 1.1
	_viewport.add_child(key)
	var rim := DirectionalLight3D.new()
	rim.rotation_degrees = Vector3(-20.0, 200.0, 0.0)
	rim.light_energy = 0.5
	rim.light_color = Color(0.6, 0.75, 1.0)
	_viewport.add_child(rim)

	_pivot = Node3D.new()
	_pivot.rotation.y = yaw
	_viewport.add_child(_pivot)

	var hint := Label.new()
	hint.text = "drag to rotate"
	hint.add_theme_font_size_override(&"font_size", 11)
	hint.add_theme_color_override(&"font_color", Color(1, 1, 1, 0.35))
	hint.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	hint.grow_horizontal = Control.GROW_DIRECTION_BOTH
	hint.grow_vertical = Control.GROW_DIRECTION_BEGIN
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(hint)
	if _hull != null:
		_build_model()


## Shows [param hull]'s model (a no-op when it's already the one on show).
func show_hull(hull: HullData) -> void:
	if hull == _hull and _model != null:
		return
	_hull = hull
	if _pivot != null:
		_build_model()


## The hull's marker for hardpoint [param index], or null.
func marker_for(index: int) -> Marker3D:
	if _model == null or _hull == null or index < 0 or index >= _hull.hardpoints.size():
		return null
	return _hull.hardpoints[index].find_marker(_model)


## Where hardpoint [param index]'s hotspot is on screen, in this control's coordinates: its
## marker, spread outward a little (see HOTSPOT_SPREAD). Vector2.INF when there is no model or marker.
func marker_screen_position(index: int) -> Vector2:
	var marker := marker_for(index)
	if marker == null or not marker.is_inside_tree() or _camera == null:
		return Vector2.INF
	var local := _model.to_local(marker.global_position)
	var center := _bounds_local.get_center()
	var spread := center + (local - center) * Vector3(HOTSPOT_SPREAD, 1.0, HOTSPOT_SPREAD)
	var low := _bounds_local.position
	var high := _bounds_local.end
	spread = Vector3(clampf(spread.x, low.x, high.x), spread.y, clampf(spread.z, low.z, high.z))
	return _camera.unproject_position(_model.to_global(spread))


## Keeps [param control] centred on hardpoint [param index]'s marker as the ship turns.
func add_hotspot(index: int, control: Control) -> void:
	add_child(control)
	_hotspots.append({"index": index, "control": control})
	_place(control, index)


func clear_hotspots() -> void:
	for spot in _hotspots:
		var control := spot.control as Control
		if is_instance_valid(control):
			remove_child(control)
			control.queue_free()
	_hotspots.clear()


func _process(_delta: float) -> void:
	reposition_hotspots()


## Puts every hotspot on its marker, then pushes overlapping ones apart.
func reposition_hotspots() -> void:
	var centers: Array[Vector2] = []
	for spot in _hotspots:
		var point := marker_screen_position(spot.index)
		centers.append(point if point != Vector2.INF else (spot.control as Control).position + (spot.control as Control).size * 0.5)
	_separate(centers)
	for i in _hotspots.size():
		var control := _hotspots[i].control as Control
		var half := control.size * 0.5
		var inside := Vector2(clampf(centers[i].x, half.x, maxf(size.x - half.x, half.x)), clampf(centers[i].y, half.y, maxf(size.y - half.y, half.y)))
		control.position = inside - half


func _place(control: Control, index: int) -> void:
	var point := marker_screen_position(index)
	if point != Vector2.INF:
		control.position = point - control.size * 0.5


## A few relaxation passes: any two centres nearer than MIN_HOTSPOT_GAP move apart equally.
static func _separate(centers: Array[Vector2]) -> void:
	for _pass in 8:
		var moved := false
		for i in centers.size():
			for j in range(i + 1, centers.size()):
				var offset := centers[j] - centers[i]
				var distance := offset.length()
				if distance >= MIN_HOTSPOT_GAP:
					continue
				var direction := offset / distance if distance > 0.01 else Vector2(1.0, 0.0)
				var push := (MIN_HOTSPOT_GAP - distance) * 0.5
				centers[i] -= direction * push
				centers[j] += direction * push
				moved = true
		if not moved:
			return


func _on_container_input(event: InputEvent) -> void:
	var motion := event as InputEventMouseMotion
	if motion != null and (motion.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
		yaw += deg_to_rad(motion.relative.x * DRAG_DEG_PER_PIXEL)
		accept_event()


func _build_model() -> void:
	if _model != null:
		_pivot.remove_child(_model)
		_model.queue_free()
		_model = null
	if _hull == null or _hull.model_scene == null:
		return
	_model = _hull.model_scene.instantiate() as Node3D
	if _model == null:
		return
	_pivot.add_child(_model)
	var bounds := _bounds(_model)
	_bounds_local = bounds
	_model.position = -bounds.get_center()
	var radius := maxf(bounds.size.length() * 0.5, 0.5)
	var distance := radius * FRAMING / tan(deg_to_rad(FOV_DEG) * 0.5)
	var pitch := deg_to_rad(PITCH_DEG)
	_camera.position = Vector3(0.0, sin(pitch), cos(pitch)) * distance
	_camera.look_at_from_position(_camera.position, Vector3.ZERO)
	_camera.far = distance * 4.0


## Bounds of every mesh under [param root] in the model's own space (markers don't count).
static func _bounds(root: Node3D) -> AABB:
	var box := AABB()
	var first := true
	for node in root.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		var local := _relative_transform(mesh, root) * mesh.get_aabb()
		box = local if first else box.merge(local)
		first = false
	return box if not first else AABB(Vector3(-1, -1, -1), Vector3(2, 2, 2))


static func _relative_transform(node: Node3D, root: Node3D) -> Transform3D:
	var xform := Transform3D.IDENTITY
	var current: Node = node
	while current != null and current != root:
		xform = (current as Node3D).transform * xform
		current = current.get_parent()
	return xform
