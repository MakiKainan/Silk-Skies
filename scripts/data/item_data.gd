class_name ItemData
extends Resource
## Base for everything that can sit in a hardpoint or the cargo hold. Authored content:
## never modified at runtime. A specific drop is an ItemInstance (rarity + rolled stats).

@export var id: StringName
@export var display_name: String = ""
## The lowest rarity this item ever drops at: rolls below it are raised to it, and loot only
## offers it in slots that rolled at least this rarity (strong items stay rare finds).
@export var min_rarity: Rarity.Type = Rarity.Type.COMMON
@export_multiline var description: String = ""
## Stat lines a drop of this item can roll. Null = never rolls.
@export var roll_pool: RollPool
## Passive effects while equipped. For a techmod that's its whole point; for a crew
## member it's the station bonus; weapons usually have none.
@export var base_mods: Array[StatMod] = []
## Name of the Q/E/R ability this item grants. Shown in the UI; combat support arrives later.
@export var active_name: String = ""
## Inventory icon (128x128 PNG). Empty = looked up as assets/icons/items/<id>.png, else the badge.
@export var icon: Texture2D
@export_multiline var active_description: String = ""


## Which kind of hardpoint this item mounts on.
func slot_type() -> HardpointData.Type:
	return HardpointData.Type.TURRET


## Turret items only: the smallest turret that fits.
func slot_size() -> HardpointData.Size:
	return HardpointData.Size.SMALL


func category_name() -> String:
	return "Item"


## The item's name plus what kind of thing it is, e.g. "Tempest (Pulse Laser)". Plain name if
## it has no kind label.
func full_name() -> String:
	return display_name
