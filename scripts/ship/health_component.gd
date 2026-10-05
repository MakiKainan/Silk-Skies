class_name HealthComponent
extends Node
## A ship's shield and hull. Max values and armor come from the StatsComponent; the
## actual damage maths lives in DamageModel.

signal damaged(result: DamageResult)
signal destroyed(source: Node)

var shield: float = 0.0
var hull: float = 0.0
var is_dead: bool = false
## Sandbox: hits are resolved and reported but nothing is lost.
var god_mode: bool = false

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


func apply_hit(hit: Hit) -> DamageResult:
	if is_dead:
		return DamageResult.new()
	var result := DamageModel.resolve(hit.damage, hit.type, shield, armor(), hull)
	result.position = hit.position
	if god_mode:
		result.destroyed = false
		result.shield_left = shield
		result.hull_left = hull
	else:
		shield = result.shield_left
		hull = result.hull_left
	_since_hit = 0.0
	damaged.emit(result)
	EventBus.ship_hit.emit(get_parent(), result)
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
	if _since_hit >= _stats.get_stat(Stats.SHIELD_DELAY) and shield < max_shield():
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
