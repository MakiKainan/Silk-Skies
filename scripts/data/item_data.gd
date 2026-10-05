class_name ItemData
extends Resource
## Base for everything that can sit in a hardpoint or the cargo hold. Authored content:
## never modified at runtime. A specific drop is an ItemInstance (rarity + rolled stats).

@export var id: StringName
@export var display_name: String = ""
@export_multiline var description: String = ""
## Stat lines a drop of this item can roll. Null = never rolls.
@export var roll_pool: RollPool
## Passive effects while equipped. For a techmod that's its whole point; for a crew
## member it's the station bonus; weapons usually have none.
@export var base_mods: Array[StatMod] = []
## Name of the Q/E/R ability this item grants. Shown in the UI; combat support arrives later.
@export var active_name: String = ""
@export_multiline var active_description: String = ""


## Which kind of hardpoint this item mounts on.
func slot_type() -> HardpointData.Type:
	return HardpointData.Type.TURRET


## Turret items only: the smallest turret that fits.
func slot_size() -> HardpointData.Size:
	return HardpointData.Size.SMALL


func category_name() -> String:
	return "Item"
