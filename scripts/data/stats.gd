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
