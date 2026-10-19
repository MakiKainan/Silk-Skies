class_name AISkill
extends Resource
## How GOOD an AI pilot is, separate from how it likes to fight (its AIProfile). The same
## profile at a rookie skill reacts late, half-leads its shots, misreads turns, zones out now
## and then and rarely dodges; at an ace skill it plays like the raw profile.
## AIDifficulty picks a blend of the presets in data/ai_skill/ for each duel.

@export var id: StringName
@export var display_name: String = ""

@export_group("Aim")
## Multiplies the profile's reaction_time: how late its picture of the target is.
@export var reaction_scale: float = 1.0
## Multiplies the profile's aim_error_deg.
@export var aim_error_scale: float = 1.0
## How much of the needed lead it actually applies, 0..1. Below 1 its shots trail a moving target.
@export_range(0.0, 1.0, 0.05) var lead_fraction: float = 1.0
## It misjudges which way the target is heading by up to this many degrees (re-rolled each shot).
@export var heading_error_deg: float = 0.0

@export_group("Attention")
## Seconds between attention lapses (picked between 0.5x and 1.5x this each time).
@export var lapse_every: float = 8.0
## During a lapse its picture of the target freezes. 0 = never lapses.
@export var lapse_duration: float = 0.0

@export_group("Evasion")
## Chance to try to dodge each incoming shot (only for profiles with dodge_burn).
@export_range(0.0, 1.0, 0.05) var dodge_chance: float = 1.0
## Seconds a shot must be on course before it reacts; fast shots can land first.
@export var dodge_delay: float = 0.0


## A new skill part-way between [param a] (t = 0) and [param b] (t = 1).
static func blend(a: AISkill, b: AISkill, t: float) -> AISkill:
	var out := AISkill.new()
	out.id = a.id if t < 0.5 else b.id
	out.display_name = a.display_name if t < 0.5 else b.display_name
	for property: StringName in [&"reaction_scale", &"aim_error_scale", &"lead_fraction", &"heading_error_deg",
			&"lapse_every", &"lapse_duration", &"dodge_chance", &"dodge_delay"]:
		out.set(property, lerpf(float(a.get(property)), float(b.get(property)), t))
	return out
