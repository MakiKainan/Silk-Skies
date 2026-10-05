class_name Rarity
extends RefCounted
## Item rarity. Rarity decides how many rolled stat lines an item gets (spec 3.2).
## Legendary is reserved for unique named items (P4) and is never generated in the slice.

enum Type { COMMON, RARE, EPIC, LEGENDARY }

const NAMES := ["Common", "Rare", "Epic", "Legendary"]
const COLORS := [Color(0.78, 0.78, 0.8), Color(0.35, 0.62, 1.0), Color(0.72, 0.42, 1.0), Color(1.0, 0.65, 0.2)]
const ROLL_COUNTS := [0, 1, 2, 2]
## Epic (and Legendary) rolls are this much bigger than the template's range.
const EPIC_SCALE := 1.5


static func display_name(rarity: Type) -> String:
	return NAMES[rarity]


static func color(rarity: Type) -> Color:
	return COLORS[rarity]


static func roll_count(rarity: Type) -> int:
	return ROLL_COUNTS[rarity]


static func roll_scale(rarity: Type) -> float:
	return EPIC_SCALE if rarity >= Type.EPIC else 1.0
