class_name Stats
extends RefCounted
## Canonical stat keys. Use these instead of raw strings so a typo fails at parse time.

const MASS := &"mass"
const THRUST := &"thrust"  ## Force; acceleration = thrust / mass.
const MAX_SPEED := &"max_speed"
const TURN_RATE := &"turn_rate"  ## Degrees per second at standstill.
const DRAG := &"drag"
const LATERAL_GRIP := &"lateral_grip"
const BURN_IMPULSE := &"burn_impulse"
const BURN_COOLDOWN := &"burn_cooldown"
const MAX_HULL := &"max_hull"
const MAX_SHIELD := &"max_shield"
const SHIELD_REGEN := &"shield_regen"  ## Shield points per second once regenerating.
const SHIELD_DELAY := &"shield_delay"  ## Seconds without a hit before regen starts.
const ARMOR := &"armor"  ## Flat damage removed from every hit that reaches the armor layer.

# Weapon stats (per weapon, built from the weapon's data plus modifiers).
const DAMAGE := &"damage"
const FIRE_RATE := &"fire_rate"  ## Firings per second; the cooldown is its inverse.
const RANGE := &"range"
const PROJECTILE_SPEED := &"projectile_speed"
## Percent bonus applied to the effects of every equipped techmod (the Engineer's station bonus).
const TECHMOD_POTENCY := &"techmod_potency"
