extends GutTest
## Base class for combat tests: builds ships, looks up weapons, steps the simulation by hand.
## Not a test file itself (no `test_` prefix), so GUT skips it.

const SHIP_SCENE := preload("res://scenes/ship/ship.tscn")
const DT := 1.0 / 60.0


func after_each() -> void:
	clear_projectiles()
	# Blast rings and other throwaway effects parented to the test node.
	for child in get_children():
		if child is MeshInstance3D:
			child.free()


func make_ship(team: StringName, pos: Vector3, hull_id: StringName = &"starter_frigate", yaw: float = 0.0) -> Ship:
	var ship := SHIP_SCENE.instantiate() as Ship
	ship.team = team
	ship.free_on_death = false
	add_child_autofree(ship)
	ship.setup(ContentDB.get_hull(hull_id))
	ship.place(pos, yaw)
	return ship


func weapon(id: StringName) -> WeaponData:
	return ContentDB.get_by_id(id) as WeaponData


func make_projectile_data(speed: float, damage: float, type: Damage.Type = Damage.Type.KINETIC) -> ProjectileData:
	var data := ProjectileData.new()
	data.speed = speed
	data.damage = damage
	data.damage_type = type
	data.lifetime = 3.0
	return data


func projectiles() -> Array[Node]:
	return get_tree().get_nodes_in_group(Projectile.GROUP)


func clear_projectiles() -> void:
	for p in projectiles():
		p.free()


## Lets the physics server see the ships' new positions before anything ray-casts.
func settle() -> void:
	await wait_physics_frames(2)


## Advances weapons, projectiles and shield regen by hand, with no real-time waiting.
## Only valid when nothing is awaiting physics frames at the same time.
func sim(seconds: float) -> void:
	for tick in roundi(seconds / DT):
		for node in get_tree().get_nodes_in_group(Ship.GROUP):
			var ship := node as Ship
			ship.health.step(DT)
			for controller in ship.weapons():
				controller.step(DT)
		for p in projectiles():
			(p as Projectile)._physics_process(DT)
