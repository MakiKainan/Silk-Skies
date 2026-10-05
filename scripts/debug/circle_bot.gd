class_name CircleBot
extends Node
## Debug controller: sails in a steady circle. Proves a ship driven by something other
## than PlayerInput is just an ordinary Ship, and gives the sandbox something to bump into.

@export var throttle: float = 0.7
@export var turn: float = 0.4

var _ship: Ship


func _ready() -> void:
	_ship = get_parent() as Ship
	assert(_ship != null, "CircleBot must be a child of a Ship")


func _physics_process(_delta: float) -> void:
	_ship.set_throttle(throttle)
	_ship.set_turn(turn)
