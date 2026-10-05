class_name HardpointData
extends Resource
## One typed mounting slot on a hull. Authored content: never modified at runtime.

enum Type { TURRET, FIGHTER_BAY, TECHMOD, CREW_SEAT }
enum Size { SMALL, LARGE }

@export var type: Type = Type.TURRET
## Turrets only.
@export var size: Size = Size.SMALL
## Width of the firing arc. 360 = all-round, small values = narrow broadside.
@export_range(10.0, 360.0, 1.0, "degrees") var arc_deg: float = 360.0
## Where the middle of the arc points, relative to the ship's bow (0 = forward, 90 = starboard).
@export_range(-180.0, 180.0, 1.0, "degrees") var arc_center_deg: float = 0.0
## Name of the Marker3D in the hull's model scene where gear visibly mounts.
@export var marker_name: StringName


## Finds this hardpoint's marker under a hull model root, or null if it's missing.
func find_marker(model_root: Node) -> Marker3D:
	if marker_name == &"":
		return null
	return model_root.find_child(String(marker_name), true, false) as Marker3D
