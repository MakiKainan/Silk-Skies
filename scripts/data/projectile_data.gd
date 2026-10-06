class_name ProjectileData
extends Resource
## What a weapon shoots. Authored content: never modified at runtime.

@export var id: StringName
@export var damage: float = 5.0
@export var damage_type: Damage.Type = Damage.Type.KINETIC
## Metres per second.
@export var speed: float = 50.0
## Seconds before it expires. speed * lifetime is its range.
@export var lifetime: float = 1.0
## Random deviation, in degrees either side of the aim direction.
@export_range(0.0, 45.0, 0.1) var spread_deg: float = 0.0
## How fast a homing projectile can turn toward its target. 0 = flies straight.
@export var homing_deg_per_sec: float = 0.0
## How many extra ships it passes through after the first.
@export var pierce: int = 0
## Explosion radius on impact. 0 = single-target.
@export var blast_radius: float = 0.0
## Visual size.
@export var radius: float = 0.15
@export var length: float = 1.0
@export var color: Color = Color.WHITE

@export_group("Art")
## Flying model, pointing toward -Z. Empty = assets/models/projectiles/<id>, else a generated shape.
@export var visual_scene: PackedScene
## Spawned where it hits; the scene frees itself. Empty = assets/vfx/scenes/<id>_impact, else a blast ring.
@export var impact_scene: PackedScene
## Played where it hits. Empty = assets/audio/sfx/<id>_impact, else silent.
@export var impact_sound: AudioStream
