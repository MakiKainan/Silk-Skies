class_name ArtBar
extends Range
## A bar drawn from textures: a nine-patch frame and a tinted nine-patch fill that shrinks
## from the right. Everything is drawn scaled so the frame's height matches the control's
## height, which keeps the art's proportions at any bar size. Value runs 0..max_value.
## Built by UiArt.make_bar(); without bar art that returns a plain ProgressBar instead.

var tint: Color = Color.WHITE:
	set(value):
		tint = value
		queue_redraw()

var _frame: StyleBoxTexture
var _fill: StyleBoxTexture
var _frame_height := 1.0
var _fill_height := 1.0
## Where the fill channel sits inside the frame, in frame-texture pixels (left, top, right, bottom).
var _inset := Vector4.ZERO


func setup(frame: Texture2D, frame_margins: Vector4, inset: Vector4, fill: Texture2D, fill_margins: Vector4, p_tint: Color) -> void:
	_frame = UiArt._nine(frame, frame_margins)
	_fill = UiArt._nine(fill, fill_margins)
	_frame_height = float(frame.get_height())
	_fill_height = float(fill.get_height())
	_inset = inset
	tint = p_tint
	if not value_changed.is_connected(_on_value_changed):
		value_changed.connect(_on_value_changed)
		changed.connect(queue_redraw)


func _on_value_changed(_v: float) -> void:
	queue_redraw()


func _draw() -> void:
	if _frame == null or size.y <= 0.0:
		return
	# Frame, drawn in texture space so its borders scale with the bar height.
	var s := size.y / _frame_height
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(s, s))
	draw_style_box(_frame, Rect2(Vector2.ZERO, Vector2(size.x / s, _frame_height)))

	var fraction := clampf(ratio, 0.0, 1.0)
	if fraction <= 0.0:
		draw_set_transform(Vector2.ZERO)
		return
	# Fill channel in screen pixels, then the fill drawn in its own texture space.
	var channel := Rect2(
		Vector2(_inset.x, _inset.y) * s,
		Vector2(size.x - (_inset.x + _inset.z) * s, size.y - (_inset.y + _inset.w) * s))
	var fs := channel.size.y / _fill_height
	if fs <= 0.0:
		return
	var min_width := (_fill.texture_margin_left + _fill.texture_margin_right) * fs
	var width := maxf(channel.size.x * fraction, minf(min_width, channel.size.x))
	draw_set_transform(channel.position, 0.0, Vector2(fs, fs))
	_fill.modulate_color = tint
	draw_style_box(_fill, Rect2(Vector2.ZERO, Vector2(width / fs, _fill_height)))
	draw_set_transform(Vector2.ZERO)
