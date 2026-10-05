extends "res://tests/helpers/ship_test.gd"
## Projectiles against real physics bodies. These await physics frames so the ray casts
## see the ships' real positions.

const ASTEROID_SCENE := preload("res://scenes/arena/asteroid.tscn")

var shooter: Ship


func before_each() -> void:
	shooter = make_ship(Ship.TEAM_PLAYER, Vector3.ZERO)


func _fire(data: ProjectileData, origin: Vector3, direction: Vector3, target: Ship = null) -> Projectile:
	return Projectile.spawn(self, data, shooter, origin, direction, target)


func test_a_projectile_damages_the_enemy_it_hits_and_disappears() -> void:
	var enemy := make_ship(Ship.TEAM_ENEMY, Vector3(0, 0, -20))
	await settle()
	var shot := _fire(weapon(&"pulse_laser").projectile, Vector3(0, 0, -3), Vector3.FORWARD)
	await wait_physics_frames(40)
	assert_lt(enemy.health.shield, 100.0, "the bolt landed")
	assert_false(is_instance_valid(shot), "and was consumed")


func test_projectiles_fly_through_friendly_ships() -> void:
	var friend := make_ship(Ship.TEAM_PLAYER, Vector3(0, 0, -10))
	var enemy := make_ship(Ship.TEAM_ENEMY, Vector3(0, 0, -22))
	await settle()
	_fire(weapon(&"pulse_laser").projectile, Vector3(0, 0, -3), Vector3.FORWARD)
	await wait_physics_frames(50)
	assert_eq(friend.health.shield, 100.0, "no friendly fire")
	assert_lt(enemy.health.shield, 100.0, "but it carried on to the enemy")


func test_the_shooter_is_never_hit_by_its_own_shot() -> void:
	await settle()
	_fire(weapon(&"pulse_laser").projectile, Vector3.ZERO, Vector3.FORWARD)
	await wait_physics_frames(5)
	assert_eq(shooter.health.shield, 100.0)


func test_asteroids_block_projectiles() -> void:
	var rock := ASTEROID_SCENE.instantiate() as Node3D
	add_child_autofree(rock)
	rock.global_position = Vector3(0, 0, -10)
	var enemy := make_ship(Ship.TEAM_ENEMY, Vector3(0, 0, -22))
	await settle()
	var shot := _fire(weapon(&"pulse_laser").projectile, Vector3(0, 0, -3), Vector3.FORWARD)
	await wait_physics_frames(50)
	assert_eq(enemy.health.shield, 100.0, "cover works")
	assert_false(is_instance_valid(shot))


func test_pierce_passes_through_that_many_extra_ships() -> void:
	var targets: Array[Ship] = []
	for z in [-10.0, -16.0, -22.0, -28.0]:
		targets.append(make_ship(Ship.TEAM_ENEMY, Vector3(0, 0, z)))
	await settle()
	_fire(weapon(&"railgun").projectile, Vector3(0, 0, -3), Vector3.FORWARD)  # pierce 2
	await wait_physics_frames(30)
	assert_lt(targets[0].health.shield, 100.0, "first ship hit")
	assert_lt(targets[1].health.shield, 100.0, "second ship hit (pierce 1)")
	assert_lt(targets[2].health.shield, 100.0, "third ship hit (pierce 2)")
	assert_eq(targets[3].health.shield, 100.0, "fourth ship is behind the pierce limit")


func test_a_pierce_shot_is_still_stopped_by_an_asteroid() -> void:
	var rock := ASTEROID_SCENE.instantiate() as Node3D
	add_child_autofree(rock)
	rock.global_position = Vector3(0, 0, -16)
	var near := make_ship(Ship.TEAM_ENEMY, Vector3(0, 0, -9))
	var far := make_ship(Ship.TEAM_ENEMY, Vector3(0, 0, -24))
	await settle()
	_fire(weapon(&"railgun").projectile, Vector3(0, 0, -3), Vector3.FORWARD)
	await wait_physics_frames(30)
	assert_lt(near.health.shield, 100.0)
	assert_eq(far.health.shield, 100.0)


func test_projectiles_expire_after_their_lifetime() -> void:
	var data := make_projectile_data(10.0, 5.0)
	data.lifetime = 0.2
	var shot := _fire(data, Vector3(0, 0, -5), Vector3.FORWARD)
	await wait_physics_frames(25)
	assert_false(is_instance_valid(shot))


func test_a_fast_projectile_does_not_tunnel_through_a_ship() -> void:
	var enemy := make_ship(Ship.TEAM_ENEMY, Vector3(0, 0, -30))
	await settle()
	var data := make_projectile_data(900.0, 10.0)  # 15 m per physics tick, far wider than the ship
	_fire(data, Vector3(0, 0, -3), Vector3.FORWARD)
	await wait_physics_frames(6)
	assert_lt(enemy.health.shield, 100.0)


