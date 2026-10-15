class_name HitFeel
extends Node
## Combat juice: camera shake on hits, a short hit-stop on heavy hits, shield breaks and kills,
## and a slow-motion beat when the last enemy dies. Listens to the EventBus; Duel and Sandbox
## add one. Gameplay never knows it exists.
##
## Time effects (hit-stop, slow-mo) change Engine.time_scale and always put back the scale they
## found, so the sandbox's [ ] time controls survive. They are off in headless runs (tests,
## probes) so GUT timing never depends on them; shake is harmless and always on.

## A hit worth this fraction of the victim's max hull counts as fully heavy.
const HEAVY_FRACTION := 0.15
## Heavy hits at or above this weight (0..1) also freeze the action for a moment.
const HIT_STOP_WEIGHT := 0.6
const HIT_STOP_SCALE := 0.05
const HIT_STOP_SECONDS := 0.045
const KILL_STOP_SECONDS := 0.07
const SLOWMO_SCALE := 0.3
const SLOWMO_SECONDS := 0.6

## Master switch for hit-stop and slow-mo (not shake). Defaults off when running headless.
static var time_effects_enabled: bool = DisplayServer.get_name() != "headless"

var camera: FollowCamera
## The player's ship: hits on it shake harder than hits it lands.
var player: Ship

var _restore_scale: float = 1.0
var _until_msec: int = 0
var _active: bool = false


func setup(p_camera: FollowCamera, p_player: Ship) -> void:
	camera = p_camera
	player = p_player


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	EventBus.ship_hit.connect(_on_ship_hit)
	EventBus.shield_broken.connect(_on_shield_broken)
	EventBus.ship_destroyed.connect(_on_ship_destroyed)


func _exit_tree() -> void:
	for connection: Array in [[EventBus.ship_hit, _on_ship_hit], [EventBus.shield_broken, _on_shield_broken], [EventBus.ship_destroyed, _on_ship_destroyed]]:
		if (connection[0] as Signal).is_connected(connection[1]):
			(connection[0] as Signal).disconnect(connection[1])
	if _active:
		Engine.time_scale = _restore_scale
		_active = false


func _process(_delta: float) -> void:
	if _active and Time.get_ticks_msec() >= _until_msec:
		Engine.time_scale = _restore_scale
		_active = false


## 0..1: how heavy [param result] was for [param ship].
static func hit_weight(ship: Ship, result: DamageResult) -> float:
	var max_hull := ship.health.max_hull() if ship != null and ship.health != null else 100.0
	return clampf(result.total_dealt() / maxf(max_hull * HEAVY_FRACTION, 0.001), 0.0, 1.0)


func is_frozen() -> bool:
	return _active


func _on_ship_hit(ship: Node, result: DamageResult) -> void:
	var victim := ship as Ship
	if victim == null:
		return
	var weight := hit_weight(victim, result)
	if victim == player:
		_shake(0.12 + 0.45 * weight)
	elif weight >= 0.3:
		_shake(0.3 * weight)
	if weight >= HIT_STOP_WEIGHT:
		freeze(HIT_STOP_SCALE, HIT_STOP_SECONDS)


func _on_shield_broken(_ship: Node) -> void:
	_shake(0.3)
	freeze(HIT_STOP_SCALE, HIT_STOP_SECONDS)


func _on_ship_destroyed(ship: Node, _source: Node) -> void:
	_shake(0.75)
	var victim := ship as Ship
	if victim != null and victim != player and player != null and is_instance_valid(player) and player.is_alive() and _last_enemy(victim):
		freeze(SLOWMO_SCALE, SLOWMO_SECONDS)
	else:
		freeze(HIT_STOP_SCALE, KILL_STOP_SECONDS)


## Was [param victim] the player's last living enemy?
func _last_enemy(victim: Ship) -> bool:
	for other in player.enemies():
		if other != victim:
			return false
	return true


## Runs the game at [param scale] for [param seconds] of real time, then restores the speed it
## found. Overlapping calls keep the slowest scale and the latest end.
func freeze(scale: float, seconds: float) -> void:
	if not time_effects_enabled:
		return
	if not _active:
		_restore_scale = Engine.time_scale
		_active = true
		Engine.time_scale = scale
	else:
		Engine.time_scale = minf(Engine.time_scale, scale)
	_until_msec = maxi(_until_msec, Time.get_ticks_msec() + roundi(seconds * 1000.0))


func _shake(amount: float) -> void:
	if camera != null and is_instance_valid(camera):
		camera.add_trauma(amount)
