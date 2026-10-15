class_name HealthComponent
extends Node
## A ship's shield and hull. Max values and armor come from the StatsComponent; the
## actual damage maths lives in DamageModel.
##
## Breaking a shield (taking it from up to 0) leaves the hull exposed for EXPOSED_SECONDS: hull
## damage is multiplied by EXPOSED_HULL_MULT and the shield can't start regenerating.

signal damaged(result: DamageResult)
signal destroyed(source: Node)
signal shield_broken

const EXPOSED_SECONDS := 2.0
const EXPOSED_HULL_MULT := 1.25

var shield: float = 0.0
var hull: float = 0.0
var is_dead: bool = false
## Sandbox: hits are resolved and reported but nothing is lost.
var god_mode: bool = false
## Seconds left of the post-break exposed window.
var exposed_left: float = 0.0

var _stats: StatsComponent
var _since_hit: float = INF
var _last_max_shield: float = 0.0
var _last_max_hull: float = 0.0


func setup(stats: StatsComponent) -> void:
	_stats = stats
	if not stats.stats_changed.is_connected(_on_stats_changed):
		stats.stats_changed.connect(_on_stats_changed)


## Full shield and hull, alive again.
func refill() -> void:
	is_dead = false
	_since_hit = INF
	exposed_left = 0.0
	shield = max_shield()
	hull = max_hull()
	_last_max_shield = shield
	_last_max_hull = hull


func max_shield() -> float:
	return _stats.get_stat(Stats.MAX_SHIELD)


func max_hull() -> float:
	return _stats.get_stat(Stats.MAX_HULL)


func armor() -> float:
	return _stats.get_stat(Stats.ARMOR)


func shield_fraction() -> float:
	return clampf(shield / maxf(max_shield(), 0.001), 0.0, 1.0)


func hull_fraction() -> float:
	return clampf(hull / maxf(max_hull(), 0.001), 0.0, 1.0)


func is_exposed() -> bool:
	return exposed_left > 0.0


func apply_hit(hit: Hit) -> DamageResult:
	if is_dead:
		return DamageResult.new()
	var exposed := is_exposed()
	var result := DamageModel.resolve(hit.damage, hit.type, shield, armor(), hull, EXPOSED_HULL_MULT if exposed else 1.0)
	result.position = hit.position
	result.exposed = exposed
	result.shield_broken = shield > 0.0 and result.shield_left <= 0.0 and not god_mode
	if god_mode:
		result.destroyed = false
		result.shield_left = shield
		result.hull_left = hull
	else:
		shield = result.shield_left
		hull = result.hull_left
	_since_hit = 0.0
	if result.shield_broken:
		exposed_left = EXPOSED_SECONDS
	damaged.emit(result)
	EventBus.ship_hit.emit(get_parent(), result)
	if result.shield_broken:
		shield_broken.emit()
		EventBus.shield_broken.emit(get_parent())
	if result.destroyed:
		is_dead = true
		destroyed.emit(hit.source)
		EventBus.ship_destroyed.emit(get_parent(), hit.source)
	return result


func _physics_process(delta: float) -> void:
	step(delta)


## Advances shield regeneration by [param delta] seconds.
func step(delta: float) -> void:
	if is_dead or _stats == null:
		return
	_since_hit += delta
	exposed_left = maxf(exposed_left - delta, 0.0)
	if not is_exposed() and _since_hit >= _stats.get_stat(Stats.SHIELD_DELAY) and shield < max_shield():
		shield = minf(shield + _stats.get_stat(Stats.SHIELD_REGEN) * delta, max_shield())


## When a maximum grows (fitting a shield capacitor) the current value grows with it; when it
## shrinks, the current value is clamped down.
func _on_stats_changed() -> void:
	if is_dead:
		return
	shield = clampf(shield + maxf(max_shield() - _last_max_shield, 0.0), 0.0, max_shield())
	hull = clampf(hull + maxf(max_hull() - _last_max_hull, 0.0), 0.0, max_hull())
	_last_max_shield = max_shield()
	_last_max_hull = max_hull()
