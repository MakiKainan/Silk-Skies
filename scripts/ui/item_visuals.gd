class_name ItemVisuals
extends RefCounted
## Placeholder look for items and slots: colour by category, two-letter badge, rarity border.

const SLOT_SIZE := Vector2(80.0, 80.0)
## Icons are authored at 128x128 and drawn at this size inside a slot.
const ICON_SIZE := Vector2(42.0, 42.0)


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


## Slot frame tinted [param border]. Uses the textured frame from assets/ui/frames when it
## exists (then [param fill] and [param border_width] are ignored), else a flat box.
static func slot_style(border: Color, fill: Color, border_width: int = 3) -> StyleBox:
	var art := UiArt.slot_style(border)
	if art != null:
		return art
	return flat_style(border, fill, border_width)


## Window panel: the textured panel when it exists, else a flat box.
static func panel_style() -> StyleBox:
	var art := UiArt.panel_style()
	if art != null:
		return art
	return flat_style(Color(0.3, 0.34, 0.45), Color(0.06, 0.07, 0.1), 2)


static func flat_style(border: Color, fill: Color, border_width: int = 3) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.set_border_width_all(border_width)
	style.border_color = border
	style.set_corner_radius_all(6)
	style.set_content_margin_all(4)
	return style
