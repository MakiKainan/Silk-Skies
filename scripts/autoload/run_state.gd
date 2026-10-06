extends Node
## Autoload. The current run: which hull and gear the player has, which act they're fighting
## through and how far along it they are. The sandbox and the duel scene both read this, so gear
## carries between them. (Hull damage carry-over, scrap and the seed-saved run arrive with the
## full loop in M4.)

## Cargo cells for a new loadout. The sandbox is roomier than a real run (4).
var cargo_capacity: int = 12

var player_hull: HullData
var loadout: ShipLoadout
var act: ActData
var duel_index: int = 0
var seed_value: int = 0
var last_result: DuelResult


## Makes sure there is a player hull and loadout, building the starter ones if not (the starter
## frigate with a Pulse Laser and a Railgun). Returns true if it had to create them.
func ensure_player() -> bool:
	if player_hull != null and loadout != null:
		return false
	player_hull = ContentDB.get_hull(&"starter_frigate")
	loadout = ShipLoadout.new(player_hull, cargo_capacity)
	loadout.set_item(ShipLoadout.Kind.SLOT, 0, ItemInstance.make(ContentDB.get_by_id(&"pulse_laser") as ItemData))
	loadout.set_item(ShipLoadout.Kind.SLOT, 1, ItemInstance.make(ContentDB.get_by_id(&"railgun") as ItemData))
	return true


## Forgets the player's gear (a fresh run, or tests).
func reset() -> void:
	player_hull = null
	loadout = null
	act = null
	duel_index = 0
	last_result = null


func start_act(new_act: ActData) -> void:
	act = new_act
	duel_index = 0
	last_result = null
	seed_value = randi()


func duel_count() -> int:
	return act.encounters.size() if act != null else 0


func current_enemy() -> EnemyData:
	if act == null or duel_index >= act.encounters.size():
		return null
	return act.encounters[duel_index]


func has_next() -> bool:
	return act != null and duel_index + 1 < act.encounters.size()


## Moves to the next encounter. Returns false if the act was already on its last one.
func advance() -> bool:
	if not has_next():
		return false
	duel_index += 1
	last_result = null
	return true


## A fresh RNG for the current duel, the same every time for the same run seed and duel, so a
## retry fights the same enemy with the same rolls. [param salt] separates uses.
func make_rng(salt: int = 0) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([seed_value, duel_index, salt])
	return rng
