extends "res://tests/helpers/ship_test.gd"
## Balance probe, NOT part of the normal suite (no `test_` prefix). Run on demand:
##   godot --headless --fixed-fps 60 --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/probe/probe_balance.gd
## An AI-driven starter frigate (the default Pulse Laser + Railgun loadout) fights each enemy a few
## times; prints how long each duel took and who won. Use it to tune HP and damage against the spec's
## 1-3 minute target. The bot is a stand-in for a competent but imperfect human.

const MAX_SECONDS := 300.0
const SEEDS := [1, 2, 3, 4]


func _bot_profile(dodge: bool, aim_error: float, reaction: float) -> AIProfile:
	var profile := AIProfile.new()
	profile.id = &"probe_bot"
	profile.preferred_range = 22.0
	profile.range_band = 6.0
	profile.orbit_lead_deg = 30.0
	profile.reaction_time = reaction
	profile.aim_error_deg = aim_error
	profile.dodge_burn = dodge
	return profile


func _fight(enemy_id: StringName, seed_value: int, bot_profile: AIProfile) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var bot_data := EnemyData.new()
	bot_data.id = &"probe_bot"
	bot_data.hull = ContentDB.get_hull(&"starter_frigate")
	bot_data.ai_profile = bot_profile
	for entry in [[&"pulse_laser", &"Turret_A"], [&"railgun", &"Turret_B"]]:
		var spec := ItemSpec.new()
		spec.item = ContentDB.get_by_id(entry[0]) as ItemData
		spec.slot = entry[1]
		bot_data.loadout.append(spec)
	var bot := EnemyFactory.spawn(self, bot_data, Vector3(0, 0, 18), 0.0, rng)
	bot.team = Ship.TEAM_PLAYER
	bot.free_on_death = false
	var enemy := EnemyFactory.spawn(self, ContentDB.get_by_id(enemy_id) as EnemyData, Vector3(0, 0, -18), PI, rng)
	enemy.free_on_death = false
	var seconds := 0.0
	while bot.is_alive() and enemy.is_alive() and seconds < MAX_SECONDS:
		await wait_physics_frames(60)
		seconds += 1.0
	var result := {
		"seconds": seconds,
		"winner": "bot" if bot.is_alive() and not enemy.is_alive() else ("enemy" if enemy.is_alive() and not bot.is_alive() else "none"),
		"bot_hull": bot.health.hull / bot.health.max_hull(),
		"enemy_hull": enemy.health.hull / enemy.health.max_hull(),
	}
	bot.queue_free()
	enemy.queue_free()
	await wait_physics_frames(3)
	clear_projectiles()
	return result


func test_probe_duel_lengths() -> void:
	for enemy_id in [&"enemy_raider", &"enemy_longshot", &"enemy_warden"]:
		for style in [["sloppy", _bot_profile(false, 7.0, 0.6)], ["sharp", _bot_profile(true, 3.0, 0.3)]]:
			var times: Array[float] = []
			var wins := 0
			var hull_left := 0.0
			var enemy_left := 0.0
			for seed_value in SEEDS:
				var r: Dictionary = await _fight(enemy_id, seed_value, style[1])
				times.append(r.seconds)
				if r.winner == "bot":
					wins += 1
				hull_left += r.bot_hull
				enemy_left += r.enemy_hull
			var average := 0.0
			for t in times:
				average += t
			average /= times.size()
			gut.p("%-16s vs %-7s bot: avg %5.1f s (min %3.0f max %3.0f)  bot wins %d/%d  (avg hull left: bot %3.0f%%, enemy %3.0f%%)" % [enemy_id, style[0], average, times.min(), times.max(), wins, SEEDS.size(), hull_left / SEEDS.size() * 100.0, enemy_left / SEEDS.size() * 100.0])
	assert_true(true)
