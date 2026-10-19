class_name AIDifficulty
extends RefCounted
## Picks how skilled the enemy pilot is for a duel: the run's difficulty sets the range, and the
## duel's place in the act sets where in that range it sits (first duel = low end, last = high).
## Skill levels: 0 = rookie, 1 = veteran, 2 = ace (the presets in data/ai_skill/), blended between.

enum Level { EASY, NORMAL, HARD }

const PRESET_IDS: Array[StringName] = [&"skill_rookie", &"skill_veteran", &"skill_ace"]
## (first duel, last duel) skill level per difficulty.
const RANGES := {
	Level.EASY: Vector2(0.0, 0.5),
	Level.NORMAL: Vector2(0.0, 1.0),
	Level.HARD: Vector2(1.0, 2.0),
}


static func display_name(level: Level) -> String:
	return ["Easy", "Normal", "Hard"][level]


## Skill level (0..2) for duel [param duel_index] of [param duel_count] at [param difficulty].
static func skill_level(difficulty: Level, duel_index: int, duel_count: int) -> float:
	var span: Vector2 = RANGES[difficulty]
	var progress := clampf(float(duel_index) / float(duel_count - 1), 0.0, 1.0) if duel_count > 1 else 0.0
	return lerpf(span.x, span.y, progress)


## The blended skill at [param level] (0..2) from [param presets] (rookie, veteran, ace).
static func skill_at(level: float, presets: Array[AISkill]) -> AISkill:
	var clamped := clampf(level, 0.0, float(presets.size() - 1))
	var low := mini(int(floor(clamped)), presets.size() - 2)
	return AISkill.blend(presets[low], presets[low + 1], clamped - low)


## The presets from ContentDB, in level order.
static func presets() -> Array[AISkill]:
	var out: Array[AISkill] = []
	for id in PRESET_IDS:
		out.append(ContentDB.get_by_id(id) as AISkill)
	return out
