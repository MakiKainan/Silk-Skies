class_name StatInfo
extends RefCounted
## How each stat is named and shown. Pure presentation: the numbers live elsewhere.
## "good" is +1 when higher is better and -1 when lower is better (it decides delta colours).

const INFO := {
	Stats.MAX_HULL: {"label": "Hull", "dec": 0, "unit": "", "good": 1},
	Stats.MAX_SHIELD: {"label": "Shield", "dec": 0, "unit": "", "good": 1},
	Stats.SHIELD_REGEN: {"label": "Shield regen", "dec": 1, "unit": "/s", "good": 1},
	Stats.SHIELD_DELAY: {"label": "Regen delay", "dec": 1, "unit": " s", "good": -1},
	Stats.ARMOR: {"label": "Armor", "dec": 1, "unit": "", "good": 1},
	Stats.MAX_SPEED: {"label": "Max speed", "dec": 1, "unit": " m/s", "good": 1},
	Stats.THRUST: {"label": "Thrust", "dec": 0, "unit": "", "good": 1},
	Stats.MASS: {"label": "Mass", "dec": 0, "unit": "", "good": -1},
	Stats.TURN_RATE: {"label": "Turn rate", "dec": 0, "unit": " deg/s", "good": 1},
	Stats.DRAG: {"label": "Drag", "dec": 2, "unit": "", "good": -1},
	Stats.LATERAL_GRIP: {"label": "Lateral grip", "dec": 1, "unit": "", "good": 1},
	Stats.BURN_IMPULSE: {"label": "Hard Burn power", "dec": 1, "unit": " m/s", "good": 1},
	Stats.BURN_COOLDOWN: {"label": "Hard Burn cooldown", "dec": 1, "unit": " s", "good": -1},
	Stats.DAMAGE: {"label": "Damage", "dec": 1, "unit": "", "good": 1},
	Stats.FIRE_RATE: {"label": "Fire rate", "dec": 2, "unit": "/s", "good": 1},
	Stats.RANGE: {"label": "Range", "dec": 0, "unit": " m", "good": 1},
	Stats.PROJECTILE_SPEED: {"label": "Projectile speed", "dec": 0, "unit": " m/s", "good": 1},
	Stats.TECHMOD_POTENCY: {"label": "Techmod potency", "dec": 0, "unit": "%", "good": 1, "percent": true},
}


static func label(stat: StringName) -> String:
	return INFO[stat].label if INFO.has(stat) else String(stat).capitalize()


static func higher_is_better(stat: StringName) -> bool:
	return not INFO.has(stat) or INFO[stat].good > 0


## A stat value as shown in the stats panel, e.g. "150", "9.5/s", "25%".
static func format_value(stat: StringName, value: float) -> String:
	if not INFO.has(stat):
		return "%.2f" % value
	var info: Dictionary = INFO[stat]
	var shown := value * 100.0 if info.get("percent", false) else value
	return "%s%s" % [_number(shown, info.dec), info.unit]


## A modifier as a tooltip line, e.g. "+50 Shield", "+15% Fire rate (all turrets)".
static func format_mod(mod: StatMod) -> String:
	var line: String
	# Percent-valued stats (potency) are stored as fractions even when added flat.
	var shown_as_percent: bool = mod.op == StatMod.Op.PERCENT or (INFO.has(mod.stat) and INFO[mod.stat].get("percent", false))
	if shown_as_percent:
		line = "%s%s%% %s" % ["+" if mod.value >= 0.0 else "-", _number(absf(mod.value) * 100.0, 0), label(mod.stat)]
	else:
		line = "%s%s %s" % ["+" if mod.value >= 0.0 else "-", _number(absf(mod.value), 1), label(mod.stat)]
	if mod.scope == StatMod.Scope.ALL_TURRETS:
		line += " (all turrets)"
	return line


## A signed change for the stats panel, e.g. "+50" or "-1.5 s"; empty if there's no change.
static func format_delta(stat: StringName, delta: float) -> String:
	if absf(delta) < 0.005:
		return ""
	var dec: int = INFO[stat].dec if INFO.has(stat) else 2
	var scaled := delta * 100.0 if INFO.has(stat) and INFO[stat].get("percent", false) else delta
	var unit := "%" if INFO.has(stat) and INFO[stat].get("percent", false) else ""
	return "%s%s%s" % ["+" if scaled > 0.0 else "-", _number(absf(scaled), dec), unit]


static func _number(value: float, decimals: int) -> String:
	var snapped_value := snappedf(value, pow(10.0, -decimals))
	if decimals == 0 or is_equal_approx(snapped_value, roundf(snapped_value)):
		return "%d" % roundi(snapped_value)
	return ("%." + str(decimals) + "f") % snapped_value
