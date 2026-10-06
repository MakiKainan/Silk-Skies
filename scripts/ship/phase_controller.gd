class_name PhaseController
extends Node
## Boss phases: watches the ship's hull and, as it falls past each threshold, switches the AI
## profile, mounts extra weapons and tops the shield up. Add as a child of the Ship.

signal phase_started(index: int, phase: PhaseData)

var phases: Array[PhaseData] = []
## How many phases have triggered so far.
var current_phase: int = 0

var _ship: Ship
var _rng: RandomNumberGenerator


func _ready() -> void:
	_ship = get_parent() as Ship
	assert(_ship != null, "PhaseController must be a child of a Ship")
	_ship.health.damaged.connect(_on_damaged)


func setup(p_phases: Array[PhaseData], p_rng: RandomNumberGenerator) -> void:
	phases = p_phases
	_rng = p_rng


func _on_damaged(_result: DamageResult) -> void:
	check()


## Triggers every phase whose threshold the hull has reached (a big hit can skip several).
func check() -> void:
	# (hull > 0: the killing blow reports "damaged" before the ship is marked dead.)
	while current_phase < phases.size() and _ship.is_alive() and _ship.health.hull > 0.0 and _ship.health.hull_fraction() <= phases[current_phase].hull_threshold:
		_start(current_phase)
		current_phase += 1


func _start(index: int) -> void:
	var phase := phases[index]
	if phase.ai_profile != null:
		var ai := _ship.get_node_or_null("AIController") as AIController
		if ai != null:
			ai.setup(phase.ai_profile, _rng)
	for spec in phase.added_items:
		EnemyFactory.equip_spec(_ship, spec, _rng)
	if phase.refill_shield:
		_ship.health.shield = _ship.health.max_shield()
	Vfx.ring(_ship.get_parent(), _ship.global_position, _ship.hull.collision_radius * 4.0, Color(1.0, 0.3, 0.2), 0.7)
	phase_started.emit(index, phase)
	EventBus.phase_started.emit(_ship, phase)
