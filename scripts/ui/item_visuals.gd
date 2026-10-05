class_name ItemVisuals
extends RefCounted
## Placeholder look for items and slots: colour by category, two-letter badge, rarity border.

const SLOT_SIZE := Vector2(72.0, 72.0)


static func category_color(type: HardpointData.Type) -> Color:
	return HardpointMount.TYPE_COLORS[type]


static func category_name(type: HardpointData.Type) -> String:
	match type:
		HardpointData.Type.TURRET:
			return "Turret"
		HardpointData.Type.FIGHTER_BAY:
			return "Fighter Bay"
		HardpointData.Type.TECHMOD:
			return "Techmod"
		_:
			return "Crew Seat"


## "Pulse Laser" -> "PL", "Gunner" -> "GU".
static func badge(data: ItemData) -> String:
	var words := data.display_name.split(" ", false)
	if words.size() >= 2:
		return (words[0].substr(0, 1) + words[1].substr(0, 1)).to_upper()
	return data.display_name.substr(0, 2).to_upper()


## "Turret A - Small, 360 deg arc" for a hardpoint.
static func slot_caption(hardpoint: HardpointData) -> String:
	var name := String(hardpoint.marker_name).replace("_", " ")
	if hardpoint.type != HardpointData.Type.TURRET:
		return name
	var size_name := "Large" if hardpoint.size == HardpointData.Size.LARGE else "Small"
	return "%s - %s, %d deg arc" % [name, size_name, roundi(hardpoint.arc_deg)]


static func slot_style(border: Color, fill: Color, border_width: int = 3) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.set_border_width_all(border_width)
	style.border_color = border
	style.set_corner_radius_all(6)
	style.set_content_margin_all(4)
	return style
