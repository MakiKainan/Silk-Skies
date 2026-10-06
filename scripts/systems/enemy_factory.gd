class_name EnemyFactory
extends RefCounted
## Builds a live enemy ship from an EnemyData recipe. Enemies are ordinary Ship scenes with
## an AIController (and a PhaseController for bosses) in place of the player's input.

const SHIP_SCENE := preload("res://scenes/ship/ship.tscn")


## Spawns the enemy under [param parent], facing [param yaw]. Rolls its items from [param rng],
## so a seeded RNG gives the same enemy every time.
static func spawn(parent: Node, enemy: EnemyData, position: Vector3, yaw: float, rng: RandomNumberGenerator) -> Ship:
	var ship := SHIP_SCENE.instantiate() as Ship
	ship.team = Ship.TEAM_ENEMY
	parent.add_child(ship)
	ship.setup(enemy.hull)
	ship.place(position, yaw)
	for spec in enemy.loadout:
		equip_spec(ship, spec, rng)

	var ai := AIController.new()
	ai.name = "AIController"
	ship.add_child(ai)
	ai.setup(enemy.ai_profile, rng)

	if not enemy.phases.is_empty():
		var phases := PhaseController.new()
		phases.name = "PhaseController"
		ship.add_child(phases)
		phases.setup(enemy.phases, rng)
	return ship


## Mounts one spec on the ship's hardpoint of that name. Returns false (with a warning) if it
## has no such hardpoint or the item doesn't fit.
static func equip_spec(ship: Ship, spec: ItemSpec, rng: RandomNumberGenerator) -> bool:
	var index := hardpoint_index(ship.hull, spec.slot)
	if index < 0 or spec.item == null or not ship.equip_item(index, ItemRoller.roll(spec.item, spec.rarity, rng)):
		push_warning("EnemyFactory: cannot mount %s on '%s' of hull '%s'" % [spec.item.id if spec.item != null else "<null>", spec.slot, ship.hull.id])
		return false
	return true


## Index of the hardpoint whose marker has this name, or -1.
static func hardpoint_index(hull: HullData, marker_name: StringName) -> int:
	for i in hull.hardpoints.size():
		if hull.hardpoints[i].marker_name == marker_name:
			return i
	return -1
