extends GutTest
## UI art: the shipped frames/bars are found and measured sensibly, and bars are real 0..1 ranges.


func test_shipped_ui_art_is_found() -> void:
	for stem in [UiArt.PANEL, UiArt.SLOT_FRAME, UiArt.DISCARD, UiArt.BAR_FRAME, UiArt.BOSS_BAR_FRAME, UiArt.BAR_FILL]:
		assert_not_null(UiArt.texture(stem), stem)
	for type in HardpointData.Type.values():
		assert_not_null(UiArt.glyph(type), "glyph for hardpoint type %d" % type)
	for type in Damage.Type.values():
		assert_not_null(UiArt.damage_icon(type), "damage icon %d" % type)
	for status in ["shield", "hull", "armor", "burn"]:
		assert_not_null(UiArt.status_icon(status), status)


func test_missing_art_gives_null_not_an_error() -> void:
	assert_null(UiArt.texture("ui/frames/does_not_exist"))
	assert_null(UiArt.status_icon("nonsense"))
	assert_null(UiArt.icon_rect(null, 32.0))


func test_nine_patch_margins_fit_inside_their_textures() -> void:
	var panel := UiArt.panel_style()
	assert_lt(panel.texture_margin_left * 2.0, panel.texture.get_width())
	assert_lt(panel.texture_margin_top * 2.0, panel.texture.get_height())
	var slot := UiArt.slot_style(Color.WHITE)
	assert_lt(slot.texture_margin_left * 2.0, slot.texture.get_width())


func test_art_bars_take_fractions_not_whole_numbers() -> void:
	var bar := UiArt.make_bar(Color.RED, Vector2(240.0, 18.0))
	autofree(bar)
	assert_true(bar is ArtBar)
	bar.value = 0.4
	assert_almost_eq(bar.value, 0.4, 0.002, "a bare Range would round this to 0")
	assert_almost_eq(bar.ratio, 0.4, 0.002)


func test_boss_bar_uses_the_boss_frame() -> void:
	var bar := UiArt.make_bar(Color.RED, Vector2(440.0, 108.0), true)
	autofree(bar)
	assert_true(bar is ArtBar)


func test_slot_tint_is_applied_to_the_frame() -> void:
	var style := UiArt.slot_style(Color(0.2, 0.4, 1.0))
	assert_gt(style.modulate_color.b, style.modulate_color.r)
