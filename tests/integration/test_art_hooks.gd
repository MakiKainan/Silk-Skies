extends "res://tests/helpers/ship_test.gd"
## Real art slots into the game when present, and the box placeholders still appear when not.


func _scene_named(node_name: String) -> PackedScene:
	var root := Node3D.new()
	root.name = node_name
	var scene := PackedScene.new()
	scene.pack(root)
	root.free()
	return scene


func test_a_weapon_without_art_gets_the_box_barrel() -> void:
	var ship := make_ship(Ship.TEAM_PLAYER, Vector3.ZERO)
	ship.equip(0, weapon(&"pulse_laser"))
	var pivot := ship.mounts[0].get_node("BarrelPivot")
	assert_eq(pivot.get_child_count(), 1)
	assert_true(pivot.get_child(0) is MeshInstance3D)


func test_a_barrel_scene_replaces_the_box() -> void:
	var data := weapon(&"pulse_laser").duplicate() as WeaponData
	data.barrel_scene = _scene_named("TestBarrel")
	var ship := make_ship(Ship.TEAM_PLAYER, Vector3.ZERO)
	ship.equip(0, data)
	var pivot := ship.mounts[0].get_node("BarrelPivot")
	assert_not_null(pivot.get_node_or_null("TestBarrel"))
	assert_eq(pivot.get_child_count(), 1, "the box is not built as well")
	ship.mounts[0].aim_barrel(Vector3.FORWARD, 1.0, 0.016)  # Must not need a glow material.
	assert_true(true)


func test_a_projectile_without_art_gets_a_generated_shape() -> void:
	var ship := make_ship(Ship.TEAM_PLAYER, Vector3.ZERO)
	var shot := Projectile.spawn(self, weapon(&"pulse_laser").projectile, ship, Vector3(0, 0, -3), Vector3.FORWARD)
	assert_true(shot.get_child(0) is MeshInstance3D)


func test_a_visual_scene_replaces_the_generated_shape() -> void:
	var data := weapon(&"pulse_laser").projectile.duplicate() as ProjectileData
	data.visual_scene = _scene_named("TestShot")
	var ship := make_ship(Ship.TEAM_PLAYER, Vector3.ZERO)
	var shot := Projectile.spawn(self, data, ship, Vector3(0, 0, -3), Vector3.FORWARD)
	assert_not_null(shot.get_node_or_null("TestShot"))
	assert_eq(shot.get_child_count(), 1)


func test_an_impact_scene_spawns_where_the_shot_lands() -> void:
	var data := weapon(&"pulse_laser").projectile.duplicate() as ProjectileData
	data.impact_scene = _scene_named("TestImpact")
	var shooter := make_ship(Ship.TEAM_PLAYER, Vector3.ZERO)
	make_ship(Ship.TEAM_ENEMY, Vector3(0, 0, -20))
	await settle()
	Projectile.spawn(self, data, shooter, Vector3(0, 0, -3), Vector3.FORWARD)
	await wait_physics_frames(40)
	var impact := get_node_or_null("TestImpact")
	assert_not_null(impact, "the effect appears at the hit")
	if impact != null:
		impact.free()


## Shots parent their sounds to the scene root (no projectile_root group in tests).
func _players() -> Array[Node]:
	return get_tree().root.find_children("*", "AudioStreamPlayer3D", true, false)


func test_a_weapon_without_a_fire_sound_makes_no_sound() -> void:
	var ship := make_ship(Ship.TEAM_PLAYER, Vector3.ZERO)
	ship.equip(0, weapon(&"pulse_laser"))
	var before := _players().size()
	ship.weapons()[0]._spawn_shot(Vector3.FORWARD, null)
	assert_eq(_players().size(), before)


func test_a_fire_sound_plays_on_each_shot() -> void:
	var data := weapon(&"pulse_laser").duplicate() as WeaponData
	data.fire_sound = AudioStreamWAV.new()
	var ship := make_ship(Ship.TEAM_PLAYER, Vector3.ZERO)
	ship.equip(0, data)
	var before := _players().size()
	ship.weapons()[0]._spawn_shot(Vector3.FORWARD, null)
	var players := _players()
	assert_eq(players.size(), before + 1)
	for player in players:
		player.free()
