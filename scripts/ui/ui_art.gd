class_name UiArt
extends RefCounted
## Art for the UI chrome: panels, slot frames, bars and glyphs, found by file name under
## `res://assets/ui/` (through ArtLookup, so the same cache and extension rules apply).
## Every getter returns null when the file is missing, and callers then build the old
## StyleBoxFlat / ProgressBar placeholder. Greyscale or white art is tinted at runtime.

const PANEL := "ui/frames/panel"
const SLOT_FRAME := "ui/frames/slot_frame"
const DISCARD := "ui/frames/icon_discard"
const BAR_FRAME := "ui/hud/bar_frame"
const BOSS_BAR_FRAME := "ui/hud/boss_bar_frame"
const BAR_FILL := "ui/hud/bar_fill"

const GLYPHS := {
	HardpointData.Type.TURRET: "ui/frames/glyph_turret",
	HardpointData.Type.FIGHTER_BAY: "ui/frames/glyph_bay",
	HardpointData.Type.TECHMOD: "ui/frames/glyph_techmod",
	HardpointData.Type.CREW_SEAT: "ui/frames/glyph_crew",
}
const DAMAGE_ICONS := {
	Damage.Type.ENERGY: "ui/hud/dmg_energy",
	Damage.Type.KINETIC: "ui/hud/dmg_kinetic",
	Damage.Type.EXPLOSIVE: "ui/hud/dmg_explosive",
}

## Nine-patch margins and fill insets, in texture pixels, measured on the shipped art.
const PANEL_MARGIN := 30.0
const SLOT_MARGIN := 14.0
const BAR_FRAME_MARGINS := Vector4(14.0, 10.0, 14.0, 10.0)
const BAR_INSET := Vector4(10.0, 10.0, 10.0, 10.0)
const BOSS_FRAME_MARGINS := Vector4(40.0, 54.0, 40.0, 34.0)
const BOSS_INSET := Vector4(32.0, 54.0, 32.0, 34.0)
const FILL_MARGINS := Vector4(24.0, 0.0, 24.0, 0.0)


static func texture(stem: String) -> Texture2D:
	return ArtLookup.find(null, stem, ArtLookup.TEXTURE_EXT) as Texture2D


## Large window panel (refit, duel preview/result, tooltip), or null.
static func panel_style() -> StyleBoxTexture:
	var tex := texture(PANEL)
	if tex == null:
		return null
	var style := _nine(tex, Vector4(PANEL_MARGIN, PANEL_MARGIN, PANEL_MARGIN, PANEL_MARGIN))
	style.set_content_margin_all(18.0)
	return style


## Item slot frame tinted [param tint] (rarity, category or drop highlight), or null.
static func slot_style(tint: Color) -> StyleBoxTexture:
	var tex := texture(SLOT_FRAME)
	if tex == null:
		return null
	var style := _nine(tex, Vector4(SLOT_MARGIN, SLOT_MARGIN, SLOT_MARGIN, SLOT_MARGIN))
	style.modulate_color = tint.lightened(0.15)
	style.set_content_margin_all(6.0)
	return style


static func glyph(type: HardpointData.Type) -> Texture2D:
	return texture(GLYPHS[type])


static func damage_icon(type: Damage.Type) -> Texture2D:
	return texture(DAMAGE_ICONS[type])


## [param name] is one of shield, hull, armor, burn.
static func status_icon(name: String) -> Texture2D:
	return texture("ui/hud/icon_%s" % name)


## A bar tinted [param tint]: an ArtBar when the bar art exists, else a flat ProgressBar.
## Both are Ranges (0..1), so callers just set `value`.
static func make_bar(tint: Color, size: Vector2, boss: bool = false) -> Range:
	var frame := texture(BOSS_BAR_FRAME if boss else BAR_FRAME)
	var fill := texture(BAR_FILL)
	var bar: Range
	if frame != null and fill != null:
		var art := ArtBar.new()
		if boss:
			art.setup(frame, BOSS_FRAME_MARGINS, BOSS_INSET, fill, FILL_MARGINS, tint)
		else:
			art.setup(frame, BAR_FRAME_MARGINS, BAR_INSET, fill, FILL_MARGINS, tint)
		bar = art
	else:
		var flat := ProgressBar.new()
		flat.show_percentage = false
		var style := StyleBoxFlat.new()
		style.bg_color = tint
		flat.add_theme_stylebox_override(&"fill", style)
		bar = flat
	bar.custom_minimum_size = size
	bar.step = 0.001  # A bare Range steps by whole numbers, which would snap a 0..1 bar to 0 or 1.
	bar.max_value = 1.0
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return bar


## A small TextureRect for an icon, or null when there is no texture.
static func icon_rect(tex: Texture2D, size: float, tint: Color = Color.WHITE) -> TextureRect:
	if tex == null:
		return null
	var rect := TextureRect.new()
	rect.texture = tex
	rect.custom_minimum_size = Vector2(size, size)
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.modulate = tint
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return rect


static func _nine(tex: Texture2D, margins: Vector4) -> StyleBoxTexture:
	var style := StyleBoxTexture.new()
	style.texture = tex
	style.texture_margin_left = margins.x
	style.texture_margin_top = margins.y
	style.texture_margin_right = margins.z
	style.texture_margin_bottom = margins.w
	return style
