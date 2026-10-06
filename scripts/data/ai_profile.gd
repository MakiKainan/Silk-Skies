class_name AIProfile
extends Resource
## How an AI-driven ship fights: where it wants to be, how well it aims, how it reacts.
## Authored content. New enemy behaviour is a new profile, not new code.

@export var id: StringName
@export var display_name: String = ""
@export_multiline var description: String = ""

@export_group("Positioning")
## The distance from the target it tries to hold, in metres.
@export var preferred_range: float = 20.0
## It only closes or opens the gap once it is this far outside its preferred range.
@export var range_band: float = 5.0
## How far around the target it aims to circle (degrees of arc ahead of its current bearing).
## Small = nearly head-on, large = tight circling.
@export_range(0.0, 85.0, 1.0) var orbit_lead_deg: float = 35.0
## It reverses its circling direction every so often, picked between these (seconds).
@export var orbit_flip_min: float = 4.0
@export var orbit_flip_max: float = 8.0
## Highest throttle it uses, 0..1.
@export_range(0.1, 1.0, 0.05) var max_throttle: float = 1.0

@export_group("Aim and awareness")
## Its picture of the target lags reality by about this many seconds; lower = harder to fool.
@export var reaction_time: float = 0.3
## Manual and lock-on shots miss by up to this many degrees (re-rolled after each shot).
@export var aim_error_deg: float = 3.0
## It only pulls the trigger when the target is within this fraction of the weapon's range.
@export_range(0.1, 1.0, 0.05) var fire_range_fraction: float = 1.0

@export_group("Evasion")
## Uses Hard Burn to sidestep projectiles that are about to hit.
@export var dodge_burn: bool = false
