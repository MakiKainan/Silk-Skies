class_name Sfx
extends RefCounted
## One-shot sound effects. Does nothing when there is no stream, so callers never check.

const BUS := &"SFX"


## Plays [param stream] at [param position] and frees the player when it finishes.
static func play_3d(parent: Node, stream: AudioStream, position: Vector3) -> void:
	if stream == null or parent == null or not parent.is_inside_tree():
		return
	var player := AudioStreamPlayer3D.new()
	player.stream = stream
	player.bus = BUS if AudioServer.get_bus_index(BUS) != -1 else &"Master"
	player.finished.connect(player.queue_free)
	parent.add_child(player)
	player.global_position = position
	player.play()
