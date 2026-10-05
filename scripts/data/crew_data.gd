class_name CrewData
extends ItemData
## A crew member: a station bonus (base_mods) plus an active ability.

## One-line summary of the station bonus for the tooltip.
@export var station_text: String = ""


func slot_type() -> HardpointData.Type:
	return HardpointData.Type.CREW_SEAT


func category_name() -> String:
	return "Crew"