func test_the_hit_applies_the_projectiles_damage_type() -> void:
	var enemy := make_ship(Ship.TEAM_ENEMY, Vector3(0, 0, -15))
	await settle()
	_fire(make_projectile_data(80.0, 10.0, Damage.Type.ENERGY), Vector3(0, 0, -3), Vector3.FORWARD)
	await wait_physics_frames(30)
	assert_almost_eq(enemy.health.shield, 100.0 - 15.0, 0.01, "energy does x1.5 to shields")


func test_projectiles_move_in_the_play_plane() -> void:
	var shot := _fire(make_projectile_data(30.0, 1.0), Vector3(0, 5, 0), Vector3(0, 0.5, -1))
	await wait_physics_frames(10)
	assert_eq(shot.global_position.y, 0.0)


# --- Homing ----------------------------------------------------------------------------

func test_a_homing_missile_turns_toward_its_target_and_hits_it() -> void:
	var enemy := make_ship(Ship.TEAM_ENEMY, Vector3(0, 0, -30))
	await settle()
	var data := make_projectile_data(20.0, 10.0, Damage.Type.EXPLOSIVE)
	data.homing_deg_per_sec = 200.0
	data.lifetime = 5.0
	var missile := _fire(data, Vector3(6, 0, 0), Vector3.RIGHT, enemy)  # Launched sideways.
	await wait_physics_frames(15)
	assert_lt(missile.direction.z, -0.2, "already bending toward the target")
	await wait_physics_frames(200)
	assert_lt(enemy.health.shield, 100.0, "it found the target")


func test_a_straight_projectile_ignores_the_target_it_is_given() -> void:
	var enemy := make_ship(Ship.TEAM_ENEMY, Vector3(0, 0, -30))
	var shot := _fire(make_projectile_data(20.0, 10.0), Vector3(6, 0, 0), Vector3.RIGHT, enemy)
	assert_null(shot.target, "homing_deg_per_sec is 0")
	await wait_physics_frames(10)
	assert_almost_eq(shot.direction, Vector3.RIGHT, Vector3.ONE * 0.0001)


func test_a_homing_missile_flies_on_when_its_target_dies() -> void:
	var enemy := make_ship(Ship.TEAM_ENEMY, Vector3(0, 0, -40))
	await settle()
	var data := make_projectile_data(20.0, 10.0)
	data.homing_deg_per_sec = 200.0
	var missile := _fire(data, Vector3(6, 0, 0), Vector3.RIGHT, enemy)
	enemy.health.shield = 0.0
	enemy.health.apply_hit(Hit.make(10000.0, Damage.Type.KINETIC, null, Vector3.ZERO))
	await wait_physics_frames(10)
	assert_null(missile.target)
	assert_almost_eq(missile.direction, Vector3.RIGHT, Vector3.ONE * 0.0001)


# --- Blast -----------------------------------------------------------------------------

func test_a_blast_hurts_nearby_enemies_but_not_far_ones_or_friends() -> void:
	var hit_ship := make_ship(Ship.TEAM_ENEMY, Vector3(0, 0, -20))
	var near := make_ship(Ship.TEAM_ENEMY, Vector3(4.0, 0, -20))   # within blast 3 + hull radius 1.7
	var far := make_ship(Ship.TEAM_ENEMY, Vector3(14, 0, -20))
	var friend := make_ship(Ship.TEAM_PLAYER, Vector3(-4.0, 0, -20))
	await settle()
	_fire(weapon(&"missile_pod").projectile, Vector3(0, 0, -5), Vector3.FORWARD)
	await wait_physics_frames(60)
	assert_lt(hit_ship.health.shield, 100.0, "the ship it hit")
	assert_lt(near.health.shield, 100.0, "caught in the blast")
	assert_eq(far.health.shield, 100.0, "outside the blast")
	assert_eq(friend.health.shield, 100.0, "friendly ships are never harmed")


func test_a_blast_damages_each_ship_once() -> void:
	var enemy := make_ship(Ship.TEAM_ENEMY, Vector3(0, 0, -20))
	await settle()
	var data := make_projectile_data(40.0, 10.0, Damage.Type.EXPLOSIVE)
	data.blast_radius = 3.0
	_fire(data, Vector3(0, 0, -5), Vector3.FORWARD)
	await wait_physics_frames(40)
	assert_almost_eq(enemy.health.shield, 100.0 - 10.0 * 0.5, 0.01, "one hit of 10 explosive = 5 shield damage")


func test_an_explosive_missile_detonates_on_an_asteroid() -> void:
	var rock := ASTEROID_SCENE.instantiate() as Node3D
	add_child_autofree(rock)
	rock.global_position = Vector3(0, 0, -12)
	var enemy := make_ship(Ship.TEAM_ENEMY, Vector3(0, 0, -16))  # Right behind the rock, inside the blast.
	await settle()
	var data := make_projectile_data(40.0, 10.0, Damage.Type.EXPLOSIVE)
	data.blast_radius = 6.0
	_fire(data, Vector3(0, 0, -3), Vector3.FORWARD)
	await wait_physics_frames(40)
	assert_lt(enemy.health.shield, 100.0, "splash reaches around cover")
